local ActiveRaces = {}
local RaceVehicles = {}
local StartTokens = {}

local function debugPrint(...)
    if Config.Debug then print('[DRIFTZONE_RACEJOB]', ...) end
end

local function notify(src, notifyType, message, duration)
    TriggerClientEvent((Config.Notify and Config.Notify.event) or 'client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function tableName(name)
    return tostring(name or ''):gsub('`', '')
end

local function col(name)
    return tostring(name or ''):gsub('`', '')
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    local state = Player(src).state
    if state then
        local keys = { 'dz_uid', 'uid', 'user_id', 'userId' }
        for i = 1, #keys do
            local value = tonumber(state[keys[i]])
            if value and value > 0 then return value end
        end
    end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end,
        function() return exports.driftzone_auth:getUserId(src) end,
        function() return exports.driftzone_auth:GetPlayerUID(src) end,
        function() return exports.driftzone_auth:getPlayerUID(src) end
    }

    for i = 1, #attempts do
        local ok, uid = pcall(attempts[i])
        uid = tonumber(uid)
        if ok and uid and uid > 0 then return uid end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and (state.dz_logged == true or state.logged == true or state.isLoggedIn == true) then return true end

    local attempts = {
        function() return exports.driftzone_auth:IsLoggedIn(src) end,
        function() return exports.driftzone_auth:isLoggedIn(src) end,
        function() return exports.driftzone_auth:IsLogged(src) end
    }

    for i = 1, #attempts do
        local ok, result = pcall(attempts[i])
        if ok and result == true then return true end
    end

    return getUid(src) ~= nil
end

local function normalizeTuning(raw)
    if type(raw) == 'table' then
        local ok, encoded = pcall(json.encode, raw)
        return ok and encoded or '{}'
    end

    raw = tostring(raw or '{}')
    if raw == '' or raw == 'null' or raw == 'nil' then return '{}' end
    return raw
end

local function getRace(raceId)
    raceId = tostring(raceId or ''):lower()
    return Config.Races and Config.Races[raceId] or nil
end

local function formatTime(seconds)
    seconds = math.max(0, tonumber(seconds or 0) or 0)
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function cooldownKey(uid, raceId)
    return ('driftzone_racejob_cd_%s_%s'):format(tostring(uid), tostring(raceId))
end

local function getCooldownUntil(uid, raceId)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return 0 end
    local untilTime = tonumber(GetResourceKvpString(cooldownKey(uid, raceId)) or 0) or 0
    if untilTime <= os.time() then
        DeleteResourceKvp(cooldownKey(uid, raceId))
        return 0
    end
    return untilTime
end

local function getCooldownLeft(uid, raceId)
    local left = getCooldownUntil(uid, raceId) - os.time()
    if left < 0 then left = 0 end
    return left
end

local function setCooldown(uid, raceId, seconds)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return 0 end
    local untilTime = os.time() + (tonumber(seconds or 0) or 0)
    SetResourceKvp(cooldownKey(uid, raceId), tostring(untilTime))
    return untilTime
end

local function clearCooldowns(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return end
    for raceId, _ in pairs(Config.Races or {}) do
        DeleteResourceKvp(cooldownKey(uid, raceId))
    end
end

local function getCooldownPayload(uid)
    local data = {}
    for raceId, _ in pairs(Config.Races or {}) do
        data[raceId] = {
            left = getCooldownLeft(uid, raceId),
            untilTime = getCooldownUntil(uid, raceId)
        }
    end
    return data
end

local function getAdminLevel(src)
    if src == 0 then return 999 end
    local uid = getUid(src)
    if not uid then return 0 end

    local usersTable = tableName(Config.UsersTable or 'users')
    local uidCol = col(Config.UsersIdColumn or 'uid')

    for _, adminColRaw in ipairs(Config.AdminColumns or { 'admin' }) do
        local adminCol = col(adminColRaw)
        local ok, row = pcall(function()
            return MySQL.single.await(('SELECT `%s` AS level FROM `%s` WHERE `%s` = ? LIMIT 1'):format(adminCol, usersTable, uidCol), { uid })
        end)
        if ok and row and tonumber(row.level) then
            return tonumber(row.level) or 0
        end
    end

    return 0
end

local function getVehicleRows(uid)
    local t = tableName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = col(Config.OwnedVehicleIdColumn or 'id')
    local ownerCol = col(Config.OwnedVehicleOwnerColumn or 'owner_id')
    local modelCol = col(Config.OwnedVehicleModelColumn or 'vehicle_model')
    local plateCol = col(Config.OwnedVehiclePlateColumn or 'vehicle_plate')
    local tuningCol = col(Config.OwnedVehicleTuningColumn or 'vehicle_tunning')

    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT
                ov.`%s` AS id,
                ov.`%s` AS owner_id,
                ov.`%s` AS model,
                ov.`%s` AS plate,
                ov.`%s` AS tuning,
                COALESCE(ov.vip, 0) AS vip,
                vn.vehicle_name,
                vn.vehicle_image,
                vn.image
            FROM `%s` ov
            LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.`%s`
            WHERE ov.`%s` = ?
            ORDER BY ov.`%s` DESC
        ]]):format(idCol, ownerCol, modelCol, plateCol, tuningCol, t, modelCol, ownerCol, idCol), { uid })
    end)

    if not ok then
        print('[DRIFTZONE_RACEJOB] getVehicleRows query failed: ' .. tostring(rows))
        return {}
    end

    return rows or {}
