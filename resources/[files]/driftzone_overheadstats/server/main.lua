local PlayerCache = {}

local function log(message)
    if Config.Debug then
        print('[DRIFTZONE_OVERHEADSTATS] ' .. tostring(message))
    end
end

local function isDutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function safeHex(value, fallback)
    local text = tostring(value or ''):gsub('%s+', '')

    if text:match('^#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return text
    end

    return fallback or Config.DefaultRank.color or '#04c7f7'
end

local function getUidFromState(src)
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

local function getPlayerMeta(src)
    local uid = getUidFromState(src)

    if not uid then
        return {
            uid = tonumber(src) or 0,
            name = GetPlayerName(src) or ('Player ' .. tostring(src)),
            rank = Config.DefaultRank.label,
            rankColor = Config.DefaultRank.color,
            staff = '',
            aduty = false
        }
    end

    local db = Config.Database
    local query = ([[
        SELECT
            `%s` AS uid,
            `%s` AS username,
            `%s` AS rank,
            `%s` AS rankcolor,
            `%s` AS admin_level,
            `%s` AS aduty
        FROM `%s`
        WHERE `%s` = ?
        LIMIT 1
    ]]):format(
        db.uidColumn,
        db.nameColumn,
        db.rankColumn,
        db.rankColorColumn,
        db.adminLevelColumn,
        db.adutyColumn,
        db.usersTable,
        db.uidColumn
    )

    local row = MySQL.single.await(query, { uid })

    if not row then
        return {
            uid = uid,
            name = GetPlayerName(src) or ('Player ' .. tostring(src)),
            rank = Config.DefaultRank.label,
            rankColor = Config.DefaultRank.color,
            staff = '',
            aduty = false
        }
    end

    local adminLevel = tonumber(row.admin_level or 0) or 0
    local aduty = isDutyValue(row.aduty)
    local staff = ''

    if aduty and adminLevel > 0 then
        staff = Config.AdminRanks[adminLevel] or ('STAFF ' .. tostring(adminLevel))
    end

    local rank = tostring(row.rank or '')
    if rank == '' or rank == 'nil' or rank == 'null' then
        rank = Config.DefaultRank.label
    end

    return {
        uid = tonumber(row.uid or uid) or uid,
        name = tostring(row.username or GetPlayerName(src) or ('Player ' .. tostring(src))),
        rank = rank,
        rankColor = safeHex(row.rankcolor, Config.DefaultRank.color),
        staff = staff,
        aduty = aduty
    }
end

local function applyState(src, meta)
    if not src or not GetPlayerName(src) then return end

    meta = meta or getPlayerMeta(src)

    PlayerCache[src] = meta

    local state = Player(src).state

    state:set('dz_overhead_uid', meta.uid, true)
    state:set('dz_overhead_name', meta.name, true)
    state:set('dz_overhead_rank', meta.rank, true)
    state:set('dz_overhead_rankcolor', meta.rankColor, true)
    state:set('dz_overhead_staff', meta.staff, true)
    state:set('dz_overhead_aduty', meta.aduty == true, true)
end

local function refreshPlayer(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    if not GetPlayerName(src) then return end

    local ok, meta = pcall(function()
        return getPlayerMeta(src)
    end)

    if ok and meta then
        applyState(src, meta)
    else
        print('[DRIFTZONE_OVERHEADSTATS] refreshPlayer error for ' .. tostring(src))
        if meta then print(meta) end
    end
end

local function refreshAll()
    for _, id in ipairs(GetPlayers()) do
        refreshPlayer(tonumber(id))
    end
end

RegisterNetEvent('driftzone_overheadstats:server:refresh', function()
    refreshPlayer(source)
end)

exports('RefreshPlayer', function(src)
    refreshPlayer(src)
end)

exports('RefreshAll', function()
    refreshAll()
end)

AddEventHandler('playerJoining', function()
    local src = source

    -- Refresh rapid cand intra un player nou, ca overhead-ul lui sa apara imediat la toti.
    CreateThread(function()
        Wait(350)
        refreshPlayer(src)

        Wait(900)
        refreshPlayer(src)

        -- Refresh scurt si pentru ceilalti, ca noul player sa primeasca metadata curenta.
        -- Nu schimba UI-ul, doar repune statebag-urile deja existente.
        refreshAll()
    end)
end)

RegisterNetEvent('driftzone_overheadstats:server:playerReady', function()
    local src = source

    CreateThread(function()
        Wait(150)
        refreshPlayer(src)

        Wait(650)
        refreshAll()
    end)
end)

AddEventHandler('playerDropped', function()
    PlayerCache[source] = nil
end)

CreateThread(function()
    Wait(1500)
    refreshAll()

    while true do
        refreshAll()
        Wait((Config.Metadata.refreshSeconds or 12) * 1000)
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_OVERHEADSTATS] Server-side loaded. Commands disabled; use triggers/exports only.')
end)
