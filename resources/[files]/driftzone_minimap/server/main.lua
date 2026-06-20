local playerStatus = {}
local pendingAdds = {}
local pendingVitals = {}
local triggerCooldowns = {}
local vitalsCooldowns = {}
local loadingPlayers = {}
local warnedPlayers = {}
local forcedUserIds = {}

local databaseReady = false
local databaseFailed = false

local schema = {
    usersTable = nil,
    statsColumn = nil,
    usersColumns = {},
    userIdColumn = nil,
    mappingTables = {}
}

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function safeName(value, fallback)
    local name = tostring(value or fallback or ''):gsub('[^%w_]', '')
    if name == '' then return fallback end
    return name
end

local function normaliseAmount(amount)
    if type(amount) ~= 'number' or amount ~= amount then return nil end
    amount = math.floor(amount)
    if amount < 1 then return nil end
    return clamp(amount, 1, Config.MaxAddPerTrigger)
end

local function queryAwait(query, parameters)
    local ok, result = pcall(function()
        return MySQL.query.await(query, parameters or {})
    end)

    if not ok then
        return nil, result
    end

    return result, nil
end

local function singleAwait(query, parameters)
    local ok, result = pcall(function()
        return MySQL.single.await(query, parameters or {})
    end)

    if not ok then
        return nil, result
    end

    return result, nil
end

local function updateAwait(query, parameters)
    local ok, result = pcall(function()
        return MySQL.update.await(query, parameters or {})
    end)

    if not ok then
        return nil, result
    end

    return result, nil
end

local function getColumns(tableName)
    local rows, err = queryAwait(('SHOW COLUMNS FROM `%s`'):format(tableName))
    if not rows then return nil, err end

    local columns = {}
    for i = 1, #rows do
        local name = rows[i].Field or rows[i].field or rows[i].COLUMN_NAME
        if name then columns[tostring(name)] = true end
    end

    return columns, nil
end

local function pickExistingColumn(columns, candidates)
    for i = 1, #candidates do
        if columns[candidates[i]] then
            return candidates[i]
        end
    end

    return nil
end

local function initializeDatabase()
    schema.usersTable = safeName(Config.Database.UsersTable, 'users')
    schema.statsColumn = safeName(Config.Database.StatsColumn, 'stats')

    local usersColumns, usersError = getColumns(schema.usersTable)
    if not usersColumns then
        databaseFailed = true
        print(('^1[driftzone_minimap] Tabela `%s` nu a fost găsită sau nu poate fi citită: %s^7')
            :format(schema.usersTable, tostring(usersError)))
        return
    end

    if not usersColumns[schema.statsColumn] and Config.Database.AutoCreateStatsColumn then
        local _, alterError = queryAwait(
            ('ALTER TABLE `%s` ADD COLUMN `%s` LONGTEXT NULL'):format(schema.usersTable, schema.statsColumn)
        )

        if alterError then
            databaseFailed = true
            print(('^1[driftzone_minimap] Nu am putut crea `%s`.`%s`: %s^7')
                :format(schema.usersTable, schema.statsColumn, tostring(alterError)))
            return
        end

        usersColumns[schema.statsColumn] = true
        print(('^2[driftzone_minimap] Coloana `%s`.`%s` a fost creată automat.^7')
            :format(schema.usersTable, schema.statsColumn))
    end

    if not usersColumns[schema.statsColumn] then
        databaseFailed = true
        print(('^1[driftzone_minimap] Lipsește coloana `%s`.`%s`.^7')
            :format(schema.usersTable, schema.statsColumn))
        return
    end

    schema.usersColumns = usersColumns

    local configuredId = safeName(Config.Database.UserIdColumn, 'id')
    if usersColumns[configuredId] then
        schema.userIdColumn = configuredId
    else
        schema.userIdColumn = pickExistingColumn(usersColumns, {
            'uid', 'id', 'user_id', 'userId', 'character_id', 'citizenid'
        })
    end

    for _, configuredTable in ipairs(Config.Database.MappingTables or {}) do
        local mappingName = safeName(configuredTable, nil)
        if mappingName then
            local columns = getColumns(mappingName)

            if columns then
                local identifierColumn = pickExistingColumn(columns, {
                    'identifier', 'license', 'steam', 'hex'
                })
                local userIdColumn = pickExistingColumn(columns, {
                    'user_id', 'userid', 'uid', 'id'
                })

                if identifierColumn and userIdColumn then
                    schema.mappingTables[#schema.mappingTables + 1] = {
                        tableName = mappingName,
                        identifierColumn = identifierColumn,
                        userIdColumn = userIdColumn
                    }
                end
            end
        end
    end

    databaseReady = true
    print(('^2[driftzone_minimap] Persistența este activă în `%s`.`%s`.^7')
        :format(schema.usersTable, schema.statsColumn))
