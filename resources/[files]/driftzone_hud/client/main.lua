local hudVisible = true
local hudReady = false
local hardHidden = false

local HARD_HIDE_KVP = 'driftzone_hud_hard_hidden'

local hudData = {
    id = 0,
    online = 0,
    cash = 0
}

local function readHardHideKvp()
    local value = GetResourceKvpString(HARD_HIDE_KVP)
    value = tostring(value or ''):lower()

    return value == '1' or value == 'true' or value == 'yes' or value == 'on'
end

local function writeHardHideKvp(value)
    SetResourceKvp(HARD_HIDE_KVP, value == true and 'true' or 'false')
end

local function effectiveVisible()
    return hudVisible == true and hardHidden ~= true
end

local function sendHud(payload)
    SendNUIMessage(payload)
end

local function pushVisible()
    sendHud({
        action = 'visible',
        visible = effectiveVisible(),
        hardHidden = hardHidden == true
    })
end

local function pushHardState()
    sendHud({
        action = 'hardHidden',
        hardHidden = hardHidden == true,
        visible = effectiveVisible()
    })
end

local function setHudVisible(state)
    hudVisible = state == true

    -- IMPORTANT:
    -- Daca hard hide este activ, trigger-ele vechi de show/hide nu mai pot afisa HUD-ul.
    -- Ele pot schimba doar starea normala, dar vizual ramane ascuns pana la unlockHide/forceShow.
    pushVisible()
end

local function lockHide()
    hardHidden = true
    writeHardHideKvp(true)

    LocalPlayer.state:set('driftzone_hud:hard_hidden', true, true)
    LocalPlayer.state:set('settings:hud_hard_hidden', true, true)

    pushHardState()
    pushVisible()
end

local function unlockHide(showAfter)
    hardHidden = false
    writeHardHideKvp(false)

    if showAfter == true then
        hudVisible = true
    end

    LocalPlayer.state:set('driftzone_hud:hard_hidden', false, true)
    LocalPlayer.state:set('settings:hud_hard_hidden', false, true)

    pushHardState()
    pushVisible()
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
            hardHidden = hardHidden == true,
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

-- Triggere normale. Nu pot afisa HUD-ul daca hard hide este activ.
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

RegisterNetEvent('driftzone_hud:show', function()
    setHudVisible(true)
end)

RegisterNetEvent('driftzone_hud:hide', function()
    setHudVisible(false)
end)

-- Triggere HARD HIDE. Doar acestea blocheaza/deblocheaza HUD-ul complet.
RegisterNetEvent('driftzone_hud:client:lockHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:client:hardHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:client:forceHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:lockHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:hardHide', function()
    lockHide()
end)

RegisterNetEvent('driftzone_hud:forceHide', function()
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

RegisterNetEvent('driftzone_hud:unlockHide', function()
    unlockHide(true)
end)

RegisterNetEvent('driftzone_hud:hardShow', function()
    unlockHide(true)
end)

RegisterNetEvent('driftzone_hud:forceShow', function()
    unlockHide(true)
end)

-- true = visible hard, false = hard hidden
RegisterNetEvent('driftzone_hud:hardVisible', function(state)
    setHardHidden(state ~= true)
end)

RegisterNetEvent('driftzone_hud:client:setHardHidden', function(state)
    setHardHidden(state == true)
end)

RegisterNetEvent('driftzone_hud:setHardHidden', function(state)
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

    if Config.ShowOnLogin and hardHidden ~= true then
        setHudVisible(true)
    else
        pushVisible()
    end

    TriggerServerEvent('driftzone_hud:server:requestData')
    updateHud()
end)

RegisterNUICallback('ready', function(_, cb)
    hudReady = true

    hardHidden = readHardHideKvp()

    TriggerServerEvent('driftzone_hud:server:requestData')
    updateHud()
    pushHardState()
    pushVisible()

    cb({ ok = true })
end)

CreateThread(function()
    hardHidden = readHardHideKvp()

    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    Wait(1500)

    TriggerServerEvent('driftzone_hud:server:requestData')
    updateHud()
    pushHardState()
    pushVisible()
end)

CreateThread(function()
    while true do
        Wait(1000)
        updateHud()
    end
end)

-- Watchdog: daca alt script reuseste sa trimita show prin triggere vechi / update-uri dese,
-- cand hardHide este ON fortam NUI ascuns constant.
CreateThread(function()
    while true do
        if hardHidden == true then
            pushHardState()
            pushVisible()
            Wait(250)
        else
            Wait(1000)
        end
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
