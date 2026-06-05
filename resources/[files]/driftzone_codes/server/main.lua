local redeemCooldown = {}
local AdminCache = {}
local ColumnCache = {}
local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

local function nowMs()
    return GetGameTimer()
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name):gsub('`', ''))
end

local function columnExists(tableName, columnName)
    if not tableName or not columnName then return false end

    local key = tostring(tableName) .. '.' .. tostring(columnName)

    if ColumnCache[key] ~= nil then
        return ColumnCache[key]
    end

    local ok, row = pcall(function()
        return MySQL.single.await(
            [[
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = ?
                  AND COLUMN_NAME = ?
                LIMIT 1
            ]],
            { tableName, columnName }
        )
    end)

    ColumnCache[key] = ok and row ~= nil
    return ColumnCache[key]
end

local function notify(src, notifyType, message, duration)
    if not Config.Notifications.enabled then return end
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function chatAll(message)
    if not Config.Chat.enabled then return end

    TriggerClientEvent('chat:addMessage', -1, {
        color = Config.Chat.color or { 4, 199, 247 },
        multiline = true,
        args = { Config.Chat.prefix or 'DriftZone', tostring(message or '') }
    })
end

local function getPlayerNameClean(src)
    local name = GetPlayerName(src) or ('Player ' .. tostring(src))
    return tostring(name):gsub('%^%d', '')
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

local function adutyOk(value)
    if value == true then return true end
    local txt = tostring(value or ''):lower()
    return txt == '1' or txt == 'true' or txt == 'yes' or txt == 'on'
end

