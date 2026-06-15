local OpenPlayers = {}
local LastAction = {}
local UidCache = {}
local LastSeenUpdate = {}

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
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
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 4500, tostring(msg or ''))
end

local function uiToast(src, typ, msg)
    TriggerClientEvent('driftzone_gangpanel:client:toast', src, typ or 'info', tostring(msg or ''))
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
    if now - last < (Config.ActionCooldownMs or 450) then return false end
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
    if state and state.dz_logged == true then return true end

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

local function getUsername(uid)
    local row = getUserByUid(uid)
    if not row then return 'UID ' .. tostring(uid or 0) end
    return tostring(row[Config.UsernameColumn or 'username'] or row.username or ('UID ' .. tostring(uid)))
end

local function isSyndicateUid(uid)
    local row = getUserByUid(uid)
    if not row then return false end
    local v = row[Config.SyndicateColumn or 'sindicate']
    return v == true or tonumber(v or 0) == 1 or tostring(v or ''):lower() == 'yes'
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

local function getOnlineMap()
    local map = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local uid = src and getUid(src)
        if uid then map[uid] = src end
    end
    return map
end

local function updateLastSeen(uid)
    uid = tonumber(uid)
    if not uid then return end
    local now = GetGameTimer()
    if LastSeenUpdate[uid] and now - LastSeenUpdate[uid] < (Config.UpdateLastSeenEveryMs or 60000) then return end
    LastSeenUpdate[uid] = now
    MySQL.update.await(('UPDATE %s SET last_seen = NOW() WHERE uid = ?'):format(sqlName(Config.MembersTable)), { uid })
end

local function getMembership(uid)
    uid = tonumber(uid)
    if not uid then return nil end
    return MySQL.single.await(([[
        SELECT gm.*, g.name AS gang_name, g.shortcut, g.color, g.gang_type, g.active
        FROM %s gm
        JOIN %s g ON g.id = gm.gang_id
        WHERE gm.uid = ? AND g.active = 1
        LIMIT 1
    ]]):format(sqlName(Config.MembersTable), sqlName(Config.GangsTable)), { uid })
end

local function getRolePower(role)
    return tonumber((Config.RolePower or {})[tostring(role or '')] or 0) or 0
end

local function getAccess(src)
    local uid = getUid(src)
    if not uid then return nil end

    updateLastSeen(uid)

    local syndicate = isSyndicateUid(uid)
    if syndicate then
        return { uid = uid, access = 'syndicate', power = 100, label = 'Syndicate', syndicate = true, username = getUsername(uid) }
    end

    local member = getMembership(uid)
    if member then
        local role = tostring(member.role or Config.Roles.member)
        local power = getRolePower(role)
        local access = 'member'
        if role == Config.Roles.leader then access = 'leader'
        elseif role == Config.Roles.coleader then access = 'coleader' end

        return {
            uid = uid,
            access = access,
            power = power,
            label = role,
            syndicate = false,
            gangId = tonumber(member.gang_id),
            gangName = member.gang_name,
            username = getUsername(uid),
            membership = member
        }
    end

    return { uid = uid, access = 'none', power = 0, syndicate = false, username = getUsername(uid) }
end

local function requireAccess(src)
    if not isLogged(src) then
        TriggerClientEvent('driftzone_gangpanel:client:deny', src, 'Trebuie sa fii logat.')
        return nil
    end

    local access = getAccess(src)
    if not access or access.access == 'none' then
        TriggerClientEvent('driftzone_gangpanel:client:deny', src, 'Nu ai acces la gang panel.')
        return nil
    end

    return access
end

local function requireSyndicate(src)
    local access = requireAccess(src)
    if not access then return nil end
    if access.syndicate ~= true then
        uiToast(src, 'error', 'Doar syndicate poate face aceasta actiune.')
        return nil
    end
    return access
end

local function logAction(action, actorUid, gangId, targetUid, details)
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (gang_id, action, actor_uid, target_uid, details, created_at) VALUES (?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.LogsTable)), {
            tonumber(gangId or 0) or 0,
            tostring(action or ''),
            tonumber(actorUid or 0) or 0,
            tonumber(targetUid or 0) or 0,
            jsonEncode(details or {})
        })
    end)
end

local function vectorFromData(data, prefix)
    data = type(data) == 'table' and data or {}
    local x = tonumber(data[prefix .. '_x'] or data[prefix .. 'X'] or data[prefix .. 'x'])
    local y = tonumber(data[prefix .. '_y'] or data[prefix .. 'Y'] or data[prefix .. 'y'])
    local z = tonumber(data[prefix .. '_z'] or data[prefix .. 'Z'] or data[prefix .. 'z'])
    if x and y and z then return x, y, z end
    return nil, nil, nil
end

local function sanitizeGangData(data, partial)
    data = type(data) == 'table' and data or {}
    local out = {}

    out.name = trim(data.name):sub(1, 64)
    out.shortcut = trim(data.shortcut):upper():gsub('%s+', ''):sub(1, 16)
    out.gang_type = trim(data.gang_type or data.type)
    out.color = normHex(data.color)
    out.leader_uid = tonumber(data.leader_uid or data.leaderUid or data.leader or 0) or 0
    out.garage_x, out.garage_y, out.garage_z = vectorFromData(data, 'garage')
    out.storage_x, out.storage_y, out.storage_z = vectorFromData(data, 'storage')

    local validType = false
    for _, t in ipairs(Config.GangTypes or {}) do
        if out.gang_type == t then validType = true break end
    end
    if not validType then out.gang_type = 'Neo' end

    if not partial then
        if out.name == '' then return nil, 'Numele gangului este obligatoriu.' end
        if out.shortcut == '' then return nil, 'Shortcut obligatoriu.' end
        if out.leader_uid <= 0 then return nil, 'ID-ul liderului este obligatoriu.' end
    end

    return out, nil
end

local function memberCount(gangId)
    local row = MySQL.single.await(('SELECT COUNT(*) AS c FROM %s WHERE gang_id = ?'):format(sqlName(Config.MembersTable)), { gangId })
    return tonumber(row and row.c or 0) or 0
end

local function getGangById(gangId)
    return MySQL.single.await(('SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1'):format(sqlName(Config.GangsTable)), { tonumber(gangId or 0) or 0 })
end

local function buildGangsList(access)
    local rows = {}
    if access.syndicate then
        rows = MySQL.query.await(('SELECT * FROM %s WHERE active = 1 ORDER BY id DESC'):format(sqlName(Config.GangsTable)), {}) or {}
    elseif access.gangId then
        rows = MySQL.query.await(('SELECT * FROM %s WHERE active = 1 AND id = ? LIMIT 1'):format(sqlName(Config.GangsTable)), { access.gangId }) or {}
    end

    local online = getOnlineMap()
    local out = {}
    for _, g in ipairs(rows) do
        local members = MySQL.query.await(('SELECT uid, role FROM %s WHERE gang_id = ?'):format(sqlName(Config.MembersTable)), { g.id }) or {}
        local total, onlineCount, leaders, coleaders = #members, 0, 0, 0
        for _, m in ipairs(members) do
            if online[tonumber(m.uid)] then onlineCount = onlineCount + 1 end
            if m.role == Config.Roles.leader then leaders = leaders + 1 end
            if m.role == Config.Roles.coleader then coleaders = coleaders + 1 end
        end

        out[#out + 1] = {
            id = tonumber(g.id),
            name = g.name,
            shortcut = g.shortcut,
            type = g.gang_type,
            color = g.color,
            leader_uid = tonumber(g.leader_uid or 0) or 0,
            totalMembers = total,
            onlineMembers = onlineCount,
            leaders = leaders,
            coleaders = coleaders,
            garage = { x = g.garage_x, y = g.garage_y, z = g.garage_z },
            storage = { x = g.storage_x, y = g.storage_y, z = g.storage_z }
        }
    end
    return out
end

local function buildMemberList(gangId, access)
    local online = getOnlineMap()
    local rows = MySQL.query.await(([[
        SELECT gm.uid, gm.role, gm.joined_at, gm.last_seen, u.%s AS username
        FROM %s gm
        LEFT JOIN %s u ON u.%s = gm.uid
        WHERE gm.gang_id = ?
        ORDER BY FIELD(gm.role, 'Lider', 'Co-Lider', 'Membru'), gm.uid ASC
    ]]):format(sqlName(Config.UsernameColumn or 'username'), sqlName(Config.MembersTable), sqlName(Config.UsersTable), sqlName(Config.UsersIdColumn)), { gangId }) or {}

    local out = {}
    for _, row in ipairs(rows) do
        local uid = tonumber(row.uid or 0) or 0
        local onlineSrc = online[uid]
        if access.syndicate then
            out[#out + 1] = {
                uid = uid,
                source = onlineSrc or 0,
                username = row.username or ('UID ' .. uid),
                role = row.role,
                online = onlineSrc ~= nil,
                joined_at = row.joined_at,
                last_seen = row.last_seen
            }
        else
            out[#out + 1] = {
                uid = uid,
                username = row.username or ('Membru'),
                role = row.role,
                online = onlineSrc ~= nil,
                joined_at = row.joined_at,
                last_seen = row.last_seen
            }
        end
    end
    return out
end

local function buildLogs(gangId, access)
    if not access.syndicate then return {} end
    return MySQL.query.await(('SELECT * FROM %s WHERE gang_id = ? ORDER BY id DESC LIMIT 30'):format(sqlName(Config.LogsTable)), { gangId }) or {}
end

local function buildPayload(src, access)
    access = access or getAccess(src)
    local payload = {
        mainColor = Config.MainColor,
        self = {
            uid = access.uid,
            username = access.username,
            access = access.access,
            role = access.label,
            gangId = access.gangId or 0,
            syndicate = access.syndicate == true
        },
        config = {
            roles = Config.Roles,
            gangTypes = Config.GangTypes,
            allowLeaderPromoteCoLeader = Config.AllowLeaderPromoteCoLeader ~= false,
            allowCoLeaderKickMembers = Config.AllowCoLeaderKickMembers ~= false,
            allowCoLeaderInviteMembers = Config.AllowCoLeaderInviteMembers ~= false
        },
        gangs = buildGangsList(access),
        details = nil
    }

    if access.gangId then
        local gang = getGangById(access.gangId)
        if gang then
            payload.details = {
                gang = gang,
                members = buildMemberList(access.gangId, access),
                logs = buildLogs(access.gangId, access)
            }
        end
    end

    return payload
end

local function pushRefresh(src)
    local access = requireAccess(src)
    if not access then return end
    TriggerClientEvent('driftzone_gangpanel:client:update', src, buildPayload(src, access))
end

local function refreshGangWatchers(gangId)
    gangId = tonumber(gangId)
    for src in pairs(OpenPlayers) do
        local access = getAccess(src)
        if access and (access.syndicate or tonumber(access.gangId) == gangId) then
            TriggerClientEvent('driftzone_gangpanel:client:update', src, buildPayload(src, access))
        end
    end
end

RegisterNetEvent('driftzone_gangpanel:server:requestOpen', function()
    local src = source
    local access = requireAccess(src)
    if not access then return end

    OpenPlayers[src] = true
    TriggerClientEvent('driftzone_gangpanel:client:open', src, buildPayload(src, access))
end)

RegisterNetEvent('driftzone_gangpanel:server:closed', function()
    OpenPlayers[source] = nil
end)

RegisterNetEvent('driftzone_gangpanel:server:refresh', function()
    local src = source
    if not cooldown(src, 'refresh') then return end
    pushRefresh(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:getGangDetails', function(gangId)
    local src = source
    local access = requireAccess(src)
    if not access then return end

    gangId = tonumber(gangId or 0) or 0
    if gangId <= 0 then return end
    if not access.syndicate and tonumber(access.gangId or 0) ~= gangId then
        return uiToast(src, 'error', 'Nu ai acces la acest gang.')
    end

    local gang = getGangById(gangId)
    if not gang then return uiToast(src, 'error', 'Gang invalid.') end

    TriggerClientEvent('driftzone_gangpanel:client:update', src, {
        detailsOnly = true,
        details = {
            gang = gang,
            members = buildMemberList(gangId, access),
            logs = buildLogs(gangId, access)
        }
    })
end)

RegisterNetEvent('driftzone_gangpanel:server:createGang', function(data)
    local src = source
    local access = requireSyndicate(src)
    if not access or not cooldown(src, 'create') then return end

    local g, err = sanitizeGangData(data, false)
    if not g then return uiToast(src, 'error', err) end

    local leader = getUserByUid(g.leader_uid)
    if not leader then return uiToast(src, 'error', 'Liderul nu exista in users.') end

    local alreadyMember = getMembership(g.leader_uid)
    if alreadyMember then return uiToast(src, 'error', 'Liderul este deja intr-un gang.') end

    local exists = MySQL.single.await(('SELECT id FROM %s WHERE shortcut = ? AND active = 1 LIMIT 1'):format(sqlName(Config.GangsTable)), { g.shortcut })
    if exists then return uiToast(src, 'error', 'Shortcut deja folosit.') end

    local gangId = MySQL.insert.await(([[
        INSERT INTO %s (gang_type, name, shortcut, color, leader_uid, garage_x, garage_y, garage_z, storage_x, storage_y, storage_z, created_by_uid, created_at, updated_at, active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), 1)
    ]]):format(sqlName(Config.GangsTable)), {
        g.gang_type, g.name, g.shortcut, g.color, g.leader_uid,
        g.garage_x, g.garage_y, g.garage_z,
        g.storage_x, g.storage_y, g.storage_z,
        access.uid
    })

    MySQL.insert.await(('INSERT INTO %s (gang_id, uid, role, added_by_uid, joined_at, last_seen) VALUES (?, ?, ?, ?, NOW(), NOW())'):format(sqlName(Config.MembersTable)), {
        gangId, g.leader_uid, Config.Roles.leader, access.uid
    })

    logAction('create_gang', access.uid, gangId, g.leader_uid, g)
    runHook('AfterCreateGang', src, gangId, g)
    uiToast(src, 'success', 'Gang creat cu succes.')
    refreshGangWatchers(gangId)
    pushRefresh(src)
end)

RegisterNetEvent('driftzone_gangpanel:server:updateGang', function(data)
    local src = source
    local access = requireSyndicate(src)
    if not access or not cooldown(src, 'updateGang') then return end

    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gangId or data.id or 0) or 0
    if gangId <= 0 then return uiToast(src, 'error', 'Gang invalid.') end

    local gang = getGangById(gangId)
    if not gang then return uiToast(src, 'error', 'Gang invalid.') end

    local g = sanitizeGangData(data, true)
    if g.name == '' then g.name = gang.name end
    if g.shortcut == '' then g.shortcut = gang.shortcut end
    if g.leader_uid <= 0 then g.leader_uid = tonumber(gang.leader_uid or 0) or 0 end

    local existingShortcut = MySQL.single.await(('SELECT id FROM %s WHERE shortcut = ? AND id <> ? AND active = 1 LIMIT 1'):format(sqlName(Config.GangsTable)), { g.shortcut, gangId })
    if existingShortcut then return uiToast(src, 'error', 'Shortcut deja folosit.') end

    MySQL.update.await(([[
        UPDATE %s SET gang_type = ?, name = ?, shortcut = ?, color = ?, leader_uid = ?, garage_x = ?, garage_y = ?, garage_z = ?, storage_x = ?, storage_y = ?, storage_z = ?, updated_at = NOW()
        WHERE id = ?
    ]]):format(sqlName(Config.GangsTable)), {
        g.gang_type, g.name, g.shortcut, g.color, g.leader_uid,
        g.garage_x, g.garage_y, g.garage_z,
        g.storage_x, g.storage_y, g.storage_z,
        gangId
    })

    if g.leader_uid > 0 then
        MySQL.update.await(('UPDATE %s SET role = ? WHERE gang_id = ? AND role = ?'):format(sqlName(Config.MembersTable)), { Config.Roles.coleader, gangId, Config.Roles.leader })
        MySQL.update.await(('INSERT INTO %s (gang_id, uid, role, added_by_uid, joined_at, last_seen) VALUES (?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE gang_id = VALUES(gang_id), role = VALUES(role), last_seen = NOW()'):format(sqlName(Config.MembersTable)), {
            gangId, g.leader_uid, Config.Roles.leader, access.uid
        })
    end

    logAction('update_gang', access.uid, gangId, g.leader_uid, g)
    runHook('AfterUpdateGang', src, gangId, g)
    uiToast(src, 'success', 'Gang actualizat.')
    refreshGangWatchers(gangId)
end)

RegisterNetEvent('driftzone_gangpanel:server:deleteGang', function(gangId)
    local src = source
    local access = requireSyndicate(src)
    if not access or not cooldown(src, 'deleteGang') then return end

    gangId = tonumber(gangId or 0) or 0
    if gangId <= 0 then return uiToast(src, 'error', 'Gang invalid.') end

    MySQL.update.await(('UPDATE %s SET active = 0, updated_at = NOW() WHERE id = ?'):format(sqlName(Config.GangsTable)), { gangId })
    logAction('delete_gang', access.uid, gangId, 0, {})
    runHook('AfterDeleteGang', src, gangId)
    uiToast(src, 'success', 'Gang dezactivat.')
    refreshGangWatchers(gangId)
end)

local function canManageMembers(access, gangId, targetRole, newRole)
    if access.syndicate then return true end
    if not access.gangId or tonumber(access.gangId) ~= tonumber(gangId) then return false end
    local role = tostring(access.label or '')

    if role == Config.Roles.leader then
        if newRole == Config.Roles.leader then return false end
        return true
    end

    if role == Config.Roles.coleader then
        if newRole and newRole ~= Config.Roles.member then return false end
        if targetRole and targetRole ~= Config.Roles.member then return false end
        return Config.AllowCoLeaderInviteMembers ~= false or Config.AllowCoLeaderKickMembers ~= false
    end

    return false
end

RegisterNetEvent('driftzone_gangpanel:server:addMember', function(data)
    local src = source
    local access = requireAccess(src)
    if not access or not cooldown(src, 'addMember') then return end

    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gangId or access.gangId or 0) or 0
    local targetUid = tonumber(data.uid or data.targetUid or 0) or 0
    local role = tostring(data.role or Config.Roles.member)

    if role ~= Config.Roles.member and role ~= Config.Roles.coleader and role ~= Config.Roles.leader then role = Config.Roles.member end
    if targetUid <= 0 then return uiToast(src, 'error', 'UID invalid.') end
    if gangId <= 0 then return uiToast(src, 'error', 'Gang invalid.') end

    if not canManageMembers(access, gangId, nil, role) then
        return uiToast(src, 'error', 'Nu ai acces sa adaugi membri.')
    end

    if not access.syndicate and access.label == Config.Roles.coleader then role = Config.Roles.member end

    local user = getUserByUid(targetUid)
    if not user then return uiToast(src, 'error', 'UID-ul nu exista in users.') end

    local count = memberCount(gangId)
    if count >= (Config.MaxMembersPerGang or 120) then return uiToast(src, 'error', 'Gangul este plin.') end

    local existing = getMembership(targetUid)
    if existing and tonumber(existing.gang_id) ~= gangId then
        return uiToast(src, 'error', 'Jucatorul este deja intr-un alt gang.')
    end

    MySQL.update.await(('INSERT INTO %s (gang_id, uid, role, added_by_uid, joined_at, last_seen) VALUES (?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE gang_id = VALUES(gang_id), role = VALUES(role), last_seen = NOW()'):format(sqlName(Config.MembersTable)), {
        gangId, targetUid, role, access.uid
    })

    if role == Config.Roles.leader then
        MySQL.update.await(('UPDATE %s SET leader_uid = ?, updated_at = NOW() WHERE id = ?'):format(sqlName(Config.GangsTable)), { targetUid, gangId })
    end

    logAction('add_member', access.uid, gangId, targetUid, { role = role })
    runHook('AfterAddMember', src, gangId, targetUid, role)
    uiToast(src, 'success', 'Membru adaugat.')

    local targetSrc = getPlayerByUid(targetUid)
    if targetSrc then notify(targetSrc, 'info', 'Ai fost adaugat intr-un gang.') end
    refreshGangWatchers(gangId)
end)

