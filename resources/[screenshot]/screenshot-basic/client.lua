local callbacks = {}
local correlationId = 0
local started = false

local function nextId()
    correlationId = correlationId + 1
    return tostring(correlationId)
end

local function safeCall(fn, ...)
    if type(fn) ~= 'function' then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        print(('[screenshot-basic] callback error: %s'):format(tostring(err)))
    end
end

-- IMPORTANT:
-- Folosim forma oficiala RegisterNuiCallbackType + __cfx_nui event.
-- RegisterNUICallback poate sa nu primeasca body-ul corect daca fetch-ul din UI nu pune Content-Type.
RegisterNuiCallbackType('screenshot_created')
AddEventHandler('__cfx_nui:screenshot_created', function(body, cb)
    if type(cb) == 'function' then cb(true) end

    body = body or {}
    local id = tostring(body.id or '')
    local item = callbacks[id]
    if not item then
        print(('[screenshot-basic] ignored screenshot_created without callback id=%s'):format(id))
        return
    end

    callbacks[id] = nil
    local data = body.data or ''
    safeCall(item.cb, data)
end)

local function requestScreenshotInternal(options, cb)
    if type(options) == 'function' then
        cb = options
        options = {}
    end

    if type(cb) ~= 'function' then
        print('[screenshot-basic] requestScreenshot called without callback')
        return
    end

    options = options or {}
    local id = nextId()

    callbacks[id] = {
        cb = cb,
        created = GetGameTimer()
    }

    options.encoding = options.encoding or 'jpg'
    options.quality = options.quality or 0.70
    options.resultURL = nil
    options.targetField = nil

    -- Pe build-uri noi CEF merge mai sigur pe https://resource/callback.
    options.targetURL = ('https://%s/screenshot_created'):format(GetCurrentResourceName())
    options.correlation = id

    SendNUIMessage({ request = options })

    SetTimeout(15000, function()
        local item = callbacks[id]
        if not item then return end
        callbacks[id] = nil
        print(('[screenshot-basic] requestScreenshot timeout id=%s'):format(id))
        safeCall(item.cb, '')
    end)
end

exports('requestScreenshot', requestScreenshotInternal)

exports('requestScreenshotUpload', function(url, field, options, cb)
    if type(options) == 'function' then
        cb = options
        options = {}
    end

    if type(cb) ~= 'function' then
        print('[screenshot-basic] requestScreenshotUpload called without callback')
        return
    end

    options = options or {}
    local id = nextId()

    callbacks[id] = {
        cb = cb,
        created = GetGameTimer()
    }

    options.encoding = options.encoding or 'jpg'
    options.quality = options.quality or 0.70
    options.targetURL = tostring(url or '')
    options.targetField = tostring(field or 'file')
    options.resultURL = ('https://%s/screenshot_created'):format(GetCurrentResourceName())
    options.correlation = id

    SendNUIMessage({ request = options })

    SetTimeout(15000, function()
        local item = callbacks[id]
        if not item then return end
        callbacks[id] = nil
        print(('[screenshot-basic] requestScreenshotUpload timeout id=%s'):format(id))
        safeCall(item.cb, '')
    end)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    started = true
    print('[screenshot-basic] DriftZone fixed Lua build started. Exports: requestScreenshot, requestScreenshotUpload')
end)
