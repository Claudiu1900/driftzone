local AccessCache = {}

local function accessCfg()
    return Config and Config.Access or {}
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function notify(src, msg, typ)
    if not src or tonumber(src) == 0 then return end
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'warning', 5000, tostring(msg or ''))
end

local function targetId(value)
    local id = tonumber(value)
    if id and GetPlayerName(id) then return id end
    return nil
end

local function getStateNumber(src, keys)
    local player = Player(src)
    if not player or not player.state then return nil end

    for _, key in ipairs(keys or {}) do
        local value = player.state[key]
        local n = tonumber(value)
        if n and n > 0 then return n end
    end

    return nil
end

local function getUid(src)
    local cfg = accessCfg()
    local stateUid = getStateNumber(src, cfg.StateUidKeys or { 'dz_uid', 'uid', 'user_id' })
    if stateUid then return stateUid end

    local res = cfg.AuthResource or 'driftzone_auth'
    if res ~= '' and GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:GetUID(src) end,
            function() return exports[res]:GetUid(src) end,
            function() return exports[res]:getUID(src) end,
            function() return exports[res]:GetUserId(src) end,
            function() return exports[res]:getUserId(src) end
        }

        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            local uid = tonumber(value)
            if ok and uid and uid > 0 then return uid end
        end
    end

    return nil
end