RegisterNetEvent('driftzone_gangpanel:server:kickMember', function(data)
    local src = source
    local access = requireAccess(src)
    if not access or not cooldown(src, 'kickMember') then return end

    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gangId or access.gangId or 0) or 0
    local targetUid = tonumber(data.uid or data.targetUid or 0) or 0
    if gangId <= 0 or targetUid <= 0 then return uiToast(src, 'error', 'Date invalide.') end
    if targetUid == access.uid and not access.syndicate then return uiToast(src, 'error', 'Nu te poti scoate singur.') end

    local target = MySQL.single.await(('SELECT * FROM %s WHERE gang_id = ? AND uid = ? LIMIT 1'):format(sqlName(Config.MembersTable)), { gangId, targetUid })
    if not target then return uiToast(src, 'error', 'Membru invalid.') end

    if not canManageMembers(access, gangId, target.role, nil) then
        return uiToast(src, 'error', 'Nu ai acces sa scoti acest membru.')
    end

    if target.role == Config.Roles.leader and not access.syndicate then
        return uiToast(src, 'error', 'Nu poti scoate liderul.')
    end

    MySQL.update.await(('DELETE FROM %s WHERE gang_id = ? AND uid = ?'):format(sqlName(Config.MembersTable)), { gangId, targetUid })
    logAction('kick_member', access.uid, gangId, targetUid, { oldRole = target.role })
    runHook('AfterKickMember', src, gangId, targetUid)
    uiToast(src, 'success', 'Membru scos.')

    local targetSrc = getPlayerByUid(targetUid)
    if targetSrc then
        notify(targetSrc, 'warning', 'Ai fost scos din gang.')
        TriggerClientEvent('driftzone_gangpanel:client:forceClose', targetSrc)
    end
    refreshGangWatchers(gangId)
end)

RegisterNetEvent('driftzone_gangpanel:server:changeRole', function(data)
    local src = source
    local access = requireAccess(src)
    if not access or not cooldown(src, 'changeRole') then return end

    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gangId or access.gangId or 0) or 0
    local targetUid = tonumber(data.uid or data.targetUid or 0) or 0
    local role = tostring(data.role or '')
    if gangId <= 0 or targetUid <= 0 then return uiToast(src, 'error', 'Date invalide.') end
    if role ~= Config.Roles.member and role ~= Config.Roles.coleader and role ~= Config.Roles.leader then return uiToast(src, 'error', 'Grad invalid.') end

    local target = MySQL.single.await(('SELECT * FROM %s WHERE gang_id = ? AND uid = ? LIMIT 1'):format(sqlName(Config.MembersTable)), { gangId, targetUid })
    if not target then return uiToast(src, 'error', 'Membru invalid.') end

    if not canManageMembers(access, gangId, target.role, role) then
        return uiToast(src, 'error', 'Nu ai acces sa schimbi gradul.')
    end

    if role == Config.Roles.leader then
        if not access.syndicate then return uiToast(src, 'error', 'Doar syndicate poate seta Lider.') end
        MySQL.update.await(('UPDATE %s SET role = ? WHERE gang_id = ? AND role = ?'):format(sqlName(Config.MembersTable)), { Config.Roles.coleader, gangId, Config.Roles.leader })
        MySQL.update.await(('UPDATE %s SET leader_uid = ?, updated_at = NOW() WHERE id = ?'):format(sqlName(Config.GangsTable)), { targetUid, gangId })
    end

    MySQL.update.await(('UPDATE %s SET role = ? WHERE gang_id = ? AND uid = ?'):format(sqlName(Config.MembersTable)), { role, gangId, targetUid })
    logAction('change_role', access.uid, gangId, targetUid, { oldRole = target.role, newRole = role })
    uiToast(src, 'success', 'Grad modificat.')
    refreshGangWatchers(gangId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getUid(src)
    if uid then
        pcall(function()
            MySQL.update.await(('UPDATE %s SET last_seen = NOW() WHERE uid = ?'):format(sqlName(Config.MembersTable)), { uid })
        end)
    end
    OpenPlayers[src] = nil
    UidCache[src] = nil
end)

CreateThread(function()
    Wait(1500)
    print('[DRIFTZONE_GANGPANEL] Loaded. Command: /' .. tostring(Config.Command or 'gang'))
end)
