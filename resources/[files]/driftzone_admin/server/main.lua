local AdminCommands = {}
local Cooldowns = {}
local NoclipState = {}
local SpectateState = {}
local AdminDataCache = {}
local PlayerLookupCache = {}
local TableColumnsCache = {}
local CleanupState = nil
local CleanupSerial = 0
local CleanupReports = {}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function jsonSafe(data)
    local ok, result = pcall(function() return json.encode(data or {}) end)
    if ok then return result end
    return '{}'
end

local function getOptConfig(key, fallback)
    if Config and Config.Optimization and Config.Optimization[key] ~= nil then return Config.Optimization[key] end
    return fallback
end

local function notify(src, typ, message, duration)
    src = tonumber(src or 0) or 0
    if src <= 0 then return end
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 5000, tostring(message or ''))
    TriggerClientEvent(Config.ChatEvent or 'driftzone_chat:client:addMessage', src, {
        type = typ == 'warning' and 'error' or 'system',
        time = os.date('%H:%M'),
        text = tostring(message or '')
    })
end

local function notifyAll(typ, message, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', -1, typ or 'info', duration or 5000, tostring(message or ''))
    TriggerClientEvent(Config.ChatEvent or 'driftzone_chat:client:addMessage', -1, {
        type = typ == 'warning' and 'error' or 'system',
        time = os.date('%H:%M'),
        text = tostring(message or '')
    })
end

local function getDb()
    return Config.Database or {}
end

local function getUsersTable()
    return (getDb().usersTable or 'users')
end

local function getUidColumn()
    return (getDb().uidColumn or 'uid')
end

local function getUsernameColumn()
    return (getDb().usernameColumn or 'username')
end

local function isAdutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end
    local state = Player(src).state
    local keys = { 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }
    for i = 1, #keys do
        local uid = tonumber(state and state[keys[i]])
        if uid and uid > 0 then return uid end
    end
    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end
    }
    for _, fn in ipairs(attempts) do
        local ok, value = pcall(fn)
        local uid = tonumber(value)
        if ok and uid and uid > 0 then return uid end
    end
    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and (state.dz_logged == true or state.logged == true or state.isLoggedIn == true) then return true end
    local attempts = {
        function() return exports.driftzone_auth:IsLoggedIn(src) end,
        function() return exports.driftzone_auth:isLoggedIn(src) end
    }
    for _, fn in ipairs(attempts) do
        local ok, result = pcall(fn)
        if ok and result == true then return true end
    end
    return getUid(src) ~= nil
end

local function getTableColumns(tableName)
    tableName = tostring(tableName or '')
    local cached = TableColumnsCache[tableName]
    if cached and cached.expires > GetGameTimer() then return cached.cols end
    local cols = {}
    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM %s'):format(sqlName(tableName)), {}) or {}
    end)
    if ok and rows then
        for _, row in ipairs(rows) do
            if row.Field then cols[tostring(row.Field)] = true end
        end
    end
    TableColumnsCache[tableName] = { expires = GetGameTimer() + getOptConfig('tableColumnsCacheMs', 60000), cols = cols }
    return cols
end

local function hasColumn(tableName, column)
    local cols = getTableColumns(tableName)
    return cols and cols[tostring(column or '')] == true
end

local function dbUpdate(query, params)
    local ok, result = pcall(function() return MySQL.update.await(query, params or {}) end)
    return ok, result
end

local function dbInsert(query, params)
    local ok, result = pcall(function() return MySQL.insert.await(query, params or {}) end)
    return ok, result
end

local function dbQuery(query, params)
    local ok, result = pcall(function() return MySQL.query.await(query, params or {}) end)
    if ok then return result or {} end
    return {}
end

local function dbSingle(query, params)
    local ok, result = pcall(function() return MySQL.single.await(query, params or {}) end)
    if ok then return result end
    return nil
end