end

local function getPlayerVehicles(uid)
    local rows = getVehicleRows(uid)
    local list = {}

    for _, row in ipairs(rows) do
        local model = tostring(row.model or ''):lower()
        if model ~= '' then
            list[#list + 1] = {
                id = tonumber(row.id) or 0,
                model = model,
                name = tostring(row.vehicle_name or model),
                plate = tostring(row.plate or 'DRIFT'),
                image = tostring(row.vehicle_image or row.image or ''),
                vip = tonumber(row.vip or 0) == 1 or row.vip == true
            }
        end
    end

    return list
end

local function getVehicleData(uid, vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return nil end

    local t = tableName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = col(Config.OwnedVehicleIdColumn or 'id')
    local ownerCol = col(Config.OwnedVehicleOwnerColumn or 'owner_id')
    local modelCol = col(Config.OwnedVehicleModelColumn or 'vehicle_model')
    local plateCol = col(Config.OwnedVehiclePlateColumn or 'vehicle_plate')
    local tuningCol = col(Config.OwnedVehicleTuningColumn or 'vehicle_tunning')

    local ok, row = pcall(function()
        return MySQL.single.await(([[
            SELECT
                ov.`%s` AS id,
                ov.`%s` AS owner_id,
                ov.`%s` AS model,
                ov.`%s` AS plate,
                ov.`%s` AS tuning,
                COALESCE(ov.vip, 0) AS vip,
                vn.vehicle_name
            FROM `%s` ov
            LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.`%s`
            WHERE ov.`%s` = ? AND ov.`%s` = ?
            LIMIT 1
        ]]):format(idCol, ownerCol, modelCol, plateCol, tuningCol, t, modelCol, idCol, ownerCol), { vehicleId, uid })
    end)

    if not ok then
        print('[DRIFTZONE_RACEJOB] getVehicleData query failed: ' .. tostring(row))
        return nil
    end

    if not row then return nil end

    return {
        id = tonumber(row.id) or vehicleId,
        ownerId = tonumber(row.owner_id) or uid,
        model = tostring(row.model or ''):lower(),
        plate = tostring(row.plate or 'DRIFT'):upper():gsub('%s+', ''):sub(1, 8),
        tuning = normalizeTuning(row.tuning or '{}'),
        name = tostring(row.vehicle_name or row.model or 'Vehicle'),
        vip = tonumber(row.vip or 0) == 1 or row.vip == true
    }
end

local function entityExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function unregisterVehicle(entity)
    pcall(function() exports.driftzone_vs:UnregisterVehicle(entity) end)
    pcall(function() TriggerEvent('vs:unregisterVehicle', entity) end)
end

local function deleteEntitySafe(entity)
    if not entityExists(entity) then return end
    unregisterVehicle(entity)
    DeleteEntity(entity)
end

local function deleteExistingVehicleInstances(uid, vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0

    if RaceVehicles[vehicleId] and entityExists(RaceVehicles[vehicleId].entity) then
        deleteEntitySafe(RaceVehicles[vehicleId].entity)
    end
    RaceVehicles[vehicleId] = nil

    local ok, active = pcall(function()
        return exports.driftzone_garage:GetActiveVehicle(vehicleId)
    end)

    if ok and active and active.entity and entityExists(active.entity) then
        deleteEntitySafe(active.entity)
    end

    local all = GetAllVehicles and GetAllVehicles() or {}
    for _, entity in ipairs(all) do
        if entityExists(entity) then
            local state = Entity(entity).state
            local dbId = tonumber(state.dz_garage_db_id or 0)
            local owner = tonumber(state.dz_garage_owner_uid or 0)
            if dbId == vehicleId and (owner == 0 or owner == tonumber(uid)) then
                deleteEntitySafe(entity)
            end
        end
    end
end

local function setRaceVehicleState(entity, src, uid, vehicleData)
    if not entityExists(entity) then return end
    local state = Entity(entity).state
    state:set('dz_race_vehicle', true, true)
    state:set('dz_race_owner_uid', tonumber(uid) or 0, true)
    state:set('dz_race_owner_src', tonumber(src) or 0, true)
    state:set('dz_garage_vehicle', true, true)
    state:set('dz_garage_owner_uid', tonumber(uid) or 0, true)
    state:set('dz_garage_owner_name', getPlayerNameSafe(src), true)
    state:set('dz_garage_db_id', tonumber(vehicleData.id) or 0, true)
    state:set('dz_garage_model', vehicleData.model, true)
    state:set('dz_garage_name', vehicleData.name, true)
    state:set('dz_garage_plate', vehicleData.plate, true)
    state:set('dz_garage_is_vip', vehicleData.vip == true, true)
    state:set('dz_garage_godmode', true, true)
    state:set('dz_garage_tuning', vehicleData.tuning, true)
    state:set('vehicleTunning', vehicleData.tuning, true)
    state:set('dz_vehicle_tunning', vehicleData.tuning, true)
end

local function cleanupRace(src, reason)
    local race = ActiveRaces[src]
    if not race then return end

    if race.entity and entityExists(race.entity) then
        deleteEntitySafe(race.entity)
    end

    if race.vehicleId then
        RaceVehicles[race.vehicleId] = nil
    end

    ActiveRaces[src] = nil
    StartTokens[src] = nil
    SetPlayerRoutingBucket(src, Config.ReturnBucket or 0)
    debugPrint(('cleanup src=%s reason=%s'):format(src, tostring(reason)))
end

local function sendMenu(src)
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    local raceList = {}
    for _, race in pairs(Config.Races or {}) do
        local untilTime = getCooldownUntil(uid, race.id)
        raceList[#raceList + 1] = {
            id = race.id,
            label = race.label,
            description = race.description,
            rewardMin = race.reward.min,
            rewardMax = race.reward.max,
            cooldown = race.cooldown,
            cooldownLeft = math.max(0, untilTime - os.time()),
            cooldownUntil = untilTime,
            timeLimit = race.timeLimit
        }
    end

    table.sort(raceList, function(a, b)
        local order = { short = 1, medium = 2, long = 3 }
        return (order[a.id] or 99) < (order[b.id] or 99)
    end)

    TriggerClientEvent('driftzone_racejob:client:openMenu', src, {
        races = raceList,
        vehicles = getPlayerVehicles(uid),
        cooldowns = getCooldownPayload(uid),
        serverTime = os.time(),
        mainColor = Config.MainColor or '#04c7f7'
    })
end

local function registerVehicleSystem(entity, vehicleData, uid, src)
    pcall(function()
        exports.driftzone_vs:RegisterVehicle(entity, {
            source = 'racejob',
            sqlVehicleId = vehicleData.id,
            ownerId = uid,
            ownerName = getPlayerNameSafe(src),
            model = vehicleData.model,
            plate = vehicleData.plate
        })
    end)

    pcall(function()
        TriggerEvent('vs:registerVehicle', entity, {
            source = 'racejob',
            sqlVehicleId = vehicleData.id,
            ownerId = uid,
            ownerName = getPlayerNameSafe(src),
            model = vehicleData.model,
            plate = vehicleData.plate
        })
    end)
end

RegisterNetEvent('driftzone_racejob:server:open', function()
    sendMenu(source)
end)

RegisterNetEvent('driftzone_racejob:server:start', function(raceId, vehicleId)
    local src = source

    if ActiveRaces[src] then notify(src, 'warning', 'Ai deja o cursa activa.') return end
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end

    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    local race = getRace(raceId)
    if not race then notify(src, 'warning', 'Cursa invalida.') return end

    local cooldownLeft = getCooldownLeft(uid, race.id)
    if cooldownLeft > 0 then
        notify(src, 'warning', ('Mai ai cooldown %s pentru %s.'):format(formatTime(cooldownLeft), race.label), 5000)
        sendMenu(src)
        return
    end

    local vehicleData = getVehicleData(uid, vehicleId)
    if not vehicleData then notify(src, 'warning', 'Masina selectata nu iti apartine.') return end
    if vehicleData.model == '' then notify(src, 'warning', 'Model invalid.') return end

    local token = ('%s:%s:%s:%s'):format(src, uid, race.id, math.random(100000, 999999))
    local bucket = (Config.RaceBucketBase or 62000) + tonumber(src)

    StartTokens[src] = {
        token = token,
        uid = uid,
        race = race,
        vehicleData = vehicleData,
        bucket = bucket,
        expiresAt = GetGameTimer() + ((Config.Vehicle and Config.Vehicle.clientSpawnTimeoutMs) or 12000)
    }

    if Config.Vehicle and Config.Vehicle.deleteExistingOwnedVehicle then
        deleteExistingVehicleInstances(uid, vehicleData.id)
    end

    SetPlayerRoutingBucket(src, bucket)

    TriggerClientEvent('driftzone_racejob:client:spawnRaceVehicle', src, {
        token = token,
        bucket = bucket,
        start = { x = race.start.x, y = race.start.y, z = race.start.z, h = race.start.w },
        vehicle = {
            id = vehicleData.id,
            model = vehicleData.model,
            name = vehicleData.name,
            plate = vehicleData.plate,
            tuning = vehicleData.tuning,
            vip = vehicleData.vip == true
        },
        race = {
            id = race.id,
            label = race.label,
            timeLimit = race.timeLimit,
            finish = { x = race.finish.x, y = race.finish.y, z = race.finish.z },
            radius = Config.FinishRadius or 9.0
        },
        countdown = Config.CountdownSeconds or 3,
        mainColor = Config.MainColor or '#04c7f7'
    })
end)

RegisterNetEvent('driftzone_racejob:server:vehicleCreated', function(token, netId)
    local src = source
    local pending = StartTokens[src]
    if not pending or pending.token ~= tostring(token or '') then return end

    netId = tonumber(netId or 0) or 0
    if netId <= 0 then
        cleanupRace(src, 'bad_netid')
        notify(src, 'error', 'Masina cursei nu a fost gasita.')
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local timeout = GetGameTimer() + 6000
    while (not entityExists(entity)) and GetGameTimer() < timeout do
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
    end

    if not entityExists(entity) then
        cleanupRace(src, 'missing_entity')
        notify(src, 'error', 'Masina cursei nu a fost gasita.')
        TriggerClientEvent('driftzone_racejob:client:forceEndLocal', src)
        return
    end

    SetEntityRoutingBucket(entity, pending.bucket)
    setRaceVehicleState(entity, src, pending.uid, pending.vehicleData)

    ActiveRaces[src] = {
        uid = pending.uid,
        raceId = pending.race.id,
        race = pending.race,
        vehicleId = pending.vehicleData.id,
        entity = entity,
        netId = netId,
        bucket = pending.bucket,
        startedAt = os.time(),
        rewardMin = pending.race.reward.min,
        rewardMax = pending.race.reward.max
    }

    RaceVehicles[pending.vehicleData.id] = { entity = entity, src = src, uid = pending.uid }
    registerVehicleSystem(entity, pending.vehicleData, pending.uid, src)

    local cooldownUntil = setCooldown(pending.uid, pending.race.id, pending.race.cooldown)
    StartTokens[src] = nil

    TriggerClientEvent('driftzone_racejob:client:raceConfirmed', src, {
        cooldowns = getCooldownPayload(pending.uid),
        raceId = pending.race.id,
        cooldownUntil = cooldownUntil,
        serverTime = os.time()
    })
end)

RegisterNetEvent('driftzone_racejob:server:spawnFailed', function(token, message)
    local src = source
    local pending = StartTokens[src]
    if pending and pending.token == tostring(token or '') then
        StartTokens[src] = nil
        SetPlayerRoutingBucket(src, Config.ReturnBucket or 0)
    end
    notify(src, 'error', tostring(message or 'Masina cursei nu a putut fi spawnata.'))
end)

RegisterNetEvent('driftzone_racejob:server:finish', function(raceId)
    local src = source
    local active = ActiveRaces[src]
    if not active or active.raceId ~= tostring(raceId or '') then return end

    local reward = math.random(tonumber(active.rewardMin) or 2500, tonumber(active.rewardMax) or 5000)
    local uid = active.uid

    local ok, err = pcall(function()
        local usersTable = tableName(Config.UsersTable or 'users')
        local uidCol = col(Config.UsersIdColumn or 'uid')
        local cashCol = col(Config.CashColumn or 'cash')
        local racesCol = col(Config.RacesColumn or 'races')

        MySQL.update.await(([[
            UPDATE `%s`
            SET `%s` = LEAST(18446744073709551615, CAST(`%s` AS UNSIGNED) + ?),
                `%s` = COALESCE(`%s`, 0) + 1
            WHERE `%s` = ?
            LIMIT 1
        ]]):format(usersTable, cashCol, cashCol, racesCol, racesCol, uidCol), { reward, uid })
    end)

    if not ok then
        print('[DRIFTZONE_RACEJOB] reward query failed: ' .. tostring(err))
        notify(src, 'error', 'Cursa a fost finalizata, dar SQL cash/races a dat eroare. Ruleaza sql.sql.')
        reward = 0
    end

    cleanupRace(src, 'finish')

    local ret = Config.ReturnPosition
    TriggerClientEvent('driftzone_racejob:client:endRace', src, {
        success = true,
        reward = reward,
        message = reward > 0 and ('Ai finalizat cursa si ai primit suma de: $' .. tostring(reward) .. '!') or 'Ai finalizat cursa.',
        returnPos = { x = ret.x, y = ret.y, z = ret.z, h = ret.w },
        bucket = Config.ReturnBucket or 0
    })
end)

RegisterNetEvent('driftzone_racejob:server:fail', function(reason)
    local src = source
    local active = ActiveRaces[src]
    if not active then
        StartTokens[src] = nil
        SetPlayerRoutingBucket(src, Config.ReturnBucket or 0)
        return
    end

    cleanupRace(src, reason or 'failed')

    local ret = Config.ReturnPosition
    TriggerClientEvent('driftzone_racejob:client:endRace', src, {
        success = false,
        reward = 0,
        message = 'Ai pierdut cursa.',
        returnPos = { x = ret.x, y = ret.y, z = ret.z, h = ret.w },
        bucket = Config.ReturnBucket or 0
    })
end)

RegisterNetEvent('driftzone_racejob:server:cancel', function()
    local src = source
    if not ActiveRaces[src] then return end
    cleanupRace(src, 'cancel')
    local ret = Config.ReturnPosition
    TriggerClientEvent('driftzone_racejob:client:endRace', src, {
        success = false,
        reward = 0,
        message = 'Cursa a fost anulata.',
        returnPos = { x = ret.x, y = ret.y, z = ret.z, h = ret.w },
        bucket = Config.ReturnBucket or 0
    })
end)

RegisterCommand(Config.ResetCooldownCommand or 'rracecd', function(src, args)
    if src ~= 0 then
        local level = getAdminLevel(src)
        if level < (Config.ResetCooldownMinAdminLevel or 7) then
            notify(src, 'error', 'Nu ai acces la aceasta comanda.')
            return
        end
    end

    local target = tonumber(args and args[1] or 0) or 0
    if target <= 0 then
        if src == 0 then print('Usage: rracecd <id>') else notify(src, 'warning', 'Foloseste: /rracecd <id>') end
        return
    end

    local targetUid = nil
    if GetPlayerName(target) then
        targetUid = getUid(target)
    end
    targetUid = targetUid or target

    clearCooldowns(targetUid)

    if GetPlayerName(target) then
        TriggerClientEvent('driftzone_racejob:client:cooldownsReset', target)
        notify(target, 'success', 'Cooldown-ul la race a fost resetat.')
    end

    if src == 0 then
        print(('[DRIFTZONE_RACEJOB] Cooldown reset pentru UID/ID %s'):format(targetUid))
    else
        notify(src, 'success', ('Ai resetat cooldown-ul race pentru ID/UID %s.'):format(targetUid))
    end
end, false)

exports('ResetCooldowns', function(uid)
    clearCooldowns(uid)
end)

AddEventHandler('playerDropped', function()
    cleanupRace(source, 'dropped')
    StartTokens[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, _ in pairs(ActiveRaces) do cleanupRace(src, 'resource_stop') end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for src, data in pairs(StartTokens) do
            if data.expiresAt and now > data.expiresAt then
                StartTokens[src] = nil
                SetPlayerRoutingBucket(src, Config.ReturnBucket or 0)
                notify(src, 'error', 'Spawn-ul masinii a expirat. Incearca din nou.')
                TriggerClientEvent('driftzone_racejob:client:forceEndLocal', src)
            end
        end
    end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_RACEJOB] Server loaded. Client spawn + persistent cooldowns enabled.')
end)
