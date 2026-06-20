local UidCache = {}

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function dbUpdate(query, params)
    params = params or {}

    if MySQL and MySQL.update and MySQL.update.await then
        local ok, result = pcall(function()
            return MySQL.update.await(query, params)
        end)
        if ok then return true, result end
    end

    if MySQL and MySQL.query and MySQL.query.await then
        local ok, result = pcall(function()
            return MySQL.query.await(query, params)
        end)
        if ok then return true, result end
    end

    local ok, result = pcall(function()
        return exports.oxmysql:executeSync(query, params)
    end)

    return ok, result
end


local function dbSingle(query, params)
    params = params or {}

    if MySQL and MySQL.single and MySQL.single.await then
        local ok, result = pcall(function()
            return MySQL.single.await(query, params)
        end)
        if ok then return true, result end
    end

    if MySQL and MySQL.query and MySQL.query.await then
        local ok, result = pcall(function()
            local rows = MySQL.query.await(query, params)
            if type(rows) == 'table' then return rows[1] end
            return nil
        end)
        if ok then return true, result end
    end

    local ok, result = pcall(function()
        local rows = exports.oxmysql:executeSync(query, params)
        if type(rows) == 'table' then return rows[1] end
        return nil
    end)

    return ok, result
end

local function decodeJsonObject(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return nil end

    local ok, data = pcall(function()
        return json.decode(raw)
    end)

    if ok and type(data) == 'table' then return data end
    return nil
end


local function setPlayerStateOff(src)
    src = tonumber(src or 0) or 0
    if src <= 0 or not GetPlayerName(src) then return end

    local state = Player(src).state
    if state then
        state:set('dz_aduty', false, true)
        state:set('aduty', false, true)
    end
end


local function getUidFromIdentifiers(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    local identifiers = GetPlayerIdentifiers(src)
    if type(identifiers) ~= 'table' or #identifiers <= 0 then return nil end

    local columns = Config.IdentifierColumns or { 'identifier', 'license', 'steam', 'discord' }

    for _, identifier in ipairs(identifiers) do
        identifier = tostring(identifier or '')

        if identifier ~= '' then
            for _, column in ipairs(columns) do
                local query = ('SELECT %s AS uid FROM %s WHERE %s = ? LIMIT 1'):format(
                    sqlName(Config.UsersUidColumn),
                    sqlName(Config.UsersTable),
                    sqlName(column)
                )

                local ok, row = dbSingle(query, { identifier })
                local uid = ok and row and tonumber(row.uid) or nil

                if uid and uid > 0 then
                    UidCache[src] = {
                        uid = uid,
                        expires = GetGameTimer() + 30000
                    }
                    return uid
                end
            end
        end
    end

    return nil
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    local state = Player(src).state
    local keys = { 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid', 'id', 'user', 'dz_user_id', 'driftzone_user_id' }

    for i = 1, #keys do
        local value = state and state[keys[i]]
        local uid = tonumber(value)

        if not uid and type(value) == 'table' then
            uid = tonumber(value.uid or value.id or value.user_id or value.userId)
        end

        if uid and uid > 0 then return uid end
    end

    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then
        return cached.uid
    end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end,
        function() return exports.driftzone_auth:getUserId(src) end,
        function() return exports.driftzone_auth:GetPlayerUid(src) end,
        function() return exports.driftzone_auth:getPlayerUid(src) end,
        function()
            local user = exports.driftzone_auth:GetUser(src)
            if type(user) == 'table' then return user.uid or user.id or user.user_id end
            return user
        end
    }

    for _, fn in ipairs(attempts) do
        local ok, value = pcall(fn)
        local uid = tonumber(value)

        if ok and uid and uid > 0 then
            UidCache[src] = {
                uid = uid,
                expires = GetGameTimer() + 30000
            }
            return uid
        end
    end

    return nil
end


local function loadStatsByUid(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return nil end

    local statsCfg = Config.PlayerStats or {}
    local statsColumn = tostring(statsCfg.UsersStatsColumn or 'stats')

    local query = ('SELECT %s AS stats FROM %s WHERE %s = ? LIMIT 1'):format(
        sqlName(statsColumn),
        sqlName(Config.UsersTable),
        sqlName(Config.UsersUidColumn)
    )

    local ok, row = dbSingle(query, { uid })
    if not ok or type(row) ~= 'table' then return nil end

    local stats = decodeJsonObject(row.stats)
    if not stats then return nil end

    local health = tonumber(stats.health)
    local armour = tonumber(stats.armour)

    if health == nil and armour == nil then return nil end

    return {
        health = health,
        armour = armour
    }
end

local function loadPlayerStats(src, reason)
    src = tonumber(src or 0) or 0
    if src <= 0 then return false end

    local statsCfg = Config.PlayerStats or {}
    if statsCfg.LoadOnJoin == false then return false end

    CreateThread(function()
        local joinCfg = statsCfg.JoinLoad or {}
        local attempts = tonumber(joinCfg.attempts or 30) or 30
        local interval = tonumber(joinCfg.intervalMs or 1000) or 1000

        for _ = 1, attempts do
            if not GetPlayerName(src) then return end

            local uid = getUid(src)
            if uid and uid > 0 then
                local stats = loadStatsByUid(uid)

                if stats then
                    TriggerClientEvent('driftzone_implements:client:applyStats', src, stats)
                    print(('[DRIFTZONE_IMPLEMENTS] Loaded health/armour for UID %s. Reason: %s'):format(uid, tostring(reason or 'join')))
                else
                    print(('[DRIFTZONE_IMPLEMENTS] Nu exista stats valide pentru UID %s.'):format(uid))
                end

                return
            end

            Wait(interval)
        end

        print(('[DRIFTZONE_IMPLEMENTS] Nu am gasit UID-ul pentru source %s ca sa incarc viata/armura.'):format(src))
    end)

    return true
end


local function resetAllAduty(reason)
    local query = ('UPDATE %s SET %s = 0'):format(
        sqlName(Config.UsersTable),
        sqlName(Config.AdutyColumn)
    )

    local ok, result = dbUpdate(query, {})

    if ok then
        print(('[DRIFTZONE_IMPLEMENTS] Reset aduty la 0 pentru toti. Reason: %s'):format(tostring(reason or 'resource_start')))
    else
        print(('[DRIFTZONE_IMPLEMENTS] Eroare reset all aduty: %s'):format(tostring(result)))
    end

    for _, id in ipairs(GetPlayers()) do
        setPlayerStateOff(tonumber(id))
    end

    return ok
end

local function resetAdutyByUid(uid, reason)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return false end

    local query = ('UPDATE %s SET %s = 0 WHERE %s = ? LIMIT 1'):format(
        sqlName(Config.UsersTable),
        sqlName(Config.AdutyColumn),
        sqlName(Config.UsersUidColumn)
    )

    local ok, result = dbUpdate(query, { uid })

    if not ok then
        print(('[DRIFTZONE_IMPLEMENTS] Eroare reset aduty UID %s: %s'):format(uid, tostring(result)))
        return false
    end

    print(('[DRIFTZONE_IMPLEMENTS] Reset aduty la 0 pentru UID %s. Reason: %s'):format(uid, tostring(reason or 'join')))
    return true
end

local function resetPlayerAduty(src, reason)
    src = tonumber(src or 0) or 0
    if src <= 0 then return false end

    setPlayerStateOff(src)

    local joinCfg = Config.ResetAduty and Config.ResetAduty.JoinReset or {}
    if joinCfg.enabled == false then return false end

    CreateThread(function()
        local attempts = tonumber(joinCfg.attempts or 18) or 18
        local interval = tonumber(joinCfg.intervalMs or 1200) or 1200

        for _ = 1, attempts do
            if not GetPlayerName(src) then return end

            local uid = getUid(src)
            if uid and uid > 0 then
                resetAdutyByUid(uid, reason or 'join')
                setPlayerStateOff(src)
                return
            end

            Wait(interval)
        end

        print(('[DRIFTZONE_IMPLEMENTS] Nu am gasit UID-ul pentru source %s ca sa resetez aduty.'):format(src))
    end)

    return true
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(tonumber((Config.ResetAduty or {}).ResourceStartDelayMs or 2500) or 2500)

        if Config.ResetAduty and Config.ResetAduty.ResetAllOnResourceStart == true then
            resetAllAduty('resource_start')
        end

        if Config.ResetAduty and Config.ResetAduty.ResetOnlinePlayersOnResourceStart ~= false then
            for _, id in ipairs(GetPlayers()) do
                resetPlayerAduty(tonumber(id), 'resource_start_online_player')
                loadPlayerStats(tonumber(id), 'resource_start_online_player')
            end
        end

        print('[DRIFTZONE_IMPLEMENTS] Clean server loaded.')
    end)
end)

AddEventHandler('playerJoining', function()
    resetPlayerAduty(source, 'player_joining')
    loadPlayerStats(source, 'player_joining')
end)

AddEventHandler('playerDropped', function()
    UidCache[source] = nil
end)

RegisterNetEvent('driftzone_implements:server:resetAdutyOnJoin', function()
    resetPlayerAduty(source, 'client_loaded')
    loadPlayerStats(source, 'client_loaded')
end)

RegisterNetEvent('driftzone_implements:server:loadStatsOnJoin', function()
    loadPlayerStats(source, 'client_requested')
end)

exports('ResetAllAduty', function()
    return resetAllAduty('export')
end)

exports('ResetPlayerAduty', function(src)
    return resetPlayerAduty(src, 'export')
end)
