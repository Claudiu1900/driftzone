DriftzoneElectricianBridge = {
    uidCache = {},
    economy = {
        ready = false,
        mode = 'disabled',
        table = nil,
        uidColumn = nil,
        moneyColumn = nil
    }
}

local RESOURCE = GetCurrentResourceName()

local function debugPrint(message)
    if Config.Debug then
        print(('^5[%s:bridge] %s^7'):format(RESOURCE, tostring(message)))
    end
end

local function safeIdentifier(value)
    value = tostring(value or ''):gsub('`', '')
    if not value:match('^[%w_]+$') then return nil end
    return ('`%s`'):format(value)
end

local function started(resource)
    return resource and resource ~= '' and GetResourceState(resource) == 'started'
end

local function firstMatchingColumn(columnSet, candidates)
    for _, name in ipairs(candidates or {}) do
        if columnSet[tostring(name):lower()] then
            return tostring(name)
        end
    end
    return nil
end

function DriftzoneElectricianBridge.GetUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    if DriftzoneElectricianBridge.uidCache[src] then
        return DriftzoneElectricianBridge.uidCache[src]
    end

    local state = Player(src).state
    local stateKeys = { 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }

    for _, key in ipairs(stateKeys) do
        local uid = tonumber(state and state[key])
        if uid and uid > 0 then
            DriftzoneElectricianBridge.uidCache[src] = uid
            return uid
        end
    end

    if started('driftzone_auth') then
        local attempts = {
            function() return exports.driftzone_auth:GetUID(src) end,
            function() return exports.driftzone_auth:GetUid(src) end,
            function() return exports.driftzone_auth:getUID(src) end,
            function() return exports.driftzone_auth:getUid(src) end,
            function() return exports.driftzone_auth:GetUserId(src) end
        }

        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            local uid = tonumber(value)
            if ok and uid and uid > 0 then
                DriftzoneElectricianBridge.uidCache[src] = uid
                return uid
            end
        end
    end

    return nil
end

function DriftzoneElectricianBridge.Notify(src, kind, message, duration)
    TriggerClientEvent('driftzone_electrician:client:notify', src, kind or 'info', tostring(message or ''), duration or 4000)
end

local function detectDatabaseEconomy()
    local wantedAccount = tostring(Config.Economy.payAccount or 'cash'):lower()

    for _, profile in ipairs(Config.Economy.databaseProfiles or {}) do
        local tableName = tostring(profile.table or '')
        if tableName ~= '' then
            local ok, rows = pcall(function()
                return MySQL.query.await([[
                    SELECT COLUMN_NAME
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
                ]], { tableName })
            end)

            if ok and type(rows) == 'table' and #rows > 0 then
                local columns = {}
                for _, row in ipairs(rows) do
                    local name = tostring(row.COLUMN_NAME or row.column_name or '')
                    if name ~= '' then columns[name:lower()] = true end
                end

                local uidColumn = firstMatchingColumn(columns, profile.uidColumns)
                local candidates = wantedAccount == 'bank' and profile.bankColumns or profile.cashColumns
                local moneyColumn = firstMatchingColumn(columns, candidates)

                if uidColumn and moneyColumn then
                    return tableName, uidColumn, moneyColumn
                end
            end
        end
    end

    return nil, nil, nil
end

function DriftzoneElectricianBridge.InitEconomy()
    local requested = tostring(Config.Economy.mode or 'auto'):lower()
    local economy = DriftzoneElectricianBridge.economy

    economy.mode = requested

    if requested == 'auto' or requested == 'database' then
        local tableName, uidColumn, moneyColumn = detectDatabaseEconomy()
        if tableName then
            economy.mode = 'database'
            economy.table = tableName
            economy.uidColumn = uidColumn
            economy.moneyColumn = moneyColumn
            economy.ready = true
            print(('^2[%s] Economie detectata: %s.%s (UID: %s)^7'):format(RESOURCE, tableName, moneyColumn, uidColumn))
            return
        end

        if requested == 'database' then
            economy.mode = 'disabled'
            economy.ready = true
            print(('^1[%s] Nu am gasit coloanele configurate pentru plata in baza de date.^7'):format(RESOURCE))
            return
        end
    end

    if requested == 'export' or requested == 'auto' then
        local exportConfig = Config.Economy.export or {}
        if started(exportConfig.resource) and tostring(exportConfig.name or '') ~= '' then
            economy.mode = 'export'
            economy.ready = true
            print(('^2[%s] Economie prin export: %s:%s^7'):format(RESOURCE, exportConfig.resource, exportConfig.name))
            return
        end
    end

    if requested == 'event' then
        economy.mode = 'event'
        economy.ready = true
        print(('^3[%s] Plata foloseste hook-ul event: %s^7'):format(RESOURCE, tostring(Config.Economy.event)))
        return
    end

    economy.mode = 'disabled'
    economy.ready = true
    print(('^3[%s] Plata este dezactivata. Castigurile vor ramane restante pana configurezi economia.^7'):format(RESOURCE))
end

local function payThroughExport(src, uid, amount, reason)
    local exportConfig = Config.Economy.export or {}
    local resource = tostring(exportConfig.resource or '')
    local name = tostring(exportConfig.name or '')
    if not started(resource) or name == '' then return false end

    local order = tostring(exportConfig.argumentOrder or 'source_uid_amount_reason')
    local ok, result = pcall(function()
        if order == 'uid_amount_reason' then
            return exports[resource][name](uid, amount, reason)
        elseif order == 'source_amount_reason' then
            return exports[resource][name](src, amount, reason)
        elseif order == 'uid_amount' then
            return exports[resource][name](uid, amount)
        end
        return exports[resource][name](src, uid, amount, reason)
    end)

    if not ok then
        print(('^1[%s] Eroare export economie: %s^7'):format(RESOURCE, tostring(result)))
        return false
    end

    return result ~= false
end

function DriftzoneElectricianBridge.AddMoney(src, uid, amount, reason)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    uid = tonumber(uid or 0) or 0
    if amount <= 0 or uid <= 0 then return false end

    local economy = DriftzoneElectricianBridge.economy
    if not economy.ready then return false end

    if economy.mode == 'database' then
        local tableName = safeIdentifier(economy.table)
        local uidColumn = safeIdentifier(economy.uidColumn)
        local moneyColumn = safeIdentifier(economy.moneyColumn)
        if not tableName or not uidColumn or not moneyColumn then return false end

        local query = ('UPDATE %s SET %s = COALESCE(%s, 0) + ? WHERE %s = ? LIMIT 1'):format(
            tableName,
            moneyColumn,
            moneyColumn,
            uidColumn
        )

        local ok, changed = pcall(function()
            return MySQL.update.await(query, { amount, uid })
        end)

        if not ok then
            print(('^1[%s] Plata SQL a esuat: %s^7'):format(RESOURCE, tostring(changed)))
            return false
        end

        return tonumber(changed or 0) > 0
    end

    if economy.mode == 'export' then
        return payThroughExport(src, uid, amount, reason)
    end

    if economy.mode == 'event' then
        TriggerEvent(Config.Economy.event or 'driftzone_electrician:server:addMoney', src, uid, amount, reason)
        return true
    end

    debugPrint(('Plata dezactivata pentru UID %s, suma %s'):format(uid, amount))
    return false
end

AddEventHandler('playerDropped', function()
    DriftzoneElectricianBridge.uidCache[source] = nil
end)