local function getIdentifiers(src)
    local ids = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
        ids[#ids + 1] = identifier
    end
    return ids
end

local function getAdminLevelFromDb(src)
    if not MySQL or not MySQL.single or not MySQL.single.await then
        print('^1[driftzone_emotes]^7 oxmysql nu este disponibil. Nu pot verifica users.admin_level.')
        return 0
    end

    local cfg = accessCfg()
    local usersTable = sqlName(cfg.UsersTable or 'users')
    local uidCol = sqlName(cfg.UsersIdColumn or 'uid')
    local adminCol = sqlName(cfg.AdminColumn or 'admin_level')
    local fallbackCol = tostring(cfg.AdminColumnFallback or '')
    local uid = getUid(src)

    if uid then
        local query = ('SELECT %s AS level%s FROM %s WHERE %s = ? LIMIT 1'):format(
            adminCol,
            fallbackCol ~= '' and (', ' .. sqlName(fallbackCol) .. ' AS fallback_level') or '',
            usersTable,
            uidCol
        )

        local ok, row = pcall(function()
            return MySQL.single.await(query, { uid })
        end)

        if ok and row then
            return tonumber(row.level or row.fallback_level or 0) or 0
        end
    end

    local identifierColumns = cfg.IdentifierColumns or { 'identifier', 'license' }
    local identifiers = getIdentifiers(src)
    for _, col in ipairs(identifierColumns) do
        local colName = sqlName(col)
        for _, identifier in ipairs(identifiers) do
            local query = ('SELECT %s AS level%s FROM %s WHERE %s = ? LIMIT 1'):format(
                adminCol,
                fallbackCol ~= '' and (', ' .. sqlName(fallbackCol) .. ' AS fallback_level') or '',
                usersTable,
                colName
            )

            local ok, row = pcall(function()
                return MySQL.single.await(query, { identifier })
            end)

            if ok and row then
                return tonumber(row.level or row.fallback_level or 0) or 0
            end
        end
    end

    return 0
end

local function getAdminLevel(src, ignoreCache)
    src = tonumber(src)
    if not src or src == 0 then return 999 end

    local cfg = accessCfg()
    local minLevel = tonumber(cfg.MinAdminLevel or 6) or 6
    local stateLevel = getStateNumber(src, cfg.StateAdminKeys or { 'admin_level', 'admin' })
    if stateLevel and stateLevel >= minLevel then return stateLevel end

    local cached = AccessCache[src]
    if not ignoreCache and cached and cached.expires > GetGameTimer() then
        return cached.level or 0
    end

    local level = getAdminLevelFromDb(src)
    AccessCache[src] = {
        level = level,
        expires = GetGameTimer() + (tonumber(cfg.CacheMs or 5000) or 5000)
    }
    return level
end

local function hasAccess(src, silent)
    local cfg = accessCfg()
    if cfg.Enabled == false then return true end

    src = tonumber(src)
    if not src or src == 0 then return true end

    local minLevel = tonumber(cfg.MinAdminLevel or 6) or 6
    local level = getAdminLevel(src)
    local allowed = level >= minLevel

    if not allowed and not silent then
        notify(src, cfg.NoAccessMessage or ('Nu ai acces. Ai nevoie de admin level ' .. minLevel .. '+.'), 'warning')
    end

    return allowed, level
end

local function hasTargetAccess(id)
    if not id then return false end
    local allowed = hasAccess(id, true)
    if not allowed then
        notify(id, accessCfg().NoAccessMessage or 'Nu ai acces la emotes.', 'warning')
    end
    return allowed
end

RegisterNetEvent('driftzone_emotes:server:checkAccess', function(requestId)
    local src = source
    local allowed, level = hasAccess(src, true)
    local cfg = accessCfg()
    TriggerClientEvent('driftzone_emotes:client:accessResult', src, requestId, allowed, cfg.NoAccessMessage or 'Nu ai acces la emotes.', level or 0)
end)

RegisterNetEvent('driftzone_emotes:sendAnimRequest:server', function(data)
    local src = source
    if not hasAccess(src) or type(data) ~= 'table' then return end

    local id = targetId(data.id)
    if id and hasTargetAccess(id) then
        TriggerClientEvent('driftzone_emotes:receiveAnimRequest:client', id, data)
    end
end)

RegisterNetEvent('driftzone_emotes:playAnimTogetherSender:server', function(data)
    local src = source
    if not hasAccess(src) or type(data) ~= 'table' then return end

    local id = data.target or (data.data and data.data.target)
    id = targetId(id)
    if id and hasTargetAccess(id) then
        TriggerClientEvent('driftzone_emotes:playAnimTogetherSender:client', id, data)
    end
end)

RegisterNetEvent('driftzone_emotes:playAnimTogetherSender2:server', function(data)
    local src = source
    if not hasAccess(src) or type(data) ~= 'table' then return end

    local id = data.target or (data.data and data.data.target)
    id = targetId(id)
    if id and hasTargetAccess(id) then
        TriggerClientEvent('driftzone_emotes:playAnimTogetherSender2:client', id, data)
    end
end)

RegisterNetEvent('driftzone_emotes:requstCanelledNotif:server', function(target)
    if not hasAccess(source) then return end
    local id = targetId(target)
    if id and hasTargetAccess(id) then TriggerClientEvent('driftzone_emotes:requstCanelledNotif:client', id) end
end)

RegisterNetEvent('driftzone_emotes:cancelEmote:server', function(target)
    if not hasAccess(source) then return end
    local id = targetId(target)
    if id and hasTargetAccess(id) then TriggerClientEvent('driftzone_emotes:cancelEmote:client', id) end
end)

RegisterNetEvent('driftzone_emotes:animDictLoaded:server', function(target)
    if not hasAccess(source) then return end
    local id = targetId(target)
    if id and hasTargetAccess(id) then TriggerClientEvent('driftzone_emotes:animDictLoaded:client', id) end
end)

RegisterNetEvent('driftzone_emotes:attachPeds:server', function(targetIdValue, myId, data)
    if not hasAccess(source) then return end
    local id = targetId(targetIdValue)
    if id and hasTargetAccess(id) then TriggerClientEvent('driftzone_emotes:attachPeds:client', id, myId, data) end
end)

RegisterNetEvent('driftzone_emotes:ptfxSync:server', function(asset, name, offset, rot, bone, scale, color)
    if not hasAccess(source) then return end
    if type(asset) ~= 'string' or type(name) ~= 'string' then return end

    local state = Player(source).state
    state:set('ptfxAsset', asset, true)
    state:set('ptfxName', name, true)
    state:set('ptfxOffset', offset, true)
    state:set('ptfxRot', rot, true)
    state:set('ptfxBone', bone, true)
    state:set('ptfxScale', scale, true)
    state:set('ptfxColor', color, true)
    state:set('ptfxPropNet', false, true)
    state:set('ptfx', false, true)
end)

RegisterNetEvent('driftzone_emotes:ptfxSyncProp:server', function(propNet)
    if not hasAccess(source) then return end

    local state = Player(source).state
    if propNet then
        local tries = 0
        while tries <= 100 and not DoesEntityExist(NetworkGetEntityFromNetworkId(propNet)) do
            Wait(10)
            tries = tries + 1
        end
        if tries < 100 then
            state:set('ptfxPropNet', propNet, true)
            return
        end
    end
    state:set('ptfxPropNet', false, true)
end)

RegisterNetEvent('driftzone_emotes:setPedAlpha:server', function(id, alpha)
    if not hasAccess(source) then return end
    TriggerClientEvent('driftzone_emotes:setPedAlpha:server', -1, id, alpha)
end)

-- Server-side helper triggers pentru framework-ul tau.
-- Usage: TriggerEvent('driftzone_emotes:server:playForSource', source, 'sit')
RegisterNetEvent('driftzone_emotes:server:playForSource', function(target, emote)
    local caller = source
    local id = targetId(target)
    if caller ~= 0 and caller ~= '' and caller ~= nil and not hasAccess(caller) then return end
    if id and type(emote) == 'string' and hasTargetAccess(id) then
        TriggerClientEvent('driftzone_emotes:client:play', id, emote)
    end
end)

RegisterNetEvent('driftzone_emotes:server:playLockedForSource', function(target, emote)
    local caller = source
    local id = targetId(target)
    if caller ~= 0 and caller ~= '' and caller ~= nil and not hasAccess(caller) then return end
    if id and type(emote) == 'string' and hasTargetAccess(id) then
        TriggerClientEvent('driftzone_emotes:client:playLocked', id, emote)
    end
end)

RegisterNetEvent('driftzone_emotes:server:forceStopForSource', function(target)
    local caller = source
    local id = targetId(target)
    if caller ~= 0 and caller ~= '' and caller ~= nil and not hasAccess(caller) then return end
    if id then TriggerClientEvent('driftzone_emotes:client:forceStop', id) end
end)

exports('HasAccess', function(src)
    return hasAccess(src, true)
end)

exports('GetAdminLevel', function(src)
    return getAdminLevel(src, true)
end)

AddEventHandler('playerDropped', function()
    AccessCache[source] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        print(('^2[driftzone_emotes]^7 started. Access: users.admin_level >= %s'):format(tostring(accessCfg().MinAdminLevel or 6)))
    end
end)
