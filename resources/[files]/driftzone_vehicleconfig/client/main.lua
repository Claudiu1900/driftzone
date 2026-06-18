local LockedBySqlId = {}
local LockedByNet = {}
local VehicleSqlCacheByPlate = {}
local EngineStateByNet = {}

local NearbyVehicle = 0
local LastNearbyCheck = 0
local LastEnterVehicle = 0
local LastLockPress = 0
local PendingLockRequest = false

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 3500, tostring(msg or ''))
end

local function trimPlate(value)
    return tostring(value or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function getPed()
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then return ped end
    return 0
end

local function getNetId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    return tonumber(NetworkGetNetworkIdFromEntity(vehicle) or 0) or 0
end

local function getStateValue(entity, keys)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local state = Entity(entity).state
    if not state then return nil end

    for _, key in ipairs(keys or {}) do
        local value = state[key]
        if value ~= nil and tostring(value) ~= '' and tostring(value) ~= '0' and tostring(value) ~= 'false' then
            return value
        end
    end

    return nil
end

local function getVehiclePlate(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return '' end

    local statePlate = getStateValue(vehicle, Config.PlateStateKeys or {})
    if statePlate then return trimPlate(statePlate) end

    return trimPlate(GetVehicleNumberPlateText(vehicle) or '')
end

local function getVehicleSqlId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end

    local value = getStateValue(vehicle, Config.SqlIdStateKeys or {})
    local sqlId = tonumber(value or 0) or 0
    if sqlId > 0 then return sqlId end

    local plate = getVehiclePlate(vehicle)
    if plate ~= '' and VehicleSqlCacheByPlate[plate] then
        return tonumber(VehicleSqlCacheByPlate[plate] or 0) or 0
    end

    return 0
end

local function requestControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not NetworkGetEntityIsNetworked(entity) then return true end
    if NetworkHasControlOfEntity(entity) then return true end

    local endTime = GetGameTimer() + (timeout or 650)

    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < endTime do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end

    return NetworkHasControlOfEntity(entity)
end

local function applyLockToVehicle(vehicle, locked)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    requestControl(vehicle, 650)

    if locked then
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)

        for _, id in ipairs(GetActivePlayers()) do
            SetVehicleDoorsLockedForPlayer(vehicle, id, true)
        end
    else
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)

        for _, id in ipairs(GetActivePlayers()) do
            SetVehicleDoorsLockedForPlayer(vehicle, id, false)
        end
    end
end

local function forceLockForSpawn(vehicle, sqlId, netId, plate)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local repeats = tonumber(Config.SpawnLockApplyRepeats or 8) or 8
    local interval = tonumber(Config.SpawnLockApplyIntervalMs or 250) or 250

    CreateThread(function()
        for _ = 1, repeats do
            if not DoesEntityExist(vehicle) then return end

            if sqlId and sqlId > 0 then
                Entity(vehicle).state:set('ownedVehicleId', sqlId, true)
                LockedBySqlId[sqlId] = true
            end

            if netId and netId > 0 then LockedByNet[netId] = true end
            if plate and plate ~= '' and sqlId and sqlId > 0 then VehicleSqlCacheByPlate[plate] = sqlId end

            applyLockToVehicle(vehicle, true)
            Wait(interval)
        end
    end)
end

local function setVehicleEngine(vehicle, state)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    requestControl(vehicle, 450)

    SetVehicleEngineOn(vehicle, state == true, false, true)
    SetVehicleUndriveable(vehicle, false)

    local netId = getNetId(vehicle)
    if netId > 0 then
        EngineStateByNet[netId] = state == true
    end
end

