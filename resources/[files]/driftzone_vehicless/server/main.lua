local AdminCache = {}

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 5000, tostring(msg or ''))
end

local function isDuty(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getUid(src)
    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local res = Config.AuthResource or 'driftzone_auth'
    if GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:GetUID(src) end,
            function() return exports[res]:GetUid(src) end,
            function() return exports[res]:getUID(src) end,
            function() return exports[res]:GetUserId(src) end
        }

        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            local uid = tonumber(value)
            if ok and uid and uid > 0 then return uid end
        end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end

    local res = Config.AuthResource or 'driftzone_auth'
    if GetResourceState(res) == 'started' then
        local ok, result = pcall(function()
            return exports[res]:IsLoggedIn(src)
        end)
        if ok and result == true then return true end
    end

    return getUid(src) ~= nil
end

local function getAdminData(src)
    local uid = getUid(src)
    if not uid then return nil end

    local cached = AdminCache[uid]
    if cached and cached.expires > GetGameTimer() then return cached.data end

    local usersTable = sqlName(Config.UsersTable or 'users')
    local uidCol = sqlName(Config.UsersIdColumn or 'uid')
    local adminCol = tostring(Config.AdminColumn or 'admin_level')
    local fallbackCol = tostring(Config.AdminColumnFallback or '')
    local adutyCol = tostring(Config.AdutyColumn or 'aduty')

    local row = MySQL.single.await((
        'SELECT * FROM %s WHERE %s = ? LIMIT 1'
    ):format(usersTable, uidCol), { uid })

    if not row then return nil end

    local level = tonumber(row[adminCol] or (fallbackCol ~= '' and row[fallbackCol]) or 0) or 0
    local data = {
        uid = uid,
        name = row.username or GetPlayerName(src) or ('Player ' .. tostring(src)),
        level = level,
        aduty = isDuty(row[adutyCol])
    }

    AdminCache[uid] = { data = data, expires = GetGameTimer() + 2500 }
    return data
end

local function requireAdmin(src)
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

local function cleanModel(value)
    return tostring(value or ''):lower():gsub('%s+', ''):gsub('[^%w_%-]', '')
end

RegisterNetEvent('driftzone_vehicless:server:requestOpen', function(model)
    local src = source
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
        mainColor = '#04c7f7'
    })
end)

AddEventHandler('playerDropped', function()
    local uid = getUid(source)
    if uid then AdminCache[uid] = nil end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_VEHICLESS] Loaded.')
end)
