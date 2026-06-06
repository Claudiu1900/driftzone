local nuiReady = false
local menuOpen = false
local settings = {}
local pendingOpen = false
local radarHidden = false

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

local function notify(message)
    if Config.Notify and Config.Notify.enabled then
        TriggerEvent(Config.Notify.event or 'client:notify', 'info', 3000, tostring(message or ''))
    end
end

local function sendNui(data)
    if not nuiReady then return false end
    SendNUIMessage(data)
    return true
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
    if GetResourceState(resource) ~= 'started' then return false end

    local args = { ... }

    local ok = pcall(function()
        exports[resource][exportName](table.unpack(args))
    end)

    return ok == true
end

local function setHudVisible(value)
    value = value == true

    -- Eventuri compatibile cu sistemele tale anterioare.
    TriggerEvent('driftzone_hud:visible', value)
    TriggerEvent('driftzone_hud:client:visible', value)
    TriggerEvent('driftzone_hud:client:setVisible', value)
    TriggerEvent('driftzone_hud:setVisible', value)

    safeExport('driftzone_hud', 'SetVisible', value)
    safeExport('driftzone_hud', 'setVisible', value)

    LocalPlayer.state:set('settings:hud', value, true)
end

local function setRadarVisible(value)
    value = value == true
    radarHidden = not value

    if value then
        DisplayRadar(true)
        SetRadarBigmapEnabled(false, false)
    else
        SetRadarBigmapEnabled(false, false)
        DisplayRadar(false)
    end

    LocalPlayer.state:set('settings:radar', value, true)
end

local function setOverheadOthers(value)
    value = value == true

    -- Corect conform driftzone_overheadstats:
    -- showAll/hideAll controleaza DOAR ce vezi tu la ceilalti.
    if value then
        TriggerEvent('driftzone_overheadstats:client:showAll')
        safeExport('driftzone_overheadstats', 'ShowAll')
    else
        TriggerEvent('driftzone_overheadstats:client:hideAll')
        safeExport('driftzone_overheadstats', 'HideAll')
    end

    LocalPlayer.state:set('settings:overhead_others', value, true)
end

local function setOverheadSelf(value)
    value = value == true

    -- Corect conform driftzone_overheadstats:
    -- showPersonal/hidePersonal controleaza DOAR overhead-ul tau local.
    if value then
        TriggerEvent('driftzone_overheadstats:client:showPersonal')
        safeExport('driftzone_overheadstats', 'ShowPersonal')
    else
        TriggerEvent('driftzone_overheadstats:client:hidePersonal')
        safeExport('driftzone_overheadstats', 'HidePersonal')
    end

    LocalPlayer.state:set('settings:overhead_self', value, true)
end


local function setTurometruVisible(value)
    value = value == true

    if value then
        TriggerEvent('driftzone_turometru:client:show')
    else
        TriggerEvent('driftzone_turometru:client:hide')
    end

    LocalPlayer.state:set('settings:turometru', value, true)
end


local function setVoiceVolumeUiVisible(value)
    value = value == true

    if value then
        TriggerEvent('driftzone_voicechat:client:showVolumeUi')
        safeExport('driftzone_voicechat', 'ShowVolumeUi')
    else
        TriggerEvent('driftzone_voicechat:client:hideVolumeUi')
        safeExport('driftzone_voicechat', 'HideVolumeUi')
    end

    LocalPlayer.state:set('settings:voice_volume_ui', value, true)
end

local function applySingle(id, value)
    value = value == true

    if id == 'hud' then
        setHudVisible(value)
    elseif id == 'radar' then
        setRadarVisible(value)
    elseif id == 'overhead_others' then
        setOverheadOthers(value)
    elseif id == 'overhead_self' then
        setOverheadSelf(value)
    elseif id == 'turometru' then
        setTurometruVisible(value)
    elseif id == 'voice_volume_ui' then
        setVoiceVolumeUiVisible(value)
    end

    TriggerEvent('driftzone_settings:client:changed', id, value)
    TriggerEvent(('driftzone_settings:client:%s'):format(id), value)
end

local function applyAll()
    applySingle('hud', settings.hud == true)
    applySingle('radar', settings.radar == true)
    applySingle('overhead_others', settings.overhead_others == true)
    applySingle('overhead_self', settings.overhead_self == true)
    applySingle('turometru', settings.turometru == true)
    applySingle('voice_volume_ui', settings.voice_volume_ui == true)
end

local function payload()
    return {
        action = 'open',
        mainColor = Config.MainColor or '#04c7f7',
        toggles = Config.Toggles or {},
        values = settings
    }
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)
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

    Wait(1200)
    applyAll()

    print('[DRIFTZONE_SETTINGS] Client-side loaded. Command: /' .. tostring(Config.Command or 'settings'))
end)

-- Radar OFF corect: GTA/FiveM poate reaprinde radarul cand intri in vehicul.
-- Cand toggle-ul radar este OFF, il fortam ascuns constant.
CreateThread(function()
    while true do
        if radarHidden then
            DisplayRadar(false)
            SetRadarBigmapEnabled(false, false)

            Wait((Config.Radar and Config.Radar.hideLoopWait) or 0)
        else
            Wait(750)
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
