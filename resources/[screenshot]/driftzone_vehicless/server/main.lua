local ScreenshotBusy = {}
local UploadSessions = {}

local function cleanText(value)
    return tostring(value or ''):gsub('[\r\n]', ' ')
end

local function cleanModel(value)
    return tostring(value or ''):lower():gsub('%s+', ''):gsub('[^%w_%-]', '')
end

local function cleanFileName(value)
    local name = cleanModel(value)
    name = name:gsub('[^a-z0-9_%-]', '')
    if name == '' then name = 'vehicle' end
    return name
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent('driftzone_vehicless:client:notify', src, typ or 'info', tostring(msg or ''), duration or 5000)
end

local function hasAccess(src)
    if Config.RequirePermission ~= true then return true end

    if Config.PermissionAce and Config.PermissionAce ~= '' and IsPlayerAceAllowed(src, Config.PermissionAce) then
        return true
    end

    if Config.UseDriftzoneAuth == true and Config.AuthResource and GetResourceState(Config.AuthResource) == 'started' then
        local res = Config.AuthResource
        local uid = nil
        local attempts = {
            function() return exports[res]:GetUID(src) end,
            function() return exports[res]:GetUid(src) end,
            function() return exports[res]:getUID(src) end,
            function() return exports[res]:GetUserId(src) end
        }

        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            if ok and tonumber(value) then
                uid = tonumber(value)
                break
            end
        end

        if uid then
            local ok, row = pcall(function()
                if not MySQL or not MySQL.single or not MySQL.single.await then return nil end
                return MySQL.single.await('SELECT admin_level, admin, aduty FROM users WHERE uid = ? LIMIT 1', { uid })
            end)

            if ok and row then
                local level = tonumber(row.admin_level or row.admin or 0) or 0
                local duty = tostring(row.aduty or ''):lower()
                local aduty = row.aduty == true or tonumber(row.aduty) == 1 or duty == 'yes' or duty == 'true' or duty == 'on'

                if level >= (Config.RequiredAdminLevel or 6) and (Config.RequireAduty ~= true or aduty) then
                    return true
                end
            end
        end
    end

    return false
end

local function normalizePath(path)
    return tostring(path or ''):gsub('\\', '/')
end

local function ensureScreenshotDir()
    local dirName = Config.Screenshot.directory or 'screenshots'
    local resourceDir = normalizePath(GetResourcePath(GetCurrentResourceName()))
    local fullDir = resourceDir .. '/' .. dirName
    local isWindows = fullDir:match('^%a:/') ~= nil

    if isWindows then
        os.execute(('mkdir "%s" >NUL 2>&1'):format(fullDir:gsub('/', '\\')))
    else
        os.execute(('mkdir -p "%s" >/dev/null 2>&1'):format(fullDir))
    end

    return fullDir, dirName
end

local function fileExists(path)
    local f = io.open(path, 'rb')
    if f then f:close() return true end
    return false
end

local function getExtension(ext)
    ext = tostring(ext or Config.Screenshot.encoding or 'jpg'):lower()
    if ext == 'jpeg' then return 'jpg' end
    if ext ~= 'png' and ext ~= 'webp' and ext ~= 'jpg' then return 'jpg' end
    return ext
end

local function buildRelativeFile(model, ext)
    local _, dirName = ensureScreenshotDir()
    local base = cleanFileName(model)
    ext = getExtension(ext)

    local relative = ('%s/%s.%s'):format(dirName, base, ext)
    local absolute = normalizePath(GetResourcePath(GetCurrentResourceName())) .. '/' .. relative
    local displayName = ('%s.%s'):format(base, ext)

    if Config.Screenshot.overwriteSameModel ~= false then
        return relative, absolute, displayName
    end

    if not fileExists(absolute) then return relative, absolute, displayName end

    for i = 2, 9999 do
        local rel = ('%s/%s_%d.%s'):format(dirName, base, i, ext)
        local abs = normalizePath(GetResourcePath(GetCurrentResourceName())) .. '/' .. rel
        local dis = ('%s_%d.%s'):format(base, i, ext)
        if not fileExists(abs) then
            return rel, abs, dis
        end
    end

    return relative, absolute, displayName
end

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64map = {}
for i = 1, #b64chars do
    b64map[b64chars:sub(i, i)] = i - 1
end

