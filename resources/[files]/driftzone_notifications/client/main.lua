local nuiReady = false
local pending = {}
local soundEnabled = true

local Settings = {
    defaultDuration = 5000,
    minDuration = 1200,
    maxDuration = 20000,
    maxPending = 60
}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalizeType(notifyType)
    local t = tostring(notifyType or 'info'):lower():gsub('%s+', '')

    if t == 'success' or t == 'succes' or t == 'ok' or t == 'done' then return 'success' end
    if t == 'warning' or t == 'warn' or t == 'attention' or t == 'atentie' then return 'warning' end
    if t == 'error' or t == 'err' or t == 'danger' or t == 'fail' then return 'error' end

    return 'info'
end

local function normalizeDuration(duration)
    duration = tonumber(duration) or Settings.defaultDuration

    if duration < Settings.minDuration then duration = Settings.minDuration end
    if duration > Settings.maxDuration then duration = Settings.maxDuration end

    return math.floor(duration)
end

local function normalizeArgs(notifyType, duration, message)
    -- Standard DriftZone: TriggerEvent('client:notify', type, duration, message)
    -- Compatibility:      TriggerEvent('client:notify', type, message, duration)
    -- Compatibility:      exports.Show(type, message)
    if type(duration) == 'string' and (message == nil or message == '') then
        message = duration
        duration = Settings.defaultDuration
    elseif type(duration) == 'string' and type(message) == 'number' then
        local oldMessage = duration
        duration = message
        message = oldMessage
    end

    return normalizeType(notifyType), normalizeDuration(duration), trim(message)
end

local function pushToNui(payload)
    SendNUIMessage({
        action = 'notify',
        payload = payload
    })
end

local function sendNotify(notifyType, duration, message)
    local nType, nDuration, nMessage = normalizeArgs(notifyType, duration, message)

    if nMessage:gsub('%s+', '') == '' then return end

    local payload = {
        type = nType,
        duration = nDuration,
        message = nMessage,
        sound = soundEnabled
    }

    if not nuiReady then
        pending[#pending + 1] = payload

        if #pending > Settings.maxPending then
            table.remove(pending, 1)
        end

        return
    end

    pushToNui(payload)
end

local function flushPending()
    if not nuiReady then return end

    for _, payload in ipairs(pending) do
        pushToNui(payload)
        Wait(45)
    end

    pending = {}
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true

    CreateThread(function()
        Wait(120)
        flushPending()
    end)

    cb({ ok = true })
end)

RegisterNetEvent('client:notify', function(notifyType, duration, message)
    sendNotify(notifyType, duration, message)
end)

RegisterNetEvent('driftzone_notifications:client:show', function(notifyType, duration, message)
    sendNotify(notifyType, duration, message)
end)

RegisterNetEvent('client:driftnotify:local', function(notifyType, duration, message)
    sendNotify(notifyType, duration, message)
end)

RegisterNetEvent('driftzone_notifications:client:setSound', function(enabled)
    soundEnabled = enabled ~= false
    SendNUIMessage({ action = 'setSound', enabled = soundEnabled })
end)

RegisterNetEvent('driftzone_notifications:client:clear', function()
    pending = {}
    SendNUIMessage({ action = 'clear' })
end)

RegisterNetEvent('client:driftnotify:show', function(payload)
    local data = payload

    if type(data) == 'string' then
        local ok, decoded = pcall(json.decode, data)
        if ok and type(decoded) == 'table' then
            data = decoded
        else
            return
        end
    end

    if type(data) ~= 'table' then return end

    sendNotify(data.type or data.notifyType or 'info', data.duration or data.time, data.message or data.msg or data.text)
end)

exports('Show', function(notifyType, duration, message)
    sendNotify(notifyType, duration, message)
end)

exports('Info', function(message, duration)
    sendNotify('info', duration or Settings.defaultDuration, message)
end)

exports('Success', function(message, duration)
    sendNotify('success', duration or Settings.defaultDuration, message)
end)

exports('Warning', function(message, duration)
    sendNotify('warning', duration or Settings.defaultDuration, message)
end)

exports('Error', function(message, duration)
    sendNotify('error', duration or Settings.defaultDuration, message)
end)

exports('SetSound', function(enabled)
    soundEnabled = enabled ~= false
    SendNUIMessage({ action = 'setSound', enabled = soundEnabled })
end)

exports('Clear', function()
    pending = {}
    SendNUIMessage({ action = 'clear' })
end)

RegisterCommand('testnotify', function()
    sendNotify('info', 5000, 'DriftZone Notifications functioneaza corect.')
    Wait(450)
    sendNotify('success', 5000, 'Actiunea a fost finalizata.')
    Wait(450)
    sendNotify('warning', 5000, 'Verifica datele introduse.')
    Wait(450)
    sendNotify('error', 5000, 'A aparut o eroare.')
end, false)

CreateThread(function()
    Wait(3500)

    if not nuiReady then
        print('[DRIFTZONE_NOTIFICATIONS] NUI nu a raspuns. Verifica html/index.html si html/script.js.')
    end
end)
