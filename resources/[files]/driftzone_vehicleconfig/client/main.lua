local LockedByNet = {}
local LockedBySqlId = {}
local LockedByPlate = {}
local LastNearbyCheck = 0
local NearbyVehicle = 0

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 3500, tostring(msg or ''))
end

local function dbg(msg)
    if Config.Debug then
        print('[driftzone_vehicleconfig] ' .. tostring(msg))
    end
end

local function getStateValue(entity, keys)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local state = Entity(entity).state
    if not state then return nil end

    for _, key in ipairs(keys or {}) do
        local value = state[key]
        if value ~= nil and tostring(value) ~= '' and tostring(value) ~= '0' then
            return value
        end
    end

    return nil
end

local function getVehicleSqlId(vehicle)
    local value = getStateValue(vehicle, Config.SqlIdStateKeys or {})
    return tonumber(value or 0) or 0
end

local function trimPlate(value)
    return tostring(value or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function getVehiclePlate(vehicle)
    local statePlate = getStateValue(vehicle, Config.PlateStateKeys or {})
    if statePlate then return trimPlate(statePlate) end
    return trimPlate(GetVehicleNumberPlateText(vehicle) or '')
end

local function getNetId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return tonumber(netId or 0) or 0
end

local function requestControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    local endTime = GetGameTimer() + (timeout or 650)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < endTime do
        NetworkRequestControlOfEntity(entity)
        Wait(20)
    end

    return NetworkHasControlOfEntity(entity)
end

local function applyLockToVehicle(vehicle, locked)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    requestControl(vehicle, 350)

    if locked then
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)
        SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), true)
    else
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    end
end

local function isVehicleLocked(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local netId = getNetId(vehicle)
    if netId > 0 and LockedByNet[netId] ~= nil then
        return LockedByNet[netId] == true
    end

    local sqlId = getVehicleSqlId(vehicle)
    if sqlId > 0 and LockedBySqlId[sqlId] ~= nil then
        return LockedBySqlId[sqlId] == true
    end

    local plate = getVehiclePlate(vehicle)
    if plate ~= '' and LockedByPlate[plate] ~= nil then
        return LockedByPlate[plate] == true
    end

    return GetVehicleDoorLockStatus(vehicle) == 2
end

local function getClosestVehicleSmart()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            return veh, 0.0
        end
    end

    local closest = 0
    local closestDist = tonumber(Config.SearchRadius or 7.5) or 7.5

    local handle, veh = FindFirstVehicle()
    local success = true

    repeat
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local dist = #(coords - GetEntityCoords(veh))
            if dist < closestDist then
                closest = veh
                closestDist = dist
            end
        end
        success, veh = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)

    if closest ~= 0 then
        return closest, closestDist
    end

    return 0, 99999.0
end

local function cacheVehicleLock(vehicle, locked)
    local netId = getNetId(vehicle)
    local sqlId = getVehicleSqlId(vehicle)
    local plate = getVehiclePlate(vehicle)

    if netId > 0 then LockedByNet[netId] = locked == true end
    if sqlId > 0 then LockedBySqlId[sqlId] = locked == true end
    if plate ~= '' then LockedByPlate[plate] = locked == true end
end

