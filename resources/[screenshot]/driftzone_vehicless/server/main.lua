local AdminCache = {}

local function nowMs()
    if type(GetGameTimer) == 'function' then return GetGameTimer() end
    return os.time() * 1000
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent('driftzone_vehicless:client:notify', src, typ or 'info', duration or 5000, tostring(msg or ''))
end

local function isDuty(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on' or text == 'da'
end

local function cleanModel(value)
    return tostring(value or ''):lower():gsub('%s+', ''):gsub('[^%w_%-]', '')
end

local function getUid(src)
    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local res = Config.AuthResource or 'driftzone_auth'
    if res ~= '' and GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:GetUID(src) end,
            function() return exports[res]:GetUid(src) end,
            function() return exports[res]:getUID(src) end,
            function() return exports[res]:getUid(src) end,
            function() return exports[res]:GetUserId(src) end,
            function() return exports[res]:getUserId(src) end
        }

        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            local uid = tonumber(value)
            if ok and uid and uid > 0 then return uid end
        end
    end

    return nil
end


local function hasAceAccess(src)
    local cmd = Config.Command or 'vehss'
    if Config.AllowAceFallback == false then return false end
    return IsPlayerAceAllowed(src, 'driftzone.vehicless') or IsPlayerAceAllowed(src, 'command.' .. cmd)
end

local function isLogged(src)
    if Config.RequireLogin == false then return true end
    if hasAceAccess(src) then return true end

    local state = Player(src).state
    if state and state.dz_logged == true then return true end

    local res = Config.AuthResource or 'driftzone_auth'
    if res ~= '' and GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:IsLoggedIn(src) end,
            function() return exports[res]:isLoggedIn(src) end,
            function() return exports[res]:IsLogged(src) end,
            function() return exports[res]:isLogged(src) end
        }

        for _, fn in ipairs(attempts) do
            local ok, result = pcall(fn)
            if ok and result == true then return true end
        end
    end

    return getUid(src) ~= nil
end

local function aceAdmin(src)
    if hasAceAccess(src) then
        return {
            uid = 0,
            name = GetPlayerName(src) or ('Player ' .. tostring(src)),
            level = Config.AdminLevel or 6,
            aduty = true,
            ace = true
        }
    end

    return nil
end

local function oxSingle(query, params)
    if Config.UseDatabase == false then return nil, 'database disabled' end

    local res = Config.OxmysqlResource or 'oxmysql'
    if GetResourceState(res) ~= 'started' then
        return nil, ('%s nu este pornit'):format(res)
    end

    local p = promise.new()
    local ok, err = pcall(function()
        exports[res]:single(query, params or {}, function(row)
            p:resolve({ row = row })
        end)
    end)

    if not ok then
        return nil, tostring(err)
    end

    local result = Citizen.Await(p)
    return result and result.row or nil, nil
end

local function getAdminData(src)
    local uid = getUid(src)

    if uid then
        local cached = AdminCache[uid]
        if cached and cached.expires > nowMs() then return cached.data end

        local usersTable = sqlName(Config.UsersTable or 'users')
        local uidCol = sqlName(Config.UsersIdColumn or 'uid')
        local query = ('SELECT * FROM %s WHERE %s = ? LIMIT 1'):format(usersTable, uidCol)
        local row, dbErr = oxSingle(query, { uid })

        if row then
            local adminCol = tostring(Config.AdminColumn or 'admin_level')
            local fallbackCol = tostring(Config.AdminColumnFallback or '')
            local adutyCol = tostring(Config.AdutyColumn or 'aduty')
            local usernameCol = tostring(Config.UsernameColumn or 'username')
            local level = tonumber(row[adminCol] or (fallbackCol ~= '' and row[fallbackCol]) or 0) or 0

            local data = {
                uid = uid,
                name = row[usernameCol] or row.username or GetPlayerName(src) or ('Player ' .. tostring(src)),
                level = level,
                aduty = isDuty(row[adutyCol])
            }

            AdminCache[uid] = { data = data, expires = nowMs() + 2500 }
            return data
        end

        if dbErr then
            print(('[DRIFTZONE_VEHICLESS] DB warning for %s: %s'):format(GetPlayerName(src) or src, dbErr))
        end
    end

    return aceAdmin(src)
end

local function requireAdmin(src)
    if not src or src <= 0 then return nil end

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local admin = getAdminData(src)
    if not admin or admin.level < (Config.AdminLevel or 6) then
        notify(src, 'warning', 'Nu ai acces la aceasta comanda.')
        return nil
    end

    if Config.RequireAduty ~= false and not admin.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return admin
end

local function openStudio(src, model)
    local admin = requireAdmin(src)
    if not admin then return end

    model = cleanModel(model)
    if model == '' then
        notify(src, 'warning', ('Folosire: /%s model_name'):format(Config.Command or 'vehss'))
        return
    end

    TriggerClientEvent('driftzone_vehicless:client:openStudio', src, {
        model = model,
        admin = admin.name,
        mainColor = Config.MainColor or '#04c7f7'
    })
end

RegisterCommand(Config.Command or 'vehss', function(src, args)
    if src <= 0 then
        print(('[DRIFTZONE_VEHICLESS] Folosire in joc: /%s model_name'):format(Config.Command or 'vehss'))
        return
    end

    openStudio(src, args and args[1] or '')
end, false)

RegisterNetEvent('driftzone_vehicless:server:requestOpen', function(model)
    openStudio(source, model)
end)

local ScreenshotUploads = {}
local Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function sanitizeFileName(value)
    local name = tostring(value or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-%.]', '')
    if name == '' then name = 'driftzone_vehicle_' .. tostring(os.time()) .. '.png' end
    if not name:find('%.png$') then name = name .. '.png' end
    return name
