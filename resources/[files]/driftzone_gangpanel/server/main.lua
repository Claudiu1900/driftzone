local OpenPlayers = {}
local LastAction = {}
local UidCache = {}
local LastSeenUpdate = {}
local PendingTaxes = {}

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function cleanName(name)
    return tostring(name or ''):gsub('`', '')
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normHex(value)
    value = trim(value)
    if value == '' then return Config.MainColor or '#04c7f7' end
    if not value:match('^#') then value = '#' .. value end
    if not value:match('^#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return Config.MainColor or '#04c7f7'
    end
    return value:upper()
end

local function jsonEncode(data)
    local ok, res = pcall(json.encode, data or {})
    if ok then return res end
    return '{}'
end

local function notify(src, typ, msg, duration)
    if not src or tonumber(src) == 0 then return end
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or Config.NotifyDuration or 4500, tostring(msg or ''))
end

local function runHook(name, ...)
    if Config.Hooks and type(Config.Hooks[name]) == 'function' then
        local ok, err = pcall(Config.Hooks[name], ...)
        if not ok then print('[DRIFTZONE_GANGPANEL] Hook error ' .. tostring(name) .. ': ' .. tostring(err)) end
    end
end

local function cooldown(src, action)
    local now = GetGameTimer()
    local key = tostring(src) .. ':' .. tostring(action)
    local last = LastAction[key] or 0
    if now - last < (Config.ActionCooldownMs or 500) then return false end
    LastAction[key] = now
    return true
end

local function getUid(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end

    local state = Player(src).state
    local keys = { 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }
    for i = 1, #keys do
        local uid = tonumber(state and state[keys[i]])
        if uid and uid > 0 then return uid end
    end

    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then return cached.uid end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end,
        function() return exports.driftzone_core:GetUID(src) end,
        function() return exports.driftzone_login:GetUID(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, uid = pcall(fn)
        uid = tonumber(uid)
        if ok and uid and uid > 0 then
            UidCache[src] = { uid = uid, expires = GetGameTimer() + 30000 }
            return uid
        end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and (state.dz_logged == true or state.logged == true or state.isLoggedIn == true) then return true end

    local attempts = {
        function() return exports.driftzone_auth:IsLoggedIn(src) end,
        function() return exports.driftzone_auth:isLoggedIn(src) end,
        function() return exports.driftzone_core:IsLoggedIn(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, res = pcall(fn)
        if ok and res == true then return true end
    end

    return getUid(src) ~= nil
end

local function getUserByUid(uid)
    uid = tonumber(uid)
    if not uid then return nil end
    return MySQL.single.await(('SELECT * FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(Config.UsersTable), sqlName(Config.UsersIdColumn)), { uid })
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)
    if not uid then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getUid(src) == uid then return src end
    end
    return nil
end

local function userDisplay(uid)
    local row = getUserByUid(uid)
    if not row then return 'CNP ' .. tostring(uid or 0) end
    return tostring(row[Config.UsernameColumn or 'username'] or row.username or ('CNP ' .. tostring(uid)))
end

local function isOnlineUid(uid)
    return getPlayerByUid(uid) ~= nil
end

local function truthy(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function isSyndicateUid(uid)
    local row = getUserByUid(uid)
    if not row then return false end

    local keys = {
        Config.SyndicateColumn or 'sindicate',
        Config.SyndicateColumnFallback or 'syndicate',
        'sindicate',
        'syndicate',
        'sindicat'
    }

    for i = 1, #keys do
        local key = keys[i]
        if key and row[key] ~= nil and truthy(row[key]) then
            return true
        end
    end

    return false
end

local function getGang(gangId)
    gangId = tonumber(gangId)
    if not gangId then return nil end
    return MySQL.single.await(('SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1'):format(sqlName(Config.GangsTable)), { gangId })
end

local function getMembership(uid)
    uid = tonumber(uid)
    if not uid then return nil end
    return MySQL.single.await(([[
        SELECT gm.*, g.name AS gang_name, g.shortcut, g.color, g.type, g.revenue, g.leader_uid, g.garage_x, g.garage_y, g.garage_z, g.storage_x, g.storage_y, g.storage_z
        FROM %s gm
        INNER JOIN %s g ON g.id = gm.gang_id AND g.active = 1
        WHERE gm.uid = ?
        LIMIT 1
    ]]):format(sqlName(Config.MembersTable), sqlName(Config.GangsTable)), { uid })
end

local function rolePower(role)
    return tonumber(Config.RolePower and Config.RolePower[tostring(role or '')] or 0) or 0
end

local function normalizeRole(role)
    role = trim(role)
    if role == 'Co-Lider' or role:lower() == 'coleader' or role:lower() == 'co-lider' then return 'Co-Lider' end
    if role == 'Lider' or role:lower() == 'leader' or role:lower() == 'lider' then return 'Lider' end
    return 'Membru'
end

local function canAccess(src)
    if not isLogged(src) then return nil end
    local uid = getUid(src)
    if not uid then return nil end

    local syndicate = isSyndicateUid(uid)
    local membership = getMembership(uid)
    if not syndicate and not membership then return nil end

    return {
        src = src,
        uid = uid,
        syndicate = syndicate,
        membership = membership,
        role = membership and membership.role or nil,
        power = membership and rolePower(membership.role) or 0,
        gangId = membership and tonumber(membership.gang_id) or nil
    }
end

local function logAction(action, byUid, gangId, targetUid, details)
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (`action`, `by_uid`, `gang_id`, `target_uid`, `details`, `created_at`) VALUES (?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.LogsTable)), {
            tostring(action or ''), tonumber(byUid or 0) or 0, tonumber(gangId or 0) or 0, tonumber(targetUid or 0) or 0, jsonEncode(details or {})
        })
    end)
end

local function logRevenue(gangId, action, amount, byUid, details)
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (`gang_id`, `action`, `amount`, `by_uid`, `details`, `created_at`) VALUES (?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.RevenueLogsTable)), {
            tonumber(gangId or 0) or 0, tostring(action or ''), tonumber(amount or 0) or 0, tonumber(byUid or 0) or 0, jsonEncode(details or {})
        })
    end)
end

local function updateUserRank(uid, shortcut, color)
    uid = tonumber(uid)
    if not uid then return end
    pcall(function()
        MySQL.update.await(('UPDATE %s SET %s = ?, %s = ? WHERE %s = ? LIMIT 1'):format(
            sqlName(Config.UsersTable), sqlName(Config.RankColumn or 'rank'), sqlName(Config.RankColorColumn or 'rankcolor'), sqlName(Config.UsersIdColumn)
        ), { tostring(shortcut or ''), tostring(color or ''), uid })
    end)
end

local function clearUserRank(uid, oldShortcut)
    uid = tonumber(uid)
    if not uid then return end
    if oldShortcut and oldShortcut ~= '' then
        pcall(function()
            MySQL.update.await(('UPDATE %s SET %s = \'\', %s = \'\' WHERE %s = ? AND %s = ? LIMIT 1'):format(
                sqlName(Config.UsersTable), sqlName(Config.RankColumn or 'rank'), sqlName(Config.RankColorColumn or 'rankcolor'), sqlName(Config.UsersIdColumn), sqlName(Config.RankColumn or 'rank')
            ), { uid, tostring(oldShortcut) })
        end)
    else
        pcall(function()
            MySQL.update.await(('UPDATE %s SET %s = \'\', %s = \'\' WHERE %s = ? LIMIT 1'):format(
                sqlName(Config.UsersTable), sqlName(Config.RankColumn or 'rank'), sqlName(Config.RankColorColumn or 'rankcolor'), sqlName(Config.UsersIdColumn)
            ), { uid })
        end)
    end
end

local function syncGangRanks(gangId)
    local gang = getGang(gangId)
    if not gang then return end
    local rows = MySQL.query.await(('SELECT uid FROM %s WHERE gang_id = ?'):format(sqlName(Config.MembersTable)), { gangId }) or {}
    for _, row in ipairs(rows) do
        updateUserRank(row.uid, gang.shortcut, gang.color)
    end
end

local function updateLastSeen(uid)
    local now = GetGameTimer()
    if LastSeenUpdate[uid] and now - LastSeenUpdate[uid] < (Config.UpdateLastSeenEveryMs or 60000) then return end
    LastSeenUpdate[uid] = now
    pcall(function()
        MySQL.update.await(('UPDATE %s SET last_seen = NOW() WHERE uid = ?'):format(sqlName(Config.MembersTable)), { uid })
    end)
end

local function memberCount(gangId)
    local row = MySQL.single.await(('SELECT COUNT(*) AS c FROM %s WHERE gang_id = ?'):format(sqlName(Config.MembersTable)), { gangId })
    return tonumber(row and row.c or 0) or 0
end

local function onlineCount(gangId)
    local rows = MySQL.query.await(('SELECT uid FROM %s WHERE gang_id = ?'):format(sqlName(Config.MembersTable)), { gangId }) or {}
    local c = 0
    for _, row in ipairs(rows) do
        if isOnlineUid(row.uid) then c = c + 1 end
    end
    return c
end

local function loadCategories()
    return MySQL.query.await(('SELECT id, name, description, active FROM %s WHERE active = 1 ORDER BY id ASC'):format(sqlName(Config.TaxCategoriesTable)), {}) or {}
end

local function loadGangs()
    local rows = MySQL.query.await(('SELECT * FROM %s WHERE active = 1 ORDER BY id ASC'):format(sqlName(Config.GangsTable)), {}) or {}
    for _, g in ipairs(rows) do
        g.members_total = memberCount(g.id)
        g.members_online = onlineCount(g.id)
        g.revenue = tonumber(g.revenue or 0) or 0
    end
    return rows
end

local function loadMembers(gangId, syndicate)
    local rows = MySQL.query.await(([[
        SELECT gm.id, gm.gang_id, gm.uid, gm.role, gm.added_at, gm.last_seen, u.%s AS username
        FROM %s gm
        LEFT JOIN %s u ON u.%s = gm.uid
        WHERE gm.gang_id = ?
        ORDER BY FIELD(gm.role, 'Lider', 'Co-Lider', 'Membru'), gm.uid ASC
    ]]):format(sqlName(Config.UsernameColumn or 'username'), sqlName(Config.MembersTable), sqlName(Config.UsersTable), sqlName(Config.UsersIdColumn)), { gangId }) or {}

    for _, row in ipairs(rows) do
        row.cnp = row.uid
        row.name = tostring(row.username or ('CNP ' .. tostring(row.uid)))
        row.online = isOnlineUid(row.uid)
        row.server_id = syndicate and getPlayerByUid(row.uid) or nil
        if not syndicate then row.username = nil end
    end
    return rows
end

local function loadTaxes(gangId, categoryId, limit)
    categoryId = tonumber(categoryId or 0) or 0
    limit = tonumber(limit or 60) or 60
    local params = { gangId }
    local where = 'WHERE tr.gang_id = ?'
    if categoryId > 0 then
        where = where .. ' AND tr.category_id = ?'
        params[#params + 1] = categoryId
    end
    return MySQL.query.await(([[
        SELECT tr.id, tr.gang_id, tr.category_id, tr.category_name, tr.amount, tr.payer_uid, tr.issuer_uid, tr.paid_from, tr.status, tr.created_at, tr.paid_at,
               up.%s AS payer_name, ui.%s AS issuer_name
        FROM %s tr
        LEFT JOIN %s up ON up.%s = tr.payer_uid
        LEFT JOIN %s ui ON ui.%s = tr.issuer_uid
        %s
        ORDER BY tr.id DESC
        LIMIT %d
    ]]):format(sqlName(Config.UsernameColumn or 'username'), sqlName(Config.UsernameColumn or 'username'), sqlName(Config.TaxRecordsTable), sqlName(Config.UsersTable), sqlName(Config.UsersIdColumn), sqlName(Config.UsersTable), sqlName(Config.UsersIdColumn), where, limit), params) or {}
end

local function loadPendingWithdrawal(uid)
    local row = MySQL.single.await(('SELECT * FROM %s WHERE leader_uid = ? AND status = \'ready\' ORDER BY id DESC LIMIT 1'):format(sqlName(Config.WithdrawalsTable)), { uid })
    if not row then return nil end
    return { id = row.id, amount = row.amount, x = row.x, y = row.y, z = row.z }
end

local function buildPayload(src, access)
    local user = getUserByUid(access.uid) or {}
    local membership = access.membership
    local gang = nil
    if membership then gang = getGang(membership.gang_id) end

    local payload = {
        mainColor = Config.MainColor,
        user = {
            cnp = access.uid,
            name = tostring(user[Config.UsernameColumn or 'username'] or GetPlayerName(src) or ('CNP ' .. tostring(access.uid))),
            syndicate = access.syndicate,
            gangId = membership and tonumber(membership.gang_id) or nil,
            role = membership and membership.role or nil,
            power = access.power
        },
        access = {
            syndicate = access.syndicate,
            member = membership ~= nil,
            canCreateGang = access.syndicate,
            canManageGang = access.syndicate,
            canManageCategories = access.syndicate,
            canManageMembers = access.syndicate or access.power >= 2,
            canSeeDashboard = access.syndicate or access.power >= 2,
            canSeeMembers = access.syndicate or access.power >= 2,
            canSeeRevenue = access.syndicate or access.power >= 2,
            canOfferTax = membership ~= nil or access.syndicate
        },
        gang = gang,
        categories = loadCategories(),
        taxAmounts = Config.TaxAmounts or { 100000, 70000, 40000 },
        withdrawal = loadPendingWithdrawal(access.uid)
    }

    if gang then
        payload.gang.members_total = memberCount(gang.id)
        payload.gang.members_online = onlineCount(gang.id)
        payload.gang.revenue = tonumber(gang.revenue or 0) or 0
        payload.members = (access.syndicate or access.power >= 2) and loadMembers(gang.id, access.syndicate) or {}
        payload.taxes = loadTaxes(gang.id, 0, 70)
    else
        payload.members = {}
        payload.taxes = {}
    end

    if access.syndicate then
        payload.gangs = loadGangs()
    else
        payload.gangs = {}
    end

    return payload
end

local function pushUpdate(src)
    local access = canAccess(src)
    if not access then return end
    if access.uid then updateLastSeen(access.uid) end
    TriggerClientEvent('driftzone_gangpanel:client:update', src, buildPayload(src, access))
end

local function canManageTarget(access, gangId, targetRole, newRole)
    if access.syndicate then return true end
    if tonumber(access.gangId or 0) ~= tonumber(gangId or 0) then return false end
    local myPower = access.power or 0
    local targetPower = rolePower(targetRole or 'Membru')
    local desiredPower = rolePower(newRole or targetRole or 'Membru')

    if myPower >= 3 then
        return targetPower < 3 and desiredPower < 3
    end

    if myPower >= 2 then
        return targetPower <= 1 and desiredPower <= 1
    end

    return false
end

local function getCategory(categoryId)
    categoryId = tonumber(categoryId or 0) or 0
    if categoryId <= 0 then return nil end
    return MySQL.single.await(('SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1'):format(sqlName(Config.TaxCategoriesTable)), { categoryId })
end

local function amountAllowed(amount)
    amount = tonumber(amount or 0) or 0
    for _, v in ipairs(Config.TaxAmounts or {}) do
        if tonumber(v) == amount then return true end
    end
    return false
end

local function getMoney(uid)
    local row = MySQL.single.await(('SELECT %s AS cash, %s AS bank FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(Config.CashColumn), sqlName(Config.BankColumn), sqlName(Config.UsersTable), sqlName(Config.UsersIdColumn)), { uid })
    return tonumber(row and row.cash or 0) or 0, tonumber(row and row.bank or 0) or 0
end

local function takeMoney(uid, amount)
    uid = tonumber(uid or 0) or 0
    amount = math.floor(tonumber(amount or 0) or 0)
    if uid <= 0 or amount <= 0 then return false, nil end

    local affected = MySQL.update.await(('UPDATE %s SET %s = %s - ? WHERE %s = ? AND %s >= ?'):format(sqlName(Config.UsersTable), sqlName(Config.CashColumn), sqlName(Config.CashColumn), sqlName(Config.UsersIdColumn), sqlName(Config.CashColumn)), { amount, uid, amount })
    if affected and affected > 0 then return true, 'cash' end

    affected = MySQL.update.await(('UPDATE %s SET %s = %s - ? WHERE %s = ? AND %s >= ?'):format(sqlName(Config.UsersTable), sqlName(Config.BankColumn), sqlName(Config.BankColumn), sqlName(Config.UsersIdColumn), sqlName(Config.BankColumn)), { amount, uid, amount })
    if affected and affected > 0 then return true, 'bank' end

    return false, nil
end

local function addRevenue(gangId, amount, byUid, reason)
    amount = math.floor(tonumber(amount or 0) or 0)
    if amount == 0 then return false end
    local affected = MySQL.update.await(('UPDATE %s SET revenue = GREATEST(0, revenue + ?), updated_at = NOW() WHERE id = ? LIMIT 1'):format(sqlName(Config.GangsTable)), { amount, gangId })
    if affected and affected > 0 then
        logRevenue(gangId, reason or (amount > 0 and 'add' or 'remove'), amount, byUid, {})
        return true
    end
    return false
end

local function giveDirtyMoney(uid, amount)
    uid = tonumber(uid or 0) or 0
    amount = math.floor(tonumber(amount or 0) or 0)
    if uid <= 0 or amount <= 0 then return false, 'Date invalide.' end

    local invRes = Config.Withdrawal.InventoryResource or 'driftzone_inventory'
    if GetResourceState(invRes) == 'started' then
        local ok, result, msg = pcall(function()
            return exports[invRes]:GiveItem(uid, Config.Withdrawal.DirtyMoneyItem or 'dirtymoney', amount)
        end)
        if ok and result == true then return true, 'Item adaugat.' end
        if ok and result == false then return false, msg or 'Inventar plin.' end
    end

    -- Fallback direct pe tabela inventory, compatibil cu driftzone_inventory.
    local row = MySQL.single.await('SELECT inventory_json FROM `inventory` WHERE uid = ? LIMIT 1', { uid })
    local inv = {}
    if row and row.inventory_json then
        local ok, decoded = pcall(json.decode, tostring(row.inventory_json or '{}'))
        if ok and type(decoded) == 'table' then inv = decoded end
    end

    local itemId = Config.Withdrawal.DirtyMoneyItem or 'dirtymoney'
    local placed = false
    for i = 1, 49 do
        local k = tostring(i)
        local slot = inv[k]
        if type(slot) == 'table' and slot.item_id == itemId then
            slot.amount = math.floor(tonumber(slot.amount or 0) or 0) + amount
            placed = true
            break
        end
    end
    if not placed then
        for i = 1, 49 do
            local k = tostring(i)
            if inv[k] == nil then
                inv[k] = { item_id = itemId, amount = amount }
                placed = true
                break
            end
        end
    end
    if not placed then return false, 'Inventar plin.' end

    MySQL.update.await('INSERT INTO `inventory` (`uid`, `inventory_json`, `updated_at`) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE inventory_json = VALUES(inventory_json), updated_at = NOW()', { uid, jsonEncode(inv) })
    return true, 'Item adaugat.'
end

RegisterCommand(Config.Command or 'gang', function(src)
    if src <= 0 then return end
    local access = canAccess(src)
    if not access then
        notify(src, 'warning', 'Nu ai acces la panoul mafiei.')
        return
    end
    updateLastSeen(access.uid)
    OpenPlayers[src] = true
    TriggerClientEvent('driftzone_gangpanel:client:open', src, buildPayload(src, access))
end, false)

RegisterNetEvent('driftzone_gangpanel:server:requestOpen', function()
    local src = source
    local access = canAccess(src)
    if not access then
        notify(src, 'warning', 'Nu ai acces la panoul mafiei.')
        TriggerClientEvent('driftzone_gangpanel:client:deny', src)
        return
    end
    updateLastSeen(access.uid)
    OpenPlayers[src] = true
    TriggerClientEvent('driftzone_gangpanel:client:open', src, buildPayload(src, access))
end)

RegisterNetEvent('driftzone_gangpanel:server:closed', function()
    OpenPlayers[source] = nil
end)

RegisterNetEvent('driftzone_gangpanel:server:refresh', function()
    local src = source
    if not cooldown(src, 'refresh') then return end
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:getGangDetails', function(gangId)
    local src = source
    local access = canAccess(src)
    if not access then return end
    gangId = tonumber(gangId or 0) or 0
    if gangId <= 0 then return end
    if not access.syndicate and tonumber(access.gangId or 0) ~= gangId then return end
    local gang = getGang(gangId)
    if not gang then return end
    gang.members_total = memberCount(gang.id)
    gang.members_online = onlineCount(gang.id)
    gang.revenue = tonumber(gang.revenue or 0) or 0
    TriggerClientEvent('driftzone_gangpanel:client:gangDetails', src, {
        gang = gang,
        members = (access.syndicate or access.power >= 2) and loadMembers(gangId, access.syndicate) or {},
        taxes = loadTaxes(gangId, 0, 100)
    })
end)

RegisterNetEvent('driftzone_gangpanel:server:createGang', function(data)
    local src = source
    local access = canAccess(src)
    if not access or not access.syndicate then return end
    if not cooldown(src, 'createGang') then return end

    data = type(data) == 'table' and data or {}
    local typ = trim(data.type)
    if typ ~= 'Mafie Oficiala' and typ ~= 'Mafie Neoficiala' then typ = 'Mafie Neoficiala' end
    local name = trim(data.name)
    local shortcut = trim(data.shortcut):upper():gsub('%s+', '')
    local color = normHex(data.color)
    local leaderUid = tonumber(data.leader_uid or data.leaderCnp or 0) or 0
    if name == '' or shortcut == '' or leaderUid <= 0 then
        notify(src, 'warning', 'Completeaza numele, shortcut-ul si CNP-ul liderului.')
        return
    end
    if not getUserByUid(leaderUid) then
        notify(src, 'warning', 'CNP lider invalid.')
        return
    end

    local id = MySQL.insert.await(('INSERT INTO %s (`type`, `name`, `shortcut`, `color`, `leader_uid`, `garage_x`, `garage_y`, `garage_z`, `storage_x`, `storage_y`, `storage_z`, `revenue`, `active`, `created_by`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?, NOW(), NOW())'):format(sqlName(Config.GangsTable)), {
        typ, name, shortcut, color, leaderUid,
        tonumber(data.garage_x), tonumber(data.garage_y), tonumber(data.garage_z),
        tonumber(data.storage_x), tonumber(data.storage_y), tonumber(data.storage_z), access.uid
    })
    if not id then return notify(src, 'error', 'Nu s-a putut crea mafia.') end

    local old = getMembership(leaderUid)
    if old then
        clearUserRank(leaderUid, old.shortcut)
        MySQL.update.await(('DELETE FROM %s WHERE uid = ?'):format(sqlName(Config.MembersTable)), { leaderUid })
    end
    MySQL.insert.await(('INSERT INTO %s (`gang_id`, `uid`, `role`, `added_by`, `added_at`, `last_seen`) VALUES (?, ?, \'Lider\', ?, NOW(), NOW())'):format(sqlName(Config.MembersTable)), { id, leaderUid, access.uid })
    updateUserRank(leaderUid, shortcut, color)
    logAction('create_gang', access.uid, id, leaderUid, { name = name, shortcut = shortcut })
    notify(src, 'success', 'Mafia a fost creata.')
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:updateGang', function(data)
    local src = source
    local access = canAccess(src)
    if not access or not access.syndicate then return end
    if not cooldown(src, 'updateGang') then return end

    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.id or data.gang_id or 0) or 0
    local gang = getGang(gangId)
    if not gang then return notify(src, 'warning', 'Mafia nu exista.') end

    local typ = trim(data.type)
    if typ ~= 'Mafie Oficiala' and typ ~= 'Mafie Neoficiala' then typ = gang.type end
    local name = trim(data.name)
    if name == '' then name = gang.name end
    local shortcut = trim(data.shortcut):upper():gsub('%s+', '')
    if shortcut == '' then shortcut = gang.shortcut end
    local color = normHex(data.color or gang.color)
    local leaderUid = tonumber(data.leader_uid or gang.leader_uid or 0) or 0

    MySQL.update.await(('UPDATE %s SET `type`=?, `name`=?, `shortcut`=?, `color`=?, `leader_uid`=?, `garage_x`=?, `garage_y`=?, `garage_z`=?, `storage_x`=?, `storage_y`=?, `storage_z`=?, `updated_at`=NOW() WHERE id=? LIMIT 1'):format(sqlName(Config.GangsTable)), {
        typ, name, shortcut, color, leaderUid,
        tonumber(data.garage_x), tonumber(data.garage_y), tonumber(data.garage_z),
        tonumber(data.storage_x), tonumber(data.storage_y), tonumber(data.storage_z), gangId
    })
    syncGangRanks(gangId)
    if leaderUid > 0 then
        MySQL.update.await(('UPDATE %s SET role=\'Lider\' WHERE gang_id=? AND uid=?'):format(sqlName(Config.MembersTable)), { gangId, leaderUid })
    end
    logAction('update_gang', access.uid, gangId, leaderUid, data)
    notify(src, 'success', 'Mafia a fost actualizata.')
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:deleteGang', function(gangId)
    local src = source
    local access = canAccess(src)
    if not access or not access.syndicate then return end
    gangId = tonumber(gangId or 0) or 0
    local gang = getGang(gangId)
    if not gang then return end
    local members = MySQL.query.await(('SELECT uid FROM %s WHERE gang_id=?'):format(sqlName(Config.MembersTable)), { gangId }) or {}
    for _, m in ipairs(members) do clearUserRank(m.uid, gang.shortcut) end
    MySQL.update.await(('UPDATE %s SET active=0, updated_at=NOW() WHERE id=? LIMIT 1'):format(sqlName(Config.GangsTable)), { gangId })
    MySQL.update.await(('DELETE FROM %s WHERE gang_id=?'):format(sqlName(Config.MembersTable)), { gangId })
    logAction('delete_gang', access.uid, gangId, 0, {})
    notify(src, 'success', 'Mafia a fost dezactivata.')
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:addMember', function(data)
    local src = source
    local access = canAccess(src)
    if not access then return end
    if not cooldown(src, 'addMember') then return end
    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gang_id or access.gangId or 0) or 0
    local targetUid = tonumber(data.uid or data.cnp or 0) or 0
    local role = normalizeRole(data.role)
    local gang = getGang(gangId)
    if not gang then return notify(src, 'warning', 'Mafia nu exista.') end
    if not getUserByUid(targetUid) then return notify(src, 'warning', 'CNP invalid.') end
    if not canManageTarget(access, gangId, 'Membru', role) then return notify(src, 'warning', 'Nu ai acces sa adaugi acest grad.') end
    if memberCount(gangId) >= (Config.MaxMembersPerGang or 120) then return notify(src, 'warning', 'Mafia a atins limita de membri.') end

    local old = getMembership(targetUid)
    if old then
        clearUserRank(targetUid, old.shortcut)
        MySQL.update.await(('DELETE FROM %s WHERE uid = ?'):format(sqlName(Config.MembersTable)), { targetUid })
    end

    MySQL.insert.await(('INSERT INTO %s (`gang_id`, `uid`, `role`, `added_by`, `added_at`, `last_seen`) VALUES (?, ?, ?, ?, NOW(), NOW())'):format(sqlName(Config.MembersTable)), { gangId, targetUid, role, access.uid })
    updateUserRank(targetUid, gang.shortcut, gang.color)
    if role == 'Lider' then
        MySQL.update.await(('UPDATE %s SET leader_uid=? WHERE id=? LIMIT 1'):format(sqlName(Config.GangsTable)), { targetUid, gangId })
    end
    logAction('add_member', access.uid, gangId, targetUid, { role = role })
    notify(src, 'success', 'Membrul a fost adaugat in mafie.')
    local targetSrc = getPlayerByUid(targetUid)
    if targetSrc then notify(targetSrc, 'info', 'Ai fost adaugat intr-o mafie.') end
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:kickMember', function(data)
    local src = source
    local access = canAccess(src)
    if not access then return end
    if not cooldown(src, 'kickMember') then return end
    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gang_id or access.gangId or 0) or 0
    local targetUid = tonumber(data.uid or data.cnp or 0) or 0
    local member = MySQL.single.await(('SELECT * FROM %s WHERE gang_id=? AND uid=? LIMIT 1'):format(sqlName(Config.MembersTable)), { gangId, targetUid })
    local gang = getGang(gangId)
    if not member or not gang then return notify(src, 'warning', 'Membrul nu exista.') end
    if targetUid == access.uid and not access.syndicate then return notify(src, 'warning', 'Nu te poti scoate singur.') end
    if not canManageTarget(access, gangId, member.role, member.role) then return notify(src, 'warning', 'Nu ai acces sa scoti acest membru.') end

    MySQL.update.await(('DELETE FROM %s WHERE gang_id=? AND uid=?'):format(sqlName(Config.MembersTable)), { gangId, targetUid })
    clearUserRank(targetUid, gang.shortcut)
    logAction('kick_member', access.uid, gangId, targetUid, { role = member.role })
    notify(src, 'success', 'Membrul a fost scos din mafie.')
    local targetSrc = getPlayerByUid(targetUid)
    if targetSrc then notify(targetSrc, 'warning', 'Ai fost scos din mafie.') end
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:changeRole', function(data)
    local src = source
    local access = canAccess(src)
    if not access then return end
    if not cooldown(src, 'changeRole') then return end
    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gang_id or access.gangId or 0) or 0
    local targetUid = tonumber(data.uid or data.cnp or 0) or 0
    local role = normalizeRole(data.role)
    local member = MySQL.single.await(('SELECT * FROM %s WHERE gang_id=? AND uid=? LIMIT 1'):format(sqlName(Config.MembersTable)), { gangId, targetUid })
    if not member then return notify(src, 'warning', 'Membrul nu exista.') end
    if not canManageTarget(access, gangId, member.role, role) then return notify(src, 'warning', 'Nu ai acces sa schimbi acest grad.') end

    MySQL.update.await(('UPDATE %s SET role=? WHERE gang_id=? AND uid=? LIMIT 1'):format(sqlName(Config.MembersTable)), { role, gangId, targetUid })
    if role == 'Lider' then
        MySQL.update.await(('UPDATE %s SET leader_uid=? WHERE id=? LIMIT 1'):format(sqlName(Config.GangsTable)), { targetUid, gangId })
    end
    logAction('change_role', access.uid, gangId, targetUid, { role = role })
    notify(src, 'success', 'Gradul a fost schimbat.')
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:createTaxCategory', function(data)
    local src = source
    local access = canAccess(src)
    if not access or not access.syndicate then return end
    data = type(data) == 'table' and data or {}
    local name = trim(data.name)
    if name == '' then return notify(src, 'warning', 'Pune numele taxei.') end
    MySQL.insert.await(('INSERT INTO %s (`name`, `description`, `active`, `created_by`, `created_at`) VALUES (?, ?, 1, ?, NOW())'):format(sqlName(Config.TaxCategoriesTable)), { name, trim(data.description), access.uid })
    notify(src, 'success', 'Categoria de taxa a fost adaugata.')
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:deleteTaxCategory', function(categoryId)
    local src = source
    local access = canAccess(src)
    if not access or not access.syndicate then return end
    categoryId = tonumber(categoryId or 0) or 0
    MySQL.update.await(('UPDATE %s SET active=0 WHERE id=? LIMIT 1'):format(sqlName(Config.TaxCategoriesTable)), { categoryId })
    notify(src, 'success', 'Categoria a fost stearsa.')
    pushUpdate(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:offerTaxToPlayer', function(data)
    local src = source
    local access = canAccess(src)
    if not access then return end
    if not cooldown(src, 'offerTax') then return end
    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gang_id or access.gangId or 0) or 0
    local categoryId = tonumber(data.category_id or 0) or 0
    local amount = math.floor(tonumber(data.amount or 0) or 0)
    local target = tonumber(data.target or 0) or 0
    if target <= 0 or GetPlayerPing(target) <= 0 then return notify(src, 'warning', 'Jucatorul selectat nu mai este pe oras.') end
    if not amountAllowed(amount) then return notify(src, 'warning', 'Suma taxei nu este valida.') end
    local category = getCategory(categoryId)
    if not category then return notify(src, 'warning', 'Categoria taxei nu exista.') end
    local gang = getGang(gangId)
    if not gang then return notify(src, 'warning', 'Mafia nu exista.') end
    if not access.syndicate and tonumber(access.gangId or 0) ~= gangId then return end
    local targetUid = getUid(target)
    if not targetUid then return notify(src, 'warning', 'Jucatorul nu este logat.') end
    if targetUid == access.uid then return notify(src, 'warning', 'Nu poti sa iti oferi taxa singur.') end
    local cash, bank = getMoney(targetUid)
    if cash < amount and bank < amount then
        notify(src, 'warning', 'Persoana selectata nu are suma necesara in cash sau banca.')
        return
    end

    local requestId = tostring(src) .. ':' .. tostring(GetGameTimer()) .. ':' .. tostring(math.random(1000, 9999))
    PendingTaxes[requestId] = {
        id = requestId,
        gangId = gangId,
        gangName = gang.name,
        categoryId = categoryId,
        categoryName = category.name,
        amount = amount,
        issuerSrc = src,
        issuerUid = access.uid,
        targetSrc = target,
        targetUid = targetUid,
        expires = GetGameTimer() + (Config.TaxRequestTimeoutMs or 35000)
    }

    TriggerClientEvent('driftzone_gangpanel:client:incomingTax', target, {
        requestId = requestId,
        gangName = gang.name,
        categoryName = category.name,
        amount = amount,
        issuerCnp = access.uid,
        issuerName = userDisplay(access.uid)
    })
    notify(src, 'info', 'Taxa a fost trimisa catre persoana selectata.')
end)

RegisterNetEvent('driftzone_gangpanel:server:payTax', function(requestId)
    local src = source
    local req = PendingTaxes[tostring(requestId or '')]
    if not req or req.targetSrc ~= src then return end
    if GetGameTimer() > req.expires then
        PendingTaxes[tostring(requestId)] = nil
        return notify(src, 'warning', 'Taxa a expirat.')
    end
    local ok, paidFrom = takeMoney(req.targetUid, req.amount)
    if not ok then
        notify(src, 'warning', 'Nu mai ai suficienti bani pentru taxa.')
        if req.issuerSrc and GetPlayerPing(req.issuerSrc) > 0 then notify(req.issuerSrc, 'warning', 'Persoana nu mai are bani pentru taxa.') end
        PendingTaxes[tostring(requestId)] = nil
        return
    end

    MySQL.insert.await(('INSERT INTO %s (`gang_id`, `category_id`, `category_name`, `amount`, `payer_uid`, `issuer_uid`, `paid_from`, `status`, `created_at`, `paid_at`) VALUES (?, ?, ?, ?, ?, ?, ?, \'paid\', NOW(), NOW())'):format(sqlName(Config.TaxRecordsTable)), {
        req.gangId, req.categoryId, req.categoryName, req.amount, req.targetUid, req.issuerUid, paidFrom
    })
    addRevenue(req.gangId, req.amount, req.issuerUid, 'tax_paid')
    PendingTaxes[tostring(requestId)] = nil
    notify(src, 'success', 'Taxa a fost platita.')
    if req.issuerSrc and GetPlayerPing(req.issuerSrc) > 0 then
        notify(req.issuerSrc, 'success', 'Taxa a fost platita.')
        pushUpdate(req.issuerSrc)
    end
end)

RegisterNetEvent('driftzone_gangpanel:server:refuseTax', function(requestId)
    local src = source
    local req = PendingTaxes[tostring(requestId or '')]
    if not req or req.targetSrc ~= src then return end
    MySQL.insert.await(('INSERT INTO %s (`gang_id`, `category_id`, `category_name`, `amount`, `payer_uid`, `issuer_uid`, `paid_from`, `status`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, \'\', \'refused\', NOW())'):format(sqlName(Config.TaxRecordsTable)), {
        req.gangId, req.categoryId, req.categoryName, req.amount, req.targetUid, req.issuerUid
    })
    PendingTaxes[tostring(requestId)] = nil
    notify(src, 'info', 'Ai refuzat taxa.')
    if req.issuerSrc and GetPlayerPing(req.issuerSrc) > 0 then notify(req.issuerSrc, 'warning', 'Taxa a fost refuzata.') end
end)

RegisterNetEvent('driftzone_gangpanel:server:adjustRevenue', function(data)
    local src = source
    local access = canAccess(src)
    if not access or not access.syndicate then return end
    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gang_id or 0) or 0
    local amount = math.floor(tonumber(data.amount or 0) or 0)
    local mode = tostring(data.mode or 'add')
    if amount <= 0 then return notify(src, 'warning', 'Suma invalida.') end
    if mode == 'remove' then amount = -amount end
    if addRevenue(gangId, amount, access.uid, mode == 'remove' and 'syndicate_remove' or 'syndicate_add') then
        notify(src, 'success', 'Veniturile au fost actualizate.')
        pushUpdate(src)
    end
end)

RegisterNetEvent('driftzone_gangpanel:server:requestWithdrawal', function(gangId)
    local src = source
    local access = canAccess(src)
    if not access then return end
    gangId = tonumber(gangId or access.gangId or 0) or 0
    local gang = getGang(gangId)
    if not gang then return end
    if not access.syndicate then
        if tonumber(access.gangId or 0) ~= gangId or access.role ~= 'Lider' then
            return notify(src, 'warning', 'Doar liderul poate solicita retragerea.')
        end
    end
    local revenue = math.floor(tonumber(gang.revenue or 0) or 0)
    if revenue <= 0 then return notify(src, 'warning', 'Mafia nu are venituri disponibile.') end
    local existing = MySQL.single.await(('SELECT id FROM %s WHERE gang_id=? AND status IN (\'processing\', \'ready\') LIMIT 1'):format(sqlName(Config.WithdrawalsTable)), { gangId })
    if existing then return notify(src, 'warning', 'Exista deja o retragere in procesare.') end

    local locations = Config.Withdrawal.Locations or {}
    local loc = locations[math.random(1, #locations)]
    if not loc then return notify(src, 'error', 'Nu exista locatii de retragere in config.') end
    local minDelay = tonumber(Config.Withdrawal.MinDelaySeconds or 300) or 300
    local maxDelay = tonumber(Config.Withdrawal.MaxDelaySeconds or 600) or 600
    if maxDelay < minDelay then maxDelay = minDelay end
    local delay = math.random(minDelay, maxDelay)

    local affected = MySQL.update.await(('UPDATE %s SET revenue = 0, updated_at = NOW() WHERE id=? AND revenue >= ? LIMIT 1'):format(sqlName(Config.GangsTable)), { gangId, revenue })
    if not affected or affected <= 0 then return notify(src, 'warning', 'Retragerea nu a putut fi pornita.') end

    local wid = MySQL.insert.await(('INSERT INTO %s (`gang_id`, `leader_uid`, `amount`, `x`, `y`, `z`, `status`, `ready_at`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, \'processing\', DATE_ADD(NOW(), INTERVAL ? SECOND), NOW())'):format(sqlName(Config.WithdrawalsTable)), {
        gangId, access.uid, revenue, loc.x, loc.y, loc.z, delay
    })
    logRevenue(gangId, 'withdraw_processing', -revenue, access.uid, { withdrawal = wid, delay = delay })
    notify(src, 'info', 'Retragerea se proceseaza. In scurt timp vei primi o locatie discreta pentru ridicarea banilor.')
    pushUpdate(src)

    SetTimeout(delay * 1000, function()
        MySQL.update.await(('UPDATE %s SET status=\'ready\' WHERE id=? AND status=\'processing\' LIMIT 1'):format(sqlName(Config.WithdrawalsTable)), { wid })
        local leaderSrc = getPlayerByUid(access.uid)
        if leaderSrc then
            TriggerClientEvent('driftzone_gangpanel:client:setWithdrawalPickup', leaderSrc, { id = wid, amount = revenue, x = loc.x, y = loc.y, z = loc.z })
            notify(leaderSrc, 'info', 'Locatia pentru ridicarea banilor a fost marcata cu un blip albastru.')
        end
    end)
end)

RegisterNetEvent('driftzone_gangpanel:server:claimWithdrawal', function(withdrawalId)
    local src = source
    local access = canAccess(src)
    if not access then return end
    withdrawalId = tonumber(withdrawalId or 0) or 0
    local row = MySQL.single.await(('SELECT * FROM %s WHERE id=? AND status=\'ready\' LIMIT 1'):format(sqlName(Config.WithdrawalsTable)), { withdrawalId })
    if not row then return notify(src, 'warning', 'Nu exista bani de revendicat aici.') end
    if tonumber(row.leader_uid) ~= tonumber(access.uid) and not access.syndicate then return notify(src, 'warning', 'Aceasta retragere nu iti apartine.') end
    local ped = GetPlayerPed(src)
    local coords = ped and GetEntityCoords(ped)
    if coords then
        local dist = #(coords - vector3(row.x + 0.0, row.y + 0.0, row.z + 0.0))
        if dist > (Config.Withdrawal.ClaimDistance or 2.0) + 1.5 then return notify(src, 'warning', 'Esti prea departe de locatie.') end
    end
    local ok, msg = giveDirtyMoney(access.uid, row.amount)
    if not ok then return notify(src, 'warning', msg or 'Nu s-au putut adauga banii in inventar.') end
    MySQL.update.await(('UPDATE %s SET status=\'claimed\', claimed_at=NOW() WHERE id=? LIMIT 1'):format(sqlName(Config.WithdrawalsTable)), { withdrawalId })
    logRevenue(row.gang_id, 'withdraw_claimed', row.amount, access.uid, { withdrawal = withdrawalId })
    TriggerClientEvent('driftzone_gangpanel:client:clearWithdrawalPickup', src)
    notify(src, 'success', ('Ai revendicat %s dirtymoney.'):format(tostring(row.amount)))
end)

AddEventHandler('playerDropped', function()
    OpenPlayers[source] = nil
    UidCache[source] = nil
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        for id, req in pairs(PendingTaxes) do
            if now > (req.expires or 0) then
                PendingTaxes[id] = nil
                if req.issuerSrc and GetPlayerPing(req.issuerSrc) > 0 then notify(req.issuerSrc, 'warning', 'Taxa a expirat. Persoana nu a raspuns.') end
                if req.targetSrc and GetPlayerPing(req.targetSrc) > 0 then TriggerClientEvent('driftzone_gangpanel:client:clearIncomingTax', req.targetSrc, id) end
            end
        end
        Wait(3000)
    end
end)

local function tryQuery(query)
    pcall(function() MySQL.query.await(query, {}) end)
end

local function ensureRuntimeSchema()
    -- Safe runtime guard: daca DB-ul e vechi, adauga coloanele critice fara sa opreasca resource-ul.
    tryQuery([[ALTER TABLE `users` ADD COLUMN `sindicate` TINYINT(1) NOT NULL DEFAULT 0]])
    tryQuery([[ALTER TABLE `users` ADD COLUMN `syndicate` TINYINT(1) NOT NULL DEFAULT 0]])
    tryQuery([[ALTER TABLE `users` ADD COLUMN `rank` VARCHAR(64) NOT NULL DEFAULT '']])
    tryQuery([[ALTER TABLE `users` ADD COLUMN `rankcolor` VARCHAR(16) NOT NULL DEFAULT '']])
    tryQuery([[ALTER TABLE `users` ADD COLUMN `bank` BIGINT NOT NULL DEFAULT 0]])
    tryQuery([[ALTER TABLE `gangs` ADD COLUMN `type` VARCHAR(64) NOT NULL DEFAULT 'Mafie Neoficiala']])
    tryQuery([[ALTER TABLE `gangs` ADD COLUMN `revenue` BIGINT NOT NULL DEFAULT 0]])
    tryQuery([[ALTER TABLE `gangs` ADD COLUMN `active` TINYINT(1) NOT NULL DEFAULT 1]])
    tryQuery([[UPDATE `gangs` SET `type` = 'Mafie Neoficiala' WHERE `type` = 'Neo' OR `type` = '' OR `type` IS NULL]])
    tryQuery([[UPDATE `gangs` SET `type` = 'Mafie Oficiala' WHERE `type` = 'Oficiala']])
end

CreateThread(function()
    Wait(1200)
    ensureRuntimeSchema()
    pcall(function()
        MySQL.update.await(([[INSERT INTO %s (`item_id`, `item_name`, `image`, `tradable`, `stackable`, `usable`, `giveable`, `max_stack`, `created_at`, `updated_at`) VALUES (?, ?, '', 1, 1, 0, 1, 100000000, NOW(), NOW()) ON DUPLICATE KEY UPDATE item_name=VALUES(item_name), stackable=1, giveable=1, max_stack=VALUES(max_stack), updated_at=NOW()]]):format(sqlName('inventory_items')), {
            Config.Withdrawal.DirtyMoneyItem or 'dirtymoney', 'Dirty Money'
        })
    end)
    print('[DRIFTZONE_GANGPANEL] V4 premium loaded.')
end)
