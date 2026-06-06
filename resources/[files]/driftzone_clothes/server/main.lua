local MAIN_DB = 'driftzone'
local LOGS_DB = MAIN_DB
local ADMIN_REQUIRED = 7

local ALLOWED_KEYS = {
    'hair', 'hat', 'mask', 'glasses', 'jacket', 'torso', 'top', 'insignia', 'pants', 'shoes', 'bag'
}

local CATEGORY_BY_NUMBER = {
    [1] = 'hair',
    [2] = 'hat',
    [3] = 'mask',
    [4] = 'glasses',
    [5] = 'jacket',
    [6] = 'torso',
    [7] = 'top',
    [8] = 'insignia',
    [9] = 'pants',
    [10] = 'shoes',
    [11] = 'bag'
}

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function isDutyValue(value)
    local text = trim(value):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
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
        uid = uid,
        username = tostring(row.username or GetPlayerName(src) or 'Admin'),
        level = tonumber(row.admin_level or 0) or 0,
        aduty = isDutyValue(row.aduty)
    }
end

local function requireAdmin7(src)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local data = getAdminData(src)

    if not data or data.level < ADMIN_REQUIRED then
        notify(src, 'warning', 'Nu ai acces la acest sistem. Necesita admin 7.')
        return nil
    end

    if not data.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return data
end

local function isAllowedKey(key)
    key = tostring(key or '')

    for _, allowed in ipairs(ALLOWED_KEYS) do
        if allowed == key then return true end
    end

    return false
end

local function categoryKeyFromNumber(number)
    return CATEGORY_BY_NUMBER[tonumber(number or 0)]
end

local function cleanJsonObject(raw)
    if type(raw) == 'table' then return raw end

    local ok, decoded = pcall(json.decode, tostring(raw or '{}'))

    if ok and type(decoded) == 'table' then return decoded end

    return {}
end

local function getPlayerByAnyId(id)
    id = tonumber(id or 0)
    if not id or id <= 0 then return nil end

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src == id then return src end

        local uid = getUid(src)
        if uid and uid == id then return src end
    end

    return nil
end

local function ensureTables()
    MySQL.query.await('ALTER TABLE users ADD COLUMN IF NOT EXISTS clothes LONGTEXT NULL', {})
    -- FIX: nu mai creeaza database separat. Foloseste baza principala.

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s`.unallowed_clothes (
            id INT NOT NULL AUTO_INCREMENT,
            category_key VARCHAR(32) NOT NULL,
            drawable INT NOT NULL,
            reason VARCHAR(255) NOT NULL DEFAULT '',
            active TINYINT NOT NULL DEFAULT 1,
            created_by VARCHAR(64) NOT NULL DEFAULT '',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY unique_clothes_blacklist (category_key, drawable)
        )
    ]]):format(LOGS_DB), {})

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s`.clothes_logs (
            id INT NOT NULL AUTO_INCREMENT,
            user_id INT NOT NULL DEFAULT 0,
            player_name VARCHAR(64) NOT NULL DEFAULT '',
            action VARCHAR(32) NOT NULL DEFAULT '',
            clothes LONGTEXT NULL,
            admin_name VARCHAR(64) NOT NULL DEFAULT '',
            admin_uid INT NOT NULL DEFAULT 0,
            target_name VARCHAR(64) NOT NULL DEFAULT '',
            target_uid INT NOT NULL DEFAULT 0,
            category_key VARCHAR(32) NOT NULL DEFAULT '',
            drawable INT NOT NULL DEFAULT 0,
            reason VARCHAR(255) NOT NULL DEFAULT '',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        )
    ]]):format(LOGS_DB), {})
end

