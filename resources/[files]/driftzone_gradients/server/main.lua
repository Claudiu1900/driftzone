local ActiveSessions = {}
local UidCache = {}
local AdminCache = {}

local function cleanSql(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 5000, tostring(msg or ''))
end

local function getUid(src)
    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then return cached.uid end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, value = pcall(fn)
        local uid = tonumber(value)
        if ok and uid and uid > 0 then
            UidCache[src] = { uid = uid, expires = GetGameTimer() + 30000 }
            return uid
        end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end
    local ok, result = pcall(function() return exports.driftzone_auth:IsLoggedIn(src) end)
    return ok and result == true
end

local function isAduty(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true'
end

local UserColumns = nil

local function getUserColumns()
    if UserColumns then return UserColumns end

    UserColumns = {}

    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM %s'):format(cleanSql(Config.UsersTable or 'users')), {}) or {}
    end)

    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row and row.Field then
                UserColumns[tostring(row.Field)] = true
            end
        end
    end

    return UserColumns
end

local function getAdminData(src)
    local uid = getUid(src)
    if not uid then return nil end
    local cached = AdminCache[uid]
    if cached and cached.expires > GetGameTimer() then return cached.data end

    local cols = getUserColumns()
    local adminCol = tostring(Config.AdminColumn or 'admin_level')
    local fallbackCol = Config.AdminColumnFallback and tostring(Config.AdminColumnFallback) or nil
    local adutyCol = tostring(Config.AdutyColumn or 'aduty')

    local selectParts = {}

    if cols[adminCol] then
        selectParts[#selectParts + 1] = ('%s AS admin_level'):format(cleanSql(adminCol))
    else
        selectParts[#selectParts + 1] = '0 AS admin_level'
    end

    if fallbackCol and fallbackCol ~= '' and cols[fallbackCol] then
        selectParts[#selectParts + 1] = ('%s AS admin_fallback'):format(cleanSql(fallbackCol))
    else
        selectParts[#selectParts + 1] = '0 AS admin_fallback'
    end

    if cols[adutyCol] then
        selectParts[#selectParts + 1] = ('%s AS aduty'):format(cleanSql(adutyCol))
    else
        selectParts[#selectParts + 1] = '0 AS aduty'
    end

    local row = MySQL.single.await((
        'SELECT %s FROM %s WHERE %s = ? LIMIT 1'
    ):format(
        table.concat(selectParts, ', '),
        cleanSql(Config.UsersTable or 'users'),
        cleanSql(Config.UsersIdColumn or 'uid')
    ), { uid })

    if not row then return nil end
    local level = tonumber(row.admin_level or row.admin_fallback or 0) or 0
    local data = { uid = uid, level = level, aduty = isAduty(row.aduty) }
    AdminCache[uid] = { data = data, expires = GetGameTimer() + 2500 }
    return data
end

local function requireAdmin(src)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return false
    end

    local admin = getAdminData(src)
    if not admin or admin.level < (Config.AdminLevel or 6) then
        notify(src, 'warning', 'Nu ai gradul necesar pentru aceasta comanda.')
        return false
    end

    if not admin.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return false
    end

    return true
end

local function getGradient(id)
    id = tonumber(id or 0) or 0
    if id <= 0 then return nil end
    return Config.Gradients and Config.Gradients[id] or nil
end

local function itemIdForGradient(id)
    return tostring(id) .. tostring(Config.InventoryItemSuffix or '_gradient')
end

local function getVehicleStateData(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local state = Entity(entity).state
    local plate = tostring(state.dz_garage_plate or state.dz_vs_plate or GetVehicleNumberPlateText(entity) or '')
    plate = plate:gsub('^%s+', ''):gsub('%s+$', '')

    return {
        entity = entity,
        vehicleId = tonumber(state.dz_garage_db_id or state.vehicleDbId or state.ownedVehicleId or state.dz_vs_sql_id or 0) or 0,
        ownerUid = tonumber(state.dz_garage_owner_uid or state.dz_vs_owner_id or 0) or 0,
        plate = plate
    }
end

local function findVehicleRow(vdata)
    if not vdata then return nil end

    local t = cleanSql(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanSql(Config.OwnedVehiclesIdColumn or 'id')
    local ownerCol = cleanSql(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local plateCol = cleanSql(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')

    if vdata.vehicleId and vdata.vehicleId > 0 then
        return MySQL.single.await(('SELECT %s AS id, %s AS owner_id, %s AS plate FROM %s WHERE %s = ? LIMIT 1'):format(idCol, ownerCol, plateCol, t, idCol), { vdata.vehicleId })
    end

    if vdata.plate and vdata.plate ~= '' then
        return MySQL.single.await(('SELECT %s AS id, %s AS owner_id, %s AS plate FROM %s WHERE TRIM(%s) = TRIM(?) LIMIT 1'):format(idCol, ownerCol, plateCol, t, plateCol), { vdata.plate })
    end

    return nil
end

local function updateVehicleGradient(vehicleId, data)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return false end
    local t = cleanSql(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanSql(Config.OwnedVehiclesIdColumn or 'id')
    local gradCol = cleanSql(Config.OwnedVehiclesGradientColumn or 'gradient')
    local payload = json.encode(data or {})
    local affected = MySQL.update.await(('UPDATE %s SET %s = ? WHERE %s = ? LIMIT 1'):format(t, gradCol, idCol), { payload, vehicleId })
    return affected and affected > 0
end

local function removeGradientItem(uid, gradientId)
    local res = tostring(Config.InventoryResource or 'driftzone_inventory')
    if GetResourceState(res) ~= 'started' then return false, 'inventory_not_started' end

    local itemId = itemIdForGradient(gradientId)
    local ok, result = pcall(function()
        return exports[res]:TakeItem(uid, itemId, 1)
    end)

    return ok and result == true, itemId
end

local function logGradient(src, uid, row, gradient, applyTo, mode, itemRemoved)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO `gradient_logs`
            (`uid`, `player_name`, `vehicle_id`, `plate`, `gradient_id`, `gradient_name`, `apply_to`, `mode`, `item_removed`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]], {
            uid or 0,
            GetPlayerName(src) or 'Unknown',
            row and tonumber(row.id or 0) or 0,
            row and tostring(row.plate or '') or '',
            gradient.id,
            gradient.label or ('Gradient ' .. gradient.id),
            applyTo,
            mode,
            itemRemoved and 1 or 0
        })
    end)
end

RegisterCommand(Config.Command or 'gradient', function(src, args)
    if not requireAdmin(src) then return end

    local gradientId = tonumber(args[1] or 0) or 0
    local gradient = getGradient(gradientId)
    if not gradient then
        notify(src, 'warning', 'Folosire: /gradient id_gradient')
        return
    end

    ActiveSessions[src] = {
        gradientId = gradientId,
        mode = 'admin',
        requireOwner = false,
        removeItem = false,
        expires = GetGameTimer() + 120000
    }

    TriggerClientEvent('driftzone_gradients:client:startSelector', src, {
        gradient = gradient,
        mode = 'admin',
        mainColor = Config.MainColor
    })
end, false)

RegisterNetEvent('driftzone_gradients:server:useGradient', function(gradientId)
    local src = source
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.') end

    gradientId = tonumber(gradientId or 0) or 0
    local gradient = getGradient(gradientId)
    if not gradient then return notify(src, 'warning', 'Gradient invalid.') end

    ActiveSessions[src] = {
        gradientId = gradientId,
        mode = 'item',
        requireOwner = Config.RequireOwnerForTrigger ~= false,
        removeItem = true,
        expires = GetGameTimer() + 120000
    }

    TriggerClientEvent('driftzone_gradients:client:startSelector', src, {
        gradient = gradient,
        mode = 'item',
        mainColor = Config.MainColor
    })
end)

RegisterNetEvent('driftzone_gradients:server:cancel', function()
    ActiveSessions[source] = nil
end)

RegisterNetEvent('driftzone_gradients:server:vehicleSelected', function(netId)
    local src = source
    local session = ActiveSessions[src]
    if not session or session.expires < GetGameTimer() then
        ActiveSessions[src] = nil
        return notify(src, 'warning', 'Selectia a expirat.')
    end

    local gradient = getGradient(session.gradientId)
    if not gradient then return notify(src, 'warning', 'Gradient invalid.') end

    local uid = getUid(src)
    local vdata = getVehicleStateData(netId)
    local row = findVehicleRow(vdata)

    if session.requireOwner then
        if not uid then return notify(src, 'warning', 'Nu ti-am gasit UID-ul.') end
        if not row then return notify(src, 'warning', 'Masina selectata nu este personala.') end
        if tonumber(row.owner_id or 0) ~= tonumber(uid) then
            return notify(src, 'warning', 'Aceasta masina nu iti apartine.')
        end
    end

    ActiveSessions[src].selectedNetId = tonumber(netId)
    ActiveSessions[src].selectedVehicleId = row and tonumber(row.id or 0) or 0
    ActiveSessions[src].selectedPlate = row and tostring(row.plate or '') or (vdata and vdata.plate or '')

    TriggerClientEvent('driftzone_gradients:client:openApplyMenu', src, {
        gradient = gradient,
        plate = ActiveSessions[src].selectedPlate or '',
        mode = session.mode
    })
end)

RegisterNetEvent('driftzone_gradients:server:apply', function(applyTo)
    local src = source
    local session = ActiveSessions[src]
    if not session or session.expires < GetGameTimer() then
        ActiveSessions[src] = nil
        return notify(src, 'warning', 'Selectia a expirat.')
    end

    applyTo = tostring(applyTo or 'both'):lower()
    if applyTo ~= 'primary' and applyTo ~= 'secondary' and applyTo ~= 'both' then
        applyTo = 'both'
    end

    local gradient = getGradient(session.gradientId)
    if not gradient then return notify(src, 'warning', 'Gradient invalid.') end

    local uid = getUid(src)
    local vdata = getVehicleStateData(session.selectedNetId)
    local row = findVehicleRow(vdata)

    if session.requireOwner then
        if not uid then return notify(src, 'warning', 'Nu ti-am gasit UID-ul.') end
        if not row then return notify(src, 'warning', 'Masina selectata nu este personala.') end
        if tonumber(row.owner_id or 0) ~= tonumber(uid) then
            return notify(src, 'warning', 'Aceasta masina nu iti apartine.')
        end
    end

    local itemRemoved = false
    if session.removeItem then
        local okRemove, itemId = removeGradientItem(uid, gradient.id)
        if not okRemove then
            return notify(src, 'warning', ('Nu ai itemul necesar: %s'):format(tostring(itemId or itemIdForGradient(gradient.id))))
        end
        itemRemoved = true
    end

    local saveData = {
        id = gradient.id,
        colorId = gradient.colorId,
        name = gradient.label,
        applyTo = applyTo,
        appliedAt = os.time()
    }

    if row and tonumber(row.id or 0) > 0 then
        updateVehicleGradient(row.id, saveData)
    end

    logGradient(src, uid, row, gradient, applyTo, session.mode, itemRemoved)

    TriggerClientEvent('driftzone_gradients:client:applyGradient', -1, session.selectedNetId, gradient.colorId, applyTo)
    TriggerClientEvent('driftzone_gradients:client:applied', src)
    notify(src, 'success', ('Gradient aplicat: %s.'):format(gradient.label or gradient.id), 5000)

    ActiveSessions[src] = nil
end)

exports('OpenGradient', function(src, gradientId)
    src = tonumber(src or 0) or 0
    gradientId = tonumber(gradientId or 0) or 0
    if src <= 0 or not getGradient(gradientId) then return false end

    ActiveSessions[src] = {
        gradientId = gradientId,
        mode = 'item',
        requireOwner = Config.RequireOwnerForTrigger ~= false,
        removeItem = true,
        expires = GetGameTimer() + 120000
    }

    TriggerClientEvent('driftzone_gradients:client:startSelector', src, {
        gradient = getGradient(gradientId),
        mode = 'item',
        mainColor = Config.MainColor
    })

    return true
end)

AddEventHandler('playerDropped', function()
    ActiveSessions[source] = nil
    UidCache[source] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_GRADIENTS] Loaded.')
end)