local function base64Decode(data)
    data = tostring(data or '')
    data = data:gsub('^data:image/%w+;base64,', '')
    data = data:gsub('%s+', '')

    local out = {}
    local buffer = 0
    local bits = 0

    for i = 1, #data do
        local c = data:sub(i, i)
        if c == '=' then break end

        local value = b64map[c]
        if value then
            buffer = (buffer << 6) | value
            bits = bits + 6

            if bits >= 8 then
                bits = bits - 8
                local byte = (buffer >> bits) & 0xFF
                out[#out + 1] = string.char(byte)
                if bits > 0 then
                    buffer = buffer & ((1 << bits) - 1)
                else
                    buffer = 0
                end
            end
        end
    end

    return table.concat(out)
end

local function clearSession(src, reason)
    local session = UploadSessions[src]
    if session and reason then
        print(('[DRIFTZONE_VEHICLESS] Upload cleared for %s: %s'):format(GetPlayerName(src) or src, cleanText(reason)))
    end
    UploadSessions[src] = nil
    ScreenshotBusy[src] = nil
end

local function finishUpload(src, token)
    local session = UploadSessions[src]
    if not session or session.token ~= token then return end

    local chunks = {}
    for i = 1, session.total do
        if not session.chunks[i] then
            return
        end
        chunks[#chunks + 1] = session.chunks[i]
    end

    local dataUri = table.concat(chunks)
    local maxLen = tonumber(Config.Screenshot.maxDataLength or 12000000) or 12000000
    if #dataUri > maxLen then
        clearSession(src, 'data too large')
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Screenshot prea mare. Scade quality sau foloseste jpg.', token)
        return
    end

    local ext = getExtension(session.ext)
    local relativePath, absolutePath, displayName = buildRelativeFile(session.model, ext)
    local raw = base64Decode(dataUri)

    if not raw or #raw < 1000 then
        clearSession(src, 'decoded image too small')
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Screenshot invalid/gol. Verifica screenshot-basic.', token)
        return
    end

    ensureScreenshotDir()
    local ok = SaveResourceFile(GetCurrentResourceName(), relativePath, raw, #raw)

    if ok then
        print(('[DRIFTZONE_VEHICLESS] Screenshot saved: %s (%d bytes)'):format(absolutePath, #raw))
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, true, 'Screenshot salvat: screenshots/' .. displayName, token)
    else
        print(('[DRIFTZONE_VEHICLESS] SaveResourceFile failed: %s'):format(relativePath))
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Nu am putut scrie fisierul in screenshots.', token)
    end

    clearSession(src)
end

RegisterNetEvent('driftzone_vehicless:server:requestOpen', function(model)
    local src = source

    if not hasAccess(src) then
        notify(src, 'warning', 'Nu ai acces la aceasta comanda.', 5500)
        return
    end

    model = cleanModel(model)
    if model == '' then
        notify(src, 'warning', ('Folosire: /%s model_name'):format(Config.Command or 'vehss'), 5500)
        return
    end

    TriggerClientEvent('driftzone_vehicless:client:openStudio', src, {
        model = model,
        mainColor = Config.MainColor or '#04c7f7'
    })
end)

RegisterNetEvent('driftzone_vehicless:server:beginScreenshotUpload', function(model, token, totalChunks, ext)
    local src = source
    model = cleanModel(model)
    token = tonumber(token)
    totalChunks = tonumber(totalChunks)

    if model == '' or not token or not totalChunks then
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Upload screenshot invalid.', token)
        return
    end

    if not hasAccess(src) then
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Nu ai acces la screenshot.', token)
        return
    end

    if ScreenshotBusy[src] then
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Asteapta, se salveaza deja un screenshot.', token)
        return
    end

    local maxChunks = tonumber(Config.Screenshot.maxChunks or 900) or 900
    if totalChunks < 1 or totalChunks > maxChunks then
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Screenshot prea mare pentru upload.', token)
        return
    end

    ScreenshotBusy[src] = true
    UploadSessions[src] = {
        token = token,
        model = model,
        ext = getExtension(ext),
        total = totalChunks,
        received = 0,
        chunks = {},
        started = GetGameTimer()
    }

    SetTimeout(Config.Screenshot.timeoutMs or 90000, function()
        local session = UploadSessions[src]
        if session and session.token == token then
            clearSession(src, 'timeout')
            TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Upload screenshot timeout.', token)
        end
    end)
end)

RegisterNetEvent('driftzone_vehicless:server:screenshotChunk', function(token, index, chunk)
    local src = source
    token = tonumber(token)
    index = tonumber(index)
    chunk = tostring(chunk or '')

    local session = UploadSessions[src]
    if not session or session.token ~= token then return end
    if not index or index < 1 or index > session.total then return end

    local maxChunk = tonumber(Config.Screenshot.chunkSize or 12000) or 12000
    if #chunk > maxChunk + 2048 then
        clearSession(src, 'chunk too large')
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Chunk screenshot prea mare.', token)
        return
    end

    if not session.chunks[index] then
        session.received = session.received + 1
    end

    session.chunks[index] = chunk

    if session.received >= session.total then
        finishUpload(src, token)
    end
end)

AddEventHandler('playerDropped', function()
    clearSession(source)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    ensureScreenshotDir()
    print('[DRIFTZONE_VEHICLESS] Loaded v10. Screenshot uses screenshot-basic Lua export + slow safe upload.')
end)
