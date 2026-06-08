local AdminCommands = {
    aduty = true,
    staff = true,
    ['goto'] = true,
    bring = true,
    kick = true,
    slap = true,
    warn = true,
    rwarn = true,
    warns = true,
    resetwarns = true,
    coords = true,
    gotocoords = true,
    tptow = true,
    nc = true,
    veh = true,
    fix = true,
    ban = true,
    tempban = true,
    unban = true,
    givecar = true,
    takecar = true,
    transfercar = true,
    changeplate = true,
    addoutfit = true,
    cleanup = true,
    cancelcleanup = true,
    addcar = true,
    removecar = true
}

local Cooldowns = {
    kick = {},
    veh = {},
    tptow = {},
    warn = {},
    rwarn = {}
}

local NoclipState = {}
local AdminDataCache = {}
local PlayerLookupCache = {}
local CleanupState = nil
local CleanupSerial = 0
local CleanupReports = {}
local VehicleNameColumns = nil

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function getOptConfig(key, fallback)
    if Config and Config.Optimization and Config.Optimization[key] ~= nil then
        return Config.Optimization[key]
    end

    return fallback
end

local function jsonSafe(data)
    local ok, result = pcall(function()
        return json.encode(data or {})
    end)

    if ok then return result end
    return '{}'
end

local function getLogTable()
    if Config and Config.Logs and Config.Logs.table then
        return tostring(Config.Logs.table)
    end

    return 'admin_command_logs'
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name):gsub('`', ''))
end

local function notify(src, type, message, duration)
    TriggerClientEvent('client:notify', src, type or 'info', duration or 5000, tostring(message or ''))

    TriggerClientEvent('driftzone_chat:client:addMessage', src, {
        type = type == 'warning' and 'error' or 'system',
        time = os.date('%H:%M'),
        text = tostring(message or '')
    })
end

local function broadcast(message)
    TriggerClientEvent('driftzone_chat:client:addMessage', -1, {
        type = 'system',
        time = os.date('%H:%M'),
        text = tostring(message or '')
    })
end

local function notifyAll(notifyType, message, duration)
    TriggerClientEvent('client:notify', -1, notifyType or 'info', duration or 5000, tostring(message or ''))
    broadcast(message)
end

local function parseCleanupTime(args)
    args = args or {}
    local amount = tonumber(args[1])
    local unit = tostring(args[2] or 's'):lower()

    if not amount or amount <= 0 then
        return nil, 'Folosire: /cleanup 10 s sau /cleanup 10 m'
    end

    if unit == 'm' or unit == 'min' or unit == 'minute' or unit == 'minutes' then
        return math.floor(amount * 60), ('%s minute'):format(math.floor(amount))
    end

    if unit == 's' or unit == 'sec' or unit == 'secunde' or unit == 'seconds' then
        return math.floor(amount), ('%s secunde'):format(math.floor(amount))
    end

    return nil, 'Unitate invalida. Foloseste s sau m.'
end

local function isVehicleUnoccupiedServer(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local driver = GetPedInVehicleSeat(veh, -1)
    return not driver or driver == 0 or not DoesEntityExist(driver)
end

local function deleteVehicleServer(veh)
    if not isVehicleUnoccupiedServer(veh) then return false end

    SetEntityAsMissionEntity(veh, true, true)

    for _ = 1, 8 do
        if not DoesEntityExist(veh) then return true end
        DeleteEntity(veh)
        Wait(0)
    end

    return not DoesEntityExist(veh)
end

local function countAndDeleteUnoccupiedVehicles()
    local deleted = 0
    local vehicles = GetAllVehicles()

    for _, veh in ipairs(vehicles) do
        if deleteVehicleServer(veh) then
            deleted = deleted + 1
        end
    end

    return deleted
end

local function loadVehicleNameColumns()
    if VehicleNameColumns then return VehicleNameColumns end

    VehicleNameColumns = {}
    local ok, rows = pcall(function()
        return MySQL.query.await('SHOW COLUMNS FROM `vehiclenames`', {}) or {}
    end)

    if ok and rows then
        for _, row in ipairs(rows) do
            if row.Field then
                VehicleNameColumns[tostring(row.Field)] = true
            end
        end
    end

    return VehicleNameColumns
end

local function resetVehicleNameColumns()
    VehicleNameColumns = nil
end

local function cleanSqlIdentifier(name)
    return tostring(name or ''):gsub('`', '')
end

local function normalizeSelectValue(value, fallback)
    local text = tostring(value or fallback or ''):lower()
    if text == '' then text = tostring(fallback or '') end
    return text
end

local function sanitizeVehicleModel(value)
    return trim(tostring(value or ''):lower():gsub('%s+', ''))
end

local function parseBoolInt(value, default)
    if value == nil or tostring(value) == '' then return tonumber(default or 0) or 0 end
    local n = tonumber(value)
    if n == 1 then return 1 end
    return 0
end

local function getAddCarInsert(payload)
    local cols = loadVehicleNameColumns()
    local insertCols = {}
    local params = {}

    local function add(col, value)
        if cols[col] then
            insertCols[#insertCols + 1] = col
            params[#params + 1] = value
        end
    end

    local model = sanitizeVehicleModel(payload.model or payload.vehicle_model or payload.carModel)
    local name = trim(payload.name or payload.vehicle_name or payload.carName)
    local price = math.max(0, math.floor(tonumber(payload.price or 0) or 0))
    local category = math.floor(tonumber(payload.category or 1) or 1)
    local vip = parseBoolInt(payload.vip, 0)
    local apear = parseBoolInt(payload.apear, 1)
    local selling = parseBoolInt(payload.selling, 1)
    local vehType = normalizeSelectValue(payload.type, 'drift')
    local image = trim(payload.image or '')

    if model == '' or name == '' then
        return nil, nil, 'Car Model ID si Car Name sunt obligatorii.'
    end

    if category < 1 or category > 6 then
        return nil, nil, 'Categoria trebuie sa fie intre 1 si 6.'
    end

    if vehType ~= 'drift' and vehType ~= 'hs' then
        vehType = 'drift'
    end

    add('vehicle_model', model)
    add('vehicle_name', name)

    if cols.price then
        add('price', price)
    elseif cols.vehicle_price then
        add('vehicle_price', price)
    end

    add('category', category)
    add('vip', vip)
    add('apear', apear)
    add('selling', selling)
    add('type', vehType)

    if cols.image then
        add('image', image)
    elseif cols.vehicle_image then
        add('vehicle_image', image)
    end

    if #insertCols <= 0 then
        return nil, nil, 'Tabela vehiclenames nu are coloane compatibile.'
    end

    return insertCols, params, nil, {
        model = model,
        name = name,
        price = price,
        category = category,
        vip = vip,
        apear = apear,
        selling = selling,
        type = vehType,
        image = image
    }
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

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function isAdutyValue(value)
    local text = tostring(value or ''):lower()

    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true'
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then return nil end

    local cached = AdminDataCache[uid]
    if cached and cached.expires > GetGameTimer() then
        return cached.data
    end

    local row = MySQL.single.await(
        'SELECT * FROM users WHERE uid = @uid LIMIT 1',
        {
            ['@uid'] = uid
        }
    )

    if not row then return nil end

    local level = tonumber(row.admin_level or row.admin or 0) or 0
    local duty = isAdutyValue(row.aduty)

    local data = {
        uid = uid,
        username = row.username or getPlayerNameSafe(src),
        level = level,
        aduty = duty,
        rank = Config.Ranks[level] or 'Staff'
    }

    AdminDataCache[uid] = {
        expires = GetGameTimer() + getOptConfig('adminDataCacheMs', 2500),
        data = data
    }

    return data
end

local function invalidateAdminCache(uid)
    uid = tonumber(uid)
    if uid then
        AdminDataCache[uid] = nil
    end
end

local function requireAdmin(src, minLevel, needDuty)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local data = getAdminData(src)

    if not data or data.level <= 0 then
        notify(src, 'warning', 'Nu esti staff.')
        return nil
    end

    if data.level < minLevel then
        notify(src, 'warning', 'Nu ai gradul necesar pentru aceasta comanda.')
        return nil
    end

    if needDuty ~= false and not data.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return data
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then return nil end

    local cached = PlayerLookupCache[uid]
    if cached and cached.expires > GetGameTimer() then
        if cached.src and GetPlayerName(cached.src) then
            return cached.src
        end
    end

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)

        if target and getUid(target) == uid then
            PlayerLookupCache[uid] = {
                src = target,
                expires = GetGameTimer() + getOptConfig('playerLookupCacheMs', 2000)
            }

            return target
        end
    end

    PlayerLookupCache[uid] = {
        src = nil,
        expires = GetGameTimer() + 500
    }

    return nil
end

local function getPlayerByIdOrUid(value)
    local number = tonumber(value)

    if not number then return nil end

    local byUid = getPlayerByUid(number)

    if byUid then return byUid end

    if GetPlayerName(number) then
        return number
    end

    return nil
end

local function parseReason(args, startIndex)
    local result = {}

    for i = startIndex, #args do
        result[#result + 1] = args[i]
    end

    return trim(table.concat(result, ' '))
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function getDatabaseConfig()
    local db = Config.Database or {}

    return {
        usersTable = db.usersTable or 'users',
        uidColumn = db.uidColumn or 'uid',
        warnsColumn = db.warnsColumn or 'warns',
        tempBanColumn = db.tempBanColumn or 'tempban',
        tempBanReasonColumn = db.tempBanReasonColumn or 'tempbanreason'
    }
end

local function getPlayerCoordsPayload(player)
    local ped = GetPlayerPed(player)

    if not ped or ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading
    }
end

local function getWarnsByUid(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return nil end

    local db = getDatabaseConfig()

    local row = MySQL.single.await(
        ('SELECT COALESCE(%s, 0) AS warns FROM %s WHERE %s = @uid LIMIT 1'):format(
            sqlName(db.warnsColumn),
            sqlName(db.usersTable),
            sqlName(db.uidColumn)
        ),
        {
            ['@uid'] = uid
        }
    )

    if not row then return nil end

    return tonumber(row.warns or 0) or 0
end

local function addWarnByUid(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return nil end

    local db = getDatabaseConfig()

    MySQL.update.await(
        ('UPDATE %s SET %s = COALESCE(%s, 0) + 1 WHERE %s = @uid LIMIT 1'):format(
            sqlName(db.usersTable),
            sqlName(db.warnsColumn),
            sqlName(db.warnsColumn),
            sqlName(db.uidColumn)
        ),
        {
            ['@uid'] = uid
        }
    )

    return getWarnsByUid(uid)
end

local function removeWarnByUid(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return nil end

    local db = getDatabaseConfig()

    MySQL.update.await(
        ('UPDATE %s SET %s = GREATEST(COALESCE(%s, 0) - 1, 0) WHERE %s = @uid LIMIT 1'):format(
            sqlName(db.usersTable),
            sqlName(db.warnsColumn),
            sqlName(db.warnsColumn),
            sqlName(db.uidColumn)
        ),
        {
            ['@uid'] = uid
        }
    )

    return getWarnsByUid(uid)
end

local function resetWarnsByUid(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return nil end

    local db = getDatabaseConfig()

    local changed = MySQL.update.await(
        ('UPDATE %s SET %s = 0 WHERE %s = @uid LIMIT 1'):format(
            sqlName(db.usersTable),
            sqlName(db.warnsColumn),
            sqlName(db.uidColumn)
        ),
        {
            ['@uid'] = uid
        }
    )

    if not changed or changed <= 0 then return nil end

    return 0
end

local function tempBanByWarns(uid, days, reason)
    uid = tonumber(uid)
    days = tonumber(days) or 4

    if not uid or uid <= 0 then return false end

    local db = getDatabaseConfig()

    local changed = MySQL.update.await(
        ('UPDATE %s SET %s = DATE_ADD(NOW(), INTERVAL @days DAY), %s = @reason WHERE %s = @uid LIMIT 1'):format(
            sqlName(db.usersTable),
            sqlName(db.tempBanColumn),
            sqlName(db.tempBanReasonColumn),
            sqlName(db.uidColumn)
        ),
        {
            ['@days'] = math.floor(days),
            ['@reason'] = reason,
            ['@uid'] = uid
        }
    )

    return changed and changed > 0
end

local function parseCoords(args)
    local raw = trim(table.concat(args or {}, ' '))

    raw = raw:gsub('|', ' ')
    raw = raw:gsub(',', ' ')
    raw = raw:gsub('%s+', ' ')

    local numbers = {}

    for item in raw:gmatch('%S+') do
        numbers[#numbers + 1] = tonumber(item)
    end

    if not numbers[1] or not numbers[2] or not numbers[3] then
        return nil
    end

    return {
        x = numbers[1],
        y = numbers[2],
        z = numbers[3],
        h = numbers[4] or 0.0
    }
end

local function hasCooldown(src, name, duration)
    local uid = getUid(src) or src
    local current = GetGameTimer()
    local last = Cooldowns[name][uid] or 0

    if current - last < duration then
        local left = math.ceil((duration - (current - last)) / 1000)
        notify(src, 'warning', ('Asteapta %s secunde.'):format(left))
        return true
    end

    Cooldowns[name][uid] = current
    return false
end

local function log(tableName, data)
    if Config and Config.Logs and Config.Logs.triggerExternalLogs == false then
        return
    end

    pcall(function()
        TriggerEvent('logs:create', tableName, jsonSafe(data))
    end)

    pcall(function()
        TriggerEvent('driftzone_logs:create', tableName, jsonSafe(data))
    end)
end

local function detectTargetFromArgs(args)
    args = args or {}

    local value = args[1]
    if not value then return nil, nil end

    local target = getPlayerByIdOrUid(value)

    if target then
        return getUid(target) or tonumber(value), getPlayerNameSafe(target)
    end

    local uid = tonumber(value)
    if uid and uid > 0 then
        return uid, nil
    end

    return nil, nil
end

local function logAdminCommand(src, command, args, status, message)
    if Config and Config.Logs and Config.Logs.enabled == false then return end
    if status ~= 'success' and Config and Config.Logs and Config.Logs.logFailed == false then return end

    command = tostring(command or ''):lower()
    args = args or {}

    local adminData = nil
    local okAdmin = pcall(function()
        adminData = getAdminData(src)
    end)

    local adminUid = okAdmin and adminData and adminData.uid or getUid(src)
    local adminName = okAdmin and adminData and adminData.username or getPlayerNameSafe(src)
    local adminLevel = okAdmin and adminData and adminData.level or 0

    local targetUid, targetName = detectTargetFromArgs(args)

    local payload = {
        admin_uid = adminUid,
        admin_name = adminName,
        admin_level = adminLevel,
        command = command,
        args = args,
        status = tostring(status or 'unknown'),
        target_uid = targetUid,
        target_name = targetName,
        message = tostring(message or '')
    }

    pcall(function()
        MySQL.insert.await(
            ('INSERT INTO %s (admin_uid, admin_name, admin_level, command, args, status, target_uid, target_name, message) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'):format(sqlName(getLogTable())),
            {
                adminUid,
                adminName,
                adminLevel,
                command,
                jsonSafe(args),
                payload.status,
                targetUid,
                targetName,
                payload.message
            }
        )
    end)

    log('admin_command_logs', payload)
end

local function sanitizePlate(value)
    return tostring(value or '')
        :upper()
        :gsub('[^A-Z0-9]', '')
        :sub(1, 8)
end

local function randomPlate()
    return ('DZ%06d'):format(math.random(0, 999999)):sub(1, 8)
end

local function plateExists(plate)
    local row = MySQL.single.await(
        'SELECT id FROM ownedvehicles WHERE vehicle_plate = @plate LIMIT 1',
        {
            ['@plate'] = plate
        }
    )

    return row ~= nil
end

local function generatePlate()
    for _ = 1, 50 do
        local plate = randomPlate()

        if not plateExists(plate) then
            return plate
        end
    end

    return ('DZ%s'):format(os.time()):sub(1, 8)
end

local function getOwnedVehicle(vehicleId)
    return MySQL.single.await(
        [[
            SELECT ov.*, vn.vehicle_name
            FROM ownedvehicles ov
            LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model
            WHERE ov.id = @id
            LIMIT 1
        ]],
        {
            ['@id'] = tonumber(vehicleId)
        }
    )
end

local Commands = {}

Commands.aduty = function(src, args)
    local data = requireAdmin(src, Config.Commands.aduty, false)
    if not data then return end

    local newDuty = data.aduty and 0 or 1

    MySQL.update.await(
        'UPDATE users SET aduty = @aduty WHERE uid = @uid',
        {
            ['@aduty'] = newDuty,
            ['@uid'] = data.uid
        }
    )

    invalidateAdminCache(data.uid)

    Player(src).state:set('dz_aduty', newDuty == 1, true)
    Player(src).state:set('dz_admin_level', data.level, true)

    if newDuty == 1 then
        notify(src, 'info', ('Esti ON DUTY ca %s.'):format(data.rank))
        broadcast(('%s este acum ON DUTY ca %s.'):format(getPlayerNameSafe(src), data.rank))
    else
        notify(src, 'info', 'Esti OFF DUTY.')
        broadcast(('%s este acum OFF DUTY.'):format(getPlayerNameSafe(src)))
    end

    log('aduty_logs', {
        admin_name = getPlayerNameSafe(src),
        admin_uid = data.uid,
        admin_level = data.level,
        state = newDuty
    })
end


Commands['goto'] = function(src, args)
    local data = requireAdmin(src, Config.Commands['goto'], true)
    if not data then return end

    local target = getPlayerByIdOrUid(args[1])

    if not target then
        notify(src, 'warning', 'Folosire: /goto id/uid')
        return
    end

    if target == src then
        notify(src, 'warning', 'Nu poti folosi /goto pe tine.')
        return
    end

    local coords = getPlayerCoordsPayload(target)

    if not coords then
        notify(src, 'warning', 'Nu am putut lua coordonatele jucatorului.')
        return
    end

    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(target))
    TriggerClientEvent('driftzone_admin:client:safeTeleport', src, coords)

    notify(src, 'info', ('Te-ai teleportat la %s (%s).'):format(getPlayerNameSafe(target), getUid(target) or target))

    log('goto_logs', {
        admin_name = getPlayerNameSafe(src),
        admin_uid = data.uid,
        admin_level = data.level,
        target_name = getPlayerNameSafe(target),
        target_uid = getUid(target) or target
    })
end

Commands.bring = function(src, args)
    local data = requireAdmin(src, Config.Commands.bring, true)
    if not data then return end

    local target = getPlayerByIdOrUid(args[1])

    if not target then
        notify(src, 'warning', 'Folosire: /bring id/uid')
        return
    end

    if target == src then
        notify(src, 'warning', 'Nu poti folosi /bring pe tine.')
        return
    end

    local coords = getPlayerCoordsPayload(src)

    if not coords then
        notify(src, 'warning', 'Nu am putut lua coordonatele tale.')
        return
    end

    SetPlayerRoutingBucket(target, GetPlayerRoutingBucket(src))
    TriggerClientEvent('driftzone_admin:client:safeTeleport', target, coords)

    notify(src, 'info', ('L-ai adus pe %s (%s) la tine.'):format(getPlayerNameSafe(target), getUid(target) or target))

    log('bring_logs', {
        admin_name = getPlayerNameSafe(src),
        admin_uid = data.uid,
        admin_level = data.level,
        target_name = getPlayerNameSafe(target),
        target_uid = getUid(target) or target
    })
end

Commands.warn = function(src, args)
    local data = requireAdmin(src, Config.Commands.warn, true)
    if not data then return end

    if hasCooldown(src, 'warn', Config.Cooldowns.warn or 4000) then return end

    local target = getPlayerByIdOrUid(args[1])
    local reason = parseReason(args, 2)

    if not target or reason == '' then
        notify(src, 'warning', 'Folosire: /warn id/uid motiv')
        return
    end

    local targetUid = getUid(target)

    if not targetUid then
        notify(src, 'warning', 'Jucatorul nu are UID valid.')
        return
    end

    local newWarns = addWarnByUid(targetUid)

    if not newWarns then
        notify(src, 'error', 'Nu am putut actualiza warn-urile.')
        return
    end

    broadcast(('Jucatorul %s (%s) a primit warn de la admin-ul %s (%s) pe motiv-ul %s!'):format(
        getPlayerNameSafe(target),
        targetUid,
        getPlayerNameSafe(src),
        data.uid,
        reason
    ))

    notify(src, 'info', ('%s are acum %s/%s warns.'):format(getPlayerNameSafe(target), newWarns, Config.Warns.maxWarns))
    notify(target, 'warning', ('Ai primit warn. Motiv: %s. Warns: %s/%s'):format(reason, newWarns, Config.Warns.maxWarns))

    log('warn_logs', {
        player_name = getPlayerNameSafe(target),
        player_uid = targetUid,
        admin_name = getPlayerNameSafe(src),
        admin_uid = data.uid,
        admin_level = data.level,
        reason = reason,
        warns = newWarns
    })

    if newWarns >= (Config.Warns.maxWarns or 3) then
        local days = Config.Warns.tempBanDays or 4
        local banReason = ('Ai acumulat %s warn-uri. Ultimul motiv: %s'):format(newWarns, reason)

        tempBanByWarns(targetUid, days, banReason)

        -- Dupa ban-ul automat pentru warn-uri, resetam warns la 0.
        -- Asa jucatorul nu ramane cu 3 warn-uri dupa ce expira tempban-ul.
        resetWarnsByUid(targetUid)

        broadcast(('Jucatorul %s (%s) a primit TEMPBAN %s zile pentru %s warn-uri. Warn-urile au fost resetate la 0.'):format(
            getPlayerNameSafe(target),
            targetUid,
            days,
            newWarns
        ))

        DropPlayer(target, ('Ai primit tempban %s zile pentru %s warn-uri. Motiv: %s'):format(days, newWarns, reason))
    end
end

Commands.rwarn = function(src, args)
    local data = requireAdmin(src, Config.Commands.rwarn, true)
    if not data then return end

    if hasCooldown(src, 'rwarn', Config.Cooldowns.rwarn or 3000) then return end

    local target = getPlayerByIdOrUid(args[1])

    if not target then
        notify(src, 'warning', 'Folosire: /rwarn id/uid')
        return
    end

    local targetUid = getUid(target)

    if not targetUid then
        notify(src, 'warning', 'Jucatorul nu are UID valid.')
        return
    end

    local newWarns = removeWarnByUid(targetUid)

    if not newWarns then
        notify(src, 'error', 'Nu am putut modifica warn-urile.')
        return
    end

    notify(src, 'info', ('Ai scos un warn de la %s (%s). Warns: %s'):format(getPlayerNameSafe(target), targetUid, newWarns))
    notify(target, 'info', ('Ti-a fost scos un warn. Warns: %s'):format(newWarns))

    log('rwarn_logs', {
        player_name = getPlayerNameSafe(target),
        player_uid = targetUid,
        admin_name = getPlayerNameSafe(src),
        admin_uid = data.uid,
        admin_level = data.level,
        warns = newWarns
    })
end

Commands.warns = function(src, args)
    local target = nil
    local targetUid = nil

    if args[1] then
        local data = requireAdmin(src, Config.Commands.warns, true)
        if not data then return end

        target = getPlayerByIdOrUid(args[1])

        if not target then
            notify(src, 'warning', 'Folosire: /warns id/uid')
            return
        end

        targetUid = getUid(target)
    else
        target = src
        targetUid = getUid(src)
    end

    if not targetUid then
        notify(src, 'warning', 'UID invalid.')
        return
    end

    local warns = getWarnsByUid(targetUid)

    if warns == nil then
        notify(src, 'warning', 'Nu am gasit jucatorul in baza de date.')
        return
    end

    if target == src then
        notify(src, 'info', ('Warns: %s'):format(warns))
    else
        notify(src, 'info', ('Warns %s (%s): %s'):format(getPlayerNameSafe(target), targetUid, warns))
    end
end

Commands.resetwarns = function(src, args)
    local data = requireAdmin(src, Config.Commands.resetwarns, true)
    if not data then return end

    local target = getPlayerByIdOrUid(args[1])

    if not target then
        notify(src, 'warning', 'Folosire: /resetwarns id/uid')
        return
    end

    local targetUid = getUid(target)

    if not targetUid then
        notify(src, 'warning', 'Jucatorul nu are UID valid.')
        return
    end

    local ok = resetWarnsByUid(targetUid)

    if ok == nil then
        notify(src, 'warning', 'Nu am gasit jucatorul in baza de date.')
        return
    end

    notify(src, 'info', ('Ai resetat warn-urile lui %s (%s).'):format(getPlayerNameSafe(target), targetUid))
    notify(target, 'info', 'Warn-urile tale au fost resetate.')

    log('resetwarns_logs', {
        player_name = getPlayerNameSafe(target),
        player_uid = targetUid,
        admin_name = getPlayerNameSafe(src),
        admin_uid = data.uid,
        admin_level = data.level
    })
end


Commands.staff = function(src, args)
    local list = {}

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        local data = getAdminData(target)

        if data and data.level > 0 and data.aduty then
            list[#list + 1] = {
                name = getPlayerNameSafe(target),
                uid = data.uid,
                level = data.level,
                rank = data.rank
            }
        end
    end

    table.sort(list, function(a, b)
        return a.level > b.level
    end)

    if #list == 0 then
        notify(src, 'info', 'Nu este niciun admin ON DUTY.')
        return
    end

    notify(src, 'info', 'Staff ON DUTY afisat in chat.')

    TriggerClientEvent('driftzone_chat:client:addMessage', src, {
        type = 'system',
        time = os.date('%H:%M'),
        text = 'Admini ON DUTY:'
    })

    for _, staff in ipairs(list) do
        TriggerClientEvent('driftzone_chat:client:addMessage', src, {
            type = 'system',
            time = os.date('%H:%M'),
            text = ('%s (%s) - %s'):format(staff.name, staff.uid, staff.rank)
        })
    end
end

Commands.coords = function(src, args)
    local data = requireAdmin(src, Config.Commands.coords, true)
    if not data then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local bucket = GetPlayerRoutingBucket(src)

    local text = ('%.6f, %.6f, %.6f'):format(coords.x, coords.y, coords.z)

    TriggerClientEvent('driftzone_admin:client:coordsPanel', src, {
        coords = text,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        dimension = bucket
    })

    notify(src, 'info', 'Coordonatele au fost deschise in panel.')
end

Commands.gotocoords = function(src, args)
    local data = requireAdmin(src, Config.Commands.gotocoords, true)
    if not data then return end

    local coords = parseCoords(args)

    if not coords then
        notify(src, 'warning', 'Folosire: /gotocoords x y z sau /gotocoords x, y, z')
        return
    end

    TriggerClientEvent('driftzone_admin:client:safeTeleport', src, coords)

    notify(src, 'info', ('Teleport catre %.2f, %.2f, %.2f.'):format(coords.x, coords.y, coords.z))
end

Commands.tptow = function(src, args)
    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local data = getAdminData(src)
    local noCooldown = data and data.level > 0 and data.aduty

    if not noCooldown then
        if hasCooldown(src, 'tptow', Config.Cooldowns.tptow) then return end
    end

    TriggerClientEvent('driftzone_admin:client:tptow', src, Config.Tptow)
end

Commands.nc = function(src, args)
    local data = requireAdmin(src, Config.Commands.nc, true)
    if not data then return end

    NoclipState[src] = not NoclipState[src]

    TriggerClientEvent('driftzone_admin:client:noclip', src, NoclipState[src])

    notify(src, 'info', NoclipState[src] and 'Noclip activat.' or 'Noclip dezactivat.')
end

Commands.veh = function(src, args)
    local data = requireAdmin(src, Config.Commands.veh, true)
    if not data then return end

    if hasCooldown(src, 'veh', Config.Cooldowns.veh) then return end

    local model = trim(args[1] or ''):lower()

    if model == '' then
        notify(src, 'warning', 'Folosire: /veh model')
        return
    end

    TriggerClientEvent('driftzone_admin:client:spawnVehicle', src, model)
end

Commands.fix = function(src, args)
    local data = requireAdmin(src, Config.Commands.fix, true)
    if not data then return end

    TriggerClientEvent('driftzone_admin:client:fixVehicle', src)
end

Commands.kick = function(src, args)
    local data = requireAdmin(src, Config.Commands.kick, true)
    if not data then return end

    if hasCooldown(src, 'kick', Config.Cooldowns.kick) then return end

    local target = getPlayerByIdOrUid(args[1])
    local reason = parseReason(args, 2)

    if not target or reason == '' then
        notify(src, 'warning', 'Folosire: /kick id/uid motiv')
        return
    end

    local targetUid = getUid(target) or target

    broadcast(('Jucatorul %s (%s) a primit kick de la %s (%s). Motiv: %s'):format(
        getPlayerNameSafe(target),
        targetUid,
        getPlayerNameSafe(src),
        data.uid,
        reason
    ))

    log('kick_logs', {
        player_name = getPlayerNameSafe(target),
        player_uid = targetUid,
        admin_name = getPlayerNameSafe(src),
        admin_uid = data.uid,
        admin_level = data.level,
        reason = reason
    })

    DropPlayer(target, 'Kick: ' .. reason)
end

Commands.slap = function(src, args)
    local data = requireAdmin(src, Config.Commands.slap, true)
    if not data then return end

    local target = getPlayerByIdOrUid(args[1])

    if not target then
        notify(src, 'warning', 'Folosire: /slap id/uid')
        return
    end

    TriggerClientEvent('driftzone_admin:client:slap', target)

    notify(src, 'info', ('I-ai dat slap lui %s.'):format(getPlayerNameSafe(target)))
    notify(target, 'warning', ('Ai primit slap de la %s.'):format(getPlayerNameSafe(src)))
end

Commands.ban = function(src, args)
    local data = requireAdmin(src, Config.Commands.ban, true)
    if not data then return end

    local target = getPlayerByIdOrUid(args[1])
    local reason = parseReason(args, 2)

    if not target or reason == '' then
        notify(src, 'warning', 'Folosire: /ban id/uid motiv')
        return
    end

    local targetUid = getUid(target)

    if not targetUid then
        notify(src, 'warning', 'Jucatorul nu are UID valid.')
        return
    end

    MySQL.update.await(
        'UPDATE users SET ban = @ban, banreason = @reason WHERE uid = @uid',
        {
            ['@ban'] = 'yes',
            ['@reason'] = reason,
            ['@uid'] = targetUid
        }
    )

    broadcast(('Jucatorul %s (%s) a primit BAN PERMANENT de la %s (%s). Motiv: %s'):format(
        getPlayerNameSafe(target),
        targetUid,
        getPlayerNameSafe(src),
        data.uid,
        reason
    ))

    DropPlayer(target, 'Ai primit ban permanent. Motiv: ' .. reason)
end

Commands.tempban = function(src, args)
    local data = requireAdmin(src, Config.Commands.tempban, true)
    if not data then return end

    local target = getPlayerByIdOrUid(args[1])
    local days = tonumber(args[2])
    local reason = parseReason(args, 3)

    if not target or not days or days <= 0 or reason == '' then
        notify(src, 'warning', 'Folosire: /tempban id/uid zile motiv')
        return
    end

    local targetUid = getUid(target)

    if not targetUid then
        notify(src, 'warning', 'Jucatorul nu are UID valid.')
        return
    end

    MySQL.update.await(
        'UPDATE users SET tempban = DATE_ADD(NOW(), INTERVAL @days DAY), tempbanreason = @reason WHERE uid = @uid',
        {
            ['@days'] = math.floor(days),
            ['@reason'] = reason,
            ['@uid'] = targetUid
        }
    )

    broadcast(('Jucatorul %s (%s) a primit TEMPBAN %s zile de la %s (%s). Motiv: %s'):format(
        getPlayerNameSafe(target),
        targetUid,
        math.floor(days),
        getPlayerNameSafe(src),
        data.uid,
        reason
    ))

    DropPlayer(target, 'Ai primit tempban. Motiv: ' .. reason)
end

Commands.unban = function(src, args)
    local data = requireAdmin(src, Config.Commands.unban, true)
    if not data then return end

    local targetUid = tonumber(args[1])

    if not targetUid or targetUid <= 0 then
        notify(src, 'warning', 'Folosire: /unban uid')
        return
    end

    MySQL.update.await(
        'UPDATE users SET ban = @ban, banreason = NULL, tempban = NULL, tempbanreason = NULL WHERE uid = @uid',
        {
            ['@ban'] = 'no',
            ['@uid'] = targetUid
        }
    )

    notify(src, 'info', ('UID %s a fost debanat.'):format(targetUid))
end

Commands.givecar = function(src, args)
    local data = requireAdmin(src, Config.Commands.givecar, true)
    if not data then return end

    local targetUid = tonumber(args[1])
    local model = trim(args[2] or ''):lower()
    local plate = sanitizePlate(args[3] or '')

    if not targetUid or targetUid <= 0 or model == '' then
        notify(src, 'warning', 'Folosire: /givecar uid model plate_optional')
        return
    end

    if plate == '' then
        plate = generatePlate()
    end

    if plateExists(plate) then
        notify(src, 'warning', 'Acest numar exista deja.')
        return
    end

    local insertId = MySQL.insert.await(
        'INSERT INTO ownedvehicles (owner_id, vehicle_model, vehicle_plate, vehicle_tunning) VALUES (@owner, @model, @plate, NULL)',
        {
            ['@owner'] = targetUid,
            ['@model'] = model,
            ['@plate'] = plate
        }
    )

    notify(src, 'info', ('Ai dat masina %s [%s] la UID %s.'):format(model, plate, targetUid))

    local target = getPlayerByUid(targetUid)

    if target then
        notify(target, 'info', ('Ai primit masina %s [%s].'):format(model, plate))
    end
end

Commands.takecar = function(src, args)
    local data = requireAdmin(src, Config.Commands.takecar, true)
    if not data then return end

    local targetUid = tonumber(args[1])
    local vehicleId = tonumber(args[2])

    if not targetUid or not vehicleId then
        notify(src, 'warning', 'Folosire: /takecar uid id_masina')
        return
    end

    local vehicle = getOwnedVehicle(vehicleId)

    if not vehicle or tonumber(vehicle.owner_id) ~= targetUid then
        notify(src, 'warning', 'Masina nu exista sau nu apartine acelui UID.')
        return
    end

    MySQL.update.await(
        'DELETE FROM ownedvehicles WHERE id = @id AND owner_id = @owner',
        {
            ['@id'] = vehicleId,
            ['@owner'] = targetUid
        }
    )

    notify(src, 'info', ('Ai sters masina ID %s de la UID %s.'):format(vehicleId, targetUid))
end

Commands.transfercar = function(src, args)
    local data = requireAdmin(src, Config.Commands.transfercar, true)
    if not data then return end

    local newOwner = tonumber(args[1])
    local vehicleId = tonumber(args[2])

    if not newOwner or not vehicleId then
        notify(src, 'warning', 'Folosire: /transfercar uid_nou id_masina')
        return
    end

    local vehicle = getOwnedVehicle(vehicleId)

    if not vehicle then
        notify(src, 'warning', 'Masina nu exista.')
        return
    end

    MySQL.update.await(
        'UPDATE ownedvehicles SET owner_id = @owner WHERE id = @id',
        {
            ['@owner'] = newOwner,
            ['@id'] = vehicleId
        }
    )

    notify(src, 'info', ('Ai transferat masina ID %s catre UID %s.'):format(vehicleId, newOwner))
end

Commands.changeplate = function(src, args)
    local data = requireAdmin(src, Config.Commands.changeplate, true)
    if not data then return end

    local vehicleId = tonumber(args[1])
    local plate = sanitizePlate(args[2] or '')

    if not vehicleId or plate == '' then
        notify(src, 'warning', 'Folosire: /changeplate id_masina plate')
        return
    end

    if plateExists(plate) then
        notify(src, 'warning', 'Acest numar exista deja.')
        return
    end

    local vehicle = getOwnedVehicle(vehicleId)

    if not vehicle then
        notify(src, 'warning', 'Masina nu exista.')
        return
    end

    MySQL.update.await(
        'UPDATE ownedvehicles SET vehicle_plate = @plate WHERE id = @id',
        {
            ['@plate'] = plate,
            ['@id'] = vehicleId
        }
    )

    notify(src, 'info', ('Ai schimbat numarul masinii ID %s in %s.'):format(vehicleId, plate))
end



RegisterNetEvent('driftzone_admin:server:cleanupClientReport', function(serial, deleted)
    serial = tonumber(serial or 0) or 0
    deleted = tonumber(deleted or 0) or 0

    if serial <= 0 or deleted <= 0 then return end
    if not CleanupState or CleanupState.serial ~= serial then return end

    CleanupReports[serial] = (CleanupReports[serial] or 0) + deleted
end)

Commands.cleanup = function(src, args)
    local data = requireAdmin(src, Config.Commands.cleanup or 3, true)
    if not data then return end

    local seconds, labelOrError = parseCleanupTime(args)
    if not seconds then
        notify(src, 'warning', labelOrError)
        return
    end

    if seconds < 1 then seconds = 1 end
    if seconds > 3600 then seconds = 3600 end

    CleanupSerial = CleanupSerial + 1
    local serial = CleanupSerial
    CleanupState = {
        serial = serial,
        adminUid = data.uid,
        adminName = getPlayerNameSafe(src),
        endsAt = os.time() + seconds
    }

    notifyAll('warning', ('Admin-ul %s (%s) a pornit cleanup. Masinile fara sofer se sterg in %s.'):format(getPlayerNameSafe(src), data.uid, labelOrError), 8000)

    SetTimeout(seconds * 1000, function()
        if not CleanupState or CleanupState.serial ~= serial then
            return
        end

        CleanupReports[serial] = 0
        CleanupState.running = true

        -- Stergere robusta: server + toti clientii. Unele vehicule sunt controlate de client si nu dispar doar cu DeleteEntity server-side.
        TriggerClientEvent('driftzone_admin:client:cleanupVehicles', -1, serial)

        SetTimeout(2500, function()
            if not CleanupState or CleanupState.serial ~= serial then
                CleanupReports[serial] = nil
                return
            end

            local serverDeleted = countAndDeleteUnoccupiedVehicles()
            local clientDeleted = tonumber(CleanupReports[serial] or 0) or 0
            local totalDeleted = serverDeleted + clientDeleted

            notifyAll('info', ('Cleanup finalizat. Au fost sterse %s masini fara sofer.'):format(totalDeleted), 8000)

            CleanupReports[serial] = nil
            CleanupState = nil
        end)
    end)
end

Commands.cancelcleanup = function(src, args)
    local data = requireAdmin(src, Config.Commands.cancelcleanup or 3, true)
    if not data then return end

    if not CleanupState then
        notify(src, 'warning', 'Nu exista cleanup activ.')
        return
    end

    CleanupSerial = CleanupSerial + 1
    CleanupState = nil

    notifyAll('info', ('Admin-ul %s (%s) a anulat cleanup-ul activ.'):format(getPlayerNameSafe(src), data.uid), 7000)
end

Commands.addcar = function(src, args)
    local data = requireAdmin(src, Config.Commands.addcar or 6, true)
    if not data then return end

    TriggerClientEvent('driftzone_admin:client:addCarPanel', src, {
        categories = {
            { value = 1, label = '1 - STARTER' },
            { value = 2, label = '2 - STREET CLASS' },
            { value = 3, label = '3 - JDM LEGENDS' },
            { value = 4, label = '4 - PRO DRIFT' },
            { value = 5, label = '5 - ELITE CLASS' },
            { value = 6, label = '6 - LIMITED EDITION' }
        }
    })
end

Commands.removecar = function(src, args)
    local data = requireAdmin(src, Config.Commands.removecar or 6, true)
    if not data then return end

    local id = tonumber(args[1])
    if not id or id <= 0 then
        notify(src, 'warning', 'Folosire: /removecar id_database')
        return
    end

    local row = MySQL.single.await('SELECT * FROM `vehiclenames` WHERE `id` = ? LIMIT 1', { id })
    if not row then
        notify(src, 'warning', 'Nu exista masina cu acest ID in vehiclenames.')
        return
    end

    local affected = MySQL.update.await('DELETE FROM `vehiclenames` WHERE `id` = ? LIMIT 1', { id }) or 0
    resetVehicleNameColumns()

    if affected > 0 then
        notify(src, 'info', ('Masina ID %s a fost stearsa din vehiclenames.'):format(id))
    else
        notify(src, 'warning', 'Nu s-a putut sterge masina.')
    end
end

Commands.addoutfit = function(src, args)
    local data = requireAdmin(src, Config.Commands.addoutfit, true)
    if not data then return end

    if #args < 1 then
        notify(src, 'warning', 'Folosire: /addoutfit nume link_optional')
        return
    end

    local imageIndex = nil

    for i, value in ipairs(args) do
        local lower = tostring(value):lower()

        if lower:find('http://', 1, true) or lower:find('https://', 1, true) then
            imageIndex = i
            break
        end
    end

    local name = ''
    local image = ''

    if imageIndex then
        local parts = {}

        for i = 1, imageIndex - 1 do
            parts[#parts + 1] = args[i]
        end

        name = trim(table.concat(parts, ' '))
        image = trim(table.concat(args, ' ', imageIndex))
    else
        name = trim(table.concat(args, ' '))
    end

    if name == '' then
        notify(src, 'warning', 'Folosire: /addoutfit nume link_optional')
        return
    end

    TriggerEvent('driftzone_outfits:server:adminAddOutfit', src, name, image)
    TriggerEvent('outfits:adminAddOutfit', src, name, image)

    notify(src, 'info', 'Comanda /addoutfit a fost trimisa catre outfits.')
end

local function runAdminCommand(src, command, args)
    command = tostring(command or ''):lower()
    args = args or {}

    if not AdminCommands[command] then
        return false
    end

    local fn = Commands[command]

    if not fn then
        notify(src, 'warning', ('Comanda /%s nu este implementata.'):format(command))
        logAdminCommand(src, command, args, 'not_implemented', 'Comanda nu este implementata.')
        return true
    end

    local startedAt = GetGameTimer()
    local ok, err = pcall(function()
        fn(src, args)
    end)

    local elapsed = GetGameTimer() - startedAt

    if not ok then
        print(('[DRIFTZONE_ADMIN] /%s error:'):format(command))
        print(err)

        notify(src, 'error', ('Eroare la /%s. Verifica consola serverului.'):format(command))
        logAdminCommand(src, command, args, 'error', tostring(err))
        return true
    end

    logAdminCommand(src, command, args, 'success', ('executed in %sms'):format(elapsed))
    return true
end


RegisterNetEvent('driftzone_admin:server:addCarSubmit', function(payload)
    local src = source
    local data = requireAdmin(src, Config.Commands.addcar or 6, true)
    if not data then
        TriggerClientEvent('driftzone_admin:client:addCarResult', src, false, 'Nu ai acces.')
        logAdminCommand(src, 'addcar', { 'nui' }, 'failed', 'no access')
        return
    end

    payload = payload or {}
    local cols, params, err, normalized = getAddCarInsert(payload)
    if err then
        TriggerClientEvent('driftzone_admin:client:addCarResult', src, false, err)
        logAdminCommand(src, 'addcar', payload, 'failed', err)
        return
    end

    local existing = MySQL.single.await('SELECT `id` FROM `vehiclenames` WHERE LOWER(`vehicle_model`) = ? LIMIT 1', { normalized.model })
    if existing then
        local msg = 'Exista deja o masina cu acest model ID.'
        TriggerClientEvent('driftzone_admin:client:addCarResult', src, false, msg)
        logAdminCommand(src, 'addcar', normalized, 'failed', msg)
        return
    end

    local placeholders = {}
    for i = 1, #cols do placeholders[#placeholders + 1] = '?' end

    local query = ('INSERT INTO `vehiclenames` (%s) VALUES (%s)'):format(
        table.concat((function()
            local out = {}
            for _, c in ipairs(cols) do out[#out + 1] = sqlName(c) end
            return out
        end)(), ', '),
        table.concat(placeholders, ', ')
    )

    local ok, insertIdOrErr = pcall(function()
        return MySQL.insert.await(query, params)
    end)

    if not ok then
        local msg = tostring(insertIdOrErr)
        TriggerClientEvent('driftzone_admin:client:addCarResult', src, false, 'Eroare DB la adaugare masina.')
        logAdminCommand(src, 'addcar', normalized, 'error', msg)
        return
    end

    TriggerClientEvent('driftzone_admin:client:addCarResult', src, true, ('Masina a fost adaugata cu ID %s.'):format(insertIdOrErr or '?'))
    logAdminCommand(src, 'addcar', normalized, 'success', ('insert id %s'):format(insertIdOrErr or '?'))
end)

RegisterNetEvent('driftzone_admin:server:run', function(command, args)
    local src = source
    runAdminCommand(src, command, args or {})
end)

RegisterNetEvent('driftzone_admin:server:runRaw', function(raw)
    local src = source
    local text = trim(raw or '')

    if text:sub(1, 1) == '/' then
        text = text:sub(2)
    end

    local parts = {}

    for part in text:gmatch('%S+') do
        parts[#parts + 1] = part
    end

    local command = tostring(parts[1] or ''):lower()
    table.remove(parts, 1)

    runAdminCommand(src, command, parts)
end)

for commandName, _ in pairs(AdminCommands) do
    RegisterCommand(commandName, function(src, args)
        if src == 0 then return end
        runAdminCommand(src, commandName, args or {})
    end, false)
end

RegisterNetEvent('driftzone_admin:server:tptowResult', function(success, coords)
    local src = source
    local uid = getUid(src)

    if not uid then return end

    if success then
        notify(src, 'info', 'Te-ai teleportat cu succes la waypoint.')
    else
        notify(src, 'warning', 'Teleportarea la waypoint a esuat.')
    end

    log('tptow_logs', {
        player_name = getPlayerNameSafe(src),
        player_uid = uid,
        success = success == true,
        x = coords and coords.x or 0,
        y = coords and coords.y or 0,
        z = coords and coords.z or 0
    })
end)

RegisterNetEvent('driftzone_admin:server:vehSpawnResult', function(success, model, plate, netId)
    local src = source

    model = tostring(model or 'unknown')
    plate = tostring(plate or 'ADMIN'):upper():gsub('%s+', ''):sub(1, 8)
    netId = tonumber(netId or 0)

    if not success then
        notify(src, 'warning', ('Model invalid sau nu s-a putut incarca: %s'):format(model))
        return
    end

    notify(src, 'info', ('Ai spawnat vehiculul %s.'):format(model))

    if netId and netId > 0 then
        CreateThread(function()
            Wait(300)

            local entity = NetworkGetEntityFromNetworkId(netId)

            if entity and entity ~= 0 and DoesEntityExist(entity) then
                local adminData = getAdminData(src)
                local uid = getUid(src) or 0

                pcall(function()
                    exports.driftzone_vs:RegisterVehicle(entity, {
                        source = 'admin',
                        sqlVehicleId = 0,
                        ownerId = uid,
                        ownerName = GetPlayerName(src) or 'Admin',
                        spawnedBy = adminData and adminData.username or GetPlayerName(src) or 'Admin',
                        model = model,
                        plate = plate
                    })
                end)

                pcall(function()
                    TriggerEvent('vs:registerVehicle', entity, {
                        source = 'admin',
                        sqlVehicleId = 0,
                        ownerId = uid,
                        ownerName = GetPlayerName(src) or 'Admin',
                        spawnedBy = adminData and adminData.username or GetPlayerName(src) or 'Admin',
                        model = model,
                        plate = plate
                    })
                end)
            else
                notify(src, 'warning', 'Masina a fost spawnata, dar nu a putut fi inregistrata in VS.')
            end
        end)
    end
end)

exports('RunCommand', function(src, command, args)
    return runAdminCommand(src, command, args or {})
end)

exports('IsAdminCommand', function(command)
    return AdminCommands[tostring(command or ''):lower()] == true
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getUid(src)

    NoclipState[src] = nil

    if uid then
        AdminDataCache[uid] = nil
        PlayerLookupCache[uid] = nil
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(800)

        pcall(function()
            MySQL.update.await('ALTER TABLE users ADD COLUMN IF NOT EXISTS warns INT NOT NULL DEFAULT 0')
        end)

        pcall(function()
            MySQL.update.await([[
                CREATE TABLE IF NOT EXISTS `admin_command_logs` (
                    `id` INT NOT NULL AUTO_INCREMENT,
                    `admin_uid` INT NULL DEFAULT NULL,
                    `admin_name` VARCHAR(64) NOT NULL DEFAULT '',
                    `admin_level` INT NOT NULL DEFAULT 0,
                    `command` VARCHAR(64) NOT NULL DEFAULT '',
                    `args` TEXT NULL,
                    `status` VARCHAR(32) NOT NULL DEFAULT 'unknown',
                    `target_uid` INT NULL DEFAULT NULL,
                    `target_name` VARCHAR(64) NULL DEFAULT NULL,
                    `message` TEXT NULL,
                    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (`id`),
                    KEY `idx_admin_uid` (`admin_uid`),
                    KEY `idx_command` (`command`),
                    KEY `idx_status` (`status`),
                    KEY `idx_created_at` (`created_at`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])
        end)
    end)


        pcall(function()
            MySQL.update.await('ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `apear` TINYINT NOT NULL DEFAULT 1')
        end)

        pcall(function()
            MySQL.update.await('ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `vip` TINYINT NOT NULL DEFAULT 0')
        end)

        pcall(function()
            MySQL.update.await('ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `selling` TINYINT NOT NULL DEFAULT 1')
        end)

        pcall(function()
            MySQL.update.await('ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `type` VARCHAR(20) NOT NULL DEFAULT "drift"')
        end)

        resetVehicleNameColumns()

    print('[DRIFTZONE_ADMIN] Server-side loaded.')
end)