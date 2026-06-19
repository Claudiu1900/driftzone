local phoneVisible = false
local phoneOpen = false
local phoneFocus = false
local lastState = {}
local currentCallOptions = { muted = false, speaker = false }


-- =========================
-- GARAGE PHONE APP
-- =========================
local PendingGarageVehicles = {}
local ConfirmedGarageVehicles = {}

local function garageNotify(typ, msg, duration)
    TriggerEvent('client:notify', typ or 'info', duration or 4500, tostring(msg or ''))
end

local function requestVehicleControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local expires = GetGameTimer() + (tonumber(timeout or 1200) or 1200)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < expires do
        NetworkRequestControlOfEntity(entity)
        Wait(25)
    end
    return NetworkHasControlOfEntity(entity)
end

local function loadVehicleModel(hash, timeout)
    hash = tonumber(hash or 0) or 0
    if hash == 0 or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return false end

    RequestModel(hash)
    local expires = GetGameTimer() + (tonumber(timeout or 10000) or 10000)

    while not HasModelLoaded(hash) and GetGameTimer() < expires do
        Wait(25)
    end

    return HasModelLoaded(hash)
end

local function getGroundSpawnZ(x, y, z)
    x = tonumber(x or 0.0) or 0.0
    y = tonumber(y or 0.0) or 0.0
    z = tonumber(z or 0.0) or 0.0

    for _, height in ipairs({ z + 80.0, z + 50.0, z + 25.0, z + 10.0, z + 3.0 }) do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
        if found and groundZ then return groundZ + 0.05 end
        Wait(0)
    end

    return z
end

local function applyGarageVehicleTuning(entity, tuningRaw, gradientRaw)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    requestVehicleControl(entity, 1200)
    SetVehicleModKit(entity, 0)

    if tuningRaw and tostring(tuningRaw) ~= '' then
        TriggerEvent('client:tunning:applyVehicle', VehToNet(entity), tostring(tuningRaw))
        TriggerEvent('driftzone_tunning:client:applyVehicle', VehToNet(entity), tostring(tuningRaw))
    end
end

local function deleteGarageVehicle(vehicle)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        requestVehicleControl(vehicle, 1000)
        DeleteVehicle(vehicle)
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end
end

local function cleanupPendingGarageVehicle(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if ConfirmedGarageVehicles[vehicleId] then
        PendingGarageVehicles[vehicleId] = nil
        return
    end
    deleteGarageVehicle(PendingGarageVehicles[vehicleId])
    PendingGarageVehicles[vehicleId] = nil
end

RegisterNetEvent('driftzone_phone:client:garageCreateVehicle', function(data)
    data = data or {}

    local vehicleId = tonumber(data.id or 0) or 0
    local model = tostring(data.model or '')
    local hash = GetHashKey(model)
    local spawn = type(data.spawn) == 'table' and data.spawn or {}

    local x = tonumber(spawn.x)
    local y = tonumber(spawn.y)
    local z = tonumber(spawn.z)
    local h = tonumber(spawn.h or spawn.heading or 0.0) or 0.0

    if vehicleId <= 0 or not x or not y or not z then
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Date spawn invalide.')
        return
    end

    cleanupPendingGarageVehicle(vehicleId)

    if not loadVehicleModel(hash, 10000) then
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Modelul masinii nu este streamat.')
        return
    end

    z = getGroundSpawnZ(x, y, z)
    local vehicle = CreateVehicle(hash, x, y, z, h, true, true)

    local expires = GetGameTimer() + 7000
    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and GetGameTimer() < expires do
        Wait(25)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Nu am putut crea masina.')
        return
    end

    PendingGarageVehicles[vehicleId] = vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityCoordsNoOffset(vehicle, x, y, z, false, false, false)
    Wait(0)
    SetVehicleOnGroundProperly(vehicle)
    Wait(0)
    SetEntityHeading(vehicle, h)
    SetVehicleNumberPlateText(vehicle, tostring(data.plate or 'DRIFT'):sub(1, 8))
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleDirtLevel(vehicle, 0.0)

    local state = Entity(vehicle).state
    state:set('dz_phone_garage_vehicle', true, true)
    state:set('dz_phone_garage_vehicle_id', vehicleId, true)
    state:set('dz_phone_garage_plate', tostring(data.plate or ''), true)
    state:set('dz_garage_vehicle', true, true)
    state:set('dz_garage_db_id', vehicleId, true)
    state:set('ownedVehicleId', vehicleId, true)

    applyGarageVehicleTuning(vehicle, data.tuning, data.gradient)

    local netId = VehToNet(vehicle)
    NetworkRegisterEntityAsNetworked(vehicle)
    netId = VehToNet(vehicle)

    if netId and netId > 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
    end

    expires = GetGameTimer() + 5000
    while (not netId or netId <= 0) and GetGameTimer() < expires do
        Wait(50)
        netId = VehToNet(vehicle)
    end

    if not netId or netId <= 0 then
        cleanupPendingGarageVehicle(vehicleId)
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Masina nu a primit Network ID.')
        return
    end

    ConfirmedGarageVehicles[vehicleId] = true
    SetModelAsNoLongerNeeded(hash)
    TriggerServerEvent('driftzone_phone:server:garageConfirmSpawn', vehicleId, netId)
end)

RegisterNetEvent('driftzone_phone:client:garageSpawnSuccess', function(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId > 0 then
        PendingGarageVehicles[vehicleId] = nil
        ConfirmedGarageVehicles[vehicleId] = true
    end
end)

RegisterNetEvent('driftzone_phone:client:garageDeletePending', function(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    ConfirmedGarageVehicles[vehicleId] = nil
    cleanupPendingGarageVehicle(vehicleId)
end)

RegisterNetEvent('driftzone_phone:client:garageDeleteNet', function(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    CreateThread(function()
        if NetworkDoesNetworkIdExist(netId) then
            deleteGarageVehicle(NetToVeh(netId))
        end
    end)
end)

RegisterNetEvent('driftzone_phone:client:garageWaypoint', function(coords)
    coords = coords or {}
    local x = tonumber(coords.x)
    local y = tonumber(coords.y)

    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
    else
        garageNotify('warning', 'Locatia masinii nu este valida.')
    end
end)


local function sendNui(data)
    SendNUIMessage(data)
end

local function setFocus(state)
    phoneFocus = state == true
    SetNuiFocus(phoneFocus, phoneFocus)
    SetNuiFocusKeepInput(false)
    sendNui({ action = 'focus', focus = phoneFocus })
end

local function resetCallOptions()
    currentCallOptions = { muted = false, speaker = false }
    TriggerEvent('driftzone_voicechat:client:setPhoneOptions', currentCallOptions)
end

local function refreshState()
    TriggerServerEvent('driftzone_phone:server:requestState')
end

local function openPhone(screen)
    phoneVisible = true
    phoneOpen = true
    setFocus(true)
    sendNui({
        action = 'open',
        screen = screen or 'home',
        mainColor = Config.MainColor or '#04c7f7',
        state = lastState or {}
    })
    refreshState()
end

local function showIncomingPeek(state)
    phoneVisible = true
    phoneOpen = false
    setFocus(false)
    sendNui({ action = 'incomingPeek', mainColor = Config.MainColor or '#04c7f7', state = state or lastState or {} })
end

local function showMessagePeek(payload)
    if phoneOpen then return end
    phoneVisible = true
    phoneOpen = false
    setFocus(false)
    sendNui({ action = 'messagePeek', mainColor = Config.MainColor or '#04c7f7', message = payload or {}, state = lastState or {} })

    SetTimeout(3000, function()
        if phoneVisible and not phoneOpen then
            closePhone()
        end
    end)
end

local function closePhone()
    phoneVisible = false
    phoneOpen = false
    resetCallOptions()
    setFocus(false)
    sendNui({ action = 'close' })
end

local function toggleCursor()
    if not phoneVisible then return end
    setFocus(not phoneFocus)
end

RegisterCommand(Config.Command or 'phone', function()
    if phoneOpen then
        closePhone()
    else
        openPhone('home')
    end
end, false)

RegisterKeyMapping(Config.Command or 'phone', 'Deschide telefonul', 'keyboard', 'L')

RegisterNUICallback('ready', function(_, cb)
    sendNui({ action = 'setup', mainColor = Config.MainColor or '#04c7f7' })
    refreshState()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb({ ok = true })
end)

RegisterNUICallback('openFull', function(data, cb)
    openPhone(data and data.screen or 'home')
    cb({ ok = true })
end)

RegisterNUICallback('toggleCursor', function(_, cb)
    toggleCursor()
    cb({ ok = true })
end)

RegisterNUICallback('requestState', function(_, cb)
    refreshState()
    cb({ ok = true })
end)

RegisterNUICallback('dial', function(data, cb)
    phoneVisible = true
    phoneOpen = true
    TriggerServerEvent('driftzone_phone:server:startCall', data and data.number or '')
    cb({ ok = true })
end)

RegisterNUICallback('answer', function(_, cb)
    phoneVisible = true
    phoneOpen = true
    setFocus(true)
    sendNui({ action = 'open', screen = 'call', state = lastState or {} })
    TriggerServerEvent('driftzone_phone:server:answerCall')
    cb({ ok = true })
end)

RegisterNUICallback('decline', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:declineCall')
    if not phoneOpen then
        closePhone()
    else
        setFocus(true)
    end
    cb({ ok = true })
end)

RegisterNUICallback('hangup', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:hangupCall')
    resetCallOptions()
    if phoneOpen then setFocus(true) end
    cb({ ok = true })
end)

RegisterNUICallback('setCallOptions', function(data, cb)
    currentCallOptions = {
        muted = data and data.muted == true,
        speaker = data and data.speaker == true
    }
    TriggerEvent('driftzone_voicechat:client:setPhoneOptions', currentCallOptions)
    cb({ ok = true })
end)

RegisterNUICallback('saveContact', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:saveContact', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('toggleBlock', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:toggleBlock', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('deleteContact', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:deleteContact', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('sendMessage', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:sendMessage', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('shareLocation', function(data, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    TriggerServerEvent('driftzone_phone:server:sendMessage', {
        number = data and data.number or '',
        type = 'location',
        text = 'Locatie partajata',
        location = { x = c.x, y = c.y, z = c.z },
        clientToken = data and data.clientToken or ''
    })
    cb({ ok = true })
end)


RegisterNUICallback('garageSpawn', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageSpawn', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('garagePark', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garagePark', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('garageTow', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageTow', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('garageLocate', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageLocate', data and data.id or 0)
    cb({ ok = true })
end)


RegisterNUICallback('setWaypoint', function(data, cb)
    local loc = data and data.location or {}
    local x = tonumber(loc.x)
    local y = tonumber(loc.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
    end
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_phone:client:state', function(state)
    local wasInCall = lastState and lastState.inCall == true
    local wasActive = lastState and lastState.active == true
    lastState = state or {}

    sendNui({ action = 'state', state = lastState })

    if wasInCall and not lastState.inCall then
        resetCallOptions()
        if phoneOpen then
            setFocus(true)
        elseif phoneVisible then
            closePhone()
        end
    end

    if wasActive and not lastState.active and phoneOpen then
        setFocus(true)
    end
end)

RegisterNetEvent('driftzone_phone:client:incoming', function(state)
    lastState = state or lastState or {}
    showIncomingPeek(lastState)
end)

RegisterNetEvent('driftzone_phone:client:messageSync', function(payload)
    sendNui({ action = 'messageSync', message = payload or {} })
end)

RegisterNetEvent('driftzone_phone:client:messageReceived', function(payload)
    sendNui({ action = 'messageReceived', message = payload or {} })
    showMessagePeek(payload or {})
end)

RegisterNetEvent('driftzone_phone:client:feedback', function(payload)
    sendNui({ action = 'feedback', payload = payload or {} })
end)

CreateThread(function()
    while true do
        if phoneVisible then
            if IsControlJustPressed(0, 243) or IsDisabledControlJustPressed(0, 243) then
                toggleCursor()
                Wait(250)
            end

            if phoneFocus then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 200, true)
            end

            Wait(0)
        else
            Wait(350)
        end
    end
end)

CreateThread(function()
    while true do
        if phoneVisible or (lastState and lastState.inCall) then
            refreshState()
            if lastState and lastState.inCall then
                Wait(2500)
            else
                Wait(Config.StateRefreshMs or 8000)
            end
        else
            Wait(6000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    resetCallOptions()
end)
