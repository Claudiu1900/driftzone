local hudVisible = true
local hudReady = false
local hardHidden = false

local hudData = {
    id = 0,
    online = 0,
    cash = 0
}

local function effectiveVisible()
    return hudVisible == true and hardHidden ~= true
end

local function sendHud(payload)
    SendNUIMessage(payload)
end

local function pushVisible()
    sendHud({
        action = 'visible',
        visible = effectiveVisible()
    })
end

local function setHudVisible(state)
    hudVisible = state == true
    pushVisible()
end

local function lockHide()
    hardHidden = true
    pushVisible()
    LocalPlayer.state:set('driftzone_hud:hard_hidden', true, true)
end

local function unlockHide(showAfter)
    hardHidden = false

    if showAfter == true then
        hudVisible = true
    end

    pushVisible()
    LocalPlayer.state:set('driftzone_hud:hard_hidden', false, true)
end

local function setHardHidden(state)
    if state == true then
        lockHide()
    else
        unlockHide(true)
    end
end

local function updateHud()
    if not hudReady then return end

    sendHud({
        action = 'update',
        data = {
            id = hudData.id or 0,
            online = hudData.online or 0,
            cash = hudData.cash or 0,
            visible = effectiveVisible(),
            mainColor = Config.MainColor,
            logo = Config.Logo
        }
    })
end

RegisterNetEvent('driftzone_hud:client:updateData', function(data)
    data = data or {}

    hudData.id = tonumber(data.id) or 0
    hudData.online = tonumber(data.online) or 0
    hudData.cash = tonumber(data.cash) or 0

    updateHud()
end)

-- Triggere normale. Acestea NU pot afisa HUD-ul daca este blocat cu hard hide.
RegisterNetEvent('driftzone_hud:client:show', function()
    setHudVisible(true)
end)

RegisterNetEvent('driftzone_hud:client:hide', function()
    setHudVisible(false)
end)

RegisterNetEvent('driftzone_hud:client:toggle', function()
    setHudVisible(not hudVisible)
end)

RegisterNetEvent('driftzone_hud:visible', function(state)
    setHudVisible(state == true)
end)

RegisterNetEvent('client:hud:visible', function(state)
    setHudVisible(state == true)
end)

RegisterNetEvent('hud:visible', function(state)
    setHudVisible(state == true)
end)

RegisterNetEvent('driftzone_hud:client:visible', function(state)
    setHudVisible(state == true)
end)

RegisterNetEvent('driftzone_hud:client:setVisible', function(state)
    setHudVisible(state == true)
end)

RegisterNetEvent('driftzone_hud:setVisible', function(state)
    setHudVisible(state == true)
end)

-- Triggere hard hide. Cand e hard hidden, orice show normal este ignorat vizual.
RegisterNetEvent('driftzone_hud:client:lockHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:client:hardHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:client:forceHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:client:unlockHide', function()
    unlockHide(true)
end)

RegisterNetEvent('driftzone_hud:client:hardShow', function()
    unlockHide(true)
end)

RegisterNetEvent('driftzone_hud:client:forceShow', function()
    unlockHide(true)
end)

RegisterNetEvent('driftzone_hud:hardVisible', function(state)
    setHardHidden(state ~= true)
end)

RegisterNetEvent('driftzone_hud:client:setHardHidden', function(state)
    setHardHidden(state == true)
end)

RegisterNetEvent('driftzone_hud:client:refresh', function()
    TriggerServerEvent('driftzone_hud:server:requestData')
end)

RegisterNetEvent('driftzone_auth:client:success', function(data)
    Wait(1000)

    if data and tonumber(data.uid) then
        hudData.id = tonumber(data.uid)
    end

    if data and tonumber(data.cash) then
        hudData.cash = tonumber(data.cash)
    end

    if Config.ShowOnLogin then
        setHudVisible(true)
    end

    TriggerServerEvent('driftzone_hud:server:requestData')
    updateHud()
end)

RegisterNUICallback('ready', function(_, cb)
    hudReady = true

    TriggerServerEvent('driftzone_hud:server:requestData')
    updateHud()
    pushVisible()

    cb({ ok = true })
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    Wait(1500)

    TriggerServerEvent('driftzone_hud:server:requestData')
    updateHud()
    pushVisible()
end)

CreateThread(function()
    while true do
        Wait(1000)
        updateHud()
    end
end)

exports('Show', function()
    setHudVisible(true)
end)

exports('Hide', function()
    setHudVisible(false)
end)

exports('Toggle', function()
    setHudVisible(not hudVisible)
end)

exports('SetVisible', function(state)
    setHudVisible(state == true)
end)

exports('LockHide', lockHide)
exports('HardHide', lockHide)
exports('ForceHide', lockHide)

exports('UnlockHide', function()
    unlockHide(true)
end)

exports('HardShow', function()
    unlockHide(true)
end)

exports('ForceShow', function()
    unlockHide(true)
end)

exports('SetHardHidden', function(state)
    setHardHidden(state == true)
end)

exports('IsHardHidden', function()
    return hardHidden == true
end)

exports('Refresh', function()
    TriggerServerEvent('driftzone_hud:server:requestData')
end)
