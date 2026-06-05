local nuiReady = false
local opened = false
local pendingStats = nil
local currentTargetId = nil
local lastOpenAttempt = 0

local function restoreHud()
    DisplayRadar(true)
    pcall(function() TriggerEvent('driftzone_hud:visible', true) end)
    pcall(function() TriggerEvent('client:hud:visible', true) end)
    pcall(function() TriggerEvent('hud:visible', true) end)
end

local function hideHud()
    DisplayRadar(false)
    pcall(function() TriggerEvent('driftzone_hud:visible', false) end)
    pcall(function() TriggerEvent('client:hud:visible', false) end)
    pcall(function() TriggerEvent('hud:visible', false) end)
end

local function clearFocus()
    opened = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    restoreHud()
end

local function openStats(stats)
    pendingStats = stats or {}

    if not nuiReady then
        SendNUIMessage({ action = 'ping' })
        SetTimeout(800, function()
            if not nuiReady and pendingStats then
                clearFocus()
                TriggerEvent('client:notify', 'warning', 5000, 'Stats UI nu s-a incarcat. Da restart la driftzone_stats.')
            end
        end)
        return
    end

    opened = true
    currentTargetId = pendingStats.isSelf == false and pendingStats.serverId or nil

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    hideHud()

    SendNUIMessage({ action = 'open', stats = pendingStats })
    pendingStats = nil
end

local function closeStats()
    SendNUIMessage({ action = 'close' })
    clearFocus()
end

RegisterNetEvent('driftzone_stats:client:open', function(stats)
    openStats(stats or {})
end)

RegisterNetEvent('driftzone_stats:client:update', function(stats)
    SendNUIMessage({ action = 'update', stats = stats or {} })
end)

RegisterNetEvent('driftzone_stats:client:close', function()
    closeStats()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if pendingStats then
        local data = pendingStats
        pendingStats = nil
        openStats(data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeStats()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('driftzone_stats:server:refresh', currentTargetId)
    cb({ ok = true })
end)

RegisterCommand('stats', function(_, args)
    local now = GetGameTimer()
    if now - lastOpenAttempt < 500 then return end
    lastOpenAttempt = now
    TriggerServerEvent('driftzone_stats:server:open', args and args[1] or nil)
end, false)

RegisterCommand('statistici', function(_, args)
    local now = GetGameTimer()
    if now - lastOpenAttempt < 500 then return end
    lastOpenAttempt = now
    TriggerServerEvent('driftzone_stats:server:open', args and args[1] or nil)
end, false)

CreateThread(function()
    Wait(1200)
    SendNUIMessage({ action = 'ping' })
end)

CreateThread(function()
    while true do
        if opened then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                closeStats()
            end

            Wait(0)
        else
            Wait(350)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearFocus()
end)
