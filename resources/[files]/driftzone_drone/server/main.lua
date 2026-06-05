local DronePoints = {}

local function notify(src, notifyType, message, duration)
    if Config.Notify and Config.Notify.enabled then
        TriggerClientEvent(Config.Notify.event or 'client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
    end
end

local function isDutyValue(value)
    if value == true then return true end

    local text = tostring(value or ''):lower()
    return tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getUid(src)
    local state = Player(src).state

    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local ok, uid = pcall(function()
        return exports.driftzone_auth:GetUID(src)
    end)

    if ok and tonumber(uid) and tonumber(uid) > 0 then
        return tonumber(uid)
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state

    if state and state.dz_logged == true then
        return true
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:IsLoggedIn(src)
    end)

    return ok and result == true
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then return nil end

    local row = MySQL.single.await(
        'SELECT uid, username, admin_level, aduty FROM users WHERE uid = ? LIMIT 1',
        { uid }
    )

    if not row then return nil end

    return {
        uid = tonumber(row.uid or uid) or uid,
        username = tostring(row.username or GetPlayerName(src) or 'Admin'),
        level = tonumber(row.admin_level or 0) or 0,
        aduty = isDutyValue(row.aduty)
    }
end

local function requireAdmin(src)
    if src == 0 then return nil end

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local data = getAdminData(src)

    if not data or data.level < (Config.RequiredAdminLevel or 6) then
        notify(src, 'warning', 'Nu ai acces la aceasta comanda.')
        return nil
    end

    if Config.RequireAduty and not data.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return data
end

RegisterCommand('pdrone', function(src)
    local admin = requireAdmin(src)
    if not admin then return end

    TriggerClientEvent('driftzone_drone:client:capturePoint', src)
end, false)

RegisterCommand('drone', function(src)
    local admin = requireAdmin(src)
    if not admin then return end

    local point = DronePoints[admin.uid]

    if not point then
        notify(src, 'warning', 'Nu ai setat punctul dronei. Foloseste /pdrone.')
        return
    end

    TriggerClientEvent('driftzone_drone:client:toggleDrone', src, point)
end, false)

RegisterNetEvent('driftzone_drone:server:savePoint', function(coords)
    local src = source
    local admin = requireAdmin(src)

    if not admin then return end

    if type(coords) ~= 'table' then
        notify(src, 'error', 'Nu am putut salva punctul dronei.')
        return
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)

    if not x or not y or not z then
        notify(src, 'error', 'Coordonate invalide pentru drone.')
        return
    end

    DronePoints[admin.uid] = {
        x = x + 0.0,
        y = y + 0.0,
        z = z + 0.0,
        createdAt = os.time()
    }

    notify(src, 'success', 'Punctul dronei a fost salvat. Foloseste /drone.')
end)

AddEventHandler('playerDropped', function()
    local uid = getUid(source)

    if uid then
        DronePoints[uid] = nil
    end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_DRONE] Server-side loaded.')
end)
