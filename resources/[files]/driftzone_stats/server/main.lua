local XP_LEVELS = {
    1000,
    5000,
    15000,
    30000,
    50000,
    75000,
    100000,
    250000,
    500000,
    1000000
}

local ADMIN_RANKS = {
    [1] = 'Trial Helper',
    [2] = 'Helper',
    [3] = 'Moderator',
    [4] = 'Admin',
    [5] = 'Manager',
    [6] = 'Co-Owner',
    [7] = 'Owner'
}

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function getUid(src)
    src = tonumber(src)

    if not src or src <= 0 then return nil end

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
    src = tonumber(src)

    if not src or src <= 0 then return false end

    local state = Player(src).state

    if state and state.dz_logged == true then
        return true
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:IsLoggedIn(src)
    end)

    return ok and result == true
end

local function isDuty(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true'
end

local function cleanColor(value)
    local color = tostring(value or '#04c7f7'):gsub('%s+', '')

    if color:match('^#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return color
    end

    if color:match('^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return '#' .. color
    end

    return '#04c7f7'
end

local function getLevelData(xp)
    xp = tonumber(xp or 0) or 0

    local currentLevel = 0
    local currentStart = 0
    local nextGoal = XP_LEVELS[1]

    for index, needed in ipairs(XP_LEVELS) do
        if xp >= needed then
            currentLevel = index
            currentStart = needed
            nextGoal = XP_LEVELS[index + 1] or needed
        else
            nextGoal = needed
            break
        end
    end

    if xp >= XP_LEVELS[#XP_LEVELS] then
        currentLevel = #XP_LEVELS
        currentStart = XP_LEVELS[#XP_LEVELS]
        nextGoal = XP_LEVELS[#XP_LEVELS]
    end

    local progress = 100

    if nextGoal > currentStart then
        progress = ((xp - currentStart) / (nextGoal - currentStart)) * 100
    end

    if progress < 0 then progress = 0 end
    if progress > 100 then progress = 100 end

    return {
        level = currentLevel + 1,
        xp = xp,
        currentStart = currentStart,
        nextGoal = nextGoal,
        progress = math.floor(progress * 10) / 10,
        maxed = xp >= XP_LEVELS[#XP_LEVELS]
    }
end

local function formatPlaytime(minutes)
    minutes = tonumber(minutes or 0) or 0

    local days = math.floor(minutes / 1440)
    local hours = math.floor((minutes % 1440) / 60)
    local mins = math.floor(minutes % 60)

    if days > 0 then
        return ('%dd %dh %dm'):format(days, hours, mins)
    end

    if hours > 0 then
        return ('%dh %dm'):format(hours, mins)
    end

    return ('%dm'):format(mins)
end

local function getVehicleCount(uid)
    local ok, count = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM ownedvehicles WHERE owner_id = ?', { uid })
    end)

    if ok and count then
        return tonumber(count) or 0
    end

    return 0
end

local function findPlayerById(value)
    local wanted = tonumber(value)

    if not wanted or wanted <= 0 then return nil end

    local direct = GetPlayerPed(wanted)

    if direct and direct ~= 0 and GetPlayerPing(wanted) > 0 then
        return wanted
    end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        if src then
            local uid = getUid(src)

            if uid and tonumber(uid) == wanted then
                return src
            end
        end
    end

    return nil
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then return nil end

    local row = MySQL.single.await(
        'SELECT uid, username, admin_level, aduty FROM users WHERE uid = ? LIMIT 1',
        { uid }
    )

    if not row then return nil end

    local level = tonumber(row.admin_level or 0) or 0

    return {
        uid = uid,
        username = tostring(row.username or GetPlayerName(src) or 'Admin'),
        level = level,
        aduty = isDuty(row.aduty),
        label = ADMIN_RANKS[level] or ('Admin ' .. tostring(level))
    }
end

local function canViewOtherStats(src)
    local admin = getAdminData(src)

    if not admin or admin.level < 6 then
        notify(src, 'warning', 'Ai nevoie de admin 6+ pentru /stats (id).')
        return false
    end

    if not admin.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY pentru /stats (id).')
        return false
    end

    return true
end

local function getStats(targetSrc, viewerSrc)
    targetSrc = tonumber(targetSrc)
    viewerSrc = tonumber(viewerSrc or targetSrc)

    local uid = getUid(targetSrc)

    if not uid then return nil end

    local row = MySQL.single.await(
        [[
            SELECT
                uid,
                username,
                `Rank` AS user_rank,
                rankcolor,
                xp,
                playtime,
                cash,
                dzcoins,
                admin_level,
                aduty,
                DATE_FORMAT(created_at, '%Y-%m-%d') AS created_date
            FROM users
            WHERE uid = ?
            LIMIT 1
        ]],
        { uid }
    )

    if not row then return nil end

    local adminLevel = tonumber(row.admin_level or 0) or 0
    local staffName = nil

    if adminLevel > 0 then
        staffName = ADMIN_RANKS[adminLevel] or ('Admin ' .. tostring(adminLevel))
    end

    local xpData = getLevelData(row.xp)
    local vehicleCount = getVehicleCount(uid)
    local playtime = tonumber(row.playtime or 0) or 0

    return {
        uid = tonumber(row.uid or uid) or uid,
        serverId = tonumber(targetSrc),
        viewerServerId = tonumber(viewerSrc),
        isSelf = tonumber(targetSrc) == tonumber(viewerSrc),
        username = tostring(row.username or GetPlayerName(targetSrc) or 'Player'),

        rank = tostring(row.user_rank or 'Newbie'),
        rankColor = cleanColor(row.rankcolor),

        xp = xpData.xp,
        level = xpData.level,
        xpCurrentStart = xpData.currentStart,
        xpNextGoal = xpData.nextGoal,
        xpProgress = xpData.progress,
        xpMaxed = xpData.maxed,

        playtime = playtime,
        playtimeText = formatPlaytime(playtime),
        createdDate = tostring(row.created_date or 'Necunoscut'),

        cash = tonumber(row.cash or 0) or 0,
        dzcoins = tonumber(row.dzcoins or 0) or 0,
        vehicles = vehicleCount,
        onlinePlayers = #GetPlayers(),

        staff = staffName and {
            level = adminLevel,
            label = staffName,
            aduty = isDuty(row.aduty)
        } or nil
    }
end

local function openStats(src, targetId)
    src = tonumber(src)

    if not src or src <= 0 then return end

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat ca sa deschizi statisticile.')
        return
    end

    local targetSrc = src

    if targetId ~= nil and tostring(targetId or '') ~= '' then
        if not canViewOtherStats(src) then return end

        targetSrc = findPlayerById(targetId)

        if not targetSrc then
            notify(src, 'warning', 'Jucatorul nu a fost gasit sau nu este online.')
            return
        end
    end

    local stats = getStats(targetSrc, src)

    if not stats then
        notify(src, 'warning', 'Nu am putut incarca statisticile.')
        return
    end

    TriggerClientEvent('driftzone_stats:client:open', src, stats)
end

RegisterNetEvent('driftzone_stats:server:open', function(targetId)
    openStats(source, targetId)
end)

RegisterNetEvent('driftzone_stats:server:refresh', function(targetId)
    local src = source
    local targetSrc = src

    if targetId ~= nil and tostring(targetId or '') ~= '' then
        if not canViewOtherStats(src) then return end

        targetSrc = findPlayerById(targetId)

        if not targetSrc then return end
    end

    local stats = getStats(targetSrc, src)

    if stats then
        TriggerClientEvent('driftzone_stats:client:update', src, stats)
    end
end)

RegisterCommand('stats', function(src, args)
    if src == 0 then return end

    openStats(src, args and args[1] or nil)
end, false)

RegisterCommand('statistici', function(src, args)
    if src == 0 then return end

    openStats(src, args and args[1] or nil)
end, false)

exports('RunCommand', function(src, command, args)
    command = tostring(command or ''):lower()
    args = args or {}

    if command == 'stats' or command == 'statistici' then
        openStats(src, args[1])
        return true
    end

    return false
end)

CreateThread(function()
    Wait(2000)

    print('[DRIFTZONE_STATS] Server-side loaded.')

    while true do
        Wait(60000)

        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)

            if src and GetPlayerPing(src) > 0 and isLogged(src) then
                local uid = getUid(src)

                if uid then
                    MySQL.update('UPDATE users SET playtime = COALESCE(playtime, 0) + 1 WHERE uid = ?', { uid })
                end
            end
        end
    end
end)
