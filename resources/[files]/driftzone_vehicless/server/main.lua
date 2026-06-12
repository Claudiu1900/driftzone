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
