local ActiveRaces = {}
local RaceVehicles = {}
local RaceLocks = {}
local RaceIdCounter = 0

math.randomseed(os.time())

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function getUid(src)
    local state = Player(src).state

    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end,
        function() return exports.driftzone_auth:getUserId(src) end
    }

    for i = 1, #attempts do
        local ok, uid = pcall(attempts[i])

        if ok and tonumber(uid) and tonumber(uid) > 0 then
            return tonumber(uid)
        end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state

    if state and (state.dz_logged == true or state.logged == true or state.isLoggedIn == true) then
        return true
    end

    local attempts = {
        function() return exports.driftzone_auth:IsLoggedIn(src) end,
        function() return exports.driftzone_auth:isLoggedIn(src) end,
        function() return exports.driftzone_auth:IsLogged(src) end
    }

    for i = 1, #attempts do
        local ok, result = pcall(attempts[i])
        if ok and result == true then
            return true
        end
    end

    return getUid(src) ~= nil
end

local function vehicleExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function randomPlate()
    return ('RACE%04d'):format(math.random(0, 9999)):sub(1, 8)
end

local function normalizeTuning(raw)
    if type(raw) == 'table' then
        local ok, encoded = pcall(json.encode, raw)
        if ok and encoded and encoded ~= '' then return encoded end
        return '{}'
    end

    raw = tostring(raw or '{}')
    if raw == '' or raw == 'null' or raw == 'nil' then return '{}' end

    return raw
end

local function getVehicles(uid)
    local rows = MySQL.query.await([[
        SELECT
            ov.id,
            ov.owner_id,
            ov.vehicle_model,
            ov.vehicle_plate,
            ov.vehicle_tunning,
            vn.vehicle_name,
            vn.vehicle_image,
            vn.image
        FROM ownedvehicles ov
        LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model
        WHERE ov.owner_id = ?
        ORDER BY ov.id DESC
    ]], { uid }) or {}

    local list = {}

    for _, row in ipairs(rows) do
        local model = tostring(row.vehicle_model or ''):lower()
        local image = row.vehicle_image or row.image or ''

        if model ~= '' then
            list[#list + 1] = {
                id = tonumber(row.id),
                model = model,
                name = tostring(row.vehicle_name or model),
                plate = tostring(row.vehicle_plate or 'DRIFT'),
                image = tostring(image or '')
            }
        end
    end

    return list
end

local function getOwnedVehicle(uid, vehicleId)
    vehicleId = tonumber(vehicleId)

    if not vehicleId or vehicleId <= 0 then return nil end

    local row = MySQL.single.await([[
        SELECT
            ov.id,
            ov.owner_id,
            ov.vehicle_model,
            ov.vehicle_plate,
            ov.vehicle_tunning,
            vn.vehicle_name
        FROM ownedvehicles ov
        LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model
        WHERE ov.id = ? AND ov.owner_id = ?
        LIMIT 1
    ]], { vehicleId, uid })

    if not row then return nil end

    return {
        id = tonumber(row.id),
        ownerId = tonumber(row.owner_id),
        model = tostring(row.vehicle_model or ''):lower(),
        plate = tostring(row.vehicle_plate or randomPlate()):upper():gsub('%s+', ''):sub(1, 8),
        tuning = normalizeTuning(row.vehicle_tunning or '{}'),
        name = tostring(row.vehicle_name or row.vehicle_model or 'Vehicle')
    }
end

local function deleteEntitySafe(entity)
    if not vehicleExists(entity) then return end

    pcall(function() exports.driftzone_vs:UnregisterVehicle(entity) end)
    pcall(function() TriggerEvent('vs:unregisterVehicle', entity) end)

    DeleteEntity(entity)
end

local function deleteExistingGarageVehicle(vehicleId)
    if Config.SpawnDeleteExisting ~= true then return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId or vehicleId <= 0 then return end

    if RaceVehicles[vehicleId] and vehicleExists(RaceVehicles[vehicleId]) then
        deleteEntitySafe(RaceVehicles[vehicleId])
        RaceVehicles[vehicleId] = nil
    end

    local ok, data = pcall(function()
        return exports.driftzone_garage:GetActiveVehicle(vehicleId)
    end)

    if ok and data then
        if data.entity and vehicleExists(data.entity) then
            deleteEntitySafe(data.entity)
        elseif data.netId and NetworkGetEntityFromNetworkId then
            local entity = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
            if vehicleExists(entity) then
                deleteEntitySafe(entity)
            end
        end
    end

    pcall(function()
        exports.driftzone_garage:DespawnVehicle(vehicleId)
    end)
end

local function setRaceVehicleState(entity, src, uid, vehicle)
    local state = Entity(entity).state

    state:set('dz_racejob_vehicle', true, true)
    state:set('dz_racejob_owner_uid', tonumber(uid) or 0, true)
    state:set('dz_garage_vehicle', true, true)
    state:set('dz_garage_owner_uid', tonumber(uid) or 0, true)
    state:set('dz_garage_db_id', tonumber(vehicle.id) or 0, true)
    state:set('dz_garage_model', tostring(vehicle.model or ''), true)
    state:set('dz_garage_name', tostring(vehicle.name or 'Race Vehicle'), true)
    state:set('dz_garage_plate', tostring(vehicle.plate or ''), true)

    local tuningRaw = normalizeTuning(vehicle.tuning or '{}')
    state:set('dz_garage_tuning', tuningRaw, true)
    state:set('vehicleTunning', tuningRaw, true)
    state:set('dz_vehicle_tunning', tuningRaw, true)
end

local function createRaceVehicle(src, uid, vehicle, raceConfig)
    local model = tostring(vehicle.model or ''):lower()

    if model == '' then
        return nil, 'Model vehicul invalid.'
    end

    local hash = joaat(model)

    if not hash or hash == 0 then
        return nil, 'Model vehicul invalid.'
    end

    local spawn = raceConfig.start
    local entity = CreateVehicle(hash, spawn.x, spawn.y, spawn.z + 0.25, spawn.w, true, true)

    local timeout = GetGameTimer() + 6500

    while not vehicleExists(entity) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not vehicleExists(entity) then
        return nil, 'Nu am putut crea masina. Verifica daca modelul este streamat.'
    end

    SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(src))
    SetVehicleNumberPlateText(entity, vehicle.plate or randomPlate())
    SetEntityHeading(entity, spawn.w)
    -- Unele native-uri de vehicul nu exista server-side pe toate build-urile FiveM.
    -- Motorul/reparatia/dirt se aplica sigur client-side dupa ce clientul primeste netId-ul.
    if type(SetVehicleDirtLevel) == 'function' then
        SetVehicleDirtLevel(entity, 0.0)
    end

    if type(SetVehicleEngineOn) == 'function' then
        SetVehicleEngineOn(entity, true, true, false)
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    timeout = GetGameTimer() + 6500

    while (not netId or netId == 0) and GetGameTimer() < timeout do
        Wait(50)
        netId = NetworkGetNetworkIdFromEntity(entity)
    end

    if not netId or netId == 0 then
        deleteEntitySafe(entity)
        return nil, 'Masina a fost creata, dar nu a primit Network ID.'
    end

    setRaceVehicleState(entity, src, uid, vehicle)

    RaceVehicles[vehicle.id] = entity

    pcall(function()
        exports.driftzone_vs:RegisterVehicle(entity, {
            source = 'racejob',
            sqlVehicleId = vehicle.id,
            ownerId = uid,
            ownerName = getPlayerNameSafe(src),
            model = vehicle.model,
            plate = vehicle.plate
        })
    end)

    pcall(function()
        TriggerEvent('vs:registerVehicle', entity, {
            source = 'racejob',
            sqlVehicleId = vehicle.id,
            ownerId = uid,
            ownerName = getPlayerNameSafe(src),
            model = vehicle.model,
            plate = vehicle.plate
        })
    end)

    return {
        entity = entity,
        netId = netId
    }, nil
end

local function vectorListToPlain(list)
    local plain = {}

    for i = 1, #(list or {}) do
        local v = list[i]
        plain[#plain + 1] = { x = v.x, y = v.y, z = v.z }
    end

    return plain
end

RegisterNetEvent('driftzone_racejob:server:open', function()
    local src = source

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    TriggerClientEvent('driftzone_racejob:client:open', src, {
        vehicles = getVehicles(uid)
    })
end)

RegisterNetEvent('driftzone_racejob:server:start', function(payload)
    local src = source
    payload = payload or {}

    if RaceLocks[src] then
        notify(src, 'warning', 'Cursa este deja in pregatire.')
        return
    end

    RaceLocks[src] = true

    local ok, err = pcall(function()
        if not isLogged(src) then
            notify(src, 'warning', 'Trebuie sa fii logat.')
            return
        end

        local uid = getUid(src)
        if not uid then
            notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
            return
        end

        if ActiveRaces[src] then
            notify(src, 'warning', 'Ai deja o cursa activa.')
            return
        end

        local raceId = tostring(payload.race or 'short'):lower()
        local raceConfig = Config.Races[raceId]

        if not raceConfig or raceConfig.enabled ~= true then
            notify(src, 'warning', 'Aceasta cursa nu este disponibila momentan.')
            return
        end

        local vehicleId = tonumber(payload.vehicleId or 0) or 0
        local vehicle = getOwnedVehicle(uid, vehicleId)

        if not vehicle then
            notify(src, 'warning', 'Masina selectata nu iti apartine.')
            return
        end

        deleteExistingGarageVehicle(vehicleId)
        Wait(250)

        local created, createErr = createRaceVehicle(src, uid, vehicle, raceConfig)

        if not created then
            notify(src, 'error', createErr or 'Nu am putut porni cursa.')
            return
        end

        RaceIdCounter = RaceIdCounter + 1
        local internalRaceId = ('race_%s_%s'):format(src, RaceIdCounter)

        ActiveRaces[src] = {
            id = internalRaceId,
            uid = uid,
            startedAt = os.time(),
            raceType = raceId,
            vehicleId = vehicleId,
            entity = created.entity,
            netId = created.netId
        }

        TriggerClientEvent('driftzone_racejob:client:start', src, {
            raceId = internalRaceId,
            vehicleId = vehicleId,
            netId = created.netId,
            checkpoints = vectorListToPlain(raceConfig.checkpoints or {}),
            finish = { x = raceConfig.finish.x, y = raceConfig.finish.y, z = raceConfig.finish.z }
        })
    end)

    RaceLocks[src] = nil

    if not ok then
        print(('[DRIFTZONE_RACEJOB] start error src=%s: %s'):format(src, tostring(err)))
        notify(src, 'error', 'A aparut o eroare la pornirea cursei.')
    end
end)

RegisterNetEvent('driftzone_racejob:server:finish', function(raceId)
    local src = source
    local race = ActiveRaces[src]

    if not race or tostring(race.id) ~= tostring(raceId or '') then
        notify(src, 'warning', 'Nu ai o cursa activa valida.')
        return
    end

    local uid = getUid(src)

    if not uid or tonumber(uid) ~= tonumber(race.uid) then
        notify(src, 'warning', 'UID invalid pentru cursa.')
        return
    end

    local reward = math.random(Config.Reward.min or 2000, Config.Reward.max or 5000)

    MySQL.update.await(
        ('UPDATE `%s` SET `%s` = `%s` + ? WHERE `%s` = ? LIMIT 1'):format(
            Config.UsersTable or 'users',
            Config.UsersCashColumn or 'cash',
            Config.UsersCashColumn or 'cash',
            Config.UsersIdColumn or 'uid'
        ),
        { reward, uid }
    )

    notify(src, 'success', ('Ai terminat cursa si ai primit $%s.'):format(reward), 6500)

    ActiveRaces[src] = nil
end)

RegisterNetEvent('driftzone_racejob:server:cancel', function()
    local src = source
    ActiveRaces[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    local race = ActiveRaces[src]

    if race and race.entity and vehicleExists(race.entity) then
        deleteEntitySafe(race.entity)
    end

    ActiveRaces[src] = nil
    RaceLocks[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, entity in pairs(RaceVehicles) do
        if vehicleExists(entity) then
            deleteEntitySafe(entity)
        end
    end

    RaceVehicles = {}
    ActiveRaces = {}
    RaceLocks = {}
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_RACEJOB] Server loaded. Short Race ready.')
end)
