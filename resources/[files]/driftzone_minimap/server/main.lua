local playerStatus = {}
local pendingAdds = {}
local triggerCooldowns = {}
local loadingPlayers = {}

local databaseReady = false
local databaseInitializing = false
local databaseCallbacks = {}

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function normaliseAmount(amount)
    if type(amount) ~= 'number' or amount ~= amount then return nil end
    amount = math.floor(amount)
    if amount < 1 then return nil end
    return clamp(amount, 1, Config.MaxAddPerTrigger)
end

local function getPrimaryIdentifier(source)
    local fallback = nil

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        fallback = fallback or identifier
        if identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end

    return fallback
end

local function tableName()
    local configured = tostring(Config.DatabaseTable or 'driftzone_status')
    -- Permitem doar caractere sigure pentru numele tabelului.
    return configured:gsub('[^%w_]', '')
end

local function finishDatabaseInitialisation(success)
    databaseReady = success == true
    databaseInitializing = false

    local callbacks = databaseCallbacks
    databaseCallbacks = {}

    for i = 1, #callbacks do
        callbacks[i](databaseReady)
    end
end

local function ensureDatabase(callback)
    if not Config.UseOxMySQL then
        callback(false)
        return
    end

    if databaseReady then
        callback(true)
        return
    end

    databaseCallbacks[#databaseCallbacks + 1] = callback
    if databaseInitializing then return end

    databaseInitializing = true

    if GetResourceState('oxmysql') ~= 'started' then
        print('^3[driftzone_minimap] oxmysql nu este pornit. Statusurile vor funcționa doar în memorie.^7')
        finishDatabaseInitialisation(false)
        return
    end

    local query = ([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `identifier` VARCHAR(80) NOT NULL,
            `food` TINYINT UNSIGNED NOT NULL DEFAULT 100,
            `water` TINYINT UNSIGNED NOT NULL DEFAULT 100,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]=]):format(tableName())

    exports.oxmysql:query(query, {}, function(result)
        if result == nil then
            print('^1[driftzone_minimap] Nu am putut inițializa tabela SQL.^7')
            finishDatabaseInitialisation(false)
            return
        end

        print(('^2[driftzone_minimap] Persistență activă în tabela %s.^7'):format(tableName()))
        finishDatabaseInitialisation(true)
    end)
end

local function createStatus(identifier, food, water)
    local now = os.time()

    return {
        identifier = identifier,
        food = clamp(math.floor(tonumber(food) or Config.DefaultFood), 0, 100),
        water = clamp(math.floor(tonumber(water) or Config.DefaultWater), 0, 100),
        nextFoodAt = now + math.max(1, math.floor(Config.FoodLossInterval / 1000)),
        nextWaterAt = now + math.max(1, math.floor(Config.WaterLossInterval / 1000)),
        damageMode = nil,
        nextDamageAt = nil,
        dirty = false,
        revision = 0
    }
end

local function syncStatus(source)
    local data = playerStatus[source]
    if not data then return end

    TriggerClientEvent('driftzone_minimap:client:syncStatus', source, data.food, data.water)
end

local function markDirty(data)
    data.dirty = true
    data.revision = data.revision + 1
end

local function saveStatus(source, data, force)
    if not data or not data.identifier then return end
    if not force and not data.dirty then return end
    if not databaseReady or GetResourceState('oxmysql') ~= 'started' then return end

    local revisionAtSave = data.revision
    local query = ([=[
        INSERT INTO `%s` (`identifier`, `food`, `water`)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `food` = VALUES(`food`),
            `water` = VALUES(`water`),
            `updated_at` = CURRENT_TIMESTAMP
    ]=]):format(tableName())

    exports.oxmysql:query(query, {
        data.identifier,
        data.food,
        data.water
    }, function(result)
        local current = playerStatus[source]
        if result ~= nil and current == data and current.revision == revisionAtSave then
            current.dirty = false
        end
    end)
end

local function applyPendingAdds(source)
    local pending = pendingAdds[source]
    local data = playerStatus[source]
    if not pending or not data then return end

    local changed = false

    if pending.food and pending.food > 0 then
        local newFood = clamp(data.food + pending.food, 0, 100)
        changed = changed or newFood ~= data.food
        data.food = newFood
    end

    if pending.water and pending.water > 0 then
        local newWater = clamp(data.water + pending.water, 0, 100)
        changed = changed or newWater ~= data.water
        data.water = newWater
    end

    pendingAdds[source] = nil

    if changed then
        markDirty(data)
    end
end

local function loadStatus(source)
    if playerStatus[source] then
        syncStatus(source)
        return
    end

    if loadingPlayers[source] then return end
    loadingPlayers[source] = true

    local identifier = getPrimaryIdentifier(source)
    if not identifier then
        loadingPlayers[source] = nil
        playerStatus[source] = createStatus(('temporary:%s'):format(source), Config.DefaultFood, Config.DefaultWater)
        applyPendingAdds(source)
        syncStatus(source)
        return
    end

    ensureDatabase(function(enabled)
        if not GetPlayerName(source) then
            loadingPlayers[source] = nil
            return
        end

        if not enabled then
            loadingPlayers[source] = nil
            playerStatus[source] = createStatus(identifier, Config.DefaultFood, Config.DefaultWater)
            applyPendingAdds(source)
            syncStatus(source)
            return
        end

        local query = ('SELECT `food`, `water` FROM `%s` WHERE `identifier` = ? LIMIT 1'):format(tableName())

        exports.oxmysql:single(query, { identifier }, function(row)
            if not GetPlayerName(source) then
                loadingPlayers[source] = nil
                return
            end

            loadingPlayers[source] = nil

            if row then
                playerStatus[source] = createStatus(identifier, row.food, row.water)
            else
                playerStatus[source] = createStatus(identifier, Config.DefaultFood, Config.DefaultWater)
                markDirty(playerStatus[source])
                saveStatus(source, playerStatus[source], true)
            end

            applyPendingAdds(source)
            syncStatus(source)
        end)
    end)
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
        loadStatus(source)
        return true
    end

    local newValue = clamp(data[key] + amount, 0, 100)
    if newValue == data[key] then
        syncStatus(source)
        return true
    end

    data[key] = newValue
    markDirty(data)
    syncStatus(source)
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

RegisterNetEvent('driftzone_minimap:requestStatus', function()
    loadStatus(source)
end)

-- Trigger-ele client-side cerute.
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

-- Trigger-ele recomandate pentru inventare/iteme server-side.
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
        food = data.food,
        water = data.water
    }
end)

CreateThread(function()
    ensureDatabase(function() end)

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
                    syncStatus(source)
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
                        TriggerClientEvent('driftzone_minimap:client:applyStatusDamage', source, Config.BothZeroDamagePercent)
                        data.nextDamageAt = now + math.max(1, math.floor(Config.BothZeroDamageInterval / 1000))
                    else
                        TriggerClientEvent('driftzone_minimap:client:applyStatusDamage', source, Config.SingleZeroDamagePercent)
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

        for source, data in pairs(playerStatus) do
            saveStatus(source, data, false)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    local data = playerStatus[playerSource]

    if data then
        saveStatus(playerSource, data, true)
    end

    playerStatus[playerSource] = nil
    pendingAdds[playerSource] = nil
    triggerCooldowns[playerSource] = nil
    loadingPlayers[playerSource] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for source, data in pairs(playerStatus) do
        saveStatus(source, data, true)
    end
end)
