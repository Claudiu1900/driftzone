local ActiveRaces = {}
local Cooldowns = {}
local RaceVehicles = {}

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
        function() return exports.driftzone_auth:getUserId(src) end
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

local function getColumnIntegerMax(tableNameValue, columnNameValue)
    local fallback = tonumber(Config.SafeCashMax or 2147483647) or 2147483647

    local ok, row = pcall(function()
        return MySQL.single.await([[
            SELECT COLUMN_TYPE AS column_type
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = ?
              AND COLUMN_NAME = ?
            LIMIT 1
        ]], { tableNameValue, columnNameValue })
    end)

    if not ok or not row or not row.column_type then return fallback end

    local t = tostring(row.column_type):lower()
    local unsigned = t:find('unsigned', 1, true) ~= nil

    if t:find('tinyint', 1, true) then return unsigned and 255 or 127 end
    if t:find('smallint', 1, true) then return unsigned and 65535 or 32767 end
    if t:find('mediumint', 1, true) then return unsigned and 16777215 or 8388607 end
    if t:find('bigint', 1, true) then return unsigned and 9007199254740991 or 9007199254740991 end
    if t:find('int', 1, true) then return unsigned and 4294967295 or 2147483647 end

    return fallback
end

local function addRewardSafe(uid, reward)
    local usersTable = tableName(Config.UsersTable or 'users')
    local uidCol = col(Config.UsersIdColumn or 'uid')
    local cashCol = col(Config.CashColumn or 'cash')
    local racesCol = col(Config.RacesColumn or 'races')
    local maxCash = getColumnIntegerMax(usersTable, cashCol)

    local row = MySQL.single.await(([[
        SELECT `%s` AS cash_value, `%s` AS races_value
        FROM `%s`
        WHERE `%s` = ?
        LIMIT 1
    ]]):format(cashCol, racesCol, usersTable, uidCol), { uid })

    if not row then return false, 'user_not_found', 0 end

    local currentCash = tonumber(row.cash_value or 0) or 0
    local newCash = currentCash + (tonumber(reward or 0) or 0)
    if newCash > maxCash then newCash = maxCash end
    if newCash < 0 then newCash = 0 end

    MySQL.update.await(([[
        UPDATE `%s`
        SET `%s` = ?, `%s` = COALESCE(`%s`, 0) + 1
        WHERE `%s` = ?
        LIMIT 1
    ]]):format(usersTable, cashCol, racesCol, racesCol, uidCol), { math.floor(newCash), uid })

    return true, nil, math.max(0, math.floor(newCash - currentCash))
end

local function cooldownKey(uid, raceId)
    return ('racecd:%s:%s'):format(tostring(uid), tostring(raceId))
end

local function getCooldownLeft(uid, raceId)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return 0 end

    local key = tostring(uid) .. ':' .. tostring(raceId)
    local untilTime = tonumber(Cooldowns[key] or 0) or 0

    if untilTime <= 0 then
        local saved = GetResourceKvpString(cooldownKey(uid, raceId))
        untilTime = tonumber(saved or 0) or 0
        if untilTime > 0 then Cooldowns[key] = untilTime end
    end

    local left = untilTime - os.time()
    if left < 0 then
        left = 0
        Cooldowns[key] = 0
        DeleteResourceKvp(cooldownKey(uid, raceId))
    end

    return left
end

local function setCooldown(uid, raceId, seconds)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return end

    local untilTime = os.time() + (tonumber(seconds or 0) or 0)
    local key = tostring(uid) .. ':' .. tostring(raceId)

    Cooldowns[key] = untilTime
    SetResourceKvp(cooldownKey(uid, raceId), tostring(untilTime))
end

