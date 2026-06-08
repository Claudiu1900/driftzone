local uiReady = false
local interactMode = false
local selectedPlayer = nil
local currentTarget = nil
local menuOpen = false
local payOpen = false
local markerRotation = 0.0
local lastRequest = 0

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 5000, tostring(msg or ''))
end

local function sendNui(data)
    if not uiReady then return false end
    SendNUIMessage(data)
    return true
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)
end

local function closeAll()
    interactMode = false
    selectedPlayer = nil
    currentTarget = nil
    payOpen = false
    sendNui({ action = 'closeAll' })
    setFocus(false)
end

local function startInteractMode()
    if interactMode then
        closeAll()
        return
    end
    closeAll()
    Wait(50)
    interactMode = true
    SetNuiFocus(false, false)
    notify('info', 'Selecteaza un jucator cu click. ESC pentru anulare.', 4500)
end

RegisterCommand(Config.Command or 'playerinteract', function()
    startInteractMode()
end, false)

local function rotationToDirection(rotation)
    local adjusted = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
    local direction = vector3(-math.sin(adjusted.z) * math.abs(math.cos(adjusted.x)), math.cos(adjusted.z) * math.abs(math.cos(adjusted.x)), math.sin(adjusted.x))
    return direction
end

local function raycastFromCamera(distance)
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local destination = camCoord + direction * (distance or Config.RayDistance or 18.0)
    local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, destination.x, destination.y, destination.z, 12, PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    return hit == 1, endCoords, entityHit
end

local function getPlayerFromEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if not IsEntityAPed(entity) or not IsPedAPlayer(entity) then return nil end
    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
    if playerIndex == -1 then return nil end
    local sid = GetPlayerServerId(playerIndex)
    if not sid or sid <= 0 or sid == GetPlayerServerId(PlayerId()) then return nil end
    local ped = PlayerPedId()
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(entity))
    if dist > (Config.MaxSelectDistance or 6.0) then return nil end
    return { serverId = sid, ped = entity, playerIndex = playerIndex, distance = dist }
end

local function drawTargetMarker(ped)
    if not Config.Marker or Config.Marker.enabled ~= true then return end
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local coords = GetEntityCoords(ped)
    markerRotation = (markerRotation + 2.2) % 360.0
    DrawMarker(
        Config.Marker.type or 25,
        coords.x, coords.y, coords.z - 0.96 + (Config.Marker.zOffset or 0.035),
        0.0, 0.0, 0.0,
        0.0, 0.0, markerRotation,
        Config.Marker.radius or 1.05,
        Config.Marker.radius or 1.05,
        Config.Marker.height or 0.035,
        Config.Marker.r or 4,
        Config.Marker.g or 199,
        Config.Marker.b or 247,
        Config.Marker.a or 190,
        false, false, 2, false, nil, nil, false
    )
end

local function openTargetMenu(info)
    if type(info) ~= 'table' then return end
    selectedPlayer = info
    interactMode = false
    sendNui({
        action = 'openMenu',
        player = info,
        mainColor = Config.MainColor
    })
    setFocus(true)
end

RegisterNetEvent('driftzone_playerinteract:client:targetInfo', function(ok, payload)
    if ok ~= true then
        notify('warning', payload or 'Nu poti interactiona cu acest jucator.', 4000)
        return
    end
    openTargetMenu(payload)
end)

RegisterNetEvent('driftzone_playerinteract:client:payResult', function(ok, message)
    sendNui({ action = 'payResult', ok = ok == true, message = tostring(message or '') })
    if ok == true then
        SetTimeout(900, function()
            closeAll()
        end)
    end
end)

CreateThread(function()
    while true do
        if not interactMode then
            Wait(250)
        else
            Wait(0)
            DisableControlAction(0, 1, false)
            DisableControlAction(0, 2, false)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsDisabledControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                closeAll()
            else
                local hit, _, entity = raycastFromCamera(Config.RayDistance or 18.0)
                if hit then
                    currentTarget = getPlayerFromEntity(entity)
                else
                    currentTarget = nil
                end

                if currentTarget and currentTarget.ped then
                    drawTargetMarker(currentTarget.ped)
                    if IsDisabledControlJustPressed(0, 24) then
                        local now = GetGameTimer()
                        if now - lastRequest > 500 then
                            lastRequest = now
                            TriggerServerEvent('driftzone_playerinteract:server:requestTargetInfo', currentTarget.serverId)
                        end
                    end
                end
            end
        end
    end
end)

RegisterNUICallback('ready', function(_, cb)
    uiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeAll()
    cb({ ok = true })
end)

RegisterNUICallback('openPay', function(_, cb)
    if not selectedPlayer then
        cb({ ok = false })
        return
    end
    payOpen = true
    sendNui({ action = 'openPay', player = selectedPlayer })
    cb({ ok = true })
end)

RegisterNUICallback('backToMenu', function(_, cb)
    if selectedPlayer then
        payOpen = false
        sendNui({ action = 'openMenu', player = selectedPlayer, mainColor = Config.MainColor })
    end
    cb({ ok = true })
end)

RegisterNUICallback('pay', function(data, cb)
    if not selectedPlayer then
        cb({ ok = false })
        return
    end
    local amount = tonumber(data and data.amount or 0) or 0
    TriggerServerEvent('driftzone_playerinteract:server:pay', selectedPlayer.serverId, amount)
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if menuOpen or interactMode then
        SetNuiFocus(false, false)
    end
end)
