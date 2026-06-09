local uiOpen = false
local nuiReady = false

local function notify(t, msg, d)
    TriggerEvent(Config.NotifyEvent or 'client:notify', t or 'info', d or 5000, tostring(msg or ''))
end

local function sendNui(data)
    if nuiReady then
        SendNUIMessage(data)
    end
end

local function setFocus(state)
    uiOpen = state == true
    SetNuiFocus(uiOpen, uiOpen)
    SetNuiFocusKeepInput(false)
end

local function openBlackjack(data)
    setFocus(true)
    sendNui({
        action = 'open',
        mainColor = Config.MainColor,
        minBet = Config.MinBet,
        maxBet = Config.MaxBet,
        cash = data and data.cash or 0
    })
end

local function closeBlackjack()
    setFocus(false)
    sendNui({ action = 'close' })
    TriggerServerEvent('driftzone_blackjack:server:close')
end

RegisterCommand(Config.Command or 'blackjack', function()
    TriggerServerEvent('driftzone_blackjack:server:open')
end, false)

RegisterNetEvent('driftzone_blackjack:client:open', function(data)
    openBlackjack(data or {})
end)

RegisterNetEvent('driftzone_blackjack:client:update', function(data)
    sendNui({ action = 'state', data = data or {} })
end)

RegisterNetEvent('driftzone_blackjack:client:status', function(t, msg)
    sendNui({ action = 'status', typ = t or 'info', message = tostring(msg or '') })
end)

RegisterNetEvent('driftzone_blackjack:client:notify', function(t, msg, d)
    notify(t, msg, d)
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeBlackjack()
    cb({ ok = true })
end)

RegisterNUICallback('start', function(data, cb)
    TriggerServerEvent('driftzone_blackjack:server:start', tonumber(data and data.bet or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('hit', function(_, cb)
    TriggerServerEvent('driftzone_blackjack:server:hit')
    cb({ ok = true })
end)

RegisterNUICallback('stand', function(_, cb)
    TriggerServerEvent('driftzone_blackjack:server:stand')
    cb({ ok = true })
end)

RegisterNUICallback('double', function(_, cb)
    TriggerServerEvent('driftzone_blackjack:server:double')
    cb({ ok = true })
end)

RegisterNUICallback('surrender', function(_, cb)
    TriggerServerEvent('driftzone_blackjack:server:surrender')
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if uiOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
                closeBlackjack()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if uiOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)
