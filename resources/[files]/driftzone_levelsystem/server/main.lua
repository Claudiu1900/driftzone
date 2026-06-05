local LastKnownRanks = {}
local IsChecking = false

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function getDb()
    return Config.Database or {}
end

local function qname(name)
    name = tostring(name or '')
    return ('`%s`'):format(name:gsub('`', ''))
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

local function normalizeColor(value, fallback)
    local color = tostring(value or ''):lower()

    if color:match('^#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$') then
        return color
    end

    return fallback or '#ffffff'
end

local function getRankForXp(xp)
    xp = tonumber(xp or 0) or 0

    local selected = {
        rank = Config.DefaultRank or '',
        color = normalizeColor(Config.DefaultRankColorForNewbie or Config.DefaultRankColor, '#ffffff'),
        levelIndex = 0,
        requiredXp = 0
    }

    for index, level in ipairs(Config.Levels or {}) do
        local required = tonumber(level.requiredXp or 0) or 0

        if xp >= required then
            selected = {
                rank = tostring(level.rank or ('LEVEL' .. index)),
                color = normalizeColor(level.color or Config.DefaultRankColor, '#ffffff'),
                levelIndex = index,
                requiredXp = required
            }
        end
    end

    return selected
end

local function fetchUser(uid)
    local db = getDb()

    local sql = ('SELECT %s AS uid, %s AS xp, %s AS rank, %s AS rankcolor FROM %s WHERE %s = ? LIMIT 1'):format(
        qname(db.uidColumn or 'uid'),
        qname(db.xpColumn or 'xp'),
        qname(db.rankColumn or 'rank'),
        qname(db.rankColorColumn or 'rankcolor'),
        qname(db.tableName or 'users'),
        qname(db.uidColumn or 'uid')
    )

    return MySQL.single.await(sql, { uid })
end

local function updateUserRank(uid, rank, color)
    local db = getDb()

    local sql = ('UPDATE %s SET %s = ?, %s = ? WHERE %s = ?'):format(
        qname(db.tableName or 'users'),
        qname(db.rankColumn or 'rank'),
        qname(db.rankColorColumn or 'rankcolor'),
        qname(db.uidColumn or 'uid')
    )

    return MySQL.update.await(sql, { rank, color, uid })
end

local function refreshPlayerLevel(src, silent)
    src = tonumber(src)

    if not src or src <= 0 then return false end
    if GetPlayerPing(src) <= 0 then return false end

    local uid = getUid(src)

    if not uid then return false end

    local row = fetchUser(uid)

    if not row then return false end

    local xp = tonumber(row.xp or 0) or 0
    local currentRank = tostring(row.rank or '')
    local currentColor = normalizeColor(row.rankcolor or '', '#ffffff')
    local newData = getRankForXp(xp)

    local wantedRank = tostring(newData.rank or '')
    local wantedColor = normalizeColor(newData.color or Config.DefaultRankColor, '#ffffff')

    if currentRank ~= wantedRank or currentColor ~= wantedColor then
        updateUserRank(uid, wantedRank, wantedColor)

        TriggerEvent('driftzone_chat:server:invalidateMeta', uid)

        LastKnownRanks[uid] = wantedRank

        if Config.NotifyOnLevelChange and not silent then
            if wantedRank ~= '' then
                notify(src, 'info', ('Rank-ul tau a fost actualizat la %s.'):format(wantedRank))
            else
                notify(src, 'info', 'Rank-ul tau a fost actualizat.')
            end
        end

        return true
    end

    LastKnownRanks[uid] = currentRank
    return false
end

local function refreshAllPlayers(silent)
    if IsChecking then return end

    IsChecking = true

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        if src and src > 0 then
            local ok, err = pcall(function()
                refreshPlayerLevel(src, silent == true)
            end)

            if not ok then
                print('[DRIFTZONE_LEVELSYSTEM] refresh player error:')
                print(err)
            end

            Wait(50)
        end
    end

    IsChecking = false
end

RegisterNetEvent('driftzone_levelsystem:server:refresh', function()
    refreshPlayerLevel(source, false)
end)

RegisterNetEvent('driftzone_levelsystem:server:refreshSilent', function()
    refreshPlayerLevel(source, true)
end)

RegisterCommand('refreshlevel', function(src)
    if src == 0 then
        refreshAllPlayers(false)
        print('[DRIFTZONE_LEVELSYSTEM] Refreshed all online players.')
        return
    end

    refreshPlayerLevel(src, false)
end, false)

exports('RefreshPlayer', function(src, silent)
    return refreshPlayerLevel(src, silent == true)
end)

exports('RefreshAll', function(silent)
    return refreshAllPlayers(silent == true)
end)

exports('GetRankForXp', function(xp)
    return getRankForXp(xp)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getUid(src)

    if uid then
        LastKnownRanks[uid] = nil
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    print('[DRIFTZONE_LEVELSYSTEM] Server-side loaded.')

    SetTimeout(3500, function()
        refreshAllPlayers(true)
    end)
end)

if Config.CheckOnPlayerJoin then
    AddEventHandler('playerJoining', function()
        local src = source

        SetTimeout(8000, function()
            refreshPlayerLevel(src, true)
        end)
    end)
end

CreateThread(function()
    while true do
        local interval = tonumber(Config.CheckIntervalSeconds or 60) or 60

        if interval < 10 then interval = 10 end

        Wait(interval * 1000)
        refreshAllPlayers(true)
    end
end)
