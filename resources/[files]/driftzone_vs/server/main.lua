local Vehicles = {}
local NextSpawnId = 1
local Watchers = {}
local AdminCache = {}

local PayloadCache = {}
local PayloadDirty = true
local DbDirty = false

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function chat(src, message)
    TriggerClientEvent('driftzone_chat:client:addMessage', src, {
        type = 'system',
        time = os.date('%H:%M'),
        text = tostring(message or '')
    })
end

local function markDirty()
    PayloadDirty = true
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

local function isDutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then return nil end

    local cached = AdminCache[uid]
    if cached and cached.expires > GetGameTimer() then
        return cached.data
    end

    local row = MySQL.single.await(
        'SELECT uid, username, admin_level, aduty FROM users WHERE uid = ? LIMIT 1',
        { uid }
    )

    if not row then return nil end

    local level = tonumber(row.admin_level or 0) or 0
    local data = {
        uid = uid,
        name = row.username or GetPlayerName(src) or 'Unknown',
        level = level,
        aduty = isDutyValue(row.aduty)
    }

    AdminCache[uid] = {
        expires = GetGameTimer() + 2500,
        data = data
    }

    return data
end

local function requireAdmin(src, command)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local minLevel = Config.Admin.commands[command] or 1
    local data = getAdminData(src)

    if not data or data.level < minLevel then
        notify(src, 'warning', 'Nu ai acces la aceasta comanda.')
        return nil
    end

    if Config.Admin.useDuty and not data.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return data
end

local function entityExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function getHealth(entity)
    if not entityExists(entity) then return 0.0 end

    local engine = GetVehicleEngineHealth(entity) or 0.0
    local body = GetVehicleBodyHealth(entity) or 0.0

    return math.floor(math.min(engine, body))
end

local function cleanPlate(plate)
    return tostring(plate or 'N/A'):upper():gsub('%s+', ''):sub(1, 16)
end

local function getCoords(entity)
    if not entityExists(entity) then
        return vector3(0.0, 0.0, 0.0)
    end

    return GetEntityCoords(entity)
end

local function getNetId(entity)
    if not entityExists(entity) then return 0 end
    return tonumber(NetworkGetNetworkIdFromEntity(entity) or 0) or 0
end

local function setState(data)
    if not data or not entityExists(data.entity) then return end

    local state = Entity(data.entity).state

    state:set('dz_vs_vehicle', true, true)
    state:set('dz_vs_spawn_id', tonumber(data.spawnId) or 0, true)
    state:set('dz_vs_sql_id', tonumber(data.sqlVehicleId) or 0, true)
    state:set('dz_vs_owner_id', tonumber(data.ownerId) or 0, true)
    state:set('dz_vs_owner_name', tostring(data.ownerName or 'Unknown'), true)
    state:set('dz_vs_model', tostring(data.model or 'unknown'), true)
    state:set('dz_vs_plate', tostring(data.plate or 'N/A'), true)
    state:set('dz_vs_source', tostring(data.source or 'unknown'), true)
end

local function deleteVsRow(spawnId)
    MySQL.update('DELETE FROM vs WHERE spawn_id = ?', { tonumber(spawnId) or 0 })
end

local function upsertVsRow(data)
    if not data or not entityExists(data.entity) then return end

    local coords = getCoords(data.entity)
    local netId = getNetId(data.entity)
    local health = getHealth(data.entity)
    local bucket = GetEntityRoutingBucket(data.entity) or 0

    MySQL.update(
        [[
            INSERT INTO vs (
                spawn_id,
                net_id,
                entity,
                sql_vehicle_id,
                owner_name,
                owner_id,
                spawned_by,
                source,
                vehicle_model,
                vehicle_plate,
                pos_x,
                pos_y,
                pos_z,
                health,
                max_health,
                bucket
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                net_id = VALUES(net_id),
                entity = VALUES(entity),
                sql_vehicle_id = VALUES(sql_vehicle_id),
                owner_name = VALUES(owner_name),
                owner_id = VALUES(owner_id),
                spawned_by = VALUES(spawned_by),
                source = VALUES(source),
                vehicle_model = VALUES(vehicle_model),
                vehicle_plate = VALUES(vehicle_plate),
                pos_x = VALUES(pos_x),
                pos_y = VALUES(pos_y),
                pos_z = VALUES(pos_z),
                health = VALUES(health),
                max_health = VALUES(max_health),
                bucket = VALUES(bucket)
        ]],
        {
            data.spawnId,
            netId,
            data.entity,
            data.sqlVehicleId or 0,
            data.ownerName or 'Unknown',
            data.ownerId or 0,
            data.spawnedBy or '',
            data.source or 'unknown',
            data.model or 'unknown',
            data.plate or 'N/A',
            coords.x,
            coords.y,
            coords.z,
            health,
            Config.MaxHealth or 1000.0,
            bucket
        }
    )
end

local function buildPayload(data)
    if not data or not entityExists(data.entity) then return nil end

    local coords = getCoords(data.entity)

    return {
        spawnId = tonumber(data.spawnId) or 0,
        netId = getNetId(data.entity),
        entity = tonumber(data.entity) or 0,

        sqlVehicleId = tonumber(data.sqlVehicleId) or 0,

        ownerName = tostring(data.ownerName or 'Unknown'),
        ownerId = tonumber(data.ownerId) or 0,

        spawnedBy = tostring(data.spawnedBy or ''),
        source = tostring(data.source or 'unknown'),

        model = tostring(data.model or 'unknown'),
        plate = tostring(data.plate or 'N/A'),

        x = coords.x,
        y = coords.y,
        z = coords.z,

        health = getHealth(data.entity),
        maxHealth = Config.MaxHealth or 1000.0,

        bucket = GetEntityRoutingBucket(data.entity) or 0
    }
end

local function cleanInvalidVehicles()
    local changed = false

    for spawnId, data in pairs(Vehicles) do
        if not data or not entityExists(data.entity) then
            Vehicles[spawnId] = nil
            deleteVsRow(spawnId)
            changed = true
        else
            setState(data)
        end
    end

    if changed then
        markDirty()
    end

    return changed
end

local function rebuildPayloadCache()
    cleanInvalidVehicles()

    local list = {}

    for _, data in pairs(Vehicles) do
        local payload = buildPayload(data)

        if payload then
            list[#list + 1] = payload
        end
    end

    table.sort(list, function(a, b)
        return a.spawnId < b.spawnId
    end)

    PayloadCache = list
    PayloadDirty = false

    return PayloadCache
end

local function getAllPayloads()
    if not PayloadDirty then
        return PayloadCache
    end

    return rebuildPayloadCache()
end

local function sendVsData(src)
    TriggerClientEvent('driftzone_vs:client:data', src, getAllPayloads())
end

local function sendVsDataWatchers()
    if next(Watchers) == nil then return end

    local list = getAllPayloads()

    for src in pairs(Watchers) do
        if GetPlayerName(src) then
            TriggerClientEvent('driftzone_vs:client:data', src, list)
        else
            Watchers[src] = nil
        end
    end
end

local function findVehicle(search)
    if search == nil or tostring(search) == '' then return nil end

    local raw = tostring(search)
    local lower = raw:lower()
    local number = tonumber(raw)

    cleanInvalidVehicles()

    if number then
        for _, data in pairs(Vehicles) do
            if tonumber(data.spawnId) == number then return data end
        end

        for _, data in pairs(Vehicles) do
            if getNetId(data.entity) == number then return data end
        end

        for _, data in pairs(Vehicles) do
            if tonumber(data.sqlVehicleId) == number then return data end
        end
    end

    for _, data in pairs(Vehicles) do
        if tostring(data.plate or ''):lower() == lower then
            return data
        end
    end

    return nil
end

local function registerVehicle(entity, rawData)
    if not entityExists(entity) then return nil end

    rawData = rawData or {}

    for spawnId, data in pairs(Vehicles) do
        if data.entity == entity then
            return spawnId
        end
    end

    local spawnId = NextSpawnId
    NextSpawnId = NextSpawnId + 1

    local ownerId = tonumber(rawData.ownerId or rawData.ownerUid or rawData.owner_id or 0) or 0
    local ownerName = tostring(rawData.ownerName or rawData.owner_name or 'Unknown')
    local sqlVehicleId = tonumber(rawData.sqlVehicleId or rawData.ownedVehicleId or rawData.vehicleId or 0) or 0
    local model = tostring(rawData.model or rawData.vehicleModel or 'unknown'):lower()
    local plate = cleanPlate(rawData.plate or rawData.vehiclePlate or GetVehicleNumberPlateText(entity) or 'N/A')

    local data = {
        spawnId = spawnId,
        entity = entity,

        sqlVehicleId = sqlVehicleId,
        ownerId = ownerId,
        ownerName = ownerName,

        spawnedBy = tostring(rawData.spawnedBy or ''),
        source = tostring(rawData.source or 'unknown'),

        model = model,
        plate = plate
    }

    Vehicles[spawnId] = data

    setState(data)
    upsertVsRow(data)
    markDirty()
    sendVsDataWatchers()

    print(('[DRIFTZONE_VS] Registered vehicle #%s | SQL %s | %s | %s'):format(
        spawnId,
        sqlVehicleId,
        model,
        plate
    ))

    return spawnId
end

local function unregisterVehicle(vehicleOrSpawnId)
    local spawnId = tonumber(vehicleOrSpawnId)

    if not spawnId then
        local entity = vehicleOrSpawnId

        for id, data in pairs(Vehicles) do
            if data.entity == entity then
                spawnId = id
                break
            end
        end
    end

    if not spawnId then return false end

    Vehicles[spawnId] = nil
    deleteVsRow(spawnId)
    markDirty()
    sendVsDataWatchers()

    return true
end

local function teleportPlayerToVehicle(src, entity)
    if not entityExists(entity) then return false end

    local ped = GetPlayerPed(src)
    local coords = getCoords(entity)

    SetEntityRoutingBucket(ped, GetEntityRoutingBucket(entity))
    SetEntityCoords(ped, coords.x + 2.5, coords.y + 2.5, coords.z + 1.0, false, false, false, false)

    return true
end

local function teleportVehicleToPlayer(src, entity)
    if not entityExists(entity) then return false end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)

    local x = coords.x + -math.sin(rad) * 5.0
    local y = coords.y + math.cos(rad) * 5.0
    local z = coords.z + 0.8

    SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(src))
    SetEntityCoords(entity, x, y, z, false, false, false, false)

    markDirty()
    DbDirty = true

    return true
end

local function fixVehicle(src, entity)
    if not entityExists(entity) then return false end

    local netId = getNetId(entity)

    if not netId or netId <= 0 then
        return false
    end

    TriggerClientEvent('driftzone_vs:client:fixVehicle', src, netId)

    return true
end

local function deleteVehicle(data)
    if not data or not entityExists(data.entity) then return false end

    local spawnId = data.spawnId

    DeleteEntity(data.entity)

    Vehicles[spawnId] = nil
    deleteVsRow(spawnId)
    markDirty()
    sendVsDataWatchers()

    return true
end

local function runCommand(src, command, args)
    args = args or {}
    command = tostring(command or ''):lower()

    local admin = requireAdmin(src, command)
    if not admin then return end

    if command == 'vs' then
        Watchers[src] = not Watchers[src]
        local payload = getAllPayloads()

        TriggerClientEvent('driftzone_vs:client:toggle', src, payload)

        notify(src, 'info', ('Vehicle Status toggle. Vehicule active: %s'):format(#payload))

        SetTimeout(150, function()
            if Watchers[src] and GetPlayerName(src) then sendVsData(src) end
        end)

        SetTimeout(500, function()
            if Watchers[src] and GetPlayerName(src) then sendVsData(src) end
        end)

        SetTimeout(1000, function()
            if Watchers[src] and GetPlayerName(src) then sendVsData(src) end
        end)

        return
    end

    local search = args[1]

    if not search or tostring(search) == '' then
        notify(src, 'warning', ('Folosire: /%s spawnId/netId/plate/sqlId'):format(command))
        return
    end

    local data = findVehicle(search)

    if not data then
        notify(src, 'warning', 'Nu am gasit vehiculul.')
        return
    end

    if command == 'dv' then
        deleteVehicle(data)
        notify(src, 'info', ('Ai sters vehiculul ID %s.'):format(data.spawnId))
        return
    end

    if command == 'gotoveh' then
        teleportPlayerToVehicle(src, data.entity)
        notify(src, 'info', ('Te-ai teleportat la vehiculul ID %s.'):format(data.spawnId))
        return
    end

    if command == 'bringveh' then
        teleportVehicleToPlayer(src, data.entity)
        upsertVsRow(data)
        sendVsDataWatchers()
        notify(src, 'info', ('Ai adus vehiculul ID %s la tine.'):format(data.spawnId))
        return
    end

    if command == 'fixveh' then
        local fixed = fixVehicle(src, data.entity)

        if not fixed then
            notify(src, 'warning', 'Nu am putut repara vehiculul.')
            return
        end

        SetTimeout(700, function()
            if data and data.entity and entityExists(data.entity) then
                upsertVsRow(data)
                markDirty()
                sendVsDataWatchers()
            end
        end)

        notify(src, 'info', ('Ai reparat vehiculul ID %s.'):format(data.spawnId))
        return
    end
end

RegisterNetEvent('driftzone_vs:server:run', function(command, args)
    runCommand(source, command, args or {})
end)

RegisterNetEvent('driftzone_vs:server:requestData', function()
    local src = source

    if Watchers[src] then
        sendVsData(src)
    end
end)

RegisterNetEvent('vs:registerVehicle', function(entity, rawData)
    registerVehicle(entity, rawData or {})
end)

RegisterNetEvent('vs:unregisterVehicle', function(vehicleOrSpawnId)
    unregisterVehicle(vehicleOrSpawnId)
end)

for _, command in ipairs({ 'vs', 'dv', 'gotoveh', 'bringveh', 'fixveh' }) do
    RegisterCommand(command, function(src, args)
        if src == 0 then return end
        runCommand(src, command, args or {})
    end, false)
end

exports('RegisterVehicle', function(entity, rawData)
    return registerVehicle(entity, rawData or {})
end)

exports('UnregisterVehicle', function(vehicleOrSpawnId)
    return unregisterVehicle(vehicleOrSpawnId)
end)

exports('GetVehicles', function()
    return getAllPayloads()
end)

exports('RunCommand', function(src, command, args)
    return runCommand(src, command, args or {})
end)

AddEventHandler('playerDropped', function()
    local src = source
    Watchers[src] = nil

    local uid = getUid(src)
    if uid then
        AdminCache[uid] = nil
    end
end)

CreateThread(function()
    Wait(500)

    MySQL.update.await('DELETE FROM vs', {})

    print('[DRIFTZONE_VS] Server-side loaded.')

    while true do
        cleanInvalidVehicles()

        for _, data in pairs(Vehicles) do
            if data and entityExists(data.entity) then
                setState(data)
            end
        end

        markDirty()
        sendVsDataWatchers()

        Wait(Config.UpdateInterval or 1000)
    end
end)

CreateThread(function()
    while true do
        for _, data in pairs(Vehicles) do
            if data and entityExists(data.entity) then
                upsertVsRow(data)
            end
        end

        Wait(Config.UpdateInterval or 1000)
    end
end)
