local nuiReady = false
local open = false
local pendingShow = false

local function sendNui(data)
    if not nuiReady then
        if data.action == 'show' then
            pendingShow = true
        end
        return
    end

    SendNUIMessage(data)
end

local function setFocus(state)
    open = state == true
    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(false)

    if open then
        DisplayHud(false)
        DisplayRadar(false)
        TriggerEvent('driftzone_hud:visible', false)
        TriggerEvent('client:hud:visible', false)
    else
        DisplayHud(true)
        DisplayRadar(true)
        TriggerEvent('driftzone_hud:visible', true)
        TriggerEvent('client:hud:visible', true)
    end
end

local function showUi()
    setFocus(true)
    sendNui({ action = 'show' })
end

local function hideUi()
    setFocus(false)
    sendNui({ action = 'hide' })
end

RegisterNetEvent('driftzone_codes:client:show', function()
    showUi()
end)

RegisterNetEvent('driftzone_codes:client:hide', function()
    hideUi()
end)

RegisterNetEvent('driftzone_codes:client:redeemResult', function(success, message)
    sendNui({
        action = 'result',
        success = success == true,
        message = tostring(message or '')
    })
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true

    if pendingShow then
        pendingShow = false
        showUi()
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    hideUi()
    cb({ ok = true })
end)

RegisterNUICallback('redeem', function(data, cb)
    local code = tostring(data and data.code or '')
    TriggerServerEvent('driftzone_codes:server:redeem', code)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if open then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 177, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 177) then
                hideUi()
            end

            Wait(0)
        else
            Wait(600)
        end
    end
end)

exports('Show', showUi)
exports('Hide', hideUi)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    DisplayHud(true)
    DisplayRadar(true)
end)
