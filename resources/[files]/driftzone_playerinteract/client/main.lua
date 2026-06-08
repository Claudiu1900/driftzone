local uiReady = false
local interactMode = false
local selectedPlayer = nil
local currentTarget = nil
local menuOpen = false
local payOpen = false
local markerRotation = 0.0
local lastRequest = 0
local cursorX = 0.5
local cursorY = 0.5

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

    local timeout = GetGameTimer() + 2000
    while not uiReady and GetGameTimer() < timeout do
        Wait(50)
    end

    interactMode = true
    selectedPlayer = nil
    currentTarget = nil
    cursorX = 0.5
    cursorY = 0.5

    sendNui({ action = 'openSelector', mainColor = Config.MainColor })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    notify('info', 'Muta mouse-ul pe un jucator si apasa click. ESC pentru anulare.', 4500)
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


local function findPlayerFromCursor()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local bestTarget = nil
    local bestScore = 999999.0
    local radius = tonumber(Config.SelectionScreenRadius or 0.055) or 0.055

    for _, playerIndex in ipairs(GetActivePlayers()) do
        if playerIndex ~= PlayerId() then
            local ped = GetPlayerPed(playerIndex)
            if ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
                local coords = GetEntityCoords(ped)
                local dist = #(myCoords - coords)
                if dist <= (Config.MaxSelectDistance or 6.0) then
                    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z + 0.72)
                    if onScreen then
                        local dx = sx - cursorX
                        local dy = sy - cursorY
                        local screenDist = math.sqrt((dx * dx) + (dy * dy))
                        if screenDist <= radius then
                            -- Prioritize cursor accuracy, then physical distance.
                            local score = screenDist + (dist * 0.002)
                            if score < bestScore then
                                bestScore = score
                                bestTarget = {
                                    serverId = GetPlayerServerId(playerIndex),
                                    ped = ped,
                                    playerIndex = playerIndex,
                                    distance = dist
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
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

            -- NUI are focus ca sa apara mouse-ul. Blocam actiunile care pot incurca selectia.
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim
            DisableControlAction(0, 37, true) -- weapon wheel
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            currentTarget = findPlayerFromCursor()
            if currentTarget and currentTarget.ped then
                drawTargetMarker(currentTarget.ped)
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


RegisterNUICallback('mouseMove', function(data, cb)
    cursorX = tonumber(data and data.x or cursorX) or cursorX
    cursorY = tonumber(data and data.y or cursorY) or cursorY
    cb({ ok = true })
end)

RegisterNUICallback('selectClick', function(_, cb)
    if not interactMode then
        cb({ ok = false })
        return
    end

    if not currentTarget or not currentTarget.serverId then
        notify('warning', 'Pune mouse-ul pe un jucator apropiat.', 1800)
        cb({ ok = false })
        return
    end

    local now = GetGameTimer()
    if now - lastRequest > 450 then
        lastRequest = now
        TriggerServerEvent('driftzone_playerinteract:server:requestTargetInfo', currentTarget.serverId)
    end

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