local function getAdminData(src)
    local uid = getUid(src)
    if not uid then return nil end
    local cached = AdminDataCache[uid]
    if cached and cached.expires > GetGameTimer() then return cached.data end

    local db = getDb()
    local row = dbSingle(('SELECT * FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(getUidColumn())), { uid })
    if not row then return nil end

    local level = tonumber(row[db.adminColumn or 'admin_level'] or row[db.adminColumnFallback or 'admin'] or row.admin_level or row.admin or 0) or 0
    local duty = isAdutyValue(row[db.adutyColumn or 'aduty'])
    local data = {
        src = src,
        uid = uid,
        username = tostring(row[getUsernameColumn()] or row.username or getPlayerNameSafe(src)),
        level = level,
        aduty = duty,
        rank = (Config.Ranks and Config.Ranks[level]) or 'Staff'
    }
    AdminDataCache[uid] = { expires = GetGameTimer() + getOptConfig('adminDataCacheMs', 2500), data = data }
    return data
end

local function invalidateAdminCache(uid)
    uid = tonumber(uid)
    if uid then AdminDataCache[uid] = nil end
end

local function getPlayerByUid(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return nil end
    local cached = PlayerLookupCache[uid]
    if cached and cached.expires > GetGameTimer() and cached.src and GetPlayerName(cached.src) then return cached.src end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getUid(src) == uid then
            PlayerLookupCache[uid] = { src = src, expires = GetGameTimer() + getOptConfig('playerLookupCacheMs', 2000) }
            return src
        end
    end
    return nil
end

local function getUserByUid(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return nil end
    return dbSingle(('SELECT * FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(getUidColumn())), { uid })
end

local function userNameByUid(uid)
    local row = getUserByUid(uid)
    if row then return tostring(row[getUsernameColumn()] or row.username or ('UID ' .. tostring(uid))) end
    return 'UID ' .. tostring(uid or 0)
end

local function isCommandKnown(command)
    command = tostring(command or ''):lower()
    return AdminCommands[command] == true or (Config.Commands and Config.Commands[command] ~= nil)
end

local function commandMin(command)
    command = tostring(command or ''):lower()
    return tonumber(Config.Commands and Config.Commands[command] or 0) or 0
end

local function commandNeedsDuty(command)
    command = tostring(command or ''):lower()
    if Config.NoDutyCommands and Config.NoDutyCommands[command] then return false end
    return true
end

local function requireAdmin(src, commandOrLevel, needDuty)
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return nil end
    local data = getAdminData(src)
    if not data or data.level <= 0 then notify(src, 'warning', 'Nu esti staff.') return nil end
    local minLevel = type(commandOrLevel) == 'string' and commandMin(commandOrLevel) or tonumber(commandOrLevel or 0) or 0
    if data.level < minLevel then notify(src, 'warning', 'Nu ai gradul necesar pentru aceasta comanda.') return nil end
    if needDuty == nil and type(commandOrLevel) == 'string' then needDuty = commandNeedsDuty(commandOrLevel) end
    if needDuty ~= false and not data.aduty then notify(src, 'warning', 'Trebuie sa fii ON DUTY.') return nil end
    return data
end

local function onCooldown(src, command)
    local cd = tonumber(Config.Cooldowns and Config.Cooldowns[command] or 0) or 0
    if cd <= 0 then return false end
    Cooldowns[command] = Cooldowns[command] or {}
    local now = GetGameTimer()
    local last = Cooldowns[command][src] or 0
    if now - last < cd then
        notify(src, 'warning', ('Asteapta %.1fs pentru /%s.'):format((cd - (now - last)) / 1000, command))
        return true
    end
    Cooldowns[command][src] = now
    return false
end

local function detectTargetFromArgs(args)
    local uid = tonumber(args and args[1])
    if uid and uid > 0 then return uid, userNameByUid(uid) end
    return nil, nil
end

local function logAdminCommand(src, command, args, status, message)
    if Config.Logs and Config.Logs.enabled == false then return end
    if status ~= 'success' and Config.Logs and Config.Logs.logFailed == false then return end
    local admin = getAdminData(src) or {}
    local targetUid, targetName = detectTargetFromArgs(args or {})
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (admin_uid, admin_name, admin_level, command, args, status, target_uid, target_name, message) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'):format(sqlName((Config.Logs and Config.Logs.table) or 'admin_command_logs')), {
            admin.uid or getUid(src), admin.username or getPlayerNameSafe(src), admin.level or 0, tostring(command or ''), jsonSafe(args or {}), tostring(status or 'unknown'), targetUid, targetName, tostring(message or '')
        })
    end)
end

local function logVehicle(src, action, status, details)
    if Config.Logs and Config.Logs.enabled == false then return end
    local admin = getAdminData(src) or {}
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (admin_uid, admin_name, admin_level, action, status, details) VALUES (?, ?, ?, ?, ?, ?)'):format(sqlName((Config.Logs and Config.Logs.vehicleTable) or 'admin_vehicle_logs')), {
            admin.uid or getUid(src), admin.username or getPlayerNameSafe(src), admin.level or 0, tostring(action or ''), tostring(status or 'unknown'), jsonSafe(details or {})
        })
    end)
end

for name, _ in pairs(Config.Commands or {}) do AdminCommands[name] = true end

local function splitRaw(raw)
    local parts = {}
    raw = trim(raw or '')
    if raw:sub(1, 1) == '/' then raw = raw:sub(2) end
    for part in raw:gmatch('%S+') do parts[#parts + 1] = part end
    local command = tostring(parts[1] or ''):lower()
    table.remove(parts, 1)
    return command, parts
end

local function getAllowedCommands(level)
    level = tonumber(level or 0) or 0
    local list = {}
    for command, minLevel in pairs(Config.Commands or {}) do
        minLevel = tonumber(minLevel or 0) or 0
        if level >= minLevel then
            local meta = Config.CommandMeta and Config.CommandMeta[command] or {}
            list[#list + 1] = {
                name = command,
                level = minLevel,
                category = meta.category or 'system',
                label = meta.label or command,
                syntax = meta.syntax or ('/' .. command),
                description = meta.description or '',
                needDuty = commandNeedsDuty(command)
            }
        end
    end
    table.sort(list, function(a, b)
        if a.category == b.category then return a.level == b.level and a.name < b.name or a.level < b.level end
        return a.category < b.category
    end)
    return list
end

local function openHelp(src, panelType)
    local admin = requireAdmin(src, panelType == 'adminPanel' and 'ap' or 'ah')
    if not admin then return end
    TriggerClientEvent(panelType == 'adminPanel' and 'driftzone_admin:client:openAdminPanel' or 'driftzone_admin:client:openAdminHelp', src, {
        mainColor = Config.MainColor or '#2aaeff',
        admin = admin,
        commands = getAllowedCommands(admin.level),
        categories = Config.Categories or {}
    })
end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, h = GetEntityHeading(ped) + 0.0 }
end

local function teleportPlayer(src, coords)
    if not src or not coords then return end
    TriggerClientEvent('driftzone_admin:client:safeTeleport', src, coords)
end

local function parseAmount(v)
    local n = tonumber(v)
    if not n then return nil end
    return math.floor(n)
end

local function updateIfColumn(tableName, column, sql, params)
    if hasColumn(tableName, column) then return dbUpdate(sql, params) end
    return false, 'missing column ' .. tostring(column)
end

local function sanitizePlate(value)
    return tostring(value or ''):upper():gsub('[^A-Z0-9]', ''):sub(1, 8)
end

local function randomPlate()
    return ('DZ%06d'):format(math.random(0, 999999)):sub(1, 8)
end

local function plateExists(plate)
    local row = dbSingle('SELECT id FROM ownedvehicles WHERE vehicle_plate = ? LIMIT 1', { plate })
    return row ~= nil
end

local function generatePlate()
    for _ = 1, 40 do
        local p = randomPlate()
        if not plateExists(p) then return p end
    end
    return ('DZ%s'):format(os.time()):sub(1, 8)
end

local function loadVehiclesConfig()
    return dbQuery('SELECT * FROM vehiclenames ORDER BY id DESC LIMIT 500', {})
end

local function getOwnedVehicle(vehicleId)
    return dbSingle([[SELECT ov.*, vn.vehicle_name, vn.image FROM ownedvehicles ov LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model WHERE ov.id = ? LIMIT 1]], { tonumber(vehicleId or 0) or 0 })
end

local function loadOwnedVehicles(uid)
    return dbQuery([[SELECT ov.*, vn.vehicle_name, vn.image FROM ownedvehicles ov LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model WHERE ov.owner_id = ? ORDER BY ov.id DESC LIMIT 250]], { tonumber(uid or 0) or 0 })
