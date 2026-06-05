local chatOpened = false
local chatReady = false
local chatEnabled = true
local chatMuted = false
local chatStarted = false
local pendingMessages = {}
local escBlock = false

local function sendNui(data)
    SendNUIMessage(data)
end

local function startChat()
    if chatStarted then return end

    chatStarted = true

    SetTextChatEnabled(false)
    TriggerServerEvent('driftzone_chat:server:requestStart')

    sendNui({
        action = 'setEnabled',
        enabled = chatEnabled
    })

    sendNui({
        action = 'setMuted',
        muted = chatMuted
    })

    sendNui({
        action = 'addMessage',
        payload = {
            type = 'system',
            time = '--:--',
            text = 'Bun venit pe Drift Zone!'
        }
    })
end

local function flushPendingMessages()
    if not chatReady then return end

    for _, payload in ipairs(pendingMessages) do
        sendNui({
            action = 'addMessage',
            payload = payload
        })
    end

    pendingMessages = {}
end

local function openChat(prefill)
    if not chatStarted then return end
    if chatOpened then return end
    if not chatEnabled then return end

    chatOpened = true

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    sendNui({
        action = 'open',
        prefill = prefill or ''
    })
end

local function closeChat(blockEsc)
    if not chatOpened then return end

    chatOpened = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    sendNui({
        action = 'close'
    })

    if blockEsc then
        escBlock = true

        CreateThread(function()
            Wait(450)
            escBlock = false
        end)
    end
end

local function addMessage(payload)
    if not chatStarted then return end

    if not chatReady then
        pendingMessages[#pendingMessages + 1] = payload

        if #pendingMessages > ((Config and Config.Chat and Config.Chat.PendingLimit) or 80) then
            table.remove(pendingMessages, 1)
        end

        return
    end

    sendNui({
        action = 'addMessage',
        payload = payload
    })
end

CreateThread(function()
    SetTextChatEnabled(false)

    while true do
        if chatOpened then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            DisableControlAction(0, 177, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 202, true)
            DisableControlAction(0, 322, true)

            SetPauseMenuActive(false)

            Wait(0)
        elseif escBlock then
            DisableControlAction(0, 177, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 202, true)
            DisableControlAction(0, 322, true)

            SetPauseMenuActive(false)

            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        SetTextChatEnabled(false)
        Wait(1000)
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    Wait(1500)

    if LocalPlayer.state and LocalPlayer.state.dz_logged == true then
        startChat()
    end
end)

RegisterNetEvent('driftzone_auth:client:success', function()
    Wait(500)
    startChat()
end)

RegisterNetEvent('driftzone_chat:client:addMessage', function(payload)
    addMessage(payload or {
        type = 'error',
        time = '--:--',
        text = 'Mesaj invalid.'
    })
end)

RegisterNetEvent('driftzone_chat:client:clear', function()
    sendNui({
        action = 'clear'
    })
end)

RegisterNetEvent('driftzone_chat:client:setEnabled', function(enabled)
    chatEnabled = enabled == true

    if not chatEnabled then
        closeChat(false)
    end

    sendNui({
        action = 'setEnabled',
        enabled = chatEnabled
    })
end)

RegisterNetEvent('driftzone_chat:client:setMuted', function(muted)
    chatMuted = muted == true

    sendNui({
        action = 'setMuted',
        muted = chatMuted
    })
end)

RegisterNUICallback('ready', function(_, cb)
    chatReady = true

    sendNui({
        action = 'setEnabled',
        enabled = chatEnabled
    })

    sendNui({
        action = 'setMuted',
        muted = chatMuted
    })

    flushPendingMessages()

    cb({ ok = true })
end)

RegisterNUICallback('submit', function(data, cb)
    local text = tostring(data and data.message or ''):gsub('^%s+', ''):gsub('%s+$', '')

    closeChat(false)

    if text ~= '' and chatEnabled and chatStarted then
        TriggerServerEvent('driftzone_chat:server:submit', text)
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeChat(true)
    cb({ ok = true })
end)

RegisterCommand('+driftchat', function()
    if IsPauseMenuActive() then return end
    openChat('')
end, false)

RegisterCommand('-driftchat', function() end, false)

RegisterCommand('+driftchatcommand', function()
    if IsPauseMenuActive() then return end
    openChat('/')
end, false)

RegisterCommand('-driftchatcommand', function() end, false)

RegisterKeyMapping('+driftchat', 'Open DriftZone Chat', 'keyboard', 'T')
RegisterKeyMapping('+driftchatcommand', 'Open DriftZone Command Chat', 'keyboard', 'SLASH')


RegisterNetEvent('driftzone_chat:client:executeCommand', function(commandLine)
    commandLine = tostring(commandLine or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if commandLine == '' then return end
    if commandLine:sub(1, 1) == '/' then
        commandLine = commandLine:sub(2)
    end

    -- Asta face ca orice script cu RegisterCommand pe CLIENT sa mearga direct,
    -- fara sa mai adaugi comanda manual in driftzone_chat/server/main.lua.
    ExecuteCommand(commandLine)
end)

RegisterNetEvent('driftzone_chat:client:openCommand', function(prefill)
    openChat('/' .. tostring(prefill or ''))
end)

exports('AddChatMessage', function(payload)
    addMessage(payload)
end)

exports('OpenChat', function(prefill)
    openChat(prefill or '')
end)

exports('CloseChat', function()
    closeChat(false)
end)