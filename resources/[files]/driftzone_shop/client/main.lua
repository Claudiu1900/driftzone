local browserReady = false
local shopOpen = false
local pendingOpen = nil
local lastOpen = 0

local function sendNui(payload)
    if not browserReady then
        if payload.action == 'open' then
            pendingOpen = payload.payload
        end
        return false
    end

    SendNUIMessage(payload)
    return true
end

local function setFocus(state)
    shopOpen = state == true

    SetNuiFocus(shopOpen, shopOpen)
    SetNuiFocusKeepInput(false)

    if shopOpen then
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

local function requestOpen()
    local now = GetGameTimer()
    if now - lastOpen < 350 then return end
    lastOpen = now

    TriggerServerEvent('driftzone_shop:server:open')
end

local function closeShop()
    setFocus(false)
    sendNui({ action = 'close' })
end

RegisterNetEvent('driftzone_shop:client:show', function()
    requestOpen()
end)

RegisterNetEvent('driftzone_shop:client:hide', function()
    closeShop()
end)

RegisterNetEvent('driftzone_shop:client:open', function(data)
    pendingOpen = nil
    setFocus(true)

    sendNui({
        action = 'open',
        payload = data or {}
    })
end)

RegisterNetEvent('driftzone_shop:client:update', function(data)
    sendNui({
        action = 'update',
        payload = data or {}
    })
end)

RegisterNUICallback('ready', function(_, cb)
    browserReady = true

    if pendingOpen then
        setFocus(true)
        sendNui({
            action = 'open',
            payload = pendingOpen
        })
        pendingOpen = nil
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeShop()
    cb({ ok = true })
end)

RegisterNUICallback('purchase', function(data, cb)
    local itemId = tostring(data and data.id or '')
    if itemId ~= '' then
        TriggerServerEvent('driftzone_shop:server:purchase', itemId)
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if shopOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 177, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 177) then
                closeShop()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

exports('Show', function()
    requestOpen()
end)

exports('Hide', function()
    closeShop()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    DisplayHud(true)
    DisplayRadar(true)
end)
