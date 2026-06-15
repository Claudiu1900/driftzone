local phoneOpen = false
local nuiReady = false
local lastState = {}

local function debugPrint(...)
    if Config.Debug then
        print('[DRIFTZONE_PHONE]', ...)
    end
end

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 4500, tostring(msg or ''))
end

local function sendNui(data)
    SendNUIMessage(data)
end

local function setFocus(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function refreshState()
    TriggerServerEvent('driftzone_phone:server:requestState')
end

local function openPhone()
    phoneOpen = true
    setFocus(true)
    sendNui({
        action = 'open',
        mainColor = Config.MainColor or '#04c7f7',
        state = lastState or {}
    })
    refreshState()
end

local function closePhone()
    phoneOpen = false
    setFocus(false)
    sendNui({ action = 'close' })
end

RegisterCommand(Config.Command or 'phone', function()
    if phoneOpen then
        closePhone()
    else
        openPhone()
    end
end, false)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendNui({
        action = 'setup',
        mainColor = Config.MainColor or '#04c7f7'
    })
    refreshState()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb({ ok = true })
end)

RegisterNUICallback('dial', function(data, cb)
    local number = data and data.number or ''
    TriggerServerEvent('driftzone_phone:server:startCall', number)
    cb({ ok = true })
end)

RegisterNUICallback('answer', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:answerCall')
    cb({ ok = true })
end)

RegisterNUICallback('decline', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:declineCall')
    cb({ ok = true })
end)

RegisterNUICallback('hangup', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:hangupCall')
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_phone:client:state', function(state)
    lastState = state or {}
    sendNui({
        action = 'state',
        state = lastState,
        open = phoneOpen == true
    })
end)

RegisterNetEvent('driftzone_phone:client:incoming', function(state)
    lastState = state or lastState or {}

    if Config.AutoOpenOnIncoming == true and not phoneOpen then
        openPhone()
    else
        notify('info', 'Telefonul suna. Deschide /phone ca sa raspunzi.', 6000)
        sendNui({
            action = 'incoming',
            state = lastState,
            open = phoneOpen == true
        })
    end
end)

RegisterNetEvent('driftzone_phone:client:notify', function(typ, msg, duration)
    notify(typ, msg, duration)
end)

RegisterNetEvent('driftzone_phone:client:forceClose', function()
    closePhone()
end)

CreateThread(function()
    while true do
        if phoneOpen then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 200, true)

            if IsDisabledControlJustPressed(0, 200) then
                closePhone()
            end

            Wait(0)
        else
            Wait(450)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    setFocus(false)
end)