end

local function refreshOwnedVehs(src, uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return end
    TriggerClientEvent('driftzone_admin:client:ownedVehsPanel', src, { uid = uid, name = userNameByUid(uid), vehicles = loadOwnedVehicles(uid) })
end


local function getVehicleConfigResource()
    local extra = Config.AdminExtra or {}
    local res = tostring(extra.lockVehicleResource or extra.vehicleConfigResource or 'driftzone_vehicleconfig')
    if res == '' then res = 'driftzone_vehicleconfig' end
    return res
end

local function setOwnedVehicleDbLock(sqlId, locked)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return false, 'sql_id invalid' end

    if not hasColumn('ownedvehicles', 'locked') then
        return true, 'coloana locked nu exista, am aplicat doar state-ul live'
    end

    local ok, result = dbUpdate('UPDATE ownedvehicles SET locked = ? WHERE id = ? LIMIT 1', { locked == true and 1 or 0, sqlId })
    if not ok then return false, tostring(result or 'eroare DB') end
    return true, 'db'
end

local function setVehicleConfigLockBySqlId(sqlId, locked)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return false, 'sql_id invalid' end

    local res = getVehicleConfigResource()
    local state = GetResourceState(res)
    local lockedBool = locked == true

    if state == 'started' then
        local ok, result = pcall(function()
            return exports[res]:SetVehicleLockBySqlId(sqlId, lockedBool)
        end)

        if ok and result ~= false then
            return true, 'export'
        end

        local okEvent = pcall(function()
            TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', sqlId, lockedBool)
        end)

        if okEvent then
            return true, 'event'
        end

        return false, 'export/event vehicleconfig failed'
    end

    local okEvent = pcall(function()
        TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', sqlId, lockedBool)
    end)

    if okEvent then
        return false, ('resource %s nu este started (%s)'):format(res, tostring(state))
    end

    return false, ('resource %s indisponibil (%s)'):format(res, tostring(state))
end

local function setAdminVehicleLock(src, sqlId, locked)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then
        notify(src, 'warning', locked and 'Folosire: /lockveh sql_id' or 'Folosire: /unlockveh sql_id')
        return false
    end

    local vehicle = getOwnedVehicle(sqlId)
    if not vehicle then
        notify(src, 'warning', ('Nu exista masina cu SQL ID %s in ownedvehicles.'):format(sqlId))
        return false
    end

    local dbOk, dbMsg = setOwnedVehicleDbLock(sqlId, locked)
    local vcOk, vcMsg = setVehicleConfigLockBySqlId(sqlId, locked)

    logVehicle(src, locked and 'lockveh' or 'unlockveh', (dbOk and vcOk) and 'success' or 'partial', {
        sqlId = sqlId,
        locked = locked == true,
        db = dbMsg,
        vehicleconfig = vcMsg,
        model = vehicle.vehicle_model,
        plate = vehicle.vehicle_plate,
        owner = vehicle.owner_id
    })

    if vcOk then
        notify(src, locked and 'warning' or 'success', ('Masina SQL ID %s a fost %s.'):format(sqlId, locked and 'incuiata' or 'descuiata'))
        return true
    end

    if dbOk then
        notify(src, 'warning', ('DB actualizat, dar vehicleconfig nu a aplicat live: %s. Verifica ensure driftzone_vehicleconfig inainte de driftzone_admin.'):format(tostring(vcMsg)))
        return true
    end

    notify(src, 'warning', ('Nu s-a putut modifica lock-ul: %s / %s'):format(tostring(dbMsg), tostring(vcMsg)))
    return false
end

local function safeVehiclePayload(payload)
    payload = type(payload) == 'table' and payload or {}
    local model = trim(tostring(payload.model or payload.vehicle_model or ''):lower():gsub('%s+', ''))
    local name = trim(payload.name or payload.vehicle_name or '')
    local price = math.max(0, math.floor(tonumber(payload.price or 0) or 0))
    local dzc = math.max(0, math.floor(tonumber(payload.dzcoins_price or 0) or 0))
    local category = math.max(1, math.floor(tonumber(payload.category or 1) or 1))
    local section = trim(payload.showroom_section or 'DRIFT'):upper()
    local sub = trim(payload.showroom_subcategory or 'starter'):lower():gsub('%s+', '_')
    local vtype = trim(payload.type or 'drift'):lower()
    local image = trim(payload.image or '')
    local function b(v, d) if v == nil or tostring(v) == '' then return d end return tonumber(v) == 1 and 1 or 0 end
    if model == '' or name == '' then return nil, 'Model si nume obligatorii.' end
    if not ({DRIFT=true, HS=true, PREMIUM=true, CUSTOM=true})[section] then section = 'DRIFT' end
    if vtype ~= 'drift' and vtype ~= 'hs' and vtype ~= 'premium' and vtype ~= 'custom' then vtype = section:lower() end
    return { model=model, name=name, price=price, dzcoins_price=dzc, category=category, showroom_section=section, showroom_subcategory=sub, vip=b(payload.vip,0), apear=b(payload.apear,1), selling=b(payload.selling,1), tradeble=b(payload.tradeble or payload.tradable,1), tunable=b(payload.tunable,1), type=vtype, image=image }
end

local Commands = {}

Commands.ah = function(src) openHelp(src, 'adminHelp') end
Commands.ap = function(src) openHelp(src, 'adminPanel') end

Commands.aduty = function(src)
    local admin = requireAdmin(src, 'aduty', false)
    if not admin then return end
    local new = admin.aduty and 0 or 1
    local db = getDb()
    dbUpdate(('UPDATE %s SET %s = ? WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(db.adutyColumn or 'aduty'), sqlName(getUidColumn())), { new, admin.uid })
    invalidateAdminCache(admin.uid)
    Player(src).state:set('dz_aduty', new == 1, true)
    Player(src).state:set('aduty', new == 1, true)
    Player(src).state:set('dz_admin_level', admin.level, true)
    notify(src, new == 1 and 'info' or 'warning', new == 1 and 'Aduty pornit.' or 'Aduty oprit.')
end

Commands.staff = function(src)
    local admin = requireAdmin(src, 'staff', false)
    if not admin then return end
    local rows = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local a = getAdminData(s)
        if a and a.level > 0 then rows[#rows + 1] = ('%s [%s] - %s - %s'):format(a.username, a.uid, a.rank, a.aduty and 'ADUTY' or 'OFF') end
    end
    notify(src, 'info', #rows > 0 and table.concat(rows, '\n') or 'Nu este staff online.', 9000)
end

Commands['goto'] = function(src, args)
    local admin = requireAdmin(src, 'goto') if not admin then return end
    local target = getPlayerByUid(args[1])
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    local c = coordsOf(target)
    if c then teleportPlayer(src, c) notify(src, 'info', 'Te-ai teleportat la jucator.') end
end

Commands.bring = function(src, args)
    local admin = requireAdmin(src, 'bring') if not admin then return end
    local target = getPlayerByUid(args[1])
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    local c = coordsOf(src)
    if c then teleportPlayer(target, c) notify(src, 'info', 'Jucator adus la tine.') end
end

Commands.mark = function(src)
    local admin = requireAdmin(src, 'mark') if not admin then return end
    TriggerClientEvent('driftzone_admin:client:mark', src)
end

Commands.gotomark = function(src)
    local admin = requireAdmin(src, 'gotomark') if not admin then return end
    TriggerClientEvent('driftzone_admin:client:gotoMark', src)
end

Commands.kick = function(src, args)
    local admin = requireAdmin(src, 'kick') if not admin then return end
    local target = getPlayerByUid(args[1])
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    local reason = trim(table.concat(args, ' ', 2)); if reason == '' then reason = 'Kick by admin' end
    DropPlayer(target, reason)
    notify(src, 'info', 'Jucatorul a primit kick.')
end

Commands.slap = function(src, args)
    local admin = requireAdmin(src, 'slap') if not admin then return end
    local target = getPlayerByUid(args[1])
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    TriggerClientEvent('driftzone_admin:client:slap', target)
    notify(src, 'info', 'Slap trimis.')
end

Commands.freeze = function(src, args)
    local admin = requireAdmin(src, 'freeze') if not admin then return end
    local target = getPlayerByUid(args[1])
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    TriggerClientEvent('driftzone_admin:client:setFrozen', target, true)
    notify(src, 'info', 'Player frozen.')
end

Commands.unfreeze = function(src, args)
    local admin = requireAdmin(src, 'unfreeze') if not admin then return end
    local target = getPlayerByUid(args[1])
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    TriggerClientEvent('driftzone_admin:client:setFrozen', target, false)
    notify(src, 'info', 'Player unfrozen.')
end

Commands.warn = function(src, args)
    local admin = requireAdmin(src, 'warn') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /warn uid motiv') end
    local reason = trim(table.concat(args, ' ', 2)); if reason == '' then reason = 'No reason' end
    local db = getDb(); local tableName = getUsersTable(); local col = db.warnsColumn or 'warns'
    dbUpdate(('UPDATE %s SET %s = COALESCE(%s,0) + 1 WHERE %s = ? LIMIT 1'):format(sqlName(tableName), sqlName(col), sqlName(col), sqlName(getUidColumn())), { uid })
    notify(src, 'info', ('Warn adaugat pentru UID %s.'):format(uid))
    local t = getPlayerByUid(uid); if t then notify(t, 'warning', 'Ai primit warn: ' .. reason, 8000) end
end

Commands.rwarn = function(src, args)
    local admin = requireAdmin(src, 'rwarn') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /rwarn uid') end
    local db = getDb(); local col = db.warnsColumn or 'warns'
    dbUpdate(('UPDATE %s SET %s = GREATEST(0, COALESCE(%s,0) - 1) WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(col), sqlName(col), sqlName(getUidColumn())), { uid })
    notify(src, 'info', 'Warn scos.')
end

Commands.warns = function(src, args)
    local admin = requireAdmin(src, 'warns', false) if not admin then return end
    local uid = tonumber(args[1]) or admin.uid
    local row = getUserByUid(uid)
    local col = getDb().warnsColumn or 'warns'
    notify(src, 'info', ('UID %s are %s warn-uri.'):format(uid, row and tonumber(row[col] or 0) or 0))
end

Commands.resetwarns = function(src, args)
    local admin = requireAdmin(src, 'resetwarns') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /resetwarns uid') end
    local col = getDb().warnsColumn or 'warns'
    dbUpdate(('UPDATE %s SET %s = 0 WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(col), sqlName(getUidColumn())), { uid })
    notify(src, 'info', 'Warn-uri resetate.')
end

Commands.coords = function(src)
    local admin = requireAdmin(src, 'coords') if not admin then return end
    local c = coordsOf(src); if not c then return end
    TriggerClientEvent('driftzone_admin:client:coordsPanel', src, { coords = ('vector3(%.6f, %.6f, %.6f)'):format(c.x, c.y, c.z), x = c.x, y = c.y, z = c.z, heading = c.h, dimension = GetPlayerRoutingBucket(src) or 0 })
end

Commands.gotocoords = function(src, args)
    local admin = requireAdmin(src, 'gotocoords') if not admin then return end
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if not x or not y or not z then return notify(src, 'warning', 'Folosire: /gotocoords x y z heading_optional') end
    teleportPlayer(src, { x = x, y = y, z = z, h = tonumber(args[4]) or 0.0 })
end

Commands.tptow = function(src)
    local admin = requireAdmin(src, 'tptow', false) if not admin then return end
    TriggerClientEvent('driftzone_admin:client:tptow', src, Config.Tptow or {})
end

Commands.nc = function(src)
    local admin = requireAdmin(src, 'nc') if not admin then return end
    NoclipState[src] = not NoclipState[src]
    TriggerClientEvent('driftzone_admin:client:noclip', src, NoclipState[src])
    notify(src, 'info', NoclipState[src] and 'Noclip pornit.' or 'Noclip oprit.')
end

Commands.spectate = function(src, args)
    local admin = requireAdmin(src, 'spectate') if not admin then return end
    if SpectateState[src] then
        SpectateState[src] = nil
        TriggerClientEvent('driftzone_admin:client:stopSpectate', src)
        return
    end
    local target = getPlayerByUid(args[1])
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    if target == src then return notify(src, 'warning', 'Nu poti da spectate pe tine.') end
    SpectateState[src] = target
    TriggerClientEvent('driftzone_admin:client:startSpectate', src, target)
end

Commands.veh = function(src, args)
    local admin = requireAdmin(src, 'veh') if not admin then return end
    local model = trim(args[1] or '')
    if model == '' then return notify(src, 'warning', 'Folosire: /veh model') end
    TriggerClientEvent('driftzone_admin:client:spawnVehicle', src, model)
end

Commands.fix = function(src, args)
    local admin = requireAdmin(src, 'fix') if not admin then return end
    local target = args[1] and getPlayerByUid(args[1]) or src
    if not target then return notify(src, 'warning', 'Jucatorul nu este online.') end
    TriggerClientEvent('driftzone_admin:client:fixVehicle', target)
end

Commands.ban = function(src, args)
    local admin = requireAdmin(src, 'ban') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /ban uid motiv') end
    local reason = trim(table.concat(args, ' ', 2)); if reason == '' then reason = 'Banned by admin' end
    local db = getDb(); local tableName = getUsersTable()
    if hasColumn(tableName, db.banColumn or 'ban') then
        local fields = ('%s = ?'):format(sqlName(db.banColumn or 'ban')); local params = { 1 }
        if hasColumn(tableName, db.banReasonColumn or 'banreason') then fields = fields .. (', %s = ?'):format(sqlName(db.banReasonColumn or 'banreason')); params[#params+1] = reason end
        params[#params+1] = uid
        dbUpdate(('UPDATE %s SET %s WHERE %s = ? LIMIT 1'):format(sqlName(tableName), fields, sqlName(getUidColumn())), params)
    end
    local target = getPlayerByUid(uid); if target then DropPlayer(target, 'Banned: ' .. reason) end
    notify(src, 'info', 'Player banat.')
end

Commands.tempban = function(src, args)
    local admin = requireAdmin(src, 'tempban') if not admin then return end
    local uid, days = tonumber(args[1]), tonumber(args[2])
    if not uid or not days then return notify(src, 'warning', 'Folosire: /tempban uid zile motiv') end
    local reason = trim(table.concat(args, ' ', 3)); if reason == '' then reason = 'Tempban by admin' end
    local expire = os.date('%Y-%m-%d %H:%M:%S', os.time() + math.floor(days * 86400))
    local db = getDb(); local tableName = getUsersTable()
    local fields, params = {}, {}
    if hasColumn(tableName, db.tempBanColumn or 'tempban') then fields[#fields+1] = sqlName(db.tempBanColumn or 'tempban') .. ' = ?'; params[#params+1] = expire end
    if hasColumn(tableName, db.tempBanReasonColumn or 'tempbanreason') then fields[#fields+1] = sqlName(db.tempBanReasonColumn or 'tempbanreason') .. ' = ?'; params[#params+1] = reason end
    if #fields > 0 then params[#params+1] = uid; dbUpdate(('UPDATE %s SET %s WHERE %s = ? LIMIT 1'):format(sqlName(tableName), table.concat(fields, ', '), sqlName(getUidColumn())), params) end
    local target = getPlayerByUid(uid); if target then DropPlayer(target, 'Tempban: ' .. reason) end
    notify(src, 'info', 'Tempban setat.')
end

Commands.unban = function(src, args)
    local admin = requireAdmin(src, 'unban') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /unban uid') end
    local db = getDb(); local tableName = getUsersTable(); local fields = {}; local params = {}
    local map = { {db.banColumn or 'ban', 0}, {db.banReasonColumn or 'banreason', nil}, {db.tempBanColumn or 'tempban', nil}, {db.tempBanReasonColumn or 'tempbanreason', nil} }
    for _, m in ipairs(map) do if hasColumn(tableName, m[1]) then fields[#fields+1] = sqlName(m[1]) .. ' = ?'; params[#params+1] = m[2] end end
    if #fields > 0 then params[#params+1] = uid; dbUpdate(('UPDATE %s SET %s WHERE %s = ? LIMIT 1'):format(sqlName(tableName), table.concat(fields, ', '), sqlName(getUidColumn())), params) end
    notify(src, 'info', 'Unban executat.')
end

Commands.giveveh = function(src, args)
    local admin = requireAdmin(src, 'giveveh') if not admin then return end
    local uid = tonumber(args[1]); local model = trim(args[2] or ''):lower():gsub('%s+', '')
    if not uid or model == '' then return notify(src, 'warning', 'Folosire: /giveveh uid model plate_optional') end
    local plate = sanitizePlate(args[3] or '') if plate == '' or plateExists(plate) then plate = generatePlate() end
    dbInsert('INSERT INTO ownedvehicles (owner_id, vehicle_model, vehicle_plate) VALUES (?, ?, ?)', { uid, model, plate })
    notify(src, 'info', ('Masina %s cu plate %s a fost data la UID %s.'):format(model, plate, uid))
end

Commands.takeveh = function(src, args)
    local admin = requireAdmin(src, 'takeveh') if not admin then return end
    local uid, id = tonumber(args[1]), tonumber(args[2])
    if not uid or not id then return notify(src, 'warning', 'Folosire: /takeveh uid sql_id') end
    dbUpdate('DELETE FROM ownedvehicles WHERE id = ? AND owner_id = ? LIMIT 1', { id, uid })
    notify(src, 'info', 'Masina stearsa.')
end

Commands.transferveh = function(src, args)
    local admin = requireAdmin(src, 'transferveh') if not admin then return end
    local uid, id = tonumber(args[1]), tonumber(args[2])
    if not uid or not id then return notify(src, 'warning', 'Folosire: /transferveh uid_nou sql_id') end
    dbUpdate('UPDATE ownedvehicles SET owner_id = ? WHERE id = ? LIMIT 1', { uid, id })
    notify(src, 'info', 'Masina transferata.')
end

Commands.changeplate = function(src, args)
    local admin = requireAdmin(src, 'changeplate') if not admin then return end
    local id = tonumber(args[1]); local plate = sanitizePlate(args[2])
    if not id or plate == '' then return notify(src, 'warning', 'Folosire: /changeplate sql_id plate') end
    if plateExists(plate) then return notify(src, 'warning', 'Plate-ul exista deja.') end
    dbUpdate('UPDATE ownedvehicles SET vehicle_plate = ? WHERE id = ? LIMIT 1', { plate, id })
    notify(src, 'info', 'Plate schimbat.')
end

Commands.lockveh = function(src, args)
    local admin = requireAdmin(src, 'lockveh') if not admin then return end
    local id = tonumber(args[1])
    setAdminVehicleLock(src, id, true)
end

Commands.unlockveh = function(src, args)
    local admin = requireAdmin(src, 'unlockveh') if not admin then return end
    local id = tonumber(args[1])
    setAdminVehicleLock(src, id, false)
end

Commands.addveh = function(src)
    local admin = requireAdmin(src, 'addveh') if not admin then return end
    TriggerClientEvent('driftzone_admin:client:addCarPanel', src, {})
end

Commands.removeveh = function(src, args)
    local admin = requireAdmin(src, 'removeveh') if not admin then return end
    local id = tonumber(args[1]); if not id then return notify(src, 'warning', 'Folosire: /removeveh id') end
    dbUpdate('DELETE FROM vehiclenames WHERE id = ? LIMIT 1', { id })
    notify(src, 'info', 'Veh config sters.')
end

Commands.configveh = function(src)
    local admin = requireAdmin(src, 'configveh') if not admin then return end
    TriggerClientEvent('driftzone_admin:client:configVehPanel', src, { vehicles = loadVehiclesConfig() })
end

Commands.vehs = function(src, args)
    local admin = requireAdmin(src, 'vehs') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /vehs uid') end
    refreshOwnedVehs(src, uid)
end

Commands.giveadm = function(src, args)
    local admin = requireAdmin(src, 'giveadm') if not admin then return end
    local uid, level = tonumber(args[1]), tonumber(args[2])
    if not uid or not level or level < 0 or level > 7 then return notify(src, 'warning', 'Folosire: /giveadm uid grad_0_7') end
    local db = getDb(); dbUpdate(('UPDATE %s SET %s = ? WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(db.adminColumn or 'admin_level'), sqlName(getUidColumn())), { level, uid })
    invalidateAdminCache(uid)
    notify(src, 'info', ('Admin level setat la %s pentru UID %s.'):format(level, uid))
end

Commands.givecash = function(src, args)
    local admin = requireAdmin(src, 'givecash') if not admin then return end
    local uid, amount = tonumber(args[1]), parseAmount(args[2])
    if not uid or not amount then return notify(src, 'warning', 'Folosire: /givecash uid suma') end
    local col = getDb().cashColumn or 'cash'
    dbUpdate(('UPDATE %s SET %s = COALESCE(%s,0) + ? WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(col), sqlName(col), sqlName(getUidColumn())), { amount, uid })
    notify(src, 'info', 'Cash adaugat.')
end

Commands.givedzcoins = function(src, args)
    local admin = requireAdmin(src, 'givedzcoins') if not admin then return end
    local uid, amount = tonumber(args[1]), parseAmount(args[2])
    if not uid or not amount then return notify(src, 'warning', 'Folosire: /givedzcoins uid suma') end
    local col = getDb().dzcoinsColumn or 'dzcoins'
    if not hasColumn(getUsersTable(), col) then return notify(src, 'warning', 'Coloana dzcoins nu exista.') end
    dbUpdate(('UPDATE %s SET %s = COALESCE(%s,0) + ? WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(col), sqlName(col), sqlName(getUidColumn())), { amount, uid })
    notify(src, 'info', 'DZ Coins adaugati.')
end

Commands.givevip = function(src, args)
    local admin = requireAdmin(src, 'givevip') if not admin then return end
    local uid, days = tonumber(args[1]), tonumber(args[2])
    if not uid or not days then return notify(src, 'warning', 'Folosire: /givevip uid zile') end
    local db = getDb(); local tableName = getUsersTable(); local fields = {}; local params = {}
    if hasColumn(tableName, db.vipColumn or 'vip') then fields[#fields+1] = sqlName(db.vipColumn or 'vip') .. ' = ?'; params[#params+1] = 1 end
    if hasColumn(tableName, db.vipDaysColumn or 'vip_days') then fields[#fields+1] = sqlName(db.vipDaysColumn or 'vip_days') .. ' = COALESCE(' .. sqlName(db.vipDaysColumn or 'vip_days') .. ',0) + ?'; params[#params+1] = math.floor(days) end
    if #fields > 0 then params[#params+1] = uid; dbUpdate(('UPDATE %s SET %s WHERE %s = ? LIMIT 1'):format(sqlName(tableName), table.concat(fields, ', '), sqlName(getUidColumn())), params) end
    notify(src, 'info', 'VIP adaugat.')
end

Commands.removevip = function(src, args)
    local admin = requireAdmin(src, 'removevip') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /removevip uid') end
    local db = getDb(); local tableName = getUsersTable(); local fields = {}; local params = {}
    if hasColumn(tableName, db.vipColumn or 'vip') then fields[#fields+1] = sqlName(db.vipColumn or 'vip') .. ' = ?'; params[#params+1] = 0 end
    if hasColumn(tableName, db.vipDaysColumn or 'vip_days') then fields[#fields+1] = sqlName(db.vipDaysColumn or 'vip_days') .. ' = ?'; params[#params+1] = 0 end
    if #fields > 0 then params[#params+1] = uid; dbUpdate(('UPDATE %s SET %s WHERE %s = ? LIMIT 1'):format(sqlName(tableName), table.concat(fields, ', '), sqlName(getUidColumn())), params) end
    notify(src, 'info', 'VIP scos.')
end

Commands.resettickets = function(src, args)
    local admin = requireAdmin(src, 'resettickets') if not admin then return end
    local uid = tonumber(args[1])
    local col = getDb().ticketsColumn or 'tickets'
    if not hasColumn(getUsersTable(), col) then return notify(src, 'warning', 'Coloana tickets nu exista.') end
    if uid then dbUpdate(('UPDATE %s SET %s = 0 WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), sqlName(col), sqlName(getUidColumn())), { uid }) else dbUpdate(('UPDATE %s SET %s = 0'):format(sqlName(getUsersTable()), sqlName(col)), {}) end
    notify(src, 'info', 'Tickets resetate.')
end

Commands.wipe = function(src, args)
    local admin = requireAdmin(src, 'wipe') if not admin then return end
    local uid = tonumber(args[1]); if not uid then return notify(src, 'warning', 'Folosire: /wipe uid') end
    local db = getDb(); local fields = {}
    if hasColumn(getUsersTable(), db.cashColumn or 'cash') then fields[#fields+1] = sqlName(db.cashColumn or 'cash') .. ' = 0' end
    if hasColumn(getUsersTable(), db.bankColumn or 'bank') then fields[#fields+1] = sqlName(db.bankColumn or 'bank') .. ' = 0' end
    if hasColumn(getUsersTable(), db.dzcoinsColumn or 'dzcoins') then fields[#fields+1] = sqlName(db.dzcoinsColumn or 'dzcoins') .. ' = 0' end
    if #fields > 0 then dbUpdate(('UPDATE %s SET %s WHERE %s = ? LIMIT 1'):format(sqlName(getUsersTable()), table.concat(fields, ', '), sqlName(getUidColumn())), { uid }) end
    pcall(function() MySQL.update.await('DELETE FROM inventory WHERE uid = ?', { uid }) end)
    pcall(function() MySQL.update.await('DELETE FROM ownedvehicles WHERE owner_id = ?', { uid }) end)
    notify(src, 'info', 'Wipe executat.')
end

Commands.addoutfit = function(src)
    local admin = requireAdmin(src, 'addoutfit') if not admin then return end
    TriggerEvent('driftzone_outfits:server:addOutfitFromAdmin', src)
    notify(src, 'info', 'Comanda addoutfit a fost trimisa catre resource-ul de outfits, daca exista.')
end

local function parseCleanupTime(args)
    local amount = tonumber(args[1]); local unit = tostring(args[2] or 's'):lower()
    if not amount or amount <= 0 then return nil, 'Folosire: /cleanup 10 s sau /cleanup 10 m' end
    if unit == 'm' or unit == 'min' or unit == 'minute' then return math.floor(amount * 60), ('%s minute'):format(math.floor(amount)) end
    return math.floor(amount), ('%s secunde'):format(math.floor(amount))
end

local function isVehicleUnoccupiedServer(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local driver = GetPedInVehicleSeat(veh, -1)
    return not driver or driver == 0 or not DoesEntityExist(driver)
end

local function deleteVehicleServer(veh)
    if not isVehicleUnoccupiedServer(veh) then return false end
    SetEntityAsMissionEntity(veh, true, true)
    for _ = 1, 8 do if not DoesEntityExist(veh) then return true end DeleteEntity(veh) Wait(0) end
    return not DoesEntityExist(veh)
end

Commands.cleanup = function(src, args)
    local admin = requireAdmin(src, 'cleanup') if not admin then return end
    if CleanupState then return notify(src, 'warning', 'Exista deja cleanup activ.') end
    local seconds, label = parseCleanupTime(args); if not seconds then return notify(src, 'warning', label) end
    CleanupSerial = CleanupSerial + 1
    local serial = CleanupSerial
    CleanupState = { serial = serial, by = src }
    notifyAll('warning', ('Cleanup vehicule fara sofer in %s.'):format(label), 8000)
    CreateThread(function()
        Wait(seconds * 1000)
        if not CleanupState or CleanupState.serial ~= serial then return end
        CleanupReports[serial] = 0
        TriggerClientEvent('driftzone_admin:client:cleanupVehicles', -1, serial)
        Wait(2500)
        local serverDeleted = 0
        for _, veh in ipairs(GetAllVehicles()) do if deleteVehicleServer(veh) then serverDeleted = serverDeleted + 1 end end
        notifyAll('info', ('Cleanup terminat. Sterse client: %s, server: %s.'):format(CleanupReports[serial] or 0, serverDeleted), 8000)
        CleanupReports[serial] = nil
        CleanupState = nil
    end)
end

Commands.cancelcleanup = function(src)
    local admin = requireAdmin(src, 'cancelcleanup') if not admin then return end
    if not CleanupState then return notify(src, 'warning', 'Nu exista cleanup activ.') end
    CleanupState = nil
    notifyAll('info', 'Cleanup anulat de staff.')
end

local function runAdminCommand(src, command, args)
    command = tostring(command or ''):lower()
    args = type(args) == 'table' and args or {}
    if command == '' then return end
    if not isCommandKnown(command) then notify(src, 'warning', 'Comanda admin necunoscuta.') return end
    if onCooldown(src, command) then return end
    local fn = Commands[command]
    if not fn then notify(src, 'warning', 'Comanda exista in config, dar nu este implementata in server/main.lua.') logAdminCommand(src, command, args, 'failed', 'not implemented') return end
    local ok, err = pcall(fn, src, args)
    if ok then logAdminCommand(src, command, args, 'success', 'ok') else notify(src, 'warning', 'Eroare la comanda /' .. command) print('[DRIFTZONE_ADMIN] command error /' .. command .. ': ' .. tostring(err)) logAdminCommand(src, command, args, 'failed', tostring(err)) end
end

RegisterNetEvent('driftzone_admin:server:run', function(command, args)
    runAdminCommand(source, command, args or {})
end)

RegisterNetEvent('driftzone_admin:server:runRaw', function(raw)
    local command, args = splitRaw(raw or '')
    runAdminCommand(source, command, args)
end)

RegisterNetEvent('driftzone_admin:server:runFromPanel', function(command, argsText)
    local src = source
    local admin = requireAdmin(src, 'ap')
    if not admin then return end
    command = tostring(command or ''):lower():gsub('^/', '')
    local args = {}
    for part in tostring(argsText or ''):gmatch('%S+') do args[#args + 1] = part end
    runAdminCommand(src, command, args)
end)

for commandName, _ in pairs(AdminCommands) do
    local cmd = tostring(commandName)
    RegisterCommand(cmd, function(src, args)
        if src == 0 then return end
        runAdminCommand(src, cmd, args or {})
    end, false)
end

RegisterNetEvent('driftzone_admin:server:tptowResult', function(success, coords)
    if success then notify(source, 'info', 'Te-ai teleportat la waypoint.') else notify(source, 'warning', 'Nu ai waypoint setat.') end
end)

RegisterNetEvent('driftzone_admin:server:vehSpawnResult', function(success, model, plate, netId)
    local src = source
    if success then notify(src, 'info', ('Masina %s spawnata. Plate: %s'):format(model or '?', plate or '?')) else notify(src, 'warning', 'Nu s-a putut spawna masina.') end
end)

RegisterNetEvent('driftzone_admin:server:ownedVehSpawnResult', function(success, data, netId)
    local src = source
    data = type(data) == 'table' and data or {}
    if success then
        notify(src, 'info', ('Masina SQL ID %s a fost spawnata.'):format(data.vehicleId or '?'))
        logVehicle(src, 'vehs_spawn', 'success', { data = data, netId = netId })
    else
        notify(src, 'warning', 'Nu s-a putut spawna masina.')
        logVehicle(src, 'vehs_spawn', 'failed', { data = data, netId = netId })
    end
    if data.uid then refreshOwnedVehs(src, tonumber(data.uid) or 0) end
end)

RegisterNetEvent('driftzone_admin:server:cleanupClientReport', function(serial, deleted)
    serial = tonumber(serial or 0) or 0
    if serial <= 0 then return end
    CleanupReports[serial] = (CleanupReports[serial] or 0) + (tonumber(deleted or 0) or 0)
end)

RegisterNetEvent('driftzone_admin:server:addCarSubmit', function(payload)
    local src = source
    local admin = requireAdmin(src, 'addveh') if not admin then return end
    local p, err = safeVehiclePayload(payload)
    if not p then TriggerClientEvent('driftzone_admin:client:addCarResult', src, false, err or 'Date invalide.') return end
    local q = [[INSERT INTO vehiclenames (vehicle_model, vehicle_name, price, dzcoins_price, category, showroom_section, showroom_subcategory, vip, apear, selling, tradeble, tradable, tunable, type, image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]]
    local ok, result = dbInsert(q, { p.model, p.name, p.price, p.dzcoins_price, p.category, p.showroom_section, p.showroom_subcategory, p.vip, p.apear, p.selling, p.tradeble, p.tradeble, p.tunable, p.type, p.image })
    TriggerClientEvent('driftzone_admin:client:addCarResult', src, ok, ok and 'Masina salvata.' or ('Eroare DB: ' .. tostring(result)))
    logVehicle(src, 'addveh', ok and 'success' or 'failed', p)
end)

RegisterNetEvent('driftzone_admin:server:configVehSave', function(id, payload)
    local src = source
    local admin = requireAdmin(src, 'configveh') if not admin then return end
    id = tonumber(id or 0) or 0
    local p, err = safeVehiclePayload(payload)
    if id <= 0 or not p then TriggerClientEvent('driftzone_admin:client:adminPanelResult', src, false, err or 'Date invalide.') return end
    local ok, result = dbUpdate([[UPDATE vehiclenames SET vehicle_model=?, vehicle_name=?, price=?, dzcoins_price=?, category=?, showroom_section=?, showroom_subcategory=?, vip=?, apear=?, selling=?, tradeble=?, tradable=?, tunable=?, type=?, image=? WHERE id=? LIMIT 1]], { p.model, p.name, p.price, p.dzcoins_price, p.category, p.showroom_section, p.showroom_subcategory, p.vip, p.apear, p.selling, p.tradeble, p.tradeble, p.tunable, p.type, p.image, id })
    TriggerClientEvent('driftzone_admin:client:adminPanelResult', src, ok, ok and 'Masina editata.' or ('Eroare DB: ' .. tostring(result)))
    TriggerClientEvent('driftzone_admin:client:configVehPanel', src, { vehicles = loadVehiclesConfig() })
end)

RegisterNetEvent('driftzone_admin:server:configVehDelete', function(id)
    local src = source
    local admin = requireAdmin(src, 'configveh') if not admin then return end
    id = tonumber(id or 0) or 0
    if id <= 0 then return end
    dbUpdate('DELETE FROM vehiclenames WHERE id = ? LIMIT 1', { id })
    TriggerClientEvent('driftzone_admin:client:configVehPanel', src, { vehicles = loadVehiclesConfig() })
end)

RegisterNetEvent('driftzone_admin:server:ownedVehAction', function(action, uid, vehicleId, extra)
    local src = source
    local admin = requireAdmin(src, 'vehs') if not admin then return end
    action = tostring(action or '')
    uid = tonumber(uid or 0) or 0
    vehicleId = tonumber(vehicleId or 0) or 0
    extra = type(extra) == 'table' and extra or {}
    if uid <= 0 or vehicleId <= 0 then return notify(src, 'warning', 'Date invalide.') end
    local row = getOwnedVehicle(vehicleId)
    if not row then return notify(src, 'warning', 'Masina nu exista.') end
    if action == 'take' then
        dbUpdate('DELETE FROM ownedvehicles WHERE id = ? LIMIT 1', { vehicleId })
        notify(src, 'info', 'Masina stearsa.')
    elseif action == 'transfer' then
        local newUid = tonumber(extra.newUid or extra.uid or 0) or 0
        if newUid <= 0 then return notify(src, 'warning', 'UID nou invalid.') end
        dbUpdate('UPDATE ownedvehicles SET owner_id = ? WHERE id = ? LIMIT 1', { newUid, vehicleId })
        notify(src, 'info', 'Masina transferata.')
        uid = newUid
    elseif action == 'spawn' then
        TriggerClientEvent('driftzone_admin:client:spawnOwnedVehicle', src, { uid = uid, vehicleId = vehicleId, model = row.vehicle_model, plate = row.vehicle_plate })
        return
    elseif action == 'goto' then
        if row.x and row.y and row.z then teleportPlayer(src, { x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z), h = 0.0 }) else notify(src, 'warning', 'Masina nu are coordonate salvate.') end
    elseif action == 'bring' then
        notify(src, 'warning', 'Bring pentru masina spawnata depinde de driftzone_vs; foloseste SPAWN daca nu e langa tine.')
    end
    refreshOwnedVehs(src, uid)
end)

AddEventHandler('playerDropped', function()
    local src = source
    NoclipState[src] = nil
    SpectateState[src] = nil
end)