local function isVehicleLocked(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local sqlId = getVehicleSqlId(vehicle)
    if sqlId > 0 and LockedBySqlId[sqlId] ~= nil then
        return LockedBySqlId[sqlId] == true
    end

    local netId = getNetId(vehicle)
    if netId > 0 and LockedByNet[netId] ~= nil then
        return LockedByNet[netId] == true
    end

    return GetVehicleDoorLockStatus(vehicle) == 2
end

local function getClosestVehicleSmart()
    local ped = getPed()
    if ped == 0 then return 0, 99999.0 end

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            return veh, 0.0
        end
    end

    local coords = GetEntityCoords(ped)
    local closest = 0
    local closestDist = tonumber(Config.SearchRadius or 7.5) or 7.5
    local vehicles = GetGamePool('CVehicle') or {}

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local dist = #(coords - GetEntityCoords(veh))
            if dist < closestDist then
                closest = veh
                closestDist = dist
            end
        end
    end

    if closest ~= 0 then return closest, closestDist end
    return 0, 99999.0
end

local function vehiclePayload(vehicle, locked)
    return {
        netId = getNetId(vehicle),
        sqlId = getVehicleSqlId(vehicle),
        plate = getVehiclePlate(vehicle),
        locked = locked == true
    }
end

local function playLockSound(locked)
    if not Config.LockedSound then return end
    PlaySoundFrontend(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', 'PI_Menu_Sounds', true)
end

local function requestToggleLock()
    local now = GetGameTimer()
    local cooldown = tonumber(Config.LockCooldownMs or 3000) or 3000

    if PendingLockRequest then return end
    if now - LastLockPress < cooldown then return end

    local vehicle, dist = getClosestVehicleSmart()

    if vehicle == 0 or dist > (tonumber(Config.LockDistance or 6.0) or 6.0) then
        notify('warning', 'Nu esti langa nicio masina.')
        return
    end

    local sqlId = getVehicleSqlId(vehicle)
    local plate = getVehiclePlate(vehicle)

    if sqlId <= 0 and (Config.AllowPlateFallback ~= true or plate == '') then
        notify('warning', 'Masina asta nu este masina personala.')
        return
    end

    local newLocked = not isVehicleLocked(vehicle)

    LastLockPress = now
    PendingLockRequest = true

    SetTimeout(1200, function()
        PendingLockRequest = false
    end)

    -- Nu aplicam local. Serverul verifica owner_id / cheia temporara si abia dupa trimite lock.
    TriggerServerEvent('driftzone_vehicleconfig:server:toggleOwnedLock', vehiclePayload(vehicle, newLocked))
end

local function toggleEngine()
    local ped = getPed()
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify('warning', 'Trebuie sa fii sofer.')
        return
    end

    local running = GetIsVehicleEngineRunning(vehicle)
    local newState = not running

    setVehicleEngine(vehicle, newState)
    TriggerServerEvent('driftzone_vehicleconfig:server:setEngine', getNetId(vehicle), newState)

    notify(newState and 'success' or 'warning', newState and 'Motor pornit.' or 'Motor oprit.')
end

RegisterCommand((Config.Commands and Config.Commands.Lock) or 'vehiclelock', function()
    requestToggleLock()
end, false)

RegisterCommand((Config.Commands and Config.Commands.Engine) or 'engine', function()
    toggleEngine()
end, false)

CreateThread(function()
    while true do
        if IsControlJustPressed(0, (Config.Keys and Config.Keys.Lock) or 170) then
            requestToggleLock()
            Wait(350)
        end

        if IsControlJustPressed(0, (Config.Keys and Config.Keys.Engine) or 37) then
            toggleEngine()
            Wait(350)
        end

        Wait(0)
    end
end)

RegisterNetEvent('driftzone_vehicleconfig:client:applyLock', function(data)
    data = type(data) == 'table' and data or {}

    local netId = tonumber(data.netId or 0) or 0
    local sqlId = tonumber(data.sqlId or 0) or 0
    local plate = trimPlate(data.plate or '')
    local locked = data.locked == true

    if sqlId > 0 then LockedBySqlId[sqlId] = locked end
    if netId > 0 then LockedByNet[netId] = locked end
    if plate ~= '' and sqlId > 0 then VehicleSqlCacheByPlate[plate] = sqlId end

    if netId > 0 and NetworkDoesEntityExistWithNetworkId(netId) then
        local vehicle = NetToVeh(netId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            applyLockToVehicle(vehicle, locked)
        end
    elseif sqlId > 0 then
        local vehicles = GetGamePool('CVehicle') or {}

        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and getVehicleSqlId(vehicle) == sqlId then
                applyLockToVehicle(vehicle, locked)
            end
        end
    end
end)

RegisterNetEvent('driftzone_vehicleconfig:client:lockFeedback', function(locked, message)
    PendingLockRequest = false
    locked = locked == true
    playLockSound(locked)
    notify(locked and 'warning' or 'success', tostring(message or (locked and 'Masina a fost incuiata.' or 'Masina a fost descuiata.')))
end)

RegisterNetEvent('driftzone_vehicleconfig:client:lockDenied', function(message)
    PendingLockRequest = false
    notify('warning', message or 'Nu ai acces la masina asta.')
end)

RegisterNetEvent('driftzone_vehicleconfig:client:applySqlLock', function(sqlId, locked)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return end

    LockedBySqlId[sqlId] = locked == true

    local vehicles = GetGamePool('CVehicle') or {}
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and getVehicleSqlId(vehicle) == sqlId then
            applyLockToVehicle(vehicle, locked == true)
        end
    end
end)

RegisterNetEvent('driftzone_vehicleconfig:client:setEngineState', function(netId, state)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    EngineStateByNet[netId] = state == true

    if NetworkDoesEntityExistWithNetworkId(netId) then
        local vehicle = NetToVeh(netId)

        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            setVehicleEngine(vehicle, state == true)
        end
    end
end)

RegisterNetEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', function(vehicleOrNetId, sqlId)
    local vehicle = tonumber(vehicleOrNetId or 0) or 0
    sqlId = tonumber(sqlId or 0) or 0

    if vehicle > 0 and not DoesEntityExist(vehicle) and NetworkDoesEntityExistWithNetworkId(vehicle) then
        vehicle = NetToVeh(vehicle)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local netId = getNetId(vehicle)
    local plate = getVehiclePlate(vehicle)

    if sqlId > 0 then
        Entity(vehicle).state:set('ownedVehicleId', sqlId, true)
        LockedBySqlId[sqlId] = true
        if plate ~= '' then VehicleSqlCacheByPlate[plate] = sqlId end
    end

    setVehicleEngine(vehicle, false)
    forceLockForSpawn(vehicle, sqlId, netId, plate)

    TriggerServerEvent('driftzone_vehicleconfig:server:registerSpawnedVehicle', {
        netId = netId,
        sqlId = sqlId,
        plate = plate
    })
end)

RegisterNetEvent('driftzone_vehicleconfig:client:setEngineOff', function(vehicleOrNetId)
    local vehicle = tonumber(vehicleOrNetId or 0) or 0

    if vehicle > 0 and not DoesEntityExist(vehicle) and NetworkDoesEntityExistWithNetworkId(vehicle) then
        vehicle = NetToVeh(vehicle)
    end

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        setVehicleEngine(vehicle, false)
        TriggerServerEvent('driftzone_vehicleconfig:server:setEngine', getNetId(vehicle), false)
    end
end)

CreateThread(function()
    while true do
        local ped = getPed()
        local waitTime = 650

        if ped ~= 0 and (IsPedTryingToEnterALockedVehicle(ped) or IsPedGettingIntoAVehicle(ped)) then
            local vehicle = GetVehiclePedIsTryingToEnter(ped)

            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and isVehicleLocked(vehicle) then
                applyLockToVehicle(vehicle, true)
                ClearPedTasks(ped)
                waitTime = 0
            end
        end

        Wait(waitTime)
    end
end)

CreateThread(function()
    while true do
        if Config.ForceEngineOffUntilStarted == true then
            local ped = getPed()

            if ped ~= 0 and IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)

                if vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
                    local netId = getNetId(vehicle)

                    if LastEnterVehicle ~= vehicle then
                        LastEnterVehicle = vehicle

                        if netId > 0 and EngineStateByNet[netId] ~= true then
                            setVehicleEngine(vehicle, false)
                            TriggerServerEvent('driftzone_vehicleconfig:server:setEngine', netId, false)
                        end
                    end
                end
            else
                LastEnterVehicle = 0
            end
        end

        Wait(tonumber(Config.DriverEngineLoopMs or 350) or 350)
    end
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()

        if now - LastNearbyCheck > (tonumber(Config.StateRefreshMs or 1000) or 1000) then
            LastNearbyCheck = now
            NearbyVehicle = getClosestVehicleSmart()

            if NearbyVehicle and NearbyVehicle ~= 0 and DoesEntityExist(NearbyVehicle) then
                TriggerServerEvent('driftzone_vehicleconfig:server:requestVehicleState', vehiclePayload(NearbyVehicle, false))
            end
        end

        if NearbyVehicle and NearbyVehicle ~= 0 and DoesEntityExist(NearbyVehicle) then
            local sqlId = getVehicleSqlId(NearbyVehicle)

            if sqlId > 0 then
                applyLockToVehicle(NearbyVehicle, isVehicleLocked(NearbyVehicle))
            end
        end

        Wait(1000)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    Wait(1500)
    TriggerServerEvent('driftzone_vehicleconfig:server:requestAllStates')
end)