end

local function waitForDatabase()
    local timeoutAt = GetGameTimer() + 15000

    while not databaseReady and not databaseFailed and GetGameTimer() < timeoutAt do
        Wait(100)
    end

    return databaseReady
end

local function getPlayerIdentifierData(source)
    local result = {
        all = {},
        byType = {}
    }

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        result.all[#result.all + 1] = identifier

        local prefix, value = identifier:match('^([^:]+):(.+)$')
        if prefix and value then
            result.byType[prefix] = result.byType[prefix] or {}
            result.byType[prefix][#result.byType[prefix] + 1] = identifier
            result.byType[prefix][#result.byType[prefix] + 1] = value
        end
    end

    return result
end

local function decodeStats(rawStats)
    if type(rawStats) == 'table' then return rawStats end
    if type(rawStats) ~= 'string' or rawStats == '' then return {} end

    local ok, decoded = pcall(json.decode, rawStats)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

local function selectUserBy(column, value)
    if not column or value == nil or not schema.usersColumns[column] then return nil end

    local query = ('SELECT `%s` AS `saved_stats` FROM `%s` WHERE `%s` = ? LIMIT 1')
        :format(schema.statsColumn, schema.usersTable, column)
    local row = singleAwait(query, { value })

    if not row then return nil end

    return {
        column = column,
        value = value,
        rawStats = row.saved_stats
    }
end

local function getStateUserId(source)
    local forced = forcedUserIds[source]
    if forced ~= nil then return forced end

    local player = Player(source)
    if not player or not player.state then return nil end

    local state = player.state
    local candidates = {
        state.uid,
        state.dz_uid,
        state.driftzone_uid,
        state.user_id,
        state.userId,
        state.userid,
        state.id,
        state.character_id,
        state.citizenid
    }

    for i = 1, #candidates do
        if candidates[i] ~= nil and tostring(candidates[i]) ~= '' then
            return candidates[i]
        end
    end

    return nil
end


local function getExportUserId(source)
    local attempts = {
        function() return exports.driftzone_auth:GetUID(source) end,
        function() return exports.driftzone_auth:GetUid(source) end,
        function() return exports.driftzone_auth:getUID(source) end,
        function() return exports.driftzone_auth:getUid(source) end,
        function() return exports.driftzone_auth:GetUserId(source) end,
        function() return exports.driftzone_auth:getUserId(source) end
    }

    for i = 1, #attempts do
        local ok, value = pcall(attempts[i])
        if ok and value ~= nil and tostring(value) ~= '' then
            return value
        end
    end

    return nil
end

local function resolveUserRow(source)
    local identifiers = getPlayerIdentifierData(source)

    -- 1. Mapări uzuale: vrp_user_ids.identifier -> users.id.
    if schema.userIdColumn then
        for _, mapping in ipairs(schema.mappingTables) do
            for i = 1, #identifiers.all do
                local query = ('SELECT `%s` AS `mapped_id` FROM `%s` WHERE `%s` = ? LIMIT 1')
                    :format(mapping.userIdColumn, mapping.tableName, mapping.identifierColumn)
                local mapped = singleAwait(query, { identifiers.all[i] })

                if mapped and mapped.mapped_id ~= nil then
                    local row = selectUserBy(schema.userIdColumn, mapped.mapped_id)
                    if row then return row end
                end
            end
        end
    end

    -- 2. Coloane de identifier direct în users.
    local directColumns = {
        identifier = identifiers.all,
        license = identifiers.byType.license,
        license2 = identifiers.byType.license2,
        steam = identifiers.byType.steam,
        discord = identifiers.byType.discord,
        fivem = identifiers.byType.fivem,
        xbl = identifiers.byType.xbl,
        live = identifiers.byType.live
    }

    for column, values in pairs(directColumns) do
        if schema.usersColumns[column] and values then
            for i = 1, #values do
                local row = selectUserBy(column, values[i])
                if row then return row end
            end
        end
    end

    -- 3. User ID pus de framework în state bag sau oferit prin export.
    if schema.userIdColumn then
        local stateUserId = getStateUserId(source)
        if stateUserId ~= nil then
            local row = selectUserBy(schema.userIdColumn, stateUserId)
            if row then return row end
        end

        local exportUserId = getExportUserId(source)
        if exportUserId ~= nil then
            local row = selectUserBy(schema.userIdColumn, exportUserId)
            if row then return row end
        end
    end

    return nil
end

local function createStatus(locator, rawStats)
    local stats = decodeStats(rawStats)
    local now = os.time()

    local health = stats.health
    if health == nil then health = stats.hp end
    if health == nil then health = Config.DefaultHealth end

    local armour = stats.armour
    if armour == nil then armour = stats.armor end
    if armour == nil then armour = Config.DefaultArmour end

    local food = stats.food
    if food == nil then food = stats.hunger end
    if food == nil then food = Config.DefaultFood end

    local water = stats.water
    if water == nil then water = stats.thirst end
    if water == nil then water = Config.DefaultWater end

    return {
        locator = locator,
        health = clamp(round(health), 0, 100),
        armour = clamp(round(armour), 0, 100),
        food = clamp(round(food), 0, 100),
        water = clamp(round(water), 0, 100),
        nextFoodAt = now + math.max(1, math.floor(Config.FoodLossInterval / 1000)),
        nextWaterAt = now + math.max(1, math.floor(Config.WaterLossInterval / 1000)),
        damageMode = nil,
        nextDamageAt = nil,
        dirty = false,
        revision = 0
    }
end

local function markDirty(data)
    data.dirty = true
    data.revision = data.revision + 1
end

local function syncStatus(source, applyVitals)
    local data = playerStatus[source]
    if not data then return end

    TriggerClientEvent('driftzone_minimap:client:syncStatus', source, {
        health = data.health,
        armour = data.armour,
        food = data.food,
        water = data.water,
        applyVitals = applyVitals == true
    })
end

local function saveStatus(data, force)
    if not data or not data.locator then return false end
    if not force and not data.dirty then return true end
    if not databaseReady then return false end

    local locatorColumn = safeName(data.locator.column, nil)
    if not locatorColumn or not schema.usersColumns[locatorColumn] then return false end

    local revisionAtSave = data.revision
    local query = ([=[
        UPDATE `%s`
        SET `%s` = JSON_SET(
            CASE
                WHEN `%s` IS NOT NULL AND JSON_VALID(`%s`) THEN `%s`
                ELSE JSON_OBJECT()
            END,
            '$.health', ?,
            '$.armour', ?,
            '$.food', ?,
            '$.water', ?
        )
        WHERE `%s` = ?
        LIMIT 1
    ]=]):format(
        schema.usersTable,
        schema.statsColumn,
        schema.statsColumn,
        schema.statsColumn,
        schema.statsColumn,
        locatorColumn
    )

    local affected, saveError = updateAwait(query, {
        data.health,
        data.armour,
        data.food,
        data.water,
        data.locator.value
    })

    if affected == nil then
        -- Fallback pentru baze de date fără suport complet JSON_SET.
        local current = selectUserBy(locatorColumn, data.locator.value)
        if not current then
            print(('^1[driftzone_minimap] Salvarea a eșuat: %s^7'):format(tostring(saveError)))
            return false
        end

        local stats = decodeStats(current.rawStats)
        stats.health = data.health
        stats.armour = data.armour
        stats.food = data.food
        stats.water = data.water

        local fallbackQuery = ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ? LIMIT 1')
            :format(schema.usersTable, schema.statsColumn, locatorColumn)
        affected, saveError = updateAwait(fallbackQuery, {
            json.encode(stats),
            data.locator.value
        })

        if affected == nil then
            print(('^1[driftzone_minimap] Salvarea în users.stats a eșuat: %s^7')
                :format(tostring(saveError)))
            return false
        end
    end

    if data.revision == revisionAtSave then
        data.dirty = false
    end

    return true
end

local function applyPendingData(source)
    local data = playerStatus[source]
    if not data then return end

    local pending = pendingAdds[source]
    if pending then
        if pending.food and pending.food > 0 then
            data.food = clamp(data.food + pending.food, 0, 100)
        end

        if pending.water and pending.water > 0 then
            data.water = clamp(data.water + pending.water, 0, 100)
        end

        pendingAdds[source] = nil
        markDirty(data)
    end

    local vitals = pendingVitals[source]
    if vitals then
        data.health = clamp(round(vitals.health), 0, 100)
        data.armour = clamp(round(vitals.armour), 0, 100)
        pendingVitals[source] = nil
        markDirty(data)
    end
end

local function loadStatus(source, applyVitals)
    source = tonumber(source)
    if not source then return end

    if playerStatus[source] then
        syncStatus(source, applyVitals)
        return
    end

    if loadingPlayers[source] then return end
    loadingPlayers[source] = true

    if not waitForDatabase() then
        loadingPlayers[source] = nil
        return
    end

    if not GetPlayerName(source) then
        loadingPlayers[source] = nil
        return
    end

    local locator = resolveUserRow(source)
    if not locator then
        loadingPlayers[source] = nil

        if not warnedPlayers[source] then
            warnedPlayers[source] = true
            print(('^1[driftzone_minimap] Nu am putut găsi jucătorul %s în `%s`. Verifică users.id / vrp_user_ids / license.^7')
                :format(tostring(source), schema.usersTable))
        end

        return
    end

    if not GetPlayerName(source) then
        loadingPlayers[source] = nil
        return
    end

    warnedPlayers[source] = nil
    playerStatus[source] = createStatus(locator, locator.rawStats)
    loadingPlayers[source] = nil

    applyPendingData(source)
    syncStatus(source, applyVitals)

    -- Scrie valorile implicite dacă stats era gol sau invalid.
    if locator.rawStats == nil or locator.rawStats == '' then
        markDirty(playerStatus[source])
        saveStatus(playerStatus[source], true)
    end
end

local function addStatus(source, key, amount)
    source = tonumber(source)
    amount = normaliseAmount(amount)

    if not source or not amount or (key ~= 'food' and key ~= 'water') then
        return false
    end

    local data = playerStatus[source]
    if not data then
        pendingAdds[source] = pendingAdds[source] or { food = 0, water = 0 }
        pendingAdds[source][key] = pendingAdds[source][key] + amount

        CreateThread(function()
            loadStatus(source, false)
        end)
        return true
    end

    local newValue = clamp(data[key] + amount, 0, 100)
    if newValue ~= data[key] then
        data[key] = newValue
        markDirty(data)
    end

    syncStatus(source, false)
    return true
end

local function clientTriggerAllowed(source, triggerName)
    if not Config.AllowClientAddTriggers then return false end

    local now = GetGameTimer()
    triggerCooldowns[source] = triggerCooldowns[source] or {}
    local lastUsed = triggerCooldowns[source][triggerName] or 0

    if now - lastUsed < Config.ClientTriggerCooldown then
        return false
    end

    triggerCooldowns[source][triggerName] = now
    return true
end

AddEventHandler('playerJoining', function()
    scheduleJoinLoad(source, 'playerJoining')
end)

RegisterNetEvent('driftzone_minimap:requestStatus', function(applyVitals)
    local playerSource = source

    CreateThread(function()
        loadStatus(playerSource, applyVitals == true)
    end)
end)

RegisterNetEvent('driftzone_minimap:updateVitals', function(health, armour)
    local playerSource = source
    local now = GetGameTimer()
    local lastUpdate = vitalsCooldowns[playerSource] or 0

    if now - lastUpdate < 500 then return end
    vitalsCooldowns[playerSource] = now

    health = clamp(round(health), 0, 100)
    armour = clamp(round(armour), 0, 100)

    local data = playerStatus[playerSource]
    if not data then
        pendingVitals[playerSource] = {
            health = health,
            armour = armour
        }

        CreateThread(function()
            loadStatus(playerSource, false)
        end)
        return
    end

    if data.health ~= health or data.armour ~= armour then
        data.health = health
        data.armour = armour
        markDirty(data)
    end
end)

RegisterNetEvent('driftzone_minimap:addFood', function(amount)
    local playerSource = source
    if not clientTriggerAllowed(playerSource, 'food') then return end
    addStatus(playerSource, 'food', amount)
end)

RegisterNetEvent('driftzone_minimap:addWater', function(amount)
    local playerSource = source
    if not clientTriggerAllowed(playerSource, 'water') then return end
    addStatus(playerSource, 'water', amount)
end)

AddEventHandler('driftzone_minimap:server:addFood', function(playerSource, amount)
    addStatus(playerSource, 'food', amount)
end)

AddEventHandler('driftzone_minimap:server:addWater', function(playerSource, amount)
    addStatus(playerSource, 'water', amount)
end)

exports('AddFood', function(playerSource, amount)
    return addStatus(playerSource, 'food', amount)
end)

exports('AddWater', function(playerSource, amount)
    return addStatus(playerSource, 'water', amount)
end)

exports('GetStatus', function(playerSource)
    local data = playerStatus[tonumber(playerSource)]
    if not data then return nil end

    return {
        health = data.health,
        armour = data.armour,
        food = data.food,
        water = data.water
    }
end)

-- Pentru framework-uri custom: setează server-side users.id, apoi resursa face load.
exports('LoadForUserId', function(playerSource, userId)
    playerSource = tonumber(playerSource)
    if not playerSource or userId == nil then return false end

    forcedUserIds[playerSource] = userId
    playerStatus[playerSource] = nil

    CreateThread(function()
        loadStatus(playerSource, true)
    end)

    return true
end)


local function applyStatusDamage(source, data, percent)
    source = tonumber(source)
    if not source or not data then return end

    percent = clamp(round(percent), 1, 100)

    if Config.StatusDamage and Config.StatusDamage.ServerAuthoritative == true then
        local minimumHealth = clamp(round(Config.StatusDamage.MinimumHealth or 0), 0, 100)
        local newHealth = clamp(data.health - percent, minimumHealth, 100)

        if newHealth ~= data.health then
            data.health = newHealth
            markDirty(data)
            syncStatus(source, true)
            return
        end
    end

    TriggerClientEvent('driftzone_minimap:client:applyStatusDamage', source, percent)
end

local function scheduleJoinLoad(source, reason)
    source = tonumber(source)
    if not source or (Config.JoinLoad and Config.JoinLoad.Enabled == false) then return end

    CreateThread(function()
        local attempts = tonumber((Config.JoinLoad or {}).Attempts or 30) or 30
        local interval = tonumber((Config.JoinLoad or {}).IntervalMs or 1000) or 1000

        for _ = 1, attempts do
            if not GetPlayerName(source) then return end

            loadStatus(source, true)

            if playerStatus[source] then
                return
            end

            Wait(interval)
        end

        print(('^1[driftzone_minimap] Nu am putut incarca status pentru %s. Reason: %s^7'):format(tostring(source), tostring(reason or 'join')))
    end)
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(250)
    end

    initializeDatabase()

    if databaseReady then
        for _, id in ipairs(GetPlayers()) do
            scheduleJoinLoad(tonumber(id), 'resource_start')
        end
    end

    while true do
        local now = os.time()

        for source, data in pairs(playerStatus) do
            if not GetPlayerName(source) then
                playerStatus[source] = nil
            else
                local changed = false
                local foodInterval = math.max(1, math.floor(Config.FoodLossInterval / 1000))
                local waterInterval = math.max(1, math.floor(Config.WaterLossInterval / 1000))

                if now >= data.nextFoodAt then
                    local elapsedSteps = math.floor((now - data.nextFoodAt) / foodInterval) + 1
                    local newFood = clamp(data.food - (elapsedSteps * Config.FoodLossAmount), 0, 100)
                    data.nextFoodAt = data.nextFoodAt + (elapsedSteps * foodInterval)
                    changed = changed or newFood ~= data.food
                    data.food = newFood
                end

                if now >= data.nextWaterAt then
                    local elapsedSteps = math.floor((now - data.nextWaterAt) / waterInterval) + 1
                    local newWater = clamp(data.water - (elapsedSteps * Config.WaterLossAmount), 0, 100)
                    data.nextWaterAt = data.nextWaterAt + (elapsedSteps * waterInterval)
                    changed = changed or newWater ~= data.water
                    data.water = newWater
                end

                if changed then
                    markDirty(data)
                    syncStatus(source, false)
                end

                local damageMode = nil
                if data.food <= 0 and data.water <= 0 then
                    damageMode = 'both'
                elseif data.food <= 0 or data.water <= 0 then
                    damageMode = 'single'
                end

                if damageMode ~= data.damageMode then
                    data.damageMode = damageMode

                    if damageMode == 'both' then
                        data.nextDamageAt = now + math.max(1, math.floor(Config.BothZeroDamageInterval / 1000))
                    elseif damageMode == 'single' then
                        data.nextDamageAt = now + math.max(1, math.floor(Config.SingleZeroDamageInterval / 1000))
                    else
                        data.nextDamageAt = nil
                    end
                elseif damageMode and data.nextDamageAt and now >= data.nextDamageAt then
                    if damageMode == 'both' then
                        applyStatusDamage(source, data, Config.BothZeroDamagePercent)
                        data.nextDamageAt = now + math.max(1, math.floor(Config.BothZeroDamageInterval / 1000))
                    else
                        applyStatusDamage(source, data, Config.SingleZeroDamagePercent)
                        data.nextDamageAt = now + math.max(1, math.floor(Config.SingleZeroDamageInterval / 1000))
                    end
                end
            end
        end

        Wait(Config.ServerTickInterval)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.DatabaseSaveInterval)

        for _, data in pairs(playerStatus) do
            saveStatus(data, false)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    local data = playerStatus[playerSource]

    if data then
        saveStatus(data, true)
    end

    playerStatus[playerSource] = nil
    pendingAdds[playerSource] = nil
    pendingVitals[playerSource] = nil
    triggerCooldowns[playerSource] = nil
    vitalsCooldowns[playerSource] = nil
    loadingPlayers[playerSource] = nil
    warnedPlayers[playerSource] = nil
    forcedUserIds[playerSource] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if not databaseReady then return end

    for _, data in pairs(playerStatus) do
        saveStatus(data, true)
    end
end)