local function resetCooldowns(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return end

    for raceId, _ in pairs(Config.Races or {}) do
        local key = tostring(uid) .. ':' .. tostring(raceId)
        Cooldowns[key] = 0
        DeleteResourceKvp(cooldownKey(uid, raceId))
    end
end

local function getCooldownPayload(uid)
    local data = {}
    for raceId, _ in pairs(Config.Races or {}) do
        data[raceId] = getCooldownLeft(uid, raceId)
    end
    return data
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
                image = tostring(row.vehicle_image or row.image or '')
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
        name = tostring(row.vehicle_name or row.model or 'Vehicle')
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

            if dbId == vehicleId or (dbId > 0 and owner == tonumber(uid) and dbId == vehicleId) then
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
    state:set('dz_garage_db_id', tonumber(vehicleData.id) or 0, true)
    state:set('dz_garage_model', vehicleData.model, true)
    state:set('dz_garage_name', vehicleData.name, true)
    state:set('dz_garage_plate', vehicleData.plate, true)
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
    SetPlayerRoutingBucket(src, Config.ReturnBucket or 0)
    debugPrint(('cleanup src=%s reason=%s'):format(src, tostring(reason)))
end

local function sendMenu(src)
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end

    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    local raceList = {}
    for _, race in pairs(Config.Races or {}) do
        raceList[#raceList + 1] = {
            id = race.id,
            label = race.label,
            description = race.description,
            rewardMin = race.reward.min,
            rewardMax = race.reward.max,
            cooldown = race.cooldown,
            cooldownLeft = getCooldownLeft(uid, race.id),
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


local function getAdminLevel(src)
    local uid = getUid(src)
    if not uid then return 0 end

    local usersTable = tableName(Config.UsersTable or 'users')
    local uidCol = col(Config.UsersIdColumn or 'uid')
    local columns = Config.AdminColumns or { 'admin_level' }

    for i = 1, #columns do
        local adminCol = col(columns[i])
        local ok, row = pcall(function()
            return MySQL.single.await(([[
                SELECT `%s` AS admin_level
                FROM `%s`
                WHERE `%s` = ?
                LIMIT 1
            ]]):format(adminCol, usersTable, uidCol), { uid })
        end)

        if ok and row and tonumber(row.admin_level) then
            return tonumber(row.admin_level) or 0
        end
    end

    return 0
end

RegisterCommand(Config.ResetCooldownCommand or 'rracecd', function(src, args)
    if src == 0 then
        local target = tonumber(args and args[1])
        if not target then print('[DRIFTZONE_RACEJOB] Folosire: /rracecd <id>') return end
        local uid = getUid(target) or target
        resetCooldowns(uid)
        print('[DRIFTZONE_RACEJOB] Cooldown race reset pentru UID ' .. tostring(uid))
        return
    end

    if getAdminLevel(src) < (Config.ResetCooldownMinAdminLevel or 6) then
        notify(src, 'error', 'Nu ai acces la aceasta comanda.')
        return
    end

    local target = tonumber(args and args[1])
    if not target then
        notify(src, 'warning', 'Folosire: /' .. tostring(Config.ResetCooldownCommand or 'rracecd') .. ' <id>')
        return
    end

    local targetUid = getUid(target) or target
    resetCooldowns(targetUid)
    notify(src, 'success', 'Cooldown-ul de race a fost resetat pentru ID ' .. tostring(target) .. '.', 5000)

    if GetPlayerName(target) then
        notify(target, 'info', 'Cooldown-ul tau de race a fost resetat.', 5000)
        sendMenu(target)
    end
end, false)

RegisterNetEvent('driftzone_racejob:server:open', function()
    sendMenu(source)
end)

RegisterNetEvent('driftzone_racejob:server:start', function(raceId, vehicleId)
    local src = source

    if ActiveRaces[src] then
        notify(src, 'warning', 'Ai deja o cursa activa.')
        return
    end

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

    local ok, err = pcall(function()
        deleteExistingVehicleInstances(uid, vehicleData.id)

        local bucket = (Config.RaceBucketBase or 62000) + tonumber(src)
        SetPlayerRoutingBucket(src, bucket)

        ActiveRaces[src] = {
            uid = uid,
            raceId = race.id,
            race = race,
            vehicleId = vehicleData.id,
            entity = nil,
            netId = 0,
            bucket = bucket,
            startedAt = os.time(),
            rewardMin = race.reward.min,
            rewardMax = race.reward.max
        }

        RaceVehicles[vehicleData.id] = { entity = nil, src = src, uid = uid }
        setCooldown(uid, race.id, race.cooldown)

        TriggerClientEvent('driftzone_racejob:client:prepareRace', src, {
            race = {
                id = race.id,
                label = race.label,
                timeLimit = race.timeLimit,
                start = { x = race.start.x, y = race.start.y, z = race.start.z, h = race.start.w },
                finish = { x = race.finish.x, y = race.finish.y, z = race.finish.z },
                radius = Config.FinishRadius or 9.0
            },
            vehicle = {
                id = vehicleData.id,
                model = vehicleData.model,
                name = vehicleData.name,
                plate = vehicleData.plate,
                tuning = vehicleData.tuning
            },
            countdown = Config.CountdownSeconds or 3,
            mainColor = Config.MainColor or '#04c7f7'
        })
    end)

    if not ok then
        print(('[DRIFTZONE_RACEJOB] start error src=%s: %s'):format(src, tostring(err)))
        cleanupRace(src, 'start_error')
        notify(src, 'error', 'A aparut o eroare la pornirea cursei.')
    end
end)

RegisterNetEvent('driftzone_racejob:server:clientVehicleReady', function(netId)
    local src = source
    local active = ActiveRaces[src]
    if not active then return end

    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        active.netId = netId
        active.entity = entity
        SetEntityRoutingBucket(entity, active.bucket or ((Config.RaceBucketBase or 62000) + tonumber(src)))

        if active.vehicleId then
            RaceVehicles[active.vehicleId] = { entity = entity, src = src, uid = active.uid }
        end
    end
end)

RegisterNetEvent('driftzone_racejob:server:finish', function(raceId)
    local src = source
    local active = ActiveRaces[src]

    if not active or active.raceId ~= tostring(raceId or '') then return end

    local reward = math.random(tonumber(active.rewardMin) or 2500, tonumber(active.rewardMax) or 5000)
    local uid = active.uid

    local ok, err, paid = pcall(function()
        local success, reason, actualPaid = addRewardSafe(uid, reward)
        if not success then error(reason or 'reward_failed') end
        return actualPaid
    end)

    if ok then
        reward = tonumber(err or reward) or reward
    else
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
    if not active then return end

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

AddEventHandler('playerDropped', function()
    cleanupRace(source, 'dropped')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, _ in pairs(ActiveRaces) do cleanupRace(src, 'resource_stop') end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_RACEJOB] Server loaded. Short/Medium/Long races ready.')
end)
