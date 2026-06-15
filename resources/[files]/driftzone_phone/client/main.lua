local phoneVisible = false
local phoneOpen = false
local phoneFocus = false
local lastState = {}
local currentCallOptions = { muted = false, speaker = false }

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
        if phoneOpen then setFocus(true) end
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
