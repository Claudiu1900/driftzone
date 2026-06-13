local ScreenshotBusy = {}

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

local function getResourceDir()
    return GetResourcePath(GetCurrentResourceName())
end

local function normalizePath(path)
    return tostring(path or ''):gsub('\\', '/')
end

local function ensureScreenshotDir()
    local dirName = Config.Screenshot.directory or 'screenshots'
    local resourceDir = normalizePath(getResourceDir())
    local fullDir = resourceDir .. '/' .. dirName

    local sep = package.config:sub(1, 1)
    if sep == '\\' then
        os.execute(('mkdir "%s" >NUL 2>NUL'):format(fullDir))
    else
        os.execute(('mkdir -p "%s" >/dev/null 2>&1'):format(fullDir))
    end

    return fullDir
end

local function fileExists(path)
    local f = io.open(path, 'rb')
    if f then f:close() return true end
    return false
end

local function buildFilePath(model)
    local dir = ensureScreenshotDir()
    local base = cleanFileName(model)
    local ext = Config.Screenshot.encoding or 'png'
    if ext == 'jpg' or ext == 'jpeg' then ext = 'jpg' else ext = 'png' end

    local path = ('%s/%s.%s'):format(dir, base, ext)
    local fileName = ('%s.%s'):format(base, ext)

    if Config.Screenshot.overwriteSameModel ~= false then
        return path, fileName
    end

    if not fileExists(path) then return path, fileName end

    for i = 2, 9999 do
        local p = ('%s/%s_%d.%s'):format(dir, base, i, ext)
        local f = ('%s_%d.%s'):format(base, i, ext)
        if not fileExists(p) then
            return p, f
        end
    end

    return path, fileName
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

RegisterNetEvent('driftzone_vehicless:server:takeScreenshot', function(model, token)
    local src = source
    model = cleanModel(model)

    if model == '' then
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Model invalid pentru screenshot.', token)
        return
    end

    if ScreenshotBusy[src] then
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Asteapta, se salveaza deja un screenshot.', token)
        return
    end

    local resourceName = Config.Screenshot.resource or 'screenshot-basic'
    if GetResourceState(resourceName) ~= 'started' then
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Porneste screenshot-basic in server.cfg inainte de driftzone_vehicless.', token)
        return
    end

    local filePath, fileName = buildFilePath(model)
    ScreenshotBusy[src] = true
    local finished = false

    SetTimeout(Config.Screenshot.timeoutMs or 20000, function()
        if finished then return end
        finished = true
        ScreenshotBusy[src] = nil
        TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Screenshot timeout. Verifica consola server/client pentru screenshot-basic.', token)
    end)

    local okCall, callErr = pcall(function()
        exports[resourceName]:requestClientScreenshot(src, {
            fileName = filePath,
            encoding = Config.Screenshot.encoding or 'png',
            quality = Config.Screenshot.quality or 0.95
        }, function(err, data)
            if finished then return end
            finished = true
            ScreenshotBusy[src] = nil

            if err then
                print(('[DRIFTZONE_VEHICLESS] screenshot-basic error for %s: %s'):format(GetPlayerName(src) or src, cleanText(err)))
                TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Screenshot-basic eroare: ' .. cleanText(err), token)
                return
            end

            SetTimeout(250, function()
                if fileExists(filePath) then
                    print(('[DRIFTZONE_VEHICLESS] Screenshot saved: %s'):format(filePath))
                    TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, true, 'Screenshot salvat: screenshots/' .. fileName, token)
                else
                    print(('[DRIFTZONE_VEHICLESS] screenshot-basic finished, but file missing: %s | data: %s'):format(filePath, cleanText(data)))
                    TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'Screenshot facut, dar fisierul nu a fost gasit pe server.', token)
                end
            end)
        end)
    end)

    if not okCall then
        if not finished then
            finished = true
            ScreenshotBusy[src] = nil
            print(('[DRIFTZONE_VEHICLESS] requestClientScreenshot failed: %s'):format(cleanText(callErr)))
            TriggerClientEvent('driftzone_vehicless:client:screenshotDone', src, false, 'requestClientScreenshot a esuat. Verifica screenshot-basic.', token)
        end
    end
end)

AddEventHandler('playerDropped', function()
    ScreenshotBusy[source] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    ensureScreenshotDir()
    print('[DRIFTZONE_VEHICLESS] Loaded. Screenshot mode: screenshot-basic fileName. No screenshotChunk events.')
end)
