local DronePoints = {}

local function dbg(...)
    if Config.Debug then print('[DRIFTZONE_DRONE]', ...) end
end

local function notify(src, notifyType, message, duration)
    if src == 0 then print('[DRIFTZONE_DRONE] ' .. tostring(message or '')) return end
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
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then return tonumber(state.dz_uid) end
    local ok, uid = pcall(function() return exports.driftzone_auth:GetUID(src) end)
    if ok and tonumber(uid) and tonumber(uid) > 0 then return tonumber(uid) end
    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end
    local ok, result = pcall(function() return exports.driftzone_auth:IsLoggedIn(src) end)
    return ok and result == true
end

local function getAdminData(src)
    local uid = getUid(src)
    if not uid then return nil end

    local ok, row = pcall(function()
        return MySQL.single.await('SELECT uid, username, admin_level, aduty FROM users WHERE uid = ? LIMIT 1', { uid })
    end)

    if not ok then
        notify(src, 'error', 'Database error la drone admin check.')
        print('[DRIFTZONE_DRONE] MySQL error: ' .. tostring(row))
        return nil
    end

    if not row then return nil end

    return {
        uid = tonumber(row.uid or uid) or uid,
        username = tostring(row.username or GetPlayerName(src) or 'Admin'),
        level = tonumber(row.admin_level or 0) or 0,
        aduty = isDutyValue(row.aduty)
    }
end

local function requireAdmin(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

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

local function commandPDrone(src)
    local admin = requireAdmin(src)
    if not admin then return true end
    dbg(('pdrone requested by src %s uid %s'):format(src, admin.uid))
    TriggerClientEvent('driftzone_drone:client:capturePoint', src)
    return true
end

local function commandDrone(src)
    local admin = requireAdmin(src)
    if not admin then return true end

    local point = DronePoints[admin.uid]
    if not point then
        notify(src, 'warning', 'Nu ai setat punctul dronei. Foloseste /pdrone.')
        return true
    end

    dbg(('drone toggle by src %s uid %s'):format(src, admin.uid))
    TriggerClientEvent('driftzone_drone:client:toggleDrone', src, point)
    return true
end

local function runCommand(src, command, args)
    command = tostring(command or ''):lower():gsub('^/', '')
    if command == 'pdrone' then return commandPDrone(src) end
    if command == 'drone' then return commandDrone(src) end
    return false
end

if Config.RegisterNativeCommands then
    RegisterCommand('pdrone', function(src) commandPDrone(src) end, false)
    RegisterCommand('drone', function(src) commandDrone(src) end, false)
end

exports('RunCommand', function(src, command, args)
    return runCommand(src, command, args or {})
end)

RegisterNetEvent('driftzone_drone:server:savePoint', function(coords)
    local src = source
    local admin = requireAdmin(src)
    if not admin then return end

    local x = type(coords) == 'table' and tonumber(coords.x) or nil
    local y = type(coords) == 'table' and tonumber(coords.y) or nil
    local z = type(coords) == 'table' and tonumber(coords.z) or nil

    if not x or not y or not z then
        notify(src, 'error', 'Coordonate invalide pentru drone.')
        return
    end

    DronePoints[admin.uid] = { x = x + 0.0, y = y + 0.0, z = z + 0.0, createdAt = os.time() }
    notify(src, 'success', 'Punctul dronei a fost salvat. Foloseste /drone.')
    dbg(('saved point uid %s -> %.3f %.3f %.3f'):format(admin.uid, x, y, z))
end)

AddEventHandler('playerDropped', function()
    local uid = getUid(source)
    if uid then DronePoints[uid] = nil end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_DRONE] Server-side loaded. Commands: /pdrone, /drone | Export: RunCommand')
end)
