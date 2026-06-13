local callbacks = {}
local correlationId = 0

local function nextId()
    correlationId = correlationId + 1
    return tostring(correlationId)
end

local function callSafe(fn, ...)
    if type(fn) ~= 'function' then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        print(('[screenshot-basic] callback error: %s'):format(tostring(err)))
    end
end

RegisterNuiCallbackType('screenshot_created')
AddEventHandler('__cfx_nui:screenshot_created', function(body, cb)
    if type(cb) == 'function' then cb(true) end

    body = body or {}
    local id = tostring(body.id or '')
    local item = callbacks[id]

    if not item then
        print(('[screenshot-basic] screenshot_created ignored, missing callback id=%s'):format(id))
        return
    end

    callbacks[id] = nil
    callSafe(item.cb, tostring(body.data or ''))
end)

local function sendRequest(options, cb)
    if type(cb) ~= 'function' then
        print('[screenshot-basic] request called without callback')
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
    options.targetURL = ('http://%s/screenshot_created'):format(GetCurrentResourceName())
    options.correlation = id

    SendNUIMessage({ request = options })

    SetTimeout(20000, function()
        local item = callbacks[id]
        if not item then return end
        callbacks[id] = nil
        print(('[screenshot-basic] requestScreenshot timeout id=%s. NUI did not return image.'):format(id))
        callSafe(item.cb, '')
    end)
end

exports('requestScreenshot', function(options, cb)
    if type(options) == 'function' then
        cb = options
        options = {}
    end
    sendRequest(options or {}, cb)
end)

-- Kept for compatibility, but DriftZone uses requestScreenshot + latent event upload.
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

    callbacks[id] = { cb = cb, created = GetGameTimer() }
    options.encoding = options.encoding or 'jpg'
    options.quality = options.quality or 0.70
    options.targetURL = tostring(url or '')
    options.targetField = tostring(field or 'file')
    options.resultURL = ('http://%s/screenshot_created'):format(GetCurrentResourceName())
    options.correlation = id

    SendNUIMessage({ request = options })

    SetTimeout(20000, function()
        local item = callbacks[id]
        if not item then return end
        callbacks[id] = nil
        print(('[screenshot-basic] requestScreenshotUpload timeout id=%s'):format(id))
        callSafe(item.cb, '')
    end)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[screenshot-basic] DriftZone standalone started. Export: requestScreenshot')
end)