local function logClothes(data)
    data = data or {}

    MySQL.insert(([[
        INSERT INTO `%s`.clothes_logs
            (user_id, player_name, action, clothes, admin_name, admin_uid, target_name, target_uid, category_key, drawable, reason)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]):format(LOGS_DB), {
        tonumber(data.user_id or 0) or 0,
        tostring(data.player_name or ''),
        tostring(data.action or ''),
        tostring(data.clothes or ''),
        tostring(data.admin_name or ''),
        tonumber(data.admin_uid or 0) or 0,
        tostring(data.target_name or ''),
        tonumber(data.target_uid or 0) or 0,
        tostring(data.category_key or ''),
        tonumber(data.drawable or 0) or 0,
        tostring(data.reason or '')
    })
end

local function getBlacklist()
    local rows = MySQL.query.await(
        ('SELECT category_key, drawable FROM `%s`.unallowed_clothes WHERE active = 1'):format(LOGS_DB),
        {}
    ) or {}

    local blacklist = {}
    for _, key in ipairs(ALLOWED_KEYS) do blacklist[key] = {} end

    for _, row in ipairs(rows) do
        local key = tostring(row.category_key or '')
        local drawable = tonumber(row.drawable)

        if isAllowedKey(key) and drawable then
            blacklist[key][#blacklist[key] + 1] = drawable
        end
    end

    return blacklist
end

local function isBlacklisted(blacklist, key, drawable)
    local list = blacklist and blacklist[key]
    if type(list) ~= 'table' then return false end

    drawable = tonumber(drawable)

    for _, value in ipairs(list) do
        if tonumber(value) == drawable then return true end
    end

    return false
end

local function findSafeDrawable(blacklist, key, drawable)
    drawable = tonumber(drawable)
    if not drawable then drawable = 0 end
    drawable = math.floor(drawable)

    if drawable < 0 then return -1 end

    for i = 0, 3000 do
        local try = drawable + i
        if not isBlacklisted(blacklist, key, try) then return try end
    end

    return 0
end

local function cleanClothes(raw, blacklist)
    raw = cleanJsonObject(raw)
    local output = {}

    for _, key in ipairs(ALLOWED_KEYS) do
        local item = raw[key]

        if type(item) == 'table' then
            local drawable = tonumber(item.drawable or 0) or 0
            local texture = tonumber(item.texture or 0) or 0

            drawable = findSafeDrawable(blacklist or {}, key, math.floor(drawable))
            texture = math.max(0, math.floor(texture))

            output[key] = { drawable = drawable, texture = texture }
        end
    end

    return output
end

local function getSavedClothes(uid)
    local row = MySQL.single.await('SELECT clothes FROM users WHERE uid = ? LIMIT 1', { uid })
    if not row then return {} end

    local blacklist = getBlacklist()
    return cleanClothes(row.clothes or '{}', blacklist)
end

local function saveClothes(uid, rawClothes)
    local blacklist = getBlacklist()
    local clothes = cleanClothes(rawClothes, blacklist)

    MySQL.update.await('UPDATE users SET clothes = ? WHERE uid = ?', { json.encode(clothes), uid })

    return clothes
end

local function openMenu(src)
    local admin = requireAdmin7(src)
    if not admin then return end

    local uid = getUid(src)
    local clothes = getSavedClothes(uid)
    local blacklist = getBlacklist()

    TriggerClientEvent('driftzone_clothes:client:open', src, {
        clothes = clothes,
        blacklist = blacklist,
        adminOnly = true
    })
end

local function applySavedClothes(src)
    local uid = getUid(src)
    if not uid then return end

    local clothes = getSavedClothes(uid)
    TriggerClientEvent('driftzone_clothes:client:fix', src, clothes)
end

local function sendUsage(src, command)
    if command == 'setcl' then
        notify(src, 'info', '/setcl (id) (categorie 1-11) (numar haina) | 1 hair, 2 hat, 3 mask, 4 glasses, 5 jacket, 6 torso, 7 top, 8 insignia, 9 pants, 10 shoes, 11 bag', 9000)
    elseif command == 'bancl' then
        notify(src, 'info', '/bancl (categorie 1-11) (numar haina) | 1 hair, 2 hat, 3 mask, 4 glasses, 5 jacket, 6 torso, 7 top, 8 insignia, 9 pants, 10 shoes, 11 bag', 9000)
    elseif command == 'fixskin' then
        notify(src, 'info', '/fixskin (id)', 6000)
    end
end

local function runCommand(src, command, args)
    command = tostring(command or ''):lower()
    args = args or {}

    local admin = requireAdmin7(src)
    if not admin then return end

    if command == 'haine' or command == 'clothes' then
        openMenu(src)
        return
    end

    if command == 'fixskin' then
        local target = getPlayerByAnyId(args[1])
        if not target then sendUsage(src, 'fixskin') return end

        local targetUid = getUid(target)
        if not targetUid then notify(src, 'warning', 'Jucatorul nu este logat.') return end

        MySQL.update.await('UPDATE users SET clothes = ? WHERE uid = ?', { '{}', targetUid })
        TriggerClientEvent('driftzone_clothes:client:resetSkin', target)

        logClothes({
            user_id = targetUid,
            player_name = GetPlayerName(target) or '',
            action = 'fixskin',
            clothes = '{}',
            admin_name = GetPlayerName(src) or '',
            admin_uid = admin.uid,
            target_name = GetPlayerName(target) or '',
            target_uid = targetUid
        })

        notify(src, 'info', ('Ai resetat hainele lui %s.'):format(GetPlayerName(target) or target))
        notify(target, 'info', 'Hainele tale au fost resetate de un admin.')
        return
    end

    if command == 'setcl' then
        local target = getPlayerByAnyId(args[1])
        local categoryKey = categoryKeyFromNumber(args[2])
        local drawable = tonumber(args[3])

        if not target or not categoryKey or not drawable then
            sendUsage(src, 'setcl')
            return
        end

        drawable = math.floor(drawable)
        local blacklist = getBlacklist()

        if isBlacklisted(blacklist, categoryKey, drawable) then
            notify(src, 'warning', ('%s %s este blocat.'):format(categoryKey, drawable))
            return
        end

        local targetUid = getUid(target)
        if not targetUid then notify(src, 'warning', 'Jucatorul nu este logat.') return end

        local saved = getSavedClothes(targetUid)
        saved[categoryKey] = { drawable = drawable, texture = 0 }
        saved = saveClothes(targetUid, saved)

        TriggerClientEvent('driftzone_clothes:client:fix', target, saved)

        logClothes({
            user_id = targetUid,
            player_name = GetPlayerName(target) or '',
            action = 'setcl',
            clothes = json.encode(saved),
            admin_name = GetPlayerName(src) or '',
            admin_uid = admin.uid,
            target_name = GetPlayerName(target) or '',
            target_uid = targetUid,
            category_key = categoryKey,
            drawable = drawable
        })

        notify(src, 'info', ('Ai setat %s %s pentru %s.'):format(categoryKey, drawable, GetPlayerName(target) or target))
        notify(target, 'info', ('Un admin ti-a setat %s %s.'):format(categoryKey, drawable))
        return
    end

    if command == 'bancl' then
        local categoryKey = categoryKeyFromNumber(args[1])
        local drawable = tonumber(args[2])

        if not categoryKey or not drawable then
            sendUsage(src, 'bancl')
            return
        end

        drawable = math.floor(drawable)

        MySQL.update.await(([[
            INSERT INTO `%s`.unallowed_clothes (category_key, drawable, reason, active, created_by)
            VALUES (?, ?, ?, 1, ?)
            ON DUPLICATE KEY UPDATE active = 1, reason = VALUES(reason), created_by = VALUES(created_by)
        ]]):format(LOGS_DB), {
            categoryKey,
            drawable,
            ('Blocat de %s'):format(GetPlayerName(src) or 'Admin'),
            GetPlayerName(src) or 'Admin'
        })

        logClothes({
            user_id = admin.uid,
            player_name = GetPlayerName(src) or '',
            action = 'bancl',
            admin_name = GetPlayerName(src) or '',
            admin_uid = admin.uid,
            category_key = categoryKey,
            drawable = drawable,
            reason = ('Blocat de %s'):format(GetPlayerName(src) or 'Admin')
        })

        notify(src, 'info', ('Ai blocat %s %s.'):format(categoryKey, drawable))
        return
    end
end

RegisterNetEvent('driftzone_clothes:server:open', function()
    openMenu(source)
end)

RegisterNetEvent('driftzone_clothes:server:save', function(payload)
    local src = source
    local admin = requireAdmin7(src)
    if not admin then return end

    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    local saved = saveClothes(uid, payload or {})

    logClothes({
        user_id = uid,
        player_name = GetPlayerName(src) or '',
        action = 'save',
        clothes = json.encode(saved),
        admin_name = GetPlayerName(src) or '',
        admin_uid = admin.uid
    })

    TriggerClientEvent('driftzone_clothes:client:fix', src, saved)
    TriggerClientEvent('driftzone_clothes:client:closeSaved', src)

    notify(src, 'info', 'Hainele au fost salvate.')
end)

RegisterNetEvent('driftzone_clothes:server:abandon', function()
    local src = source
    local admin = requireAdmin7(src)
    if not admin then return end

    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    local saved = getSavedClothes(uid)

    TriggerClientEvent('driftzone_clothes:client:fix', src, saved)
    TriggerClientEvent('driftzone_clothes:client:closeAbandoned', src)

    notify(src, 'info', 'Modificarile au fost abandonate.')
end)

RegisterNetEvent('driftzone_clothes:server:requestFix', function()
    applySavedClothes(source)
end)

for _, cmd in ipairs({ 'haine', 'clothes', 'fixskin', 'setcl', 'bancl' }) do
    RegisterCommand(cmd, function(src, args)
        if src == 0 then return end
        runCommand(src, cmd, args or {})
    end, false)
end

exports('RunCommand', function(src, command, args)
    return runCommand(src, command, args or {})
end)

exports('ApplySavedClothes', function(src)
    return applySavedClothes(src)
end)

CreateThread(function()
    Wait(700)

    local ok, err = pcall(ensureTables)

    if not ok then
        print('[DRIFTZONE_CLOTHES] SQL setup failed:')
        print(err)
    end

    print('[DRIFTZONE_CLOTHES] Server-side loaded. Admin required: 7 + aduty yes.')
end)
