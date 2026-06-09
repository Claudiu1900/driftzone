local nuiOpen = false
local nuiReady = false
local lastOpen = 0

local function notify(t, msg, d)
    TriggerEvent(Config.NotifyEvent or 'client:notify', t or 'info', d or 5000, tostring(msg or ''))
end

local function sendNui(data)
    if not nuiReady then return false end
    SendNUIMessage(data)
    return true
end

local function setFocus(state)
    nuiOpen = state == true
    SetNuiFocus(nuiOpen, nuiOpen)
    SetNuiFocusKeepInput(false)
end

local function closeUi()
    if not nuiOpen then return end
    sendNui({ action = 'close' })
    setFocus(false)
end

local function openFromServer(data)
    data = data or {}
    setFocus(true)
    sendNui({
        action = 'open',
        mainColor = Config.MainColor,
        data = data
    })
end

local function requestOpen()
    local now = GetGameTimer()
    if now - lastOpen < 650 then return end
    lastOpen = now
    TriggerServerEvent('driftzone_licenses:server:requestOpen')
end

RegisterCommand(Config.Command or 'licenses', function()
    requestOpen()
end, false)

RegisterNetEvent('driftzone_licenses:client:openFromInteraction', function()
    requestOpen()
end)

RegisterNetEvent('driftzone_licenses:client:open', function(data)
    openFromServer(data)
end)

RegisterNetEvent('driftzone_licenses:client:refresh', function(data)
    sendNui({ action = 'refresh', data = data or {} })
end)

RegisterNetEvent('driftzone_licenses:client:result', function(ok, message, data)
    sendNui({ action = 'result', ok = ok == true, message = tostring(message or ''), data = data or {} })
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('buyPlate', function(data, cb)
    TriggerServerEvent('driftzone_licenses:server:buyPlate', data or {})
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if nuiOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 243, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 243) then
                closeUi()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Fallback marker daca nu folosesti driftzone_interactions.
CreateThread(function()
    while true do
        local waitTime = 850
        local loc = Config.Location or {}
        local coords = loc.coords

        if coords then
            local ped = PlayerPedId()
            local dist = #(GetEntityCoords(ped) - coords)

            if dist <= 18.0 then
                waitTime = 0

                if loc.marker == true then
                    DrawMarker(2, coords.x, coords.y, coords.z + 0.18, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 4, 199, 247, 180, false, true, 2, false, nil, nil, false)
                end

                if dist <= (loc.range or 2.6) then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Apasa ~INPUT_CONTEXT~ pentru License Plates')
                    EndTextCommandDisplayHelp(0, false, true, -1)

                    if IsControlJustPressed(0, 38) then
                        requestOpen()
                    end
                end
            end
        end

        Wait(waitTime)
    end
end)