RegisterCommand(Config.LockCommand or 'vehiclelock', function()
    local vehicle, dist = getClosestVehicleSmart()

    if vehicle == 0 or dist > (tonumber(Config.LockDistance or 5.0) or 5.0) then
        notify('warning', 'Nu esti langa nicio masina.')
        return
    end

    local locked = not isVehicleLocked(vehicle)
    cacheVehicleLock(vehicle, locked)
    applyLockToVehicle(vehicle, locked)

    TriggerServerEvent('driftzone_vehicleconfig:server:setLock', {
        netId = getNetId(vehicle),
        sqlId = getVehicleSqlId(vehicle),
        plate = getVehiclePlate(vehicle),
        locked = locked
    })

    if Config.LockedSound then
        PlaySoundFrontend(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', 'PI_Menu_Sounds', true)
    end

    notify(locked and 'warning' or 'success', locked and 'Masina a fost blocata.' or 'Masina a fost deblocata.')
end, false)

RegisterCommand(Config.EngineCommand or 'engine', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    requestControl(vehicle, 450)

    local running = GetIsVehicleEngineRunning(vehicle)
    SetVehicleEngineOn(vehicle, not running, false, true)
    SetVehicleUndriveable(vehicle, false)

    TriggerServerEvent('driftzone_vehicleconfig:server:setEngine', getNetId(vehicle), not running)
end, false)

RegisterNetEvent('driftzone_vehicleconfig:client:applyLock', function(data)
    data = data or {}
    local netId = tonumber(data.netId or 0) or 0
    local sqlId = tonumber(data.sqlId or 0) or 0
    local plate = trimPlate(data.plate or '')
    local locked = data.locked == true

    if netId > 0 then LockedByNet[netId] = locked end
    if sqlId > 0 then LockedBySqlId[sqlId] = locked end
    if plate ~= '' then LockedByPlate[plate] = locked end

    if netId > 0 and NetworkDoesEntityExistWithNetworkId(netId) then
        local vehicle = NetToVeh(netId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            applyLockToVehicle(vehicle, locked)
        end
    end
end)

RegisterNetEvent('driftzone_vehicleconfig:client:applySqlLock', function(sqlId, locked)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return end
    LockedBySqlId[sqlId] = locked == true

    local handle, veh = FindFirstVehicle()
    local success = true
    repeat
        if veh and veh ~= 0 and DoesEntityExist(veh) and getVehicleSqlId(veh) == sqlId then
            cacheVehicleLock(veh, locked == true)
            applyLockToVehicle(veh, locked == true)
        end
        success, veh = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
end)

RegisterNetEvent('driftzone_vehicleconfig:client:setEngineState', function(netId, state)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 or not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local vehicle = NetToVeh(netId)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        requestControl(vehicle, 450)
        SetVehicleEngineOn(vehicle, state == true, false, true)
        SetVehicleUndriveable(vehicle, false)
    end
end)

-- Trigger pentru garaj dupa ce spawneaza masina:
-- TriggerEvent('driftzone_vehicleconfig:client:setEngineOff', vehicle)
-- TriggerEvent('driftzone_vehicleconfig:client:setEngineOff', VehToNet(vehicle))
RegisterNetEvent('driftzone_vehicleconfig:client:setEngineOff', function(vehicleOrNetId)
    local vehicle = tonumber(vehicleOrNetId or 0) or 0

    if vehicle > 0 and not DoesEntityExist(vehicle) and NetworkDoesEntityExistWithNetworkId(vehicle) then
        vehicle = NetToVeh(vehicle)
    end

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        requestControl(vehicle, 650)
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleUndriveable(vehicle, false)
        TriggerServerEvent('driftzone_vehicleconfig:server:setEngine', getNetId(vehicle), false)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local waitTime = 650

        if IsPedTryingToEnterALockedVehicle(ped) or IsPedGettingIntoAVehicle(ped) then
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
        local now = GetGameTimer()

        if now - LastNearbyCheck > 1200 then
            LastNearbyCheck = now
            NearbyVehicle = getClosestVehicleSmart()

            if NearbyVehicle and NearbyVehicle ~= 0 and DoesEntityExist(NearbyVehicle) then
                local sqlId = getVehicleSqlId(NearbyVehicle)
                local netId = getNetId(NearbyVehicle)
                local plate = getVehiclePlate(NearbyVehicle)

                if sqlId > 0 or netId > 0 or plate ~= '' then
                    TriggerServerEvent('driftzone_vehicleconfig:server:requestLockState', netId, sqlId, plate)
                end
            end
        end

        if NearbyVehicle and NearbyVehicle ~= 0 and DoesEntityExist(NearbyVehicle) then
            local locked = isVehicleLocked(NearbyVehicle)
            applyLockToVehicle(NearbyVehicle, locked)
        end

        Wait(1000)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(1500)
    TriggerServerEvent('driftzone_vehicleconfig:server:requestAllStates')
end)
