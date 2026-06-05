local ActiveVehicles = {}

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function getUid(src)
    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then return tonumber(state.dz_uid) end
    local ok, uid = pcall(function() return exports.driftzone_auth:GetUID(src) end)
    if ok and tonumber(uid) and tonumber(uid) > 0 then return tonumber(uid) end
    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end
    local ok, result = pcall(function() return exports.driftzone_auth:IsLoggedIn(src) end)
    return ok and result == true
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function randomPlate()
    return ('DZ%06d'):format(math.random(0, 999999)):sub(1, 8)
end

local function vehicleExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function hasVipValue(value)
    if value == nil then return false end
    local text = tostring(value):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' or text == '0' or text == 'false' or text == 'no' or text == 'null' or text == 'nil' then return false end
    return true
end

local function getUserVip(uid)
    local row = MySQL.single.await('SELECT vip FROM users WHERE uid = ? LIMIT 1', { uid })
    if not row then return false end
    return hasVipValue(row.vip)
end

local function getSpawnCoords(src)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    return { x = coords.x + -math.sin(rad) * 5.0, y = coords.y + math.cos(rad) * 5.0, z = coords.z + 0.75, h = heading }
end

local function cleanupVehicle(vehicleId)
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end
    local data = ActiveVehicles[vehicleId]
    if data and vehicleExists(data.entity) then DeleteEntity(data.entity) end
    ActiveVehicles[vehicleId] = nil
end

local function isVehicleSpawned(vehicleId)
    vehicleId = tonumber(vehicleId)
    local data = ActiveVehicles[vehicleId]
    if not data then return false end
    if not vehicleExists(data.entity) then ActiveVehicles[vehicleId] = nil return false end
    return true
end

local function setGarageVehicleState(entity, data)
    if not vehicleExists(entity) then return end
    local state = Entity(entity).state
    state:set('dz_garage_vehicle', true, true)
    state:set('dz_garage_owner_uid', tonumber(data.ownerUid) or 0, true)
    state:set('dz_garage_owner_name', tostring(data.ownerName or ''), true)
    state:set('dz_garage_db_id', tonumber(data.vehicleId) or 0, true)
    state:set('dz_garage_model', tostring(data.model or ''), true)
    state:set('dz_garage_name', tostring(data.name or 'Vehiculul tau'), true)
    state:set('dz_garage_plate', tostring(data.plate or ''), true)
    state:set('dz_garage_is_vip', data.vip == true, true)
    state:set('dz_garage_godmode', true, true)
end

local function getPlayerVehicles(uid)
    local hasVip = getUserVip(uid)
    local rows = MySQL.query.await([[ 
        SELECT
            ov.id, ov.owner_id, ov.vehicle_model, ov.vehicle_plate, ov.vehicle_tunning,
            ov.vehicle_fuel, ov.vehicle_engine, ov.vehicle_body, COALESCE(ov.vip, 0) AS vip,
            vn.vehicle_name, vn.vehicle_image, vn.image
        FROM ownedvehicles ov
        LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model
        WHERE ov.owner_id = ?
        ORDER BY ov.id DESC
    ]], { uid }) or {}

    local list = {}
    for _, row in ipairs(rows) do
        local isVipVehicle = tonumber(row.vip or 0) == 1 or row.vip == true
        if (not isVipVehicle) or hasVip then
            local model = tostring(row.vehicle_model or ''):lower()
            local image = row.vehicle_image or row.image or ''
            list[#list + 1] = {
                id = tonumber(row.id),
                model = model,
                name = tostring(row.vehicle_name or model or 'Vehicle'),
                plate = tostring(row.vehicle_plate or 'DRIFT'),
                image = tostring(image or ''),
                spawned = isVehicleSpawned(row.id),
                vip = isVipVehicle
            }
        end
    end

    return { vehicles = list, hasVip = hasVip }
end

local function sendGarageList(src)
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Trebuie sa fii logat ca sa deschizi garajul.') return end
    local payload = getPlayerVehicles(uid)
    TriggerClientEvent('driftzone_garage:client:open', src, payload.vehicles, payload.hasVip)
end

local function refreshGarageList(src)
    local uid = getUid(src)
    if not uid then return end
    local payload = getPlayerVehicles(uid)
    TriggerClientEvent('driftzone_garage:client:update', src, payload.vehicles, payload.hasVip)
end

RegisterNetEvent('driftzone_garage:server:open', function()
    local src = source
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end
    sendGarageList(src)
end)

RegisterNetEvent('driftzone_garage:server:spawn', function(vehicleId)
    local src = source
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId or vehicleId <= 0 then notify(src, 'warning', 'Vehicul invalid.') return end

    local rows = MySQL.query.await([[ 
        SELECT ov.id, ov.owner_id, ov.vehicle_model, ov.vehicle_plate, ov.vehicle_tunning,
               ov.vehicle_fuel, ov.vehicle_engine, ov.vehicle_body, COALESCE(ov.vip, 0) AS vip,
               vn.vehicle_name
        FROM ownedvehicles ov
        LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model
        WHERE ov.id = ? AND ov.owner_id = ?
        LIMIT 1
    ]], { vehicleId, uid }) or {}

    local row = rows[1]
    if not row then notify(src, 'warning', 'Acest vehicul nu iti apartine.') return end

    local isVipVehicle = tonumber(row.vip or 0) == 1 or row.vip == true
    if isVipVehicle and not getUserVip(uid) then
        notify(src, 'warning', 'Ai nevoie de VIP activ pentru acest vehicul.')
        return
    end

    if isVehicleSpawned(vehicleId) then notify(src, 'warning', 'Acest vehicul este deja spawnat.') refreshGarageList(src) return end

    local model = tostring(row.vehicle_model or ''):lower()
    if model == '' then notify(src, 'warning', 'Model vehicul invalid.') return end
    local hash = joaat(model)
    if not hash or hash == 0 then notify(src, 'warning', 'Model vehicul invalid.') return end

    local spawn = getSpawnCoords(src)
    local plate = tostring(row.vehicle_plate or randomPlate()):upper():gsub('%s+', ''):sub(1, 8)
    local vehicleName = tostring(row.vehicle_name or model)
    local tuningRaw = tostring(row.vehicle_tunning or '{}')
    local entity = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.h, true, true)

    local timeout = GetGameTimer() + 6000
    while not vehicleExists(entity) and GetGameTimer() < timeout do Wait(50) end
    if not vehicleExists(entity) then notify(src, 'warning', 'Nu am putut crea vehiculul. Verifica daca modelul este streamat corect.') return end

    SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(src))
    SetVehicleNumberPlateText(entity, plate)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    timeout = GetGameTimer() + 6000
    while (not netId or netId == 0) and GetGameTimer() < timeout do Wait(50) netId = NetworkGetNetworkIdFromEntity(entity) end
    if not netId or netId == 0 then cleanupVehicle(vehicleId) notify(src, 'warning', 'Vehiculul a fost creat, dar nu a primit Network ID.') return end

    ActiveVehicles[vehicleId] = { entity = entity, ownerUid = uid, ownerSrc = src, model = model, plate = plate, name = vehicleName, vip = isVipVehicle }

    setGarageVehicleState(entity, {
        ownerUid = uid, ownerName = getPlayerNameSafe(src), vehicleId = vehicleId,
        model = model, name = vehicleName, plate = plate, vip = isVipVehicle
    })

    TriggerClientEvent('driftzone_garage:client:spawnedSuccess', src)
    notify(src, 'info', ('Vehiculul %s a fost scos din garaj.'):format(vehicleName))
    refreshGarageList(src)

    TriggerClientEvent('driftzone_garage:client:prepareVehicle', src, netId, { id = vehicleId, model = model, name = vehicleName, plate = plate, tuning = tuningRaw })

    pcall(function()
        exports.driftzone_vs:RegisterVehicle(entity, { source = 'garage', sqlVehicleId = vehicleId, ownerId = uid, ownerName = getPlayerNameSafe(src), model = model, plate = plate })
    end)
    pcall(function()
        TriggerEvent('vs:registerVehicle', entity, { source = 'garage', sqlVehicleId = vehicleId, ownerId = uid, ownerName = getPlayerNameSafe(src), model = model, plate = plate })
    end)
