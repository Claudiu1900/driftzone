local hudVisible = true
local hudReady = false

local hudData = {
    id = 0,
    online = 0,
    cash = 0
}

local function sendHud(payload)
    SendNUIMessage(payload)
end

local function setHudVisible(state)
    hudVisible = state == true

    sendHud({
        action = 'visible',
        visible = hudVisible
    })
end

local function updateHud()
    if not hudReady then return end

    sendHud({
        action = 'update',
        data = {
            id = hudData.id or 0,
            online = hudData.online or 0,
            cash = hudData.cash or 0,
            visible = hudVisible,
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

    cb({ ok = true })
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    Wait(1500)

    TriggerServerEvent('driftzone_hud:server:requestData')
    updateHud()
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

exports('Refresh', function()
    TriggerServerEvent('driftzone_hud:server:requestData')
end)