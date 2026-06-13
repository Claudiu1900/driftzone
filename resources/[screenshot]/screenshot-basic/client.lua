local callbacks = {}
local correlationId = 0

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

RegisterNUICallback('screenshot_created', function(body, cb)
    if type(cb) == 'function' then cb(true) end

    body = body or {}
    local id = tostring(body.id or '')
    local item = callbacks[id]
    if not item then return end

    callbacks[id] = nil
    safeCall(item.cb, body.data or '')
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
    options.quality = options.quality or 0.82
    options.resultURL = nil
    options.targetField = nil
    options.targetURL = ('http://%s/screenshot_created'):format(GetCurrentResourceName())
    options.correlation = id

    SendNUIMessage({ request = options })

    SetTimeout(30000, function()
        local item = callbacks[id]
        if not item then return end
        callbacks[id] = nil
        safeCall(item.cb, '')
    end)
end

exports('requestScreenshot', requestScreenshotInternal)

-- Compatibilitate minima. Upload-ul HTTP extern ramane disponibil daca ai un URL valid.
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
    options.quality = options.quality or 0.82
    options.targetURL = tostring(url or '')
    options.targetField = tostring(field or 'file')
    options.resultURL = ('http://%s/screenshot_created'):format(GetCurrentResourceName())
    options.correlation = id

    SendNUIMessage({ request = options })

    SetTimeout(30000, function()
        local item = callbacks[id]
        if not item then return end
        callbacks[id] = nil
        safeCall(item.cb, '')
    end)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[screenshot-basic] DriftZone Lua export build started. Exports: requestScreenshot, requestScreenshotUpload')
end)