end)

RegisterNetEvent('driftzone_garage:server:spawnPrepared', function(vehicleId) end)
RegisterNetEvent('driftzone_garage:server:spawnPrepareFailed', function(vehicleId) end)

RegisterNetEvent('driftzone_garage:server:despawn', function(vehicleId)
    local src = source
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Trebuie sa fii logat.') return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId or vehicleId <= 0 then notify(src, 'warning', 'Vehicul invalid.') return end
    local data = ActiveVehicles[vehicleId]
    if not data or not vehicleExists(data.entity) then ActiveVehicles[vehicleId] = nil notify(src, 'warning', 'Vehiculul nu este spawnat.') refreshGarageList(src) return end
    if tonumber(data.ownerUid) ~= tonumber(uid) then notify(src, 'warning', 'Nu poti despawna masina altcuiva.') return end
    pcall(function() exports.driftzone_vs:UnregisterVehicle(data.entity) end)
    pcall(function() TriggerEvent('vs:unregisterVehicle', data.entity) end)
    cleanupVehicle(vehicleId)
    notify(src, 'info', 'Vehiculul a fost despawnat.')
    refreshGarageList(src)
    TriggerClientEvent('driftzone_garage:client:spawnedSuccess', src)
end)

RegisterNetEvent('driftzone_garage:server:parkCurrent', function(netId)
    local src = source
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Trebuie sa fii logat.') return end
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicleExists(entity) then notify(src, 'warning', 'Nu esti intr-un vehicul valid.') return end
    local state = Entity(entity).state
    local ownerUid = tonumber(state.dz_garage_owner_uid or 0)
    local vehicleId = tonumber(state.dz_garage_db_id or 0)
    if ownerUid ~= tonumber(uid) or vehicleId <= 0 then notify(src, 'warning', 'Acest vehicul nu iti apartine.') return end
    pcall(function() exports.driftzone_vs:UnregisterVehicle(entity) end)
    pcall(function() TriggerEvent('vs:unregisterVehicle', entity) end)
    cleanupVehicle(vehicleId)
    notify(src, 'info', 'Vehiculul a fost parcat in garaj.')
    refreshGarageList(src)
end)

local function runCommand(src, command, args)
    command = tostring(command or ''):lower()
    if command == 'garage' or command == 'garaj' then
        TriggerClientEvent('driftzone_garage:client:openCommand', src)
        return
    end
    if command == 'park' then
        TriggerClientEvent('driftzone_garage:client:parkCurrent', src)
        return
    end
end

RegisterCommand('garage', function(src) if src ~= 0 then runCommand(src, 'garage', {}) end end, false)
RegisterCommand('garaj', function(src) if src ~= 0 then runCommand(src, 'garaj', {}) end end, false)
RegisterCommand('park', function(src) if src ~= 0 then runCommand(src, 'park', {}) end end, false)

exports('RunCommand', function(src, command, args)
    return runCommand(src, command, args or {})
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getUid(src)
    if not uid then return end
    for vehicleId, data in pairs(ActiveVehicles) do
        if tonumber(data.ownerUid) == tonumber(uid) then cleanupVehicle(vehicleId) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for vehicleId, _ in pairs(ActiveVehicles) do cleanupVehicle(vehicleId) end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_GARAGE] Server-side loaded. Old UI + VIP fixed.')
end)
