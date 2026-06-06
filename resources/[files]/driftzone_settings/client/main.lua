local nuiReady = false
local menuOpen = false
local settings = {}
local pendingOpen = false

local function kvpKey(id)
    return tostring(Config.KvpPrefix or 'driftzone_settings_') .. tostring(id)
end

local function boolFromKvp(value, default)
    if value == nil or value == '' then
        return default == true
    end

    value = tostring(value):lower()
    return value == '1' or value == 'true' or value == 'yes' or value == 'on'
end

local function sendNui(data)
    if not nuiReady then return false end
    SendNUIMessage(data)
    return true
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)

    if menuOpen then
        TriggerEvent('driftzone_hud:visible', false)
    else
        if settings.hud ~= false then
            TriggerEvent('driftzone_hud:visible', true)
        end
    end
end

local function defaultSettings()
    local result = {}

    for i = 1, #(Config.Toggles or {}) do
        local item = Config.Toggles[i]
        result[item.id] = item.default == true
    end

    return result
end

local function loadSettings()
    settings = defaultSettings()

    for i = 1, #(Config.Toggles or {}) do
        local item = Config.Toggles[i]
        local value = GetResourceKvpString(kvpKey(item.id))
        settings[item.id] = boolFromKvp(value, item.default)
    end
end

local function saveSetting(id, value)
    settings[id] = value == true
    SetResourceKvp(kvpKey(id), settings[id] and 'true' or 'false')
end

local function safeExport(resource, exportName, ...)
    if GetResourceState(resource) ~= 'started' then return end

    pcall(function(...)
        exports[resource][exportName](exports[resource], ...)
    end, ...)
end

local function emitSettingEvent(id, value)
    TriggerEvent('driftzone_settings:client:changed', id, value)
    TriggerEvent(('driftzone_settings:client:%s'):format(id), value)

    -- Server/client resources pot asculta aceste state bags daca vor integra direct.
    LocalPlayer.state:set(('settings:%s'):format(id), value, true)
end

local function applySingle(id, value)
    value = value == true

    if id == 'hud' then
        TriggerEvent('driftzone_hud:visible', value)
        TriggerEvent('driftzone_hud:client:visible', value)
        TriggerEvent('driftzone_hud:client:setVisible', value)
        safeExport('driftzone_hud', 'SetVisible', value)
    elseif id == 'minimap' then
        DisplayRadar(value)
    elseif id == 'tickets_counter' then
        TriggerEvent('driftzone_tickets:client:setCounterVisible', value)
        safeExport('driftzone_tickets', 'SetCounterVisible', value)
    elseif id == 'speedometer' then
        TriggerEvent('driftzone_turometru:client:setVisible', value)
        TriggerEvent('driftzone_turometru:setVisible', value)
        safeExport('driftzone_turometru', 'SetVisible', value)
    elseif id == 'vehicle_stats' then
        TriggerEvent('driftzone_vs:client:setVisible', value)
        safeExport('driftzone_vs', 'SetVisible', value)
    elseif id == 'voice_ui' then
        TriggerEvent('driftzone_voicechat:client:setVisible', value)
        safeExport('driftzone_voicechat', 'SetVisible', value)
    elseif id == 'overhead' then
        TriggerEvent('driftzone_overheadstats:client:setVisible', value)
        TriggerEvent('driftzone_overheadstats:client:setEnabled', value)
        safeExport('driftzone_overheadstats', 'SetVisible', value)
        safeExport('driftzone_overheadstats', 'SetEnabled', value)
    elseif id == 'overhead_names' then
        TriggerEvent('driftzone_overheadstats:client:setNamesVisible', value)
        safeExport('driftzone_overheadstats', 'SetNamesVisible', value)
    elseif id == 'overhead_ids' then
        TriggerEvent('driftzone_overheadstats:client:setIdsVisible', value)
        safeExport('driftzone_overheadstats', 'SetIdsVisible', value)
    elseif id == 'overhead_admin' then
        TriggerEvent('driftzone_overheadstats:client:setAdminVisible', value)
        safeExport('driftzone_overheadstats', 'SetAdminVisible', value)
    elseif id == 'overhead_health' then
        TriggerEvent('driftzone_overheadstats:client:setHealthVisible', value)
        safeExport('driftzone_overheadstats', 'SetHealthVisible', value)
    elseif id == 'notifications' then
        TriggerEvent('driftzone_notifications:client:setVisible', value)
        safeExport('driftzone_notifications', 'SetVisible', value)
    end

    emitSettingEvent(id, value)
end

local function applyAll()
    for id, value in pairs(settings) do
        applySingle(id, value)
    end
end

local function payload()
    return {
        action = 'open',
        mainColor = Config.MainColor or '#04c7f7',
        toggles = Config.Toggles or {},
        values = settings
    }
end

local function openSettings()
    if not nuiReady then
        pendingOpen = true
        return
    end

    sendNui(payload())
    setFocus(true)
end

local function closeSettings()
    sendNui({ action = 'close' })
    setFocus(false)
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendNui({
        action = 'init',
        mainColor = Config.MainColor or '#04c7f7',
        toggles = Config.Toggles or {},
        values = settings
    })

    if pendingOpen then
        pendingOpen = false
        openSettings()
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeSettings()
    cb({ ok = true })
end)

RegisterNUICallback('toggle', function(data, cb)
    local id = tostring(data and data.id or '')
    local value = data and data.value == true

    if id ~= '' then
        saveSetting(id, value)
        applySingle(id, value)
        sendNui({ action = 'values', values = settings })
    end

    cb({ ok = true })
end)

RegisterNUICallback('reset', function(_, cb)
    settings = defaultSettings()

    for id, value in pairs(settings) do
        SetResourceKvp(kvpKey(id), value and 'true' or 'false')
    end

    applyAll()
    sendNui({ action = 'values', values = settings })

    cb({ ok = true })
end)

RegisterNetEvent('driftzone_settings:client:open', function()
    openSettings()
end)

RegisterNetEvent('driftzone_settings:client:close', function()
    closeSettings()
end)

RegisterNetEvent('driftzone_settings:client:apply', function()
    applyAll()
end)

RegisterCommand(Config.Command or 'settings', function()
    openSettings()
end, false)

exports('Open', openSettings)
exports('Close', closeSettings)
exports('Get', function(id)
    return settings[id] == true
end)
exports('Set', function(id, value)
    saveSetting(id, value == true)
    applySingle(id, value == true)
end)
exports('Apply', applyAll)

CreateThread(function()
    loadSettings()

    Wait(1500)
    applyAll()

    print('[DRIFTZONE_SETTINGS] Client-side loaded. Command: /' .. tostring(Config.Command or 'settings'))
end)

CreateThread(function()
    while true do
        if settings.minimap == false then
            DisplayRadar(false)
            Wait(500)
        else
            Wait(1500)
        end
    end
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                closeSettings()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
