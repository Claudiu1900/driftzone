local nuiReady = false
local pending = {}

local function normalizeType(notifyType)
    notifyType = tostring(notifyType or 'info'):lower()

    if notifyType == 'warning' then return 'warning' end
    if notifyType == 'error' then return 'error' end
    if notifyType == 'success' then return 'info' end

    return 'info'
end

local function normalizeDuration(duration)
    duration = tonumber(duration) or 5000

    if duration < 1500 then duration = 1500 end
    if duration > 20000 then duration = 20000 end

    return math.floor(duration)
end

local function pushToNui(payload)
    SendNUIMessage({
        action = 'notify',
        payload = payload
    })
end

local function sendNotify(notifyType, duration, message)
    local payload = {
        type = normalizeType(notifyType),
        duration = normalizeDuration(duration),
        message = tostring(message or '')
    }

    if payload.message:gsub('%s+', '') == '' then
        return
    end

    if not nuiReady then
        pending[#pending + 1] = payload

        if #pending > 50 then
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
        Wait(70)
    end

    pending = {}
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true

    CreateThread(function()
        Wait(100)
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

RegisterNetEvent('client:driftnotify:show', function(payload)
    local data = payload

    if type(data) == 'string' then
        local ok, decoded = pcall(json.decode, data)

        if ok and type(decoded) == 'table' then
            data = decoded
        else
            sendNotify('error', 5000, 'Notificare invalida.')
            return
        end
    end

    if type(data) ~= 'table' then
        sendNotify('error', 5000, 'Notificare invalida.')
        return
    end

    sendNotify(data.type, data.duration, data.message)
end)

exports('Show', function(notifyType, duration, message)
    sendNotify(notifyType, duration, message)
end)

exports('Info', function(message, duration)
    sendNotify('info', duration or 5000, message)
end)

exports('Warning', function(message, duration)
    sendNotify('warning', duration or 5000, message)
end)

exports('Error', function(message, duration)
    sendNotify('error', duration or 5000, message)
end)

RegisterCommand('testnotify', function()
    sendNotify('info', 5000, 'Notificarile DriftZone functioneaza.')
end, false)

CreateThread(function()
    Wait(2500)

    if not nuiReady then
        print('[DRIFTZONE_NOTIFICATIONS] NUI ready nu a venit inca. Verifica html/script.js.')
    end
end)

CreateThread(function()
    Wait(3500)

    if nuiReady then
        sendNotify('info', 3500, 'Sistemul de notificari a fost incarcat.')
    end
end)