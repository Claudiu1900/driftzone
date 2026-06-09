local LocksBySqlId = {}
local LocksByPlate = {}
local LocksByNet = {}
local EnginesByNet = {}

local function trimPlate(value)
    return tostring(value or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalizeData(data)
    data = data or {}
    return {
        netId = tonumber(data.netId or 0) or 0,
        sqlId = tonumber(data.sqlId or 0) or 0,
        plate = trimPlate(data.plate or ''),
        locked = data.locked == true
    }
end

local function saveLock(data)
    data = normalizeData(data)

    if data.netId > 0 then LocksByNet[data.netId] = data.locked end
    if data.sqlId > 0 then LocksBySqlId[data.sqlId] = data.locked end
    if data.plate ~= '' then LocksByPlate[data.plate] = data.locked end

    return data
end

local function getLockState(netId, sqlId, plate)
    netId = tonumber(netId or 0) or 0
    sqlId = tonumber(sqlId or 0) or 0
    plate = trimPlate(plate or '')

    if netId > 0 and LocksByNet[netId] ~= nil then return LocksByNet[netId] end
    if sqlId > 0 and LocksBySqlId[sqlId] ~= nil then return LocksBySqlId[sqlId] end
    if plate ~= '' and LocksByPlate[plate] ~= nil then return LocksByPlate[plate] end

    return nil
end

RegisterNetEvent('driftzone_vehicleconfig:server:setLock', function(data)
    local src = source
    local state = saveLock(data)

    TriggerClientEvent('driftzone_vehicleconfig:client:applyLock', -1, state)
end)

RegisterNetEvent('driftzone_vehicleconfig:server:requestLockState', function(netId, sqlId, plate)
    local src = source
    local locked = getLockState(netId, sqlId, plate)

    if locked == nil then return end

    TriggerClientEvent('driftzone_vehicleconfig:client:applyLock', src, {
        netId = tonumber(netId or 0) or 0,
        sqlId = tonumber(sqlId or 0) or 0,
        plate = trimPlate(plate or ''),
        locked = locked == true
    })
end)

RegisterNetEvent('driftzone_vehicleconfig:server:requestAllStates', function()
    local src = source

    for sqlId, locked in pairs(LocksBySqlId) do
        TriggerClientEvent('driftzone_vehicleconfig:client:applySqlLock', src, sqlId, locked == true)
    end

    for netId, locked in pairs(LocksByNet) do
        TriggerClientEvent('driftzone_vehicleconfig:client:applyLock', src, {
            netId = netId,
            sqlId = 0,
            plate = '',
            locked = locked == true
        })
    end
end)

RegisterNetEvent('driftzone_vehicleconfig:server:setEngine', function(netId, state)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    EnginesByNet[netId] = state == true
    TriggerClientEvent('driftzone_vehicleconfig:client:setEngineState', -1, netId, state == true)
end)

-- Trigger server-side pentru garaj dupa spawn:
-- TriggerEvent('driftzone_vehicleconfig:server:setEngineOff', VehToNet(vehicle))
RegisterNetEvent('driftzone_vehicleconfig:server:setEngineOff', function(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    EnginesByNet[netId] = false
    TriggerClientEvent('driftzone_vehicleconfig:client:setEngineState', -1, netId, false)
end)

-- Trigger cerut: lock/unlock dupa SQL ID-ul masinii.
-- Exemple:
-- TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', 123, true)
-- TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', 123, false)
AddEventHandler('driftzone_vehicleconfig:server:setLockBySqlId', function(sqlId, locked)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return end

    LocksBySqlId[sqlId] = locked == true
    TriggerClientEvent('driftzone_vehicleconfig:client:applySqlLock', -1, sqlId, locked == true)
end)

AddEventHandler('driftzone_vehicleconfig:server:lockBySqlId', function(sqlId)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return end

    LocksBySqlId[sqlId] = true
    TriggerClientEvent('driftzone_vehicleconfig:client:applySqlLock', -1, sqlId, true)
end)

AddEventHandler('driftzone_vehicleconfig:server:unlockBySqlId', function(sqlId)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return end

    LocksBySqlId[sqlId] = false
    TriggerClientEvent('driftzone_vehicleconfig:client:applySqlLock', -1, sqlId, false)
end)

exports('SetVehicleLockBySqlId', function(sqlId, locked)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return false end

    LocksBySqlId[sqlId] = locked == true
    TriggerClientEvent('driftzone_vehicleconfig:client:applySqlLock', -1, sqlId, locked == true)
    return true
end)

exports('IsVehicleLockedBySqlId', function(sqlId)
    sqlId = tonumber(sqlId or 0) or 0
    if sqlId <= 0 then return false end
    return LocksBySqlId[sqlId] == true
end)

AddEventHandler('entityRemoved', function(entity)
    -- Curata net cache doar pentru entitati care dispar. SQL/plate raman ca state logic.
    if entity and entity ~= 0 then
        local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
        netId = ok and tonumber(netId or 0) or 0
        if netId > 0 then
            LocksByNet[netId] = nil
            EnginesByNet[netId] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[driftzone_vehicleconfig] loaded')
end)
