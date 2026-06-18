local ActiveVehicles = {}
local SpawnCooldowns = {}
local SpawnLocks = {}
local VehicleSpawnLocks = {}
local GarageBlocked = {}

local Garages = {}
local GarageById = {}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function notify(src, notifyType, message, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function db()
    return Config.Database or {}
end

local function garagesTable()
    return db().garagesTable or 'garages'
end

local function usersTable()
    return db().usersTable or 'users'
end

local function uidColumn()
    return db().uidColumn or 'uid'
end

local function adminColumn()
    return db().adminColumn or 'admin_level'
end

local function adutyColumn()
    return db().adutyColumn or 'aduty'
end

local function isAdutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    local state = Player(src).state
    if state then
        local keys = { 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }
        for _, key in ipairs(keys) do
            local uid = tonumber(state[key])
            if uid and uid > 0 then return uid end
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
        if ok and uid and uid > 0 then return uid end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and (state.dz_logged == true or state.logged == true or state.isLoggedIn == true) then return true end

    local attempts = {
        function() return exports.driftzone_auth:IsLoggedIn(src) end,
        function() return exports.driftzone_auth:isLoggedIn(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, result = pcall(fn)
        if ok and result == true then return true end
    end

    return getUid(src) ~= nil
end

local function getAdminData(src)
    local uid = getUid(src)
    if not uid then return nil end

    local ok, row = pcall(function()
        return MySQL.single.await(
            ('SELECT %s AS uid, %s AS admin_level, %s AS aduty FROM %s WHERE %s = ? LIMIT 1'):format(
                sqlName(uidColumn()),
                sqlName(adminColumn()),
                sqlName(adutyColumn()),
                sqlName(usersTable()),
                sqlName(uidColumn())
            ),
            { uid }
        )
    end)

    if not ok or not row then return nil end

    return {
        uid = uid,
        level = tonumber(row.admin_level or 0) or 0,
        aduty = isAdutyValue(row.aduty),
        name = getPlayerNameSafe(src)
    }
end

local function requireAdmin(src, minLevel)
    minLevel = tonumber(minLevel or 0) or 0

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local admin = getAdminData(src)

    if not admin or admin.level < minLevel then
        notify(src, 'warning', 'Nu ai gradul necesar.')
        return nil
    end

    if not admin.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return admin
end

local function setGarageBlocked(src, state, reason)
    src = tonumber(src or 0) or 0
    if src <= 0 then return false end

    if state == true then
        GarageBlocked[src] = tostring(reason or (Config.Block and Config.Block.defaultReason) or 'Garaj indisponibil.')
        TriggerClientEvent('driftzone_garage:client:setBlocked', src, true, GarageBlocked[src])
    else
        GarageBlocked[src] = nil
        TriggerClientEvent('driftzone_garage:client:setBlocked', src, false)
    end

    return true
end

local function isGarageBlocked(src)
    return GarageBlocked[tonumber(src or 0)] ~= nil
end

local function denyGarageOpen(src)
    notify(src, 'warning', GarageBlocked[tonumber(src or 0)] or 'Garaj indisponibil.', 3500)
    return true
end

local function ensureGaragesTable()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS %s (
            id INT NOT NULL AUTO_INCREMENT,
            name VARCHAR(96) NOT NULL DEFAULT 'Garage',
            x DOUBLE NOT NULL DEFAULT 0,
            y DOUBLE NOT NULL DEFAULT 0,
            z DOUBLE NOT NULL DEFAULT 0,
            radius DOUBLE NOT NULL DEFAULT 4,
            visible_radius TINYINT(1) NOT NULL DEFAULT 1,
            parking_spots LONGTEXT NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            created_by INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_active (active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]]):format(sqlName(garagesTable())))
end

local function encodeSpots(spots)
    local out = {}

    if type(spots) == 'table' then
        for _, spot in ipairs(spots) do
            local x = tonumber(spot.x or spot[1])
            local y = tonumber(spot.y or spot[2])
            local z = tonumber(spot.z or spot[3])
            local h = tonumber(spot.h or spot.w or spot[4] or spot.heading)

            if x and y and z then
                out[#out + 1] = {
                    x = x + 0.0,
                    y = y + 0.0,
                    z = z + 0.0,
                    h = h or 0.0
                }
            end
        end
    end

    local ok, encoded = pcall(json.encode, out)
    return ok and encoded or '[]'
end

local function decodeSpots(raw)
    if type(raw) == 'table' then raw = json.encode(raw) end

    local ok, data = pcall(json.decode, tostring(raw or '[]'))
    if not ok or type(data) ~= 'table' then return {} end

    local out = {}

    for _, spot in ipairs(data) do
        local x = tonumber(spot.x or spot[1])
        local y = tonumber(spot.y or spot[2])
        local z = tonumber(spot.z or spot[3])
        local h = tonumber(spot.h or spot.w or spot[4] or spot.heading)

        if x and y and z then
            out[#out + 1] = { x = x + 0.0, y = y + 0.0, z = z + 0.0, h = h or 0.0 }
        end
    end

    return out
end

local function convertVector3(v)
    if type(v) == 'vector3' then return v.x, v.y, v.z end
    if type(v) == 'table' then return tonumber(v.x or v[1]), tonumber(v.y or v[2]), tonumber(v.z or v[3]) end
    return nil, nil, nil
end

local function convertVector4(v)
    if type(v) == 'vector4' then return { x = v.x, y = v.y, z = v.z, h = v.w } end
    if type(v) == 'table' then
        return { x = tonumber(v.x or v[1]) or 0, y = tonumber(v.y or v[2]) or 0, z = tonumber(v.z or v[3]) or 0, h = tonumber(v.h or v.w or v[4]) or 0 }
    end
    return nil
end

local function migrateDefaultGaragesIfEmpty()
    local row = MySQL.single.await(('SELECT COUNT(*) AS count FROM %s WHERE active = 1'):format(sqlName(garagesTable())), {})
    if row and tonumber(row.count or 0) > 0 then return end

    for _, g in ipairs(Config.Garages or {}) do
        local x, y, z = convertVector3(g.coords)
        if x and y and z then
            local spots = {}

            if type(g.parking_spots) == 'table' then
                for _, spot in ipairs(g.parking_spots) do
                    local s = convertVector4(spot)
                    if s then spots[#spots + 1] = s end
                end
            elseif g.spawn then
                local s = convertVector4(g.spawn)
                if s then spots[#spots + 1] = s end
            end

            MySQL.insert.await(
                ('INSERT INTO %s (name, x, y, z, radius, visible_radius, parking_spots, active, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0)'):format(sqlName(garagesTable())),
                {
                    tostring(g.name or g.subText or g.id or 'Garage'),
                    x, y, z,
                    tonumber(g.radius or g.range or Config.DefaultGarageRadius or 4.0) or 4.0,
                    g.visible_radius == false and 0 or 1,
                    encodeSpots(spots)
                }
            )
        end
    end
end

local function loadGarages()
    Garages = {}
    GarageById = {}

    local rows = MySQL.query.await(('SELECT * FROM %s WHERE active = 1 ORDER BY id ASC'):format(sqlName(garagesTable())), {}) or {}

    for _, row in ipairs(rows) do
        local garage = {
            id = tonumber(row.id or 0) or 0,
            name = tostring(row.name or 'Garage'),
            coords = {
                x = tonumber(row.x or 0) or 0,
                y = tonumber(row.y or 0) or 0,
                z = tonumber(row.z or 0) or 0
            },
            radius = tonumber(row.radius or Config.DefaultGarageRadius or 4.0) or 4.0,
            visible_radius = tonumber(row.visible_radius or 1) == 1,
            parking_spots = decodeSpots(row.parking_spots or '[]')
        }

        if garage.id > 0 then
            Garages[#Garages + 1] = garage
            GarageById[garage.id] = garage
        end
    end

    TriggerClientEvent('driftzone_garage:client:syncGarages', -1, Garages)
    return Garages
end

local function distance3(a, b)
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function getPlayerCoordsTable(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end

    local c = GetEntityCoords(ped)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
end

local function getGarageForPlayer(src)
    local coords = getPlayerCoordsTable(src)
    if not coords then return nil end

    local best = nil
    local bestDist = 999999.0

    for _, garage in ipairs(Garages) do
        local dist = distance3(coords, garage.coords)
        if dist <= (tonumber(garage.radius or 4.0) or 4.0) and dist < bestDist then
            best = garage
            bestDist = dist
        end
    end

    return best, bestDist
end

local function syncGaragesTo(src)
    TriggerClientEvent('driftzone_garage:client:syncGarages', src, Garages)
end

local function randomPlate()
    return ('DZ%06d'):format(math.random(0, 999999)):sub(1, 8)
end

local function vehicleExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function getServerVehiclesSafe()
    local ok, vehicles = pcall(GetAllVehicles)
    if ok and type(vehicles) == 'table' then return vehicles end
    return {}
end

local function getGarageVehicleIdFromEntity(entity)
    if not vehicleExists(entity) then return 0 end
    local state = Entity(entity).state
    return tonumber(state.dz_garage_db_id or state.vehicleDbId or state.ownedVehicleId or state.dz_owned_vehicle_id or 0) or 0
end

local function findExistingGarageVehicle(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return 0 end

    local data = ActiveVehicles[vehicleId]
    if data and vehicleExists(data.entity) then return data.entity end

    for _, entity in ipairs(getServerVehiclesSafe()) do
        if vehicleExists(entity) and getGarageVehicleIdFromEntity(entity) == vehicleId then
            return entity
        end
    end

    return 0
end

local function updateActiveVehicleOwner(vehicleId, uid, ownerSrc)
    vehicleId = tonumber(vehicleId or 0) or 0
    uid = tonumber(uid or 0) or 0
    if vehicleId <= 0 or uid <= 0 then return end

    local data = ActiveVehicles[vehicleId]
    local entity = data and data.entity or findExistingGarageVehicle(vehicleId)

    if vehicleExists(entity) then
        ActiveVehicles[vehicleId] = ActiveVehicles[vehicleId] or { entity = entity, netId = NetworkGetNetworkIdFromEntity(entity) }
        ActiveVehicles[vehicleId].entity = entity
        ActiveVehicles[vehicleId].netId = NetworkGetNetworkIdFromEntity(entity)
        ActiveVehicles[vehicleId].ownerUid = uid
        ActiveVehicles[vehicleId].ownerSrc = ownerSrc or ActiveVehicles[vehicleId].ownerSrc

        local state = Entity(entity).state
        state:set('dz_garage_owner_uid', uid, true)
        if ownerSrc then state:set('dz_garage_owner_name', getPlayerNameSafe(ownerSrc), true) end
    end
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

local function cleanupVehicle(vehicleId)
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local data = ActiveVehicles[vehicleId]
    local deleted = {}

    if data and vehicleExists(data.entity) then
        deleted[data.entity] = true
        DeleteEntity(data.entity)
    end

    for _, entity in ipairs(getServerVehiclesSafe()) do
        if vehicleExists(entity) and not deleted[entity] and getGarageVehicleIdFromEntity(entity) == vehicleId then
            DeleteEntity(entity)
        end
    end

    ActiveVehicles[vehicleId] = nil
end

local function isVehicleSpawned(vehicleId)
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return false end

    local data = ActiveVehicles[vehicleId]
    if data and vehicleExists(data.entity) then return true end
    if data and not vehicleExists(data.entity) then ActiveVehicles[vehicleId] = nil end

    local entity = findExistingGarageVehicle(vehicleId)
    return vehicleExists(entity)
end

local function getCurrentVehicleOwner(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return nil end

    local row = MySQL.single.await('SELECT owner_id FROM ownedvehicles WHERE id = ? LIMIT 1', { vehicleId })
    return row and tonumber(row.owner_id or 0) or nil
end

local function normalizeTuning(raw)
    if type(raw) == 'table' then
        local ok, encoded = pcall(json.encode, raw)
        if ok and encoded and encoded ~= '' then return encoded end
        return '{}'
    end

    raw = tostring(raw or '{}')
    if raw == '' or raw == 'null' or raw == 'nil' then return '{}' end

    return raw
end

local function normalizeGradient(raw)
    if type(raw) == 'table' then
        local ok, encoded = pcall(json.encode, raw)
        if ok and encoded and encoded ~= '' then return encoded end
        return ''
    end

    raw = tostring(raw or '')
    if raw == '' or raw == 'null' or raw == 'nil' or raw == '{}' then return '' end

    return raw
end

local function setGarageVehicleState(entity, data)
    if not vehicleExists(entity) then return end

    local state = Entity(entity).state
    local tuningRaw = normalizeTuning(data.tuning or '{}')
    local gradientRaw = normalizeGradient(data.gradient or '')

    state:set('dz_garage_vehicle', true, true)
    state:set('dz_garage_owner_uid', tonumber(data.ownerUid) or 0, true)
    state:set('dz_garage_owner_name', tostring(data.ownerName or ''), true)
    state:set('dz_garage_db_id', tonumber(data.vehicleId) or 0, true)
    state:set('ownedVehicleId', tonumber(data.vehicleId) or 0, true)
    state:set('vehicle_id', tonumber(data.vehicleId) or 0, true)
    state:set('dz_garage_model', tostring(data.model or ''), true)
    state:set('dz_garage_name', tostring(data.name or 'Vehiculul tau'), true)
    state:set('dz_garage_plate', tostring(data.plate or ''), true)
    state:set('vehicle_plate', tostring(data.plate or ''), true)
    state:set('dz_garage_is_vip', data.vip == true, true)
    state:set('dz_garage_godmode', true, true)
    state:set('dz_garage_id', tonumber(data.garageId or 0) or 0, true)

    state:set('dz_garage_tuning', tuningRaw, true)
    state:set('vehicleTunning', tuningRaw, true)
    state:set('dz_vehicle_tunning', tuningRaw, true)

    state:set('dz_garage_gradient', gradientRaw, true)
    state:set('vehicleGradient', gradientRaw, true)
    state:set('dz_vehicle_gradient', gradientRaw, true)
end

local function getPlayerVehicles(uid)
    local hasVip = getUserVip(uid)

    local rows = MySQL.query.await([[
        SELECT
            ov.id, ov.owner_id, ov.vehicle_model, ov.vehicle_plate, ov.vehicle_tunning,
            ov.vehicle_fuel, ov.vehicle_engine, ov.vehicle_body, COALESCE(ov.vip, 0) AS vip,
            ov.gradient,
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
                id = tonumber(row.id) or 0,
                model = model,
                name = tostring(row.vehicle_name or model or 'Vehicle'),
                plate = tostring(row.vehicle_plate or 'DRIFT'),
                image = tostring(image or ''),
                spawned = isVehicleSpawned(row.id),
                vip = isVipVehicle,
                gradient = normalizeGradient(row.gradient or '')
            }
        end
    end

    return { vehicles = list, hasVip = hasVip }
end

local function sendGarageList(src, garage)
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Trebuie sa fii logat ca sa deschizi garajul.') return end

    local payload = getPlayerVehicles(uid)
    TriggerClientEvent('driftzone_garage:client:open', src, payload.vehicles, payload.hasVip, garage)
end

local function refreshGarageList(src, garage)
    local uid = getUid(src)
    if not uid then return end

    local payload = getPlayerVehicles(uid)
    TriggerClientEvent('driftzone_garage:client:update', src, payload.vehicles, payload.hasVip, garage)
end

local function getSpawnCooldownMs()
    return tonumber(Config and Config.SpawnCooldownMs or 3000) or 3000
end

local function checkSpawnCooldown(src)
    local now = GetGameTimer()
    local cooldownMs = getSpawnCooldownMs()
    local untilTime = SpawnCooldowns[src] or 0

    if untilTime > now then
        local left = math.ceil((untilTime - now) / 1000)
        notify(src, 'warning', ('Asteapta %s secunde inainte sa scoti alta masina.'):format(left), 3500)
        return false
    end

    SpawnCooldowns[src] = now + cooldownMs
    return true
end

local function isSpotFree(spot, bucket)
    local radius = tonumber(Config.ParkingSpotClearRadius or 3.2) or 3.2

    for _, entity in ipairs(getServerVehiclesSafe()) do
        if vehicleExists(entity) then
            local sameBucket = true
            local ok, vehBucket = pcall(GetEntityRoutingBucket, entity)
            if ok and vehBucket ~= nil then sameBucket = tonumber(vehBucket or 0) == tonumber(bucket or 0) end

            if sameBucket then
                local c = GetEntityCoords(entity)
                local dist = math.sqrt((c.x - spot.x) ^ 2 + (c.y - spot.y) ^ 2 + (c.z - spot.z) ^ 2)
                if dist <= radius then return false end
            end
        end
    end

    return true
end

local function findFreeParkingSpot(garage, bucket)
    if not garage or type(garage.parking_spots) ~= 'table' or #garage.parking_spots == 0 then return nil end

    for index, spot in ipairs(garage.parking_spots) do
        if isSpotFree(spot, bucket) then
            return spot, index
        end
    end

    return nil
end

RegisterNetEvent('driftzone_garage:server:requestGarages', function()
    syncGaragesTo(source)
end)

RegisterNetEvent('driftzone_garage:server:open', function()
    local src = source

    if isGarageBlocked(src) then denyGarageOpen(src) return end
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end

    local garage = getGarageForPlayer(src)
    if not garage then
        notify(src, 'warning', 'Nu esti la un garaj.')
        return
    end

    sendGarageList(src, garage)
end)

RegisterNetEvent('driftzone_garage:server:setBlocked', function(state, reason)
    local src = source
    if src and src > 0 then
        if state == true then
            GarageBlocked[src] = tostring(reason or 'Garaj indisponibil.')
        else
            GarageBlocked[src] = nil
        end
    end
end)

RegisterNetEvent('driftzone_garage:server:spawn', function(vehicleId, garageId)
    local src = source

    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end

    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    local garage = getGarageForPlayer(src)
    if not garage then
        notify(src, 'warning', 'Nu esti la un garaj.')
        return
    end

    garageId = tonumber(garageId or 0) or 0
    if garageId > 0 and garage.id ~= garageId then
        notify(src, 'warning', 'Nu esti la garajul selectat.')
        return
    end

    vehicleId = tonumber(vehicleId)
    if not vehicleId or vehicleId <= 0 then notify(src, 'warning', 'Vehicul invalid.') return end

    if SpawnLocks[src] or VehicleSpawnLocks[vehicleId] then
        notify(src, 'warning', 'Ai deja aceasta masina in curs de spawn.')
        return
    end

    if isVehicleSpawned(vehicleId) then
        updateActiveVehicleOwner(vehicleId, uid, src)
        notify(src, 'warning', 'Acest vehicul este deja spawnat.')
        refreshGarageList(src, garage)
        return
    end

    local bucket = GetPlayerRoutingBucket(src) or 0
    local spot, spotIndex = findFreeParkingSpot(garage, bucket)

    if not spot then
        notify(src, 'warning', 'Nu este niciun loc liber momentan.')
        return
    end

    if not checkSpawnCooldown(src) then return end

    SpawnLocks[src] = true
    VehicleSpawnLocks[vehicleId] = src

    local ok, err = pcall(function()
        local rows = MySQL.query.await([[
            SELECT ov.id, ov.owner_id, ov.vehicle_model, ov.vehicle_plate, ov.vehicle_tunning,
                   ov.gradient,
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

        if isVehicleSpawned(vehicleId) then
            notify(src, 'warning', 'Acest vehicul este deja spawnat.')
            refreshGarageList(src, garage)
            return
        end

        -- Reverifica locul dupa query.
        if not isSpotFree(spot, bucket) then
            spot, spotIndex = findFreeParkingSpot(garage, bucket)
            if not spot then
                notify(src, 'warning', 'Nu este niciun loc liber momentan.')
                return
            end
        end

        local model = tostring(row.vehicle_model or ''):lower()
        if model == '' then notify(src, 'warning', 'Model vehicul invalid.') return end

        local hash = joaat(model)
        if not hash or hash == 0 then notify(src, 'warning', 'Model vehicul invalid.') return end

        local plate = tostring(row.vehicle_plate or randomPlate()):upper():gsub('%s+', ''):sub(1, 8)
        local vehicleName = tostring(row.vehicle_name or model)
        local tuningRaw = normalizeTuning(row.vehicle_tunning or '{}')
        local gradientRaw = normalizeGradient(row.gradient or '')

        local entity = CreateVehicle(hash, spot.x, spot.y, spot.z, spot.h or 0.0, true, true)

        local timeout = GetGameTimer() + 6000
        while not vehicleExists(entity) and GetGameTimer() < timeout do Wait(50) end

        if not vehicleExists(entity) then
            notify(src, 'warning', 'Nu am putut crea vehiculul. Verifica daca modelul este streamat corect.')
            return
        end

        SetEntityRoutingBucket(entity, bucket)
        SetVehicleNumberPlateText(entity, plate)
        SetVehicleDoorsLocked(entity, 2)

        local netId = NetworkGetNetworkIdFromEntity(entity)
        timeout = GetGameTimer() + 6000

        while (not netId or netId == 0) and GetGameTimer() < timeout do
            Wait(50)
            netId = NetworkGetNetworkIdFromEntity(entity)
        end

        if not netId or netId == 0 then
            cleanupVehicle(vehicleId)
            notify(src, 'warning', 'Vehiculul a fost creat, dar nu a primit Network ID.')
            return
        end

        ActiveVehicles[vehicleId] = {
            entity = entity,
            netId = netId,
            ownerUid = uid,
            ownerSrc = src,
            model = model,
            plate = plate,
            name = vehicleName,
            vip = isVipVehicle,
            tuning = tuningRaw,
            gradient = gradientRaw,
            garageId = garage.id,
            parkingIndex = spotIndex
        }

        setGarageVehicleState(entity, {
            ownerUid = uid,
            ownerName = getPlayerNameSafe(src),
            vehicleId = vehicleId,
            model = model,
            name = vehicleName,
            plate = plate,
            vip = isVipVehicle,
            tuning = tuningRaw,
            gradient = gradientRaw,
            garageId = garage.id
        })

        pcall(function()
            TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', vehicleId, true)
            TriggerEvent('driftzone_vehicleconfig:server:setEngineOff', netId)
        end)

        TriggerClientEvent('driftzone_garage:client:spawnedSuccess', src)
        notify(src, 'info', ('Vehiculul %s a fost scos din garaj.'):format(vehicleName))
        refreshGarageList(src, garage)

        TriggerClientEvent('driftzone_garage:client:prepareVehicle', src, netId, {
            id = vehicleId,
            model = model,
            name = vehicleName,
            plate = plate,
            tuning = tuningRaw,
            gradient = gradientRaw,
            forceTuning = true
        })

        SetTimeout(1200, function()
            if GetPlayerName(src) and ActiveVehicles[vehicleId] and ActiveVehicles[vehicleId].netId == netId then
                TriggerClientEvent('driftzone_garage:client:forceTuning', src, netId, {
                    id = vehicleId,
                    tuning = tuningRaw,
                    gradient = gradientRaw,
                    plate = plate
                })
            end
        end)

        SetTimeout(3500, function()
            if GetPlayerName(src) and ActiveVehicles[vehicleId] and ActiveVehicles[vehicleId].netId == netId then
                TriggerClientEvent('driftzone_garage:client:forceTuning', src, netId, {
                    id = vehicleId,
                    tuning = tuningRaw,
                    gradient = gradientRaw,
                    plate = plate
                })
            end
        end)

        pcall(function()
            exports.driftzone_vs:RegisterVehicle(entity, {
                source = 'garage',
                sqlVehicleId = vehicleId,
                ownerId = uid,
                ownerName = getPlayerNameSafe(src),
                model = model,
                plate = plate
            })
        end)

        pcall(function()
            TriggerEvent('vs:registerVehicle', entity, {
                source = 'garage',
                sqlVehicleId = vehicleId,
                ownerId = uid,
                ownerName = getPlayerNameSafe(src),
                model = model,
                plate = plate
            })
        end)
    end)

    SpawnLocks[src] = nil
    VehicleSpawnLocks[vehicleId] = nil

    if not ok then
        print(('[DRIFTZONE_GARAGE] spawn error src=%s vehicleId=%s: %s'):format(src, vehicleId, tostring(err)))
        notify(src, 'error', 'A aparut o eroare la scoaterea masinii.')
    end
end)

RegisterNetEvent('driftzone_garage:server:spawnPrepared', function(vehicleId)
    local src = source
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local data = ActiveVehicles[vehicleId]
    if data and tonumber(data.ownerSrc) == tonumber(src) then data.preparedAt = os.time() end
end)

RegisterNetEvent('driftzone_garage:server:spawnPrepareFailed', function(vehicleId)
    local src = source
    vehicleId = tonumber(vehicleId)

    if vehicleId and ActiveVehicles[vehicleId] and tonumber(ActiveVehicles[vehicleId].ownerSrc) == tonumber(src) then
        print(('[DRIFTZONE_GARAGE] prepare failed src=%s vehicleId=%s'):format(src, vehicleId))
    end
end)

RegisterNetEvent('driftzone_garage:server:despawn', function(vehicleId)
    local src = source
    local uid = getUid(src)

    if not uid then notify(src, 'warning', 'Trebuie sa fii logat.') return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId or vehicleId <= 0 then notify(src, 'warning', 'Vehicul invalid.') return end

    local data = ActiveVehicles[vehicleId]
    local entity = data and data.entity or findExistingGarageVehicle(vehicleId)

    if not vehicleExists(entity) then
        ActiveVehicles[vehicleId] = nil
        notify(src, 'warning', 'Vehiculul nu este spawnat.')
        refreshGarageList(src, getGarageForPlayer(src))
        return
    end

    local currentOwner = getCurrentVehicleOwner(vehicleId)
    if tonumber(currentOwner or 0) ~= tonumber(uid) then
        notify(src, 'warning', 'Nu poti despawna masina altcuiva.')
        return
    end

    updateActiveVehicleOwner(vehicleId, uid, src)

    pcall(function() exports.driftzone_vs:UnregisterVehicle(entity) end)
    pcall(function() TriggerEvent('vs:unregisterVehicle', entity) end)

    cleanupVehicle(vehicleId)

    notify(src, 'info', 'Vehiculul a fost despawnat.')
    refreshGarageList(src, getGarageForPlayer(src))
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

    local currentOwner = getCurrentVehicleOwner(vehicleId)
    if vehicleId <= 0 or tonumber(currentOwner or ownerUid or 0) ~= tonumber(uid) then
        notify(src, 'warning', 'Acest vehicul nu iti apartine.')
        return
    end

    updateActiveVehicleOwner(vehicleId, uid, src)

    pcall(function() exports.driftzone_vs:UnregisterVehicle(entity) end)
    pcall(function() TriggerEvent('vs:unregisterVehicle', entity) end)

    cleanupVehicle(vehicleId)

    notify(src, 'info', 'Vehiculul a fost parcat in garaj.')
    refreshGarageList(src, getGarageForPlayer(src))
end)

local function sanitizeGaragePayload(data)
    data = type(data) == 'table' and data or {}

    local name = trim(data.name or '')
    if name == '' then return nil, 'Numele garajului este obligatoriu.' end

    local coords = data.coords or {}
    local x = tonumber(coords.x or data.x)
    local y = tonumber(coords.y or data.y)
    local z = tonumber(coords.z or data.z)
    local radius = tonumber(data.radius or 4.0) or 4.0
    local visible = data.visible_radius == true or data.visible_radius == 1 or tostring(data.visible_radius) == '1' or tostring(data.visible_radius):lower() == 'true'
    local id = tonumber(data.id or 0) or 0

    if not x or not y or not z then return nil, 'Coordonate garaj invalide.' end
    if radius < 1.0 then radius = 1.0 end
    if radius > 60.0 then radius = 60.0 end

    local spots = decodeSpots(data.parking_spots or data.spots or {})
    if #spots <= 0 then return nil, 'Adauga minim un loc de parcare.' end

    return {
        id = id,
        name = name:sub(1, 96),
        x = x + 0.0,
        y = y + 0.0,
        z = z + 0.0,
        radius = radius + 0.0,
        visible_radius = visible and 1 or 0,
        parking_spots = encodeSpots(spots)
    }
end

local function openAdminPanel(src, mode)
    local min = mode == 'add' and Config.Admin.minLevelAddGarage or Config.Admin.minLevelEditGarages
    if not requireAdmin(src, min or 6) then return false end

    TriggerClientEvent('driftzone_garage:client:openAdmin', src, {
        mode = mode == 'add' and 'add' or 'edit',
        garages = Garages
    })

    return true
end

RegisterNetEvent('driftzone_garage:server:adminOpen', function(mode)
    openAdminPanel(source, mode)
end)

RegisterNetEvent('driftzone_garage:server:adminSaveGarage', function(data)
    local src = source
    local admin = requireAdmin(src, Config.Admin.minLevelAddGarage or 6)
    if not admin then return end

    local payload, err = sanitizeGaragePayload(data)
    if not payload then
        notify(src, 'warning', err or 'Date garaj invalide.')
        return
    end

    if payload.id > 0 and GarageById[payload.id] then
        MySQL.update.await(
            ('UPDATE %s SET name = ?, x = ?, y = ?, z = ?, radius = ?, visible_radius = ?, parking_spots = ?, active = 1 WHERE id = ? LIMIT 1'):format(sqlName(garagesTable())),
            { payload.name, payload.x, payload.y, payload.z, payload.radius, payload.visible_radius, payload.parking_spots, payload.id }
        )
        notify(src, 'success', 'Garaj editat.')
    else
        local newId = MySQL.insert.await(
            ('INSERT INTO %s (name, x, y, z, radius, visible_radius, parking_spots, active, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)'):format(sqlName(garagesTable())),
            { payload.name, payload.x, payload.y, payload.z, payload.radius, payload.visible_radius, payload.parking_spots, admin.uid or 0 }
        )
        notify(src, 'success', ('Garaj adaugat cu ID %s.'):format(newId or '?'))
    end

    loadGarages()
    TriggerClientEvent('driftzone_garage:client:openAdmin', src, { mode = 'edit', garages = Garages })
end)

RegisterNetEvent('driftzone_garage:server:adminDeleteGarage', function(id)
    local src = source
    if not requireAdmin(src, Config.Admin.minLevelEditGarages or 6) then return end

    id = tonumber(id or 0) or 0
    if id <= 0 then notify(src, 'warning', 'ID garaj invalid.') return end

    MySQL.update.await(('UPDATE %s SET active = 0 WHERE id = ? LIMIT 1'):format(sqlName(garagesTable())), { id })
    notify(src, 'success', 'Garaj dezactivat.')
    loadGarages()
    TriggerClientEvent('driftzone_garage:client:openAdmin', src, { mode = 'edit', garages = Garages })
end)

RegisterNetEvent('driftzone_garage:server:resetGarages', function()
    local src = source
    if src ~= 0 and not requireAdmin(src, Config.Admin.minLevelResetGarages or 6) then return end

    loadGarages()

    if src and src > 0 then
        notify(src, 'success', 'Garajele au fost reincarcate din tabela garages.')
        TriggerClientEvent('driftzone_garage:client:openAdmin', src, { mode = 'edit', garages = Garages })
    end
end)

local function runCommand(src, command, args)
    command = tostring(command or ''):lower()

    if command == 'garage' or command == 'garaj' then
        if isGarageBlocked(src) then denyGarageOpen(src) return true end
        TriggerClientEvent('driftzone_garage:client:openCommand', src)
        return true
    end

    if command == 'park' then
        TriggerClientEvent('driftzone_garage:client:parkCurrent', src)
        return true
    end

    if command == 'addgarage' then
        return openAdminPanel(src, 'add')
    end

    if command == 'editgarages' then
        return openAdminPanel(src, 'edit')
    end

    if command == 'resetgarages' then
        if not requireAdmin(src, Config.Admin.minLevelResetGarages or 6) then return false end
        loadGarages()
        notify(src, 'success', 'Garajele au fost reincarcate din tabela garages.')
        TriggerClientEvent('driftzone_garage:client:openAdmin', src, { mode = 'edit', garages = Garages })
        return true
    end

    return false
end

RegisterCommand('garage', function(src) if src ~= 0 then runCommand(src, 'garage', {}) end end, false)
RegisterCommand('garaj', function(src) if src ~= 0 then runCommand(src, 'garaj', {}) end end, false)
RegisterCommand('park', function(src) if src ~= 0 then runCommand(src, 'park', {}) end end, false)

RegisterCommand('addgarage', function(src)
    if src ~= 0 then openAdminPanel(src, 'add') end
end, false)

RegisterCommand('editgarages', function(src)
    if src ~= 0 then openAdminPanel(src, 'edit') end
end, false)

RegisterCommand('resetgarages', function(src)
    if src ~= 0 then
        if not requireAdmin(src, Config.Admin.minLevelResetGarages or 6) then return end
        loadGarages()
        notify(src, 'success', 'Garajele au fost reincarcate din tabela garages.')
        TriggerClientEvent('driftzone_garage:client:openAdmin', src, { mode = 'edit', garages = Garages })
    else
        loadGarages()
        print('[DRIFTZONE_GARAGE] Garages reloaded from DB.')
    end
end, false)

exports('RunCommand', function(src, command, args)
    return runCommand(src, command, args or {})
end)

exports('SetGarageBlocked', function(src, state, reason)
    return setGarageBlocked(src, state == true, reason or 'Garaj indisponibil.')
end)

exports('BlockGarage', function(src, reason)
    return setGarageBlocked(src, true, reason or 'Garaj indisponibil.')
end)

exports('UnblockGarage', function(src)
    return setGarageBlocked(src, false)
end)

exports('IsGarageBlocked', function(src)
    return isGarageBlocked(src)
end)

exports('GetActiveVehicle', function(vehicleId)
    vehicleId = tonumber(vehicleId)
    return vehicleId and ActiveVehicles[vehicleId] or nil
end)

exports('ReloadGarages', function()
    return loadGarages()
end)

AddEventHandler('playerDropped', function()
    local src = source
    GarageBlocked[src] = nil
    local uid = getUid(src)

    SpawnCooldowns[src] = nil
    SpawnLocks[src] = nil

    if not uid then return end

    for vehicleId, data in pairs(ActiveVehicles) do
        if tonumber(data.ownerUid) == tonumber(uid) then cleanupVehicle(vehicleId) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for vehicleId, _ in pairs(ActiveVehicles) do cleanupVehicle(vehicleId) end

    ActiveVehicles = {}
    SpawnCooldowns = {}
    SpawnLocks = {}
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    ensureGaragesTable()
    migrateDefaultGaragesIfEmpty()
    loadGarages()

    print(('[DRIFTZONE_GARAGE] Server-side loaded. DB garages=%s, parking spots, admin editor.'):format(#Garages))
end)