local function getAdminDbMeta(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then
        return {
            level = 0,
            aduty = false
        }
    end

    local cached = AdminCache[uid]
    if cached and cached.expires > GetGameTimer() then
        return cached.data
    end

    local meta = {
        level = 0,
        aduty = false
    }

    if not Config.Admin.useDatabaseFallback then
        return meta
    end

    local usersTable = Config.Database.usersTable
    local adminColumn = Config.Admin.adminLevelColumn or 'admin_level'
    local adutyColumn = Config.Admin.adutyColumn or 'aduty'

    local hasAdmin = columnExists(usersTable, adminColumn)
    local hasAduty = columnExists(usersTable, adutyColumn)

    local selectParts = {}

    if hasAdmin then
        selectParts[#selectParts + 1] = ('%s AS adminLevel'):format(sqlName(adminColumn))
    else
        selectParts[#selectParts + 1] = '0 AS adminLevel'
    end

    if hasAduty then
        selectParts[#selectParts + 1] = ('%s AS aduty'):format(sqlName(adutyColumn))
    else
        selectParts[#selectParts + 1] = '0 AS aduty'
    end

    local okDb, row = pcall(function()
        return MySQL.single.await(
            ('SELECT %s FROM %s WHERE %s = ? LIMIT 1'):format(
                table.concat(selectParts, ', '),
                sqlName(usersTable),
                sqlName(Config.Database.uidColumn)
            ),
            { uid }
        )
    end)

    if okDb and row then
        meta.level = tonumber(row.adminLevel or 0) or 0
        meta.aduty = adutyOk(row.aduty)
    end

    AdminCache[uid] = {
        expires = GetGameTimer() + 3000,
        data = meta
    }

    return meta
end

local function getAdminLevel(src)
    local state = Player(src).state

    if state and tonumber(state.dz_admin_level) then
        return tonumber(state.dz_admin_level) or 0
    end

    local ok, level = pcall(function()
        return exports.driftzone_auth:GetAdminLevel(src)
    end)

    if ok and tonumber(level) then
        return tonumber(level) or 0
    end

    local uid = getUid(src)
    return getAdminDbMeta(uid).level or 0
end

local function isAduty(src)
    local state = Player(src).state

    if state and state.dz_aduty ~= nil then
        return adutyOk(state.dz_aduty)
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:IsAdminDuty(src)
    end)

    if ok then
        return result == true or adutyOk(result)
    end

    local uid = getUid(src)
    return getAdminDbMeta(uid).aduty == true
end

local function isAdmin(src)
    local level = getAdminLevel(src)

    if level < (tonumber(Config.Admin.minLevel or 6) or 6) then
        return false
    end

    if Config.Admin.requireAduty and not isAduty(src) then
        return false
    end

    return true
end

local function normalizeCode(code)
    code = tostring(code or ''):gsub('%s+', '')
    code = code:gsub('[^%w_%-]', '')
    return code:sub(1, tonumber(Config.Code.maxCodeLength or 64) or 64)
end

local function generateCode()
    local len = tonumber(Config.Code.generatedLength or 12) or 12

    for _ = 1, 60 do
        local code = {}

        for i = 1, len do
            local index = math.random(1, #chars)
            code[i] = chars:sub(index, index)
        end

        local value = table.concat(code)
        local exists = MySQL.single.await('SELECT id FROM `codes` WHERE BINARY `code` = ? LIMIT 1', { value })

        if not exists then
            return value
        end
    end

    return tostring(math.random(100000, 999999)) .. tostring(os.time())
end

local function parseExpire(token)
    token = tostring(token or ''):lower()
    local days = token:match('^(%d+)d$')

    if not days then return nil end

    days = tonumber(days)
    if not days or days <= 0 then return nil end

    return days
end

local function resolveRewardAlias(value)
    value = tostring(value or ''):lower()

    if Config.RewardAliases and Config.RewardAliases[value] then
        return Config.RewardAliases[value]
    end

    return nil
end

local function parseAmountAndOptions(args, startIndex)
    local amount = nil
    local rewardType = nil
    local maxUses = nil
    local expiresDays = nil

    local i = startIndex
    local first = tostring(args[i] or ''):lower()
    local num, suffix = first:match('^(%d+)(%a+)$')

    if num and suffix then
        amount = tonumber(num)
        rewardType = resolveRewardAlias(suffix)
        i = i + 1
    else
        amount = tonumber(first)
        i = i + 1
    end

    if not amount or amount <= 0 then
        return nil, nil, nil, nil, 'Suma este invalida.'
    end

    while args[i] do
        local token = tostring(args[i] or ''):lower()
        local tokenReward = resolveRewardAlias(token)

        if tokenReward then
            rewardType = tokenReward
        elseif token:match('^%d+d$') then
            expiresDays = parseExpire(token)
        elseif token:match('^%d+$') and not maxUses then
            maxUses = tonumber(token)
        end

        i = i + 1
    end

    if not rewardType then
        rewardType = 'dzcoins'
    end

    if rewardType ~= 'dzcoins' and rewardType ~= 'money' then
        return nil, nil, nil, nil, 'Tip reward invalid. Foloseste dz pentru DriftZone Coins sau c/coin/coins pentru Money.'
    end

    if not maxUses or maxUses <= 0 then
        maxUses = 1
    end

    return amount, rewardType, maxUses, expiresDays, nil
end

local function expireSql(days)
    if not days then return nil end
    return os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
end

local function rewardLabel(amount, rewardType)
    local reward = Config.Rewards[rewardType]
    local label = reward and reward.label or rewardType
    return ('%s %s'):format(tonumber(amount or 0) or 0, label)
end

local function getRewardColumn(rewardType)
    local reward = Config.Rewards[rewardType]
    if not reward then return nil end

    if reward.column and columnExists(Config.Database.usersTable, reward.column) then
        return reward.column
    end

    if reward.columns then
        for _, columnName in ipairs(reward.columns) do
            if columnExists(Config.Database.usersTable, columnName) then
                return columnName
            end
        end
    end

    return nil
end

local function rollbackRedeem(codeId, uid)
    MySQL.update.await('UPDATE `codes` SET `used_count` = GREATEST(`used_count` - 1, 0) WHERE `id` = ? LIMIT 1', { codeId })
    MySQL.update.await('DELETE FROM `code_redemptions` WHERE `code_id` = ? AND `user_id` = ? LIMIT 1', { codeId, uid })
end

local function createCode(src, code, amount, rewardType, maxUses, expiresDays)
    local uid = getUid(src)
    code = normalizeCode(code)

    if code == '' then
        notify(src, 'warning', 'Cod invalid.')
        return
    end

    if not Config.Rewards[rewardType] then
        notify(src, 'warning', 'Tip reward invalid.')
        return
    end

    local rewardColumn = getRewardColumn(rewardType)
    if not rewardColumn then
        notify(src, 'error', ('Nu exista coloana pentru reward type %s in users.'):format(rewardType))
        return
    end

    local expiresAt = expireSql(expiresDays)

    local ok = pcall(function()
        return MySQL.insert.await(
            [[
                INSERT INTO `codes`
                    (`code`, `reward_type`, `reward_amount`, `max_uses`, `expires_at`, `created_by`)
                VALUES
                    (?, ?, ?, ?, ?, ?)
            ]],
            { code, rewardType, amount, maxUses, expiresAt, uid }
        )
    end)

    if not ok then
        notify(src, 'error', 'Codul exista deja sau baza de date a dat eroare.')
        return
    end

    local expireText = expiresDays and (expiresDays .. ' zile') or 'niciodata'
    notify(src, 'info', ('Cod creat: %s | %s | tip: %s | coloana: %s | folosiri: %s | expira: %s'):format(code, rewardLabel(amount, rewardType), rewardType, rewardColumn, maxUses, expireText), 9000)
end

local function redeemCode(src, rawCode)
    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local cooldown = tonumber(Config.Code.redeemCooldownMs or 1800) or 1800
    local now = nowMs()

    if redeemCooldown[src] and now - redeemCooldown[src] < cooldown then
        notify(src, 'warning', 'Asteapta putin inainte sa dai redeem iar.')
        return
    end

    redeemCooldown[src] = now

    local code = normalizeCode(rawCode)

    if code == '' then
        TriggerClientEvent('driftzone_codes:client:redeemResult', src, false, 'Cod invalid.')
        notify(src, 'warning', 'Cod invalid.')
        return
    end

    local row = MySQL.single.await(
        [[
            SELECT *
            FROM `codes`
            WHERE BINARY `code` = ?
              AND `active` = 1
              AND (`expires_at` IS NULL OR `expires_at` > NOW())
            LIMIT 1
        ]],
        { code }
    )

    if not row then
        TriggerClientEvent('driftzone_codes:client:redeemResult', src, false, 'Cod invalid sau expirat.')
        notify(src, 'warning', 'Cod invalid sau expirat.')
        return
    end

    local codeId = tonumber(row.id)
    local amount = tonumber(row.reward_amount or 0) or 0
    local rewardType = tostring(row.reward_type or 'dzcoins')
    local reward = Config.Rewards[rewardType]
    local rewardColumn = getRewardColumn(rewardType)

    if not reward or amount <= 0 or not rewardColumn then
        TriggerClientEvent('driftzone_codes:client:redeemResult', src, false, 'Reward invalid sau coloana lipsa.')
        notify(src, 'error', 'Reward invalid sau coloana lipsa.')
        return
    end

    local playerName = getPlayerNameClean(src)

    local inserted = MySQL.insert.await(
        [[
            INSERT IGNORE INTO `code_redemptions`
                (`code_id`, `code`, `user_id`, `player_name`, `reward_type`, `reward_amount`)
            VALUES
                (?, ?, ?, ?, ?, ?)
        ]],
        { codeId, code, uid, playerName, rewardType, amount }
    )

    if not inserted or inserted <= 0 then
        TriggerClientEvent('driftzone_codes:client:redeemResult', src, false, 'Ai folosit deja acest cod.')
        notify(src, 'warning', 'Ai folosit deja acest cod.')
        return
    end

    local updatedCode = MySQL.update.await(
        [[
            UPDATE `codes`
            SET `used_count` = `used_count` + 1
            WHERE `id` = ?
              AND `active` = 1
              AND `used_count` < `max_uses`
              AND (`expires_at` IS NULL OR `expires_at` > NOW())
            LIMIT 1
        ]],
        { codeId }
    )

    if not updatedCode or updatedCode <= 0 then
        MySQL.update.await('DELETE FROM `code_redemptions` WHERE `code_id` = ? AND `user_id` = ? LIMIT 1', { codeId, uid })
        TriggerClientEvent('driftzone_codes:client:redeemResult', src, false, 'Codul a atins limita de redeem sau a expirat.')
        notify(src, 'warning', 'Codul a atins limita de redeem sau a expirat.')
        return
    end

    local okUpdate, updatedUser = pcall(function()
        return MySQL.update.await(
            ('UPDATE %s SET %s = COALESCE(%s, 0) + ? WHERE %s = ? LIMIT 1'):format(
                sqlName(Config.Database.usersTable),
                sqlName(rewardColumn),
                sqlName(rewardColumn),
                sqlName(Config.Database.uidColumn)
            ),
            { amount, uid }
        )
    end)

    if not okUpdate or not updatedUser or updatedUser <= 0 then
        rollbackRedeem(codeId, uid)
        TriggerClientEvent('driftzone_codes:client:redeemResult', src, false, 'Nu am putut adauga recompensa.')
        notify(src, 'error', 'Nu am putut adauga recompensa.')
        return
    end

    local message = ('%s (%s) a dat redeem la codul %s si a primit %s!'):format(playerName, uid, code, rewardLabel(amount, rewardType))
    chatAll(message)

    TriggerClientEvent('driftzone_codes:client:redeemResult', src, true, 'Cod folosit cu succes.')
    notify(src, 'info', 'Ai primit ' .. rewardLabel(amount, rewardType) .. '.', 6500)
end

local function listCodes(src)
    local limit = tonumber(Config.Code.listLimit or 30) or 30
    local rows = MySQL.query.await(
        [[
            SELECT `id`, `code`, `reward_type`, `reward_amount`, `max_uses`, `used_count`, `expires_at`, `active`
            FROM `codes`
            ORDER BY `id` DESC
            LIMIT ?
        ]],
        { limit }
    ) or {}

    if #rows == 0 then
        notify(src, 'info', 'Codes: nu exista coduri.')
        return
    end

    local chunk = 'Codes: '

    for _, row in ipairs(rows) do
        local active = tonumber(row.active or 0) == 1 and 'ON' or 'OFF'
        local part = ('%s (%s) %s [%s/%s] %s; '):format(
            row.code,
            row.id,
            rewardLabel(row.reward_amount, row.reward_type),
            tonumber(row.used_count or 0) or 0,
            tonumber(row.max_uses or 0) or 0,
            active
        )

        if #chunk + #part > 430 then
            notify(src, 'info', chunk, 12000)
            chunk = 'Codes: '
        end

        chunk = chunk .. part
    end

    if chunk ~= 'Codes: ' then
        notify(src, 'info', chunk, 12000)
    end
end

local function runCommandFromChat(src, command, args)
    command = tostring(command or ''):lower()
    args = args or {}

    if command == 'code' or command == 'codes' then
        TriggerClientEvent('driftzone_codes:client:show', src)
        return
    end

    if command == 'createcode' then
        if not isAdmin(src) then
            notify(src, 'warning', 'Nu ai acces la aceasta comanda sau nu esti aduty.')
            return
        end

        local code = args[1]

        if not code then
            notify(src, 'warning', 'Folosire: /createcode (code) (1000 dz) (redeems optional) (1d optional)')
            return
        end

        local amount, rewardType, maxUses, expiresDays, err = parseAmountAndOptions(args, 2)

        if err then
            notify(src, 'warning', err)
            return
        end

        createCode(src, code, amount, rewardType, maxUses, expiresDays)
        return
    end

    if command == 'creatercode' then
        if not isAdmin(src) then
            notify(src, 'warning', 'Nu ai acces la aceasta comanda sau nu esti aduty.')
            return
        end

        local amount, rewardType, maxUses, expiresDays, err = parseAmountAndOptions(args, 1)

        if err then
            notify(src, 'warning', 'Folosire: /creatercode (1000 dz) (redeems optional) (1d optional)')
            return
        end

        local code = generateCode()
        createCode(src, code, amount, rewardType, maxUses, expiresDays)
        return
    end

    if command == 'delcode' then
        if not isAdmin(src) then
            notify(src, 'warning', 'Nu ai acces la aceasta comanda sau nu esti aduty.')
            return
        end

        local id = tonumber(args[1] or '')

        if not id then
            notify(src, 'warning', 'Folosire: /delcode (id)')
            return
        end

        local affected = MySQL.update.await(
            'UPDATE `codes` SET `active` = 0, `deleted_at` = NOW() WHERE `id` = ? LIMIT 1',
            { id }
        )

        if affected and affected > 0 then
            notify(src, 'info', 'Cod sters/dezactivat: ID ' .. id)
        else
            notify(src, 'warning', 'Nu exista codul cu ID ' .. id)
        end

        return
    end

    if command == 'codeslist' then
        if not isAdmin(src) then
            notify(src, 'warning', 'Nu ai acces la aceasta comanda sau nu esti aduty.')
            return
        end

        listCodes(src)
        return
    end
end

RegisterNetEvent('driftzone_codes:server:redeem', function(code)
    redeemCode(source, code)
end)

RegisterCommand('code', function(src)
    if src == 0 then return end
    runCommandFromChat(src, 'code', {})
end, false)

RegisterCommand('codes', function(src)
    if src == 0 then return end
    runCommandFromChat(src, 'codes', {})
end, false)

RegisterCommand('createcode', function(src, args)
    if src == 0 then return end
    runCommandFromChat(src, 'createcode', args or {})
end, false)

RegisterCommand('creatercode', function(src, args)
    if src == 0 then return end
    runCommandFromChat(src, 'creatercode', args or {})
end, false)

RegisterCommand('delcode', function(src, args)
    if src == 0 then return end
    runCommandFromChat(src, 'delcode', args or {})
end, false)

RegisterCommand('codeslist', function(src)
    if src == 0 then return end
    runCommandFromChat(src, 'codeslist', {})
end, false)

exports('RunCommand', runCommandFromChat)

AddEventHandler('playerDropped', function()
    local src = source
    redeemCooldown[src] = nil

    local uid = getUid(src)
    if uid then
        AdminCache[uid] = nil
    end
end)

CreateThread(function()
    Wait(500)
    print('[DRIFTZONE_CODES] Loaded.')
end)
