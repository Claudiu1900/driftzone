local Config = {}

Config.UsersTable = 'users'
Config.UsersUidColumn = 'uid'
Config.AdutyColumn = 'aduty'

-- La pornirea resource-ului/serverului pune aduty = 0 la toti utilizatorii din DB.
Config.ResetAllOnResourceStart = true
Config.ResourceStartDelayMs = 2500

-- Cand un jucator intra, incearca de mai multe ori sa-i gaseasca UID-ul,
-- pentru ca uneori auth-ul seteaza UID-ul dupa cateva secunde.
Config.JoinReset = {
    enabled = true,
    attempts = 16,
    intervalMs = 1500
}

local UidCache = {}

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function dbExecute(query, params)
    params = params or {}

    if MySQL and MySQL.query and MySQL.query.await then
        local ok, result = pcall(function()
            return MySQL.query.await(query, params)
        end)
        if ok then return true, result end
    end

    if MySQL and MySQL.update and MySQL.update.await then
        local ok, result = pcall(function()
            return MySQL.update.await(query, params)
        end)
        if ok then return true, result end
    end

    local ok, result = pcall(function()
        return exports.oxmysql:executeSync(query, params)
    end)
    if ok then return true, result end

    ok, result = pcall(function()
        exports.oxmysql:execute(query, params)
        return true
    end)

    return ok, result
end

local function isAdutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
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

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then
        return cached.uid
    end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end
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

local function resetAllAduty(reason)
    local query = ('UPDATE %s SET %s = 0'):format(
        sqlName(Config.UsersTable),
        sqlName(Config.AdutyColumn)
    )

    local ok, result = dbExecute(query, {})

    if ok then
        print(('[DRIFTZONE_IMPLEMENTS] users.aduty resetat la 0 pentru toti jucatorii. Reason: %s'):format(tostring(reason or 'resource_start')))
    else
        print(('[DRIFTZONE_IMPLEMENTS] Eroare reset all aduty: %s'):format(tostring(result)))
    end

    for _, id in ipairs(GetPlayers()) do
        setPlayerStateOff(tonumber(id))
    end
end

local function resetAdutyByUid(uid, reason)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return false end

    local query = ('UPDATE %s SET %s = 0 WHERE %s = ? LIMIT 1'):format(
        sqlName(Config.UsersTable),
        sqlName(Config.AdutyColumn),
        sqlName(Config.UsersUidColumn)
    )

    local ok, result = dbExecute(query, { uid })

    if not ok then
        print(('[DRIFTZONE_IMPLEMENTS] Eroare reset aduty UID %s: %s'):format(uid, tostring(result)))
        return false
    end

    print(('[DRIFTZONE_IMPLEMENTS] users.aduty resetat la 0 pentru UID %s. Reason: %s'):format(uid, tostring(reason or 'join')))
    return true
end

local function resetPlayerAduty(src, reason)
    src = tonumber(src or 0) or 0
    if src <= 0 then return end

    setPlayerStateOff(src)

    if Config.JoinReset.enabled ~= true then return end

    CreateThread(function()
        local attempts = tonumber(Config.JoinReset.attempts or 16) or 16
        local interval = tonumber(Config.JoinReset.intervalMs or 1500) or 1500

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

        print(('[DRIFTZONE_IMPLEMENTS] Nu am putut gasi UID-ul pentru source %s ca sa resetez aduty.'):format(src))
    end)
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(tonumber(Config.ResourceStartDelayMs or 2500) or 2500)

        if Config.ResetAllOnResourceStart then
            resetAllAduty('resource_start')
        end

        for _, id in ipairs(GetPlayers()) do
            resetPlayerAduty(tonumber(id), 'resource_start_online_player')
        end

        print('[DRIFTZONE_IMPLEMENTS] Server-side loaded. Auto aduty reset enabled.')
    end)
end)

AddEventHandler('playerJoining', function()
    resetPlayerAduty(source, 'player_joining')
end)

RegisterNetEvent('driftzone_implements:server:resetAdutyOnJoin', function()
    resetPlayerAduty(source, 'client_loaded')
end)

exports('ResetAllAduty', function()
    resetAllAduty('export')
    return true
end)

exports('ResetPlayerAduty', function(src)
    resetPlayerAduty(tonumber(src or 0) or 0, 'export')
    return true
end)

AddEventHandler('playerDropped', function()
    UidCache[source] = nil
end)
