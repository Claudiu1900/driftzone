local panelOpen = false
local focusEnabled = false
local nuiReady = false
local pendingOpen = nil

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 4500, tostring(msg or ''))
end

local function sendNui(payload)
    SendNUIMessage(payload)
end

local function setFocus(state)
    focusEnabled = state == true
    SetNuiFocus(focusEnabled, focusEnabled)
    SetNuiFocusKeepInput(false)
    sendNui({ action = 'focus', focus = focusEnabled })
end

local function startTabletEmote()
    if not Config.Emote or Config.Emote.enabled == false then return end

    local eventName = Config.Emote.playEvent or 'driftzone_emotes:client:play'
    local emoteName = Config.Emote.name or 'tablet2'

    pcall(function()
        TriggerEvent(eventName, emoteName)
    end)
end

local function stopTabletEmote()
    if not Config.Emote or Config.Emote.enabled == false then return end

    pcall(function()
        TriggerEvent(Config.Emote.stopEvent or 'driftzone_emotes:client:stop')
    end)

    if Config.Emote.fallbackCancelCommand and Config.Emote.fallbackCancelCommand ~= '' then
        SetTimeout(60, function()
            if not panelOpen then
                ExecuteCommand(Config.Emote.fallbackCancelCommand)
            end
        end)
    end
end

local function openPanel(data)
    panelOpen = true
    pendingOpen = nil
    startTabletEmote()
    setFocus(true)
    sendNui({ action = 'open', data = data or {} })
end

local function closePanel(skipServer)
    if not panelOpen then
        setFocus(false)
        return
    end

    panelOpen = false
    setFocus(false)
    stopTabletEmote()
    sendNui({ action = 'close' })

    if skipServer ~= true then
        TriggerServerEvent('driftzone_gangpanel:server:closed')
    end
end

RegisterCommand(Config.Command or 'gang', function()
    TriggerServerEvent('driftzone_gangpanel:server:requestOpen')
end, false)

RegisterNetEvent('driftzone_gangpanel:client:open', function(data)
    if not nuiReady then
        pendingOpen = data or {}
        return
    end
    openPanel(data or {})
end)

RegisterNetEvent('driftzone_gangpanel:client:deny', function(message)
    notify('warning', message or 'Nu ai acces la gang panel.')
end)

RegisterNetEvent('driftzone_gangpanel:client:update', function(data)
    if not panelOpen then return end
    sendNui({ action = 'update', data = data or {} })
end)

RegisterNetEvent('driftzone_gangpanel:client:toast', function(typ, message)
    if panelOpen then
        sendNui({ action = 'toast', typ = typ or 'info', message = tostring(message or '') })
    else
        notify(typ or 'info', message or '')
    end
end)

RegisterNetEvent('driftzone_gangpanel:client:forceClose', function()
    closePanel(true)
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })

    if pendingOpen then
        Wait(100)
        openPanel(pendingOpen)
    end
end)

RegisterNUICallback('close', function(_, cb)
    closePanel(false)
    cb({ ok = true })
end)

RegisterNUICallback('toggleFocus', function(_, cb)
    if panelOpen then
        setFocus(not focusEnabled)
    end
    cb({ ok = true, focus = focusEnabled })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('driftzone_gangpanel:server:refresh')
    cb({ ok = true })
end)

RegisterNUICallback('getGangDetails', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:getGangDetails', tonumber(data and data.gangId or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('createGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:createGang', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('updateGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:updateGang', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('deleteGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:deleteGang', tonumber(data and data.gangId or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('addMember', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:addMember', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('kickMember', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:kickMember', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('changeRole', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:changeRole', data or {})
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if panelOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 245, true)
            DisableControlAction(0, 243, true)

            if IsDisabledControlJustPressed(0, 200) then
                closePanel(false)
            elseif IsDisabledControlJustPressed(0, 243) then
                setFocus(not focusEnabled)
            end

            Wait(0)
        else
            Wait(450)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if panelOpen then
        stopTabletEmote()
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)
