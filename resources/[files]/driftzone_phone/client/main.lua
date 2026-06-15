local phoneVisible = false
local phoneOpen = false
local phonePeek = false
local phoneFocus = false
local nuiReady = false
local lastState = {}

local function debugPrint(...)
    if Config.Debug then
        print('[DRIFTZONE_PHONE]', ...)
    end
end

local function sendNui(data)
    SendNUIMessage(data)
end

local function setFocus(state)
    phoneFocus = state == true
    SetNuiFocus(phoneFocus, phoneFocus)
    SetNuiFocusKeepInput(false)
    sendNui({ action = 'focus', focus = phoneFocus })
end

local function refreshState()
    TriggerServerEvent('driftzone_phone:server:requestState')
end

local function openPhone()
    phoneVisible = true
    phoneOpen = true
    phonePeek = false
    setFocus(true)
    sendNui({
        action = 'open',
        mode = 'full',
        mainColor = Config.MainColor or '#04c7f7',
        state = lastState or {}
    })
    refreshState()
end

local function showIncomingPeek(state)
    phoneVisible = true
    phoneOpen = false
    phonePeek = true
    setFocus(true)
    sendNui({
        action = 'peek',
        mainColor = Config.MainColor or '#04c7f7',
        state = state or lastState or {}
    })
end

local function closePhone()
    phoneVisible = false
    phoneOpen = false
    phonePeek = false
    setFocus(false)
    sendNui({ action = 'close' })
end

RegisterCommand(Config.Command or 'phone', function()
    if phoneOpen then
        closePhone()
        return
    end

    openPhone()
end, false)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendNui({ action = 'setup', mainColor = Config.MainColor or '#04c7f7' })
    refreshState()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb({ ok = true })
end)

RegisterNUICallback('openFull', function(_, cb)
    openPhone()
    cb({ ok = true })
end)

RegisterNUICallback('dial', function(data, cb)
    local number = data and data.number or ''
    TriggerServerEvent('driftzone_phone:server:startCall', number)
    cb({ ok = true })
end)

RegisterNUICallback('answer', function(_, cb)
    phoneVisible = true
    phoneOpen = true
    phonePeek = false
    setFocus(true)
    sendNui({ action = 'open', mode = 'full', state = lastState or {} })
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

    if lastState.incoming == true and not phoneOpen and Config.ShowPeekOnIncoming ~= false then
        showIncomingPeek(lastState)
        return
    end

    if phoneVisible or lastState.inCall == true then
        sendNui({
            action = 'state',
            state = lastState,
            open = phoneOpen == true,
            peek = phonePeek == true
        })
    end
end)

RegisterNetEvent('driftzone_phone:client:incoming', function(state)
    lastState = state or lastState or {}

    if Config.ShowPeekOnIncoming ~= false and not phoneOpen then
        showIncomingPeek(lastState)
    else
        phoneVisible = true
        phoneOpen = true
        phonePeek = false
        setFocus(true)
        sendNui({ action = 'incoming', state = lastState, open = true })
    end
end)

RegisterNetEvent('driftzone_phone:client:feedback', function(payload)
    sendNui({ action = 'feedback', payload = payload or {} })
end)

-- Compatibilitate: daca vreun fisier vechi mai trimite acest event, nu mai dam notificari externe.
RegisterNetEvent('driftzone_phone:client:notify', function(typ, msg, duration)
    sendNui({
        action = 'feedback',
        payload = {
            kind = typ or 'info',
            title = typ or 'Info',
            text = tostring(msg or ''),
            duration = duration or 3500
        }
    })
end)

RegisterNetEvent('driftzone_phone:client:forceClose', function()
    closePhone()
end)

CreateThread(function()
    while true do
        if phoneVisible then
            if IsControlJustPressed(0, 243) or IsDisabledControlJustPressed(0, 243) then
                setFocus(not phoneFocus)
            end

            if phoneFocus then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 243, true)

                if IsDisabledControlJustPressed(0, 200) then
                    closePhone()
                end
            end

            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)
