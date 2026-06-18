local LocksBySqlId = {}
local LocksByNet = {}
local EnginesByNet = {}
local TemporaryKeys = {}
local PlateSqlCache = {}
local SourceUidCache = {}

local function dbg(msg)
    if Config.Debug then
        print('[driftzone_vehicleconfig:server] ' .. tostring(msg))
    end
end

local function trimPlate(value)
    return tostring(value or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function db()
    return Config.Database or {}
end

local function getOwnedTable()
    return db().ownedVehiclesTable or 'ownedvehicles'
end

local function getOwnedIdColumn()
    return db().ownedVehicleIdColumn or 'id'
end

local function getOwnerUidColumn()
    return db().ownerUidColumn or 'owner_id'
end

local function getPlateColumn()
    return db().plateColumn or 'vehicle_plate'
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    if SourceUidCache[src] then return SourceUidCache[src] end

    local state = Player(src).state
    local keys = { 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }

    for i = 1, #keys do
        local uid = tonumber(state and state[keys[i]])
        if uid and uid > 0 then
            SourceUidCache[src] = uid
            return uid
        end
    end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, value = pcall(fn)
        local uid = tonumber(value)
        if ok and uid and uid > 0 then
            SourceUidCache[src] = uid
            return uid
        end
    end

    return nil
end

local function getOwnedVehicleBySqlId(sqlId)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return nil end

    local ok, row = pcall(function()
        return MySQL.single.await(
            ('SELECT %s AS id, %s AS owner_id, %s AS plate FROM %s WHERE %s = ? LIMIT 1'):format(
                sqlName(getOwnedIdColumn()),
                sqlName(getOwnerUidColumn()),
                sqlName(getPlateColumn()),
                sqlName(getOwnedTable()),
                sqlName(getOwnedIdColumn())
            ),
            { sqlId }
        )
    end)

    if ok and row then
        row.id = tonumber(row.id or 0) or 0
        row.owner_id = tonumber(row.owner_id or 0) or 0
        row.plate = trimPlate(row.plate or '')

        if row.plate ~= '' and row.id > 0 then
            PlateSqlCache[row.plate] = row.id
        end

        return row
    end

    return nil
end

local function getOwnedVehicleByPlate(plate)
    plate = trimPlate(plate or '')
    if plate == '' then return nil end

    if PlateSqlCache[plate] then
        local cached = getOwnedVehicleBySqlId(PlateSqlCache[plate])
        if cached then return cached end
    end

    local ok, row = pcall(function()
        return MySQL.single.await(
            ('SELECT %s AS id, %s AS owner_id, %s AS plate FROM %s WHERE UPPER(TRIM(%s)) = ? LIMIT 1'):format(
                sqlName(getOwnedIdColumn()),
                sqlName(getOwnerUidColumn()),
                sqlName(getPlateColumn()),
                sqlName(getOwnedTable()),
                sqlName(getPlateColumn())
            ),
            { plate }
        )
    end)

    if ok and row then
        row.id = tonumber(row.id or 0) or 0
        row.owner_id = tonumber(row.owner_id or 0) or 0
        row.plate = trimPlate(row.plate or '')

        if row.plate ~= '' and row.id > 0 then
            PlateSqlCache[row.plate] = row.id
        end

        return row
    end

    return nil
end

local function normalizePayload(data)
    data = type(data) == 'table' and data or {}

    return {
        netId = tonumber(data.netId or 0) or 0,
        sqlId = tonumber(data.sqlId or 0) or 0,
        plate = trimPlate(data.plate or ''),
        locked = data.locked == true
    }
end

local function resolveOwnedVehicle(data)
    data = normalizePayload(data)

    local row = nil

    if data.sqlId > 0 then
        row = getOwnedVehicleBySqlId(data.sqlId)
    end

    if not row and Config.AllowPlateFallback == true and data.plate ~= '' then
        row = getOwnedVehicleByPlate(data.plate)
    end

    if not row or not row.id or row.id <= 0 then
        return nil, data
    end

    data.sqlId = row.id
    if data.plate == '' then data.plate = row.plate or '' end

    return row, data
end

local function hasTemporaryKey(uid, sqlId, netId)
    uid = tonumber(uid or 0) or 0
    sqlId = tonumber(sqlId or 0) or 0
    netId = tonumber(netId or 0) or 0

    if uid <= 0 then return false end

    if sqlId > 0 and TemporaryKeys[sqlId] and TemporaryKeys[sqlId][uid] == true then
        return true
    end

    if netId > 0 and TemporaryKeys['net:' .. tostring(netId)] and TemporaryKeys['net:' .. tostring(netId)][uid] == true then
        return true
    end

    return false
end

local function canControlVehicle(src, row, netId)
    local uid = getUid(src)
    if not uid then return false, 0 end

    if row and tonumber(row.owner_id or 0) == uid then
        return true, uid
    end

    if row and hasTemporaryKey(uid, row.id, netId) then
        return true, uid
    end

    return false, uid
end

local function broadcastLock(data, notifySrc, message)
    data = normalizePayload(data)

    if data.sqlId > 0 then LocksBySqlId[data.sqlId] = data.locked end
    if data.netId > 0 then LocksByNet[data.netId] = data.locked end
    if data.plate ~= '' and data.sqlId > 0 then PlateSqlCache[data.plate] = data.sqlId end

    TriggerClientEvent('driftzone_vehicleconfig:client:applyLock', -1, {
        netId = data.netId,
        sqlId = data.sqlId,
        plate = data.plate,
        locked = data.locked,
        notify = false
    })

    if notifySrc and notifySrc > 0 then
        TriggerClientEvent('driftzone_vehicleconfig:client:applyLock', notifySrc, {
            netId = data.netId,
            sqlId = data.sqlId,
            plate = data.plate,
            locked = data.locked,
            notify = true,
            message = message or (data.locked and 'Masina a fost incuiata.' or 'Masina a fost descuiata.')
        })
    end
end

local function handleLockRequest(src, data)
    local row, state = resolveOwnedVehicle(data)

    if not row then
        TriggerClientEvent('driftzone_vehicleconfig:client:lockDenied', src, 'Masina asta nu este masina personala.')
        return
    end

    local allowed = canControlVehicle(src, row, state.netId)
    if not allowed then
        TriggerClientEvent('driftzone_vehicleconfig:client:lockDenied', src, 'Nu ai cheia la masina asta.')
        return
    end

    state.sqlId = row.id
    if state.plate == '' then state.plate = row.plate or '' end

    broadcastLock(state, src, state.locked and 'Masina a fost incuiata.' or 'Masina a fost descuiata.')
end

RegisterNetEvent('driftzone_vehicleconfig:server:toggleOwnedLock', function(data)
    handleLockRequest(source, data)
end)

-- Compatibilitate cu versiunile mai vechi care trimiteau setLock.
RegisterNetEvent('driftzone_vehicleconfig:server:setLock', function(data)
    handleLockRequest(source, data)
end)

RegisterNetEvent('driftzone_vehicleconfig:server:requestVehicleState', function(data)
    local src = source
    local row, state = resolveOwnedVehicle(data)

    if not row then return end

    local locked = LocksBySqlId[row.id]
    if locked == nil then locked = true end

    state.sqlId = row.id
    state.locked = locked == true

    TriggerClientEvent('driftzone_vehicleconfig:client:applyLock', src, {
        netId = state.netId,
        sqlId = state.sqlId,
        plate = state.plate ~= '' and state.plate or row.plate,
        locked = state.locked,
        notify = false
    })
end)

RegisterNetEvent('driftzone_vehicleconfig:server:requestAllStates', function()
    local src = source

    for sqlId, locked in pairs(LocksBySqlId) do
        TriggerClientEvent('driftzone_vehicleconfig:client:applySqlLock', src, sqlId, locked == true)
    end

    for netId, engineState in pairs(EnginesByNet) do
        TriggerClientEvent('driftzone_vehicleconfig:client:setEngineState', src, netId, engineState == true)
    end
end)

RegisterNetEvent('driftzone_vehicleconfig:server:setEngine', function(netId, state)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    EnginesByNet[netId] = state == true
    TriggerClientEvent('driftzone_vehicleconfig:client:setEngineState', -1, netId, state == true)
end)

RegisterNetEvent('driftzone_vehicleconfig:server:setEngineOff', function(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    EnginesByNet[netId] = false
    TriggerClientEvent('driftzone_vehicleconfig:client:setEngineState', -1, netId, false)
end)

RegisterNetEvent('driftzone_vehicleconfig:server:registerSpawnedVehicle', function(data)
    local row, state = resolveOwnedVehicle(data)
    if not row then return end

    state.sqlId = row.id
    state.locked = true

    LocksBySqlId[row.id] = true

    if state.netId > 0 then
        LocksByNet[state.netId] = true
        EnginesByNet[state.netId] = false
    end

    if state.plate ~= '' then
        PlateSqlCache[state.plate] = row.id
    end

    -- Cheile temporare se sterg cand masina se respawneaza.
    TemporaryKeys[row.id] = nil
    if state.netId > 0 then
        TemporaryKeys['net:' .. tostring(state.netId)] = nil
    end

    broadcastLock(state, nil)

    if state.netId > 0 then
        TriggerClientEvent('driftzone_vehicleconfig:client:setEngineState', -1, state.netId, false)
    end
end)

local function setLockBySqlId(sqlId, locked)
    local row = getOwnedVehicleBySqlId(sqlId)
    if not row then return false end

    broadcastLock({
        netId = 0,
        sqlId = row.id,
        plate = row.plate,
        locked = locked == true
    }, nil)

    return true
end

AddEventHandler('driftzone_vehicleconfig:server:setLockBySqlId', function(sqlId, locked)
    setLockBySqlId(sqlId, locked)
end)

AddEventHandler('driftzone_vehicleconfig:server:lockBySqlId', function(sqlId)
    setLockBySqlId(sqlId, true)
end)

AddEventHandler('driftzone_vehicleconfig:server:unlockBySqlId', function(sqlId)
    setLockBySqlId(sqlId, false)
end)

exports('SetVehicleLockBySqlId', function(sqlId, locked)
    return setLockBySqlId(sqlId, locked)
end)

exports('IsVehicleLockedBySqlId', function(sqlId)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return false end

    if LocksBySqlId[sqlId] == nil then return true end
    return LocksBySqlId[sqlId] == true
end)

local function addTemporaryKey(sqlId, uid, netId)
    sqlId = tonumber(sqlId or 0) or 0
    uid = tonumber(uid or 0) or 0
    netId = tonumber(netId or 0) or 0

    if sqlId <= 0 or uid <= 0 then return false end
    if not getOwnedVehicleBySqlId(sqlId) then return false end

    TemporaryKeys[sqlId] = TemporaryKeys[sqlId] or {}
    TemporaryKeys[sqlId][uid] = true

    if netId > 0 then
        local key = 'net:' .. tostring(netId)
        TemporaryKeys[key] = TemporaryKeys[key] or {}
        TemporaryKeys[key][uid] = true
    end

    return true
end

exports('GiveTemporaryKey', function(sqlId, uid, netId)
    return addTemporaryKey(sqlId, uid, netId)
end)

AddEventHandler('driftzone_vehicleconfig:server:giveTemporaryKey', function(sqlId, uid, netId)
    addTemporaryKey(sqlId, uid, netId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = SourceUidCache[src]
    SourceUidCache[src] = nil

    if not uid then return end

    for _, list in pairs(TemporaryKeys) do
        if type(list) == 'table' then
            list[uid] = nil
        end
    end
end)

AddEventHandler('entityRemoved', function(entity)
    if entity and entity ~= 0 then
        local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
        netId = ok and tonumber(netId or 0) or 0

        if netId > 0 then
            LocksByNet[netId] = nil
            EnginesByNet[netId] = nil
            TemporaryKeys['net:' .. tostring(netId)] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[driftzone_vehicleconfig] loaded - owned-only lock enabled')
end)
