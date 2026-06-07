local nuiReady = false
local menuOpen = false
local pendingPayload = nil
local activeRace = nil
local activeBlip = nil
local activeCheckpoint = nil
local currentMarkerThread = false

local function notify(notifyType, message, duration)
    TriggerEvent('client:notify', notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function sendNui(data)
    if not nuiReady then
        if data.action == 'open' then
            pendingPayload = data
        end
        return false
    end

    SendNUIMessage(data)
    return true
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)

    if menuOpen then
        TriggerEvent('driftzone_hud:visible', false)
    else
        TriggerEvent('driftzone_hud:visible', true)
    end
end

local function closeMenu()
    sendNui({ action = 'close' })
    setFocus(false)
end

local function openMenu(payload)
    payload = payload or {}

    local data = {
        action = 'open',
        mainColor = Config.MainColor,
        races = {
            Config.Races.short,
            Config.Races.medium,
            Config.Races.long
        },
        vehicles = payload.vehicles or {}
    }

    if sendNui(data) then
        setFocus(true)
    else
        pendingPayload = data
    end
end

local function clearRaceBlip()
    if activeBlip and DoesBlipExist(activeBlip) then
        RemoveBlip(activeBlip)
    end

    activeBlip = nil
end

local function clearRaceCheckpoint()
    if activeCheckpoint then
        DeleteCheckpoint(activeCheckpoint)
    end

    activeCheckpoint = nil
end

local function cleanupRaceUi()
    clearRaceBlip()
    clearRaceCheckpoint()
    currentMarkerThread = false
end

local function createRouteBlip(coords, label)
    clearRaceBlip()

    activeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(activeBlip, 1)
    SetBlipColour(activeBlip, 3)
    SetBlipScale(activeBlip, 0.85)
    SetBlipRoute(activeBlip, true)
    SetBlipRouteColour(activeBlip, 3)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Race Checkpoint')
    EndTextCommandSetBlipName(activeBlip)

    SetNewWaypoint(coords.x, coords.y)
end

local function createRaceCheckpoint(coords, isFinish)
    clearRaceCheckpoint()

    local cType = isFinish and 4 or 47
    activeCheckpoint = CreateCheckpoint(
        cType,
        coords.x, coords.y, coords.z + 0.4,
        coords.x, coords.y, coords.z,
        7.0,
        4, 199, 247, 190,
        0
    )

    if activeCheckpoint then
        SetCheckpointCylinderHeight(activeCheckpoint, 4.0, 4.0, 4.0)
    end
end

local function getTargetCoords()
    if not activeRace then return nil, false end

    local nextIndex = activeRace.index or 1
    local checkpoints = activeRace.checkpoints or {}

    if checkpoints[nextIndex] then
        return checkpoints[nextIndex], false
    end

    return activeRace.finish, true
end

local function setNextCheckpoint()
    if not activeRace then return end

    local coords, isFinish = getTargetCoords()
    if not coords then return end

    createRouteBlip(coords, isFinish and 'Race Finish' or ('Race Checkpoint ' .. tostring(activeRace.index or 1)))
    createRaceCheckpoint(coords, isFinish)

    notify('info', isFinish and 'Mergi la finish.' or ('Checkpoint ' .. tostring(activeRace.index or 1) .. '/' .. tostring(#(activeRace.checkpoints or {}))), 2500)
end

local function tryWarpIntoVehicle(netId)
    local timeout = GetGameTimer() + 6500
    local vehicle = 0

    while GetGameTimer() < timeout do
        if NetworkDoesNetworkIdExist(netId) then
            vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                break
            end
        end

        Wait(75)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('error', 'Masina cursei nu s-a incarcat corect.')
        return nil
    end

    local ped = PlayerPedId()
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineOn(vehicle, true, true, false)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    return vehicle
end

local function startRaceLoop()
    if currentMarkerThread then return end
    currentMarkerThread = true

    CreateThread(function()
        while activeRace and currentMarkerThread do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local target, isFinish = getTargetCoords()

            if not target then
                Wait(500)
            else
                DrawMarker(
                    1,
                    target.x, target.y, target.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    isFinish and 10.5 or 8.5,
                    isFinish and 10.5 or 8.5,
                    2.0,
                    4, 199, 247, 165,
                    false, true, 2, false, nil, nil, false
                )

                local radius = isFinish and (Config.FinishRadius or 8.0) or (Config.CheckpointRadius or 8.0)
                local dist = #(coords - vector3(target.x, target.y, target.z))

                if dist <= radius then
                    if isFinish then
                        local raceId = activeRace.raceId
                        cleanupRaceUi()
                        activeRace = nil
                        TriggerServerEvent('driftzone_racejob:server:finish', raceId)
                    else
                        activeRace.index = (activeRace.index or 1) + 1
                        setNextCheckpoint()
                        Wait(900)
                    end
                end

                Wait(0)
            end
        end

        cleanupRaceUi()
    end)
end

RegisterNetEvent(Config.OpenEvent or 'driftzone_racejob:client:openFromInteraction', function()
    TriggerServerEvent('driftzone_racejob:server:open')
end)

RegisterNetEvent('driftzone_racejob:client:open', function(payload)
    openMenu(payload or {})
end)

RegisterNetEvent('driftzone_racejob:client:start', function(data)
    data = data or {}

    closeMenu()
    cleanupRaceUi()

    local netId = tonumber(data.netId or 0) or 0
    local vehicle = tryWarpIntoVehicle(netId)

    if not vehicle then
        TriggerServerEvent('driftzone_racejob:server:cancel')
        return
    end

    activeRace = {
        raceId = data.raceId,
        vehicleId = tonumber(data.vehicleId or 0) or 0,
        netId = netId,
        vehicle = vehicle,
        index = 1,
        checkpoints = data.checkpoints or {},
        finish = data.finish
    }

    notify('success', 'Race Job a inceput. Urmareste checkpointurile albastre.', 4500)
    setNextCheckpoint()
    startRaceLoop()
end)

RegisterNetEvent('driftzone_racejob:client:cancel', function()
    cleanupRaceUi()
    activeRace = nil
    closeMenu()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true

    if pendingPayload then
        local payload = pendingPayload
        pendingPayload = nil
        sendNui(payload)
        if payload.action == 'open' then
            setFocus(true)
        end
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('start', function(data, cb)
    data = data or {}

    TriggerServerEvent('driftzone_racejob:server:start', {
        race = tostring(data.race or ''),
        vehicleId = tonumber(data.vehicleId or 0) or 0
    })

    cb({ ok = true })
end)

RegisterCommand('racejob', function()
    TriggerServerEvent('driftzone_racejob:server:open')
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    cleanupRaceUi()
    SetNuiFocus(false, false)
end)