end

local function screenshotKey(src, token)
    return tostring(src) .. ':' .. tostring(token)
end

local function base64Decode(data)
    data = tostring(data or ''):gsub('[^' .. Base64Chars .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local f = (Base64Chars:find(x, 1, true) or 1) - 1
        local r = ''
        for i = 6, 1, -1 do
            r = r .. ((f % 2^i - f % 2^(i - 1) > 0) and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do
            if x:sub(i, i) == '1' then c = c + 2^(8 - i) end
        end
        return string.char(c)
    end))
end

local function screenshotFail(src, token, msg)
    ScreenshotUploads[screenshotKey(src, token)] = nil
    TriggerClientEvent('driftzone_vehicless:client:screenshotSaved', src, {
        ok = false,
        token = token,
        error = msg or 'Screenshot save failed.'
    })
end

RegisterNetEvent('driftzone_vehicless:server:screenshotStart', function(token, filename, total, size, model)
    local src = source
    token = tonumber(token or 0) or 0
    total = tonumber(total or 0) or 0
    size = tonumber(size or 0) or 0

    if token <= 0 then return end
    if not requireAdmin(src) then return end

    local maxChars = tonumber(Config.ScreenshotMaxBase64Chars or 25000000) or 25000000
    local maxChunks = tonumber(Config.ScreenshotMaxChunks or 2500) or 2500

    if total <= 0 or total > maxChunks or size <= 0 or size > maxChars then
        screenshotFail(src, token, 'Screenshot prea mare sau invalid.')
        return
    end

    local safeFile = sanitizeFileName(filename)
    ScreenshotUploads[screenshotKey(src, token)] = {
        src = src,
        token = token,
        filename = safeFile,
        model = cleanModel(model or 'vehicle'),
        total = total,
        size = size,
        chunks = {},
        received = 0,
        started = nowMs()
    }
end)

RegisterNetEvent('driftzone_vehicless:server:screenshotChunk', function(token, index, total, chunk)
    local src = source
    token = tonumber(token or 0) or 0
    index = tonumber(index or 0) or 0
    total = tonumber(total or 0) or 0
    chunk = tostring(chunk or '')

    local upload = ScreenshotUploads[screenshotKey(src, token)]
    if not upload then return end
    if total ~= upload.total or index < 1 or index > upload.total or chunk == '' then return end

    if not upload.chunks[index] then
        upload.chunks[index] = chunk
        upload.received = upload.received + 1
    end
end)

RegisterNetEvent('driftzone_vehicless:server:screenshotFinish', function(token)
    local src = source
    token = tonumber(token or 0) or 0

    local key = screenshotKey(src, token)
    local upload = ScreenshotUploads[key]
    if not upload then
        screenshotFail(src, token, 'Upload-ul screenshot-ului nu exista.')
        return
    end

    if upload.received ~= upload.total then
        screenshotFail(src, token, ('Lipsesc bucati din screenshot: %s/%s.'):format(upload.received, upload.total))
        return
    end

    local parts = {}
    for i = 1, upload.total do
        if not upload.chunks[i] then
            screenshotFail(src, token, ('Lipseste bucata %s din screenshot.'):format(i))
            return
        end
        parts[i] = upload.chunks[i]
    end

    local base64 = table.concat(parts)
    if #base64 ~= upload.size then
        -- Nu e fatal mereu, dar daca e diferenta mare, ceva s-a corupt.
        if math.abs(#base64 - upload.size) > 32 then
            screenshotFail(src, token, 'Screenshot corupt la upload.')
            return
        end
    end

    local bytes = base64Decode(base64)
    if not bytes or #bytes < 1000 then
        screenshotFail(src, token, 'Screenshot invalid dupa decodare.')
        return
    end

    local folder = tostring(Config.ScreenshotServerFolder or 'screenshots'):gsub('^/+', ''):gsub('/+$', '')
    folder = folder:gsub('%.%.', '')
    if folder == '' then folder = 'screenshots' end

    local relativePath = folder .. '/' .. upload.filename
    local ok = SaveResourceFile(GetCurrentResourceName(), relativePath, bytes, #bytes)
    ScreenshotUploads[key] = nil

    if not ok then
        TriggerClientEvent('driftzone_vehicless:client:screenshotSaved', src, {
            ok = false,
            token = token,
            error = 'Nu pot scrie fisierul. Verifica daca folderul screenshots exista si resource-ul are permisiune de scriere.'
        })
        return
    end

    local resourcePath = GetResourcePath(GetCurrentResourceName()) or GetCurrentResourceName()
    local savedPath = resourcePath .. '/' .. relativePath
    print(('[DRIFTZONE_VEHICLESS] Screenshot saved: %s'):format(savedPath))

    TriggerClientEvent('driftzone_vehicless:client:screenshotSaved', src, {
        ok = true,
        token = token,
        file = relativePath,
        message = 'Screenshot salvat pe server: ' .. relativePath
    })
end)

CreateThread(function()
    while true do
        local t = nowMs()
        for key, upload in pairs(ScreenshotUploads) do
            if upload.started and t - upload.started > 60000 then
                ScreenshotUploads[key] = nil
            end
        end
        Wait(30000)
    end
end)

RegisterNetEvent('driftzone_vehicless:server:clearCache', function()
    local uid = getUid(source)
    if uid then AdminCache[uid] = nil end
end)

AddEventHandler('playerDropped', function()
    local uid = getUid(source)
    if uid then AdminCache[uid] = nil end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_VEHICLESS] Loaded fixed version. Command: /' .. (Config.Command or 'vehss'))
end)
