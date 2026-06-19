local Calls = {}
local PlayerCall = {}
local PhoneCache = {}
local UidCache = {}
local UserColumns = nil
local NextCallId = 0
local GarageVehicles = {}
local GarageSpawnLocks = {}
local GarageSpawnCooldowns = {}
local PendingGarageSpawns = {}
local GaragesCache = nil
local GaragesCacheExpires = 0
local sendState

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function cleanNumber(number)
    number = tostring(number or '')
    number = number:gsub('%s+', '')
    number = number:gsub('[^%d]', '')
    return number
end

local function jsonEncode(data)
    local ok, res = pcall(json.encode, data or {})
    if ok then return res end
    return '{}'
end

local function jsonDecode(raw)
    if type(raw) == 'table' then return raw end
    local ok, res = pcall(json.decode, tostring(raw or '{}'))
    if ok and type(res) == 'table' then return res end
    return {}
end

local function sendFeedback(src, payload)
    src = tonumber(src)
    if src and src > 0 then
        TriggerClientEvent('driftzone_phone:client:feedback', src, payload or {})
    end
end

local function getUserColumns()
    if UserColumns then return UserColumns end
    UserColumns = {}
    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM %s'):format(sqlName(Config.UsersTable or 'users')), {}) or {}
    end)
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row and row.Field then UserColumns[tostring(row.Field)] = true end
        end
    end
    return UserColumns
end

local function getPhoneColumns()
    local cols = getUserColumns()
    local out, added = {}, {}
    local function add(name)
        name = tostring(name or '')
        if name ~= '' and not added[name] and (cols[name] == true or next(cols) == nil) then
            added[name] = true
            out[#out + 1] = name
        end
    end
    add(Config.PhoneColumn or 'phonenumber')
    for _, name in ipairs(Config.PhoneColumns or {}) do add(name) end
    if #out <= 0 then out[1] = Config.PhoneColumn or 'phonenumber' end
    return out
end

local function normalizeSqlExpr(columnName)
    local col = ('COALESCE(CAST(%s AS CHAR), \'\')'):format(sqlName(columnName))
    local chars = { ' ', '-', '.', '+', '(', ')', '/', '_', ':' }
    local expr = col
    for _, ch in ipairs(chars) do
        expr = ("REPLACE(%s, '%s', '')"):format(expr, ch:gsub("'", "\\'"))
    end
    return expr
end

local function getUid(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local state = Player(src).state
    for _, key in ipairs({ 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }) do
        local value = state and tonumber(state[key])
        if value and value > 0 then return value end
    end
    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then return cached.uid end
    local res = Config.AuthResource or 'driftzone_auth'
    if GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:GetUID(src) end,
            function() return exports[res]:GetUid(src) end,
            function() return exports[res]:getUID(src) end,
            function() return exports[res]:GetUserId(src) end,
            function() return exports[res]:getUserId(src) end,
            function() return exports[res]:getUserID(src) end
        }
        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            local uid = tonumber(value)
            if ok and uid and uid > 0 then
                UidCache[src] = { uid = uid, expires = GetGameTimer() + 30000 }
                return uid
            end
        end
    end
    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end
    local res = Config.AuthResource or 'driftzone_auth'
    if GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:IsLoggedIn(src) end,
            function() return exports[res]:isLoggedIn(src) end,
            function() return exports[res]:IsLogged(src) end
        }
        for _, fn in ipairs(attempts) do
            local ok, result = pcall(fn)
            if ok and result == true then return true end
        end
    end
    return getUid(src) ~= nil
end

local function getPhoneByUid(uid, force)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return nil end
    local cached = PhoneCache[uid]
    if not force and cached and cached.expires > GetGameTimer() then return cached.phone end
    local phone = nil
    for _, col in ipairs(getPhoneColumns()) do
        local ok, row = pcall(function()
            return MySQL.single.await(
                ('SELECT %s AS phone FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(col), sqlName(Config.UsersTable or 'users'), sqlName(Config.UsersIdColumn or 'uid')),
                { uid }
            )
        end)
        if ok and row then
            phone = cleanNumber(row.phone)
            if phone ~= '' then break end
        end
    end
    if phone == '' then phone = nil end
    PhoneCache[uid] = { phone = phone, expires = GetGameTimer() + 7000 }
    return phone
end

local function getUidByPhone(phone)
    phone = cleanNumber(phone)
    if phone == '' then return nil end
    for _, col in ipairs(getPhoneColumns()) do
        local expr = normalizeSqlExpr(col)
        local ok, row = pcall(function()
            return MySQL.single.await(
                ('SELECT %s AS uid FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(Config.UsersIdColumn or 'uid'), sqlName(Config.UsersTable or 'users'), expr),
                { phone }
            )
        end)
        if ok and row and tonumber(row.uid) then return tonumber(row.uid) end
    end
    return nil
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)
    if not uid then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getUid(src) == uid then return src end
    end
    return nil
end

local function getPlayerByPhone(phone)
    local uid = getUidByPhone(phone)
    if not uid then return nil, nil end
    return getPlayerByUid(uid), uid
end

local function getContactName(ownerUid, number)
    ownerUid = tonumber(ownerUid)
    number = cleanNumber(number)
    if not ownerUid or ownerUid <= 0 or number == '' then return nil end
    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT contact_name FROM %s WHERE owner_uid = ? AND phone_number = ? LIMIT 1'):format(sqlName(Config.ContactsTable)), { ownerUid, number })
    end)
    if ok and row and trim(row.contact_name) ~= '' then return trim(row.contact_name) end
    return nil
end

local function isBlocked(ownerUid, number)
    ownerUid = tonumber(ownerUid)
    number = cleanNumber(number)
    if not ownerUid or ownerUid <= 0 or number == '' then return false end
    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT blocked FROM %s WHERE owner_uid = ? AND phone_number = ? LIMIT 1'):format(sqlName(Config.ContactsTable)), { ownerUid, number })
    end)
    return ok and row and tonumber(row.blocked or 0) == 1
end

local function getContacts(uid)
    uid = tonumber(uid)
    if not uid then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT id, contact_name, phone_number, blocked FROM %s WHERE owner_uid = ? ORDER BY contact_name ASC LIMIT ?'):format(sqlName(Config.ContactsTable)), { uid, tonumber(Config.ContactsLimit or 300) or 300 }) or {}
    end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            id = tonumber(row.id or 0) or 0,
            name = tostring(row.contact_name or ''),
            number = cleanNumber(row.phone_number),
            blocked = tonumber(row.blocked or 0) == 1
        }
    end
    return out
end

local function addCallHistory(ownerUid, otherNumber, otherName, direction, status, duration)
    ownerUid = tonumber(ownerUid)
    if not ownerUid then return end
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (owner_uid, other_number, other_name, direction, status, duration, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.CallHistoryTable)), {
            ownerUid, cleanNumber(otherNumber), tostring(otherName or ''), tostring(direction or ''), tostring(status or ''), tonumber(duration or 0) or 0
        })
    end)
end

local function getCallHistory(uid)
    uid = tonumber(uid)
    if not uid then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT id, other_number, other_name, direction, status, duration, created_at FROM %s WHERE owner_uid = ? ORDER BY id DESC LIMIT ?'):format(sqlName(Config.CallHistoryTable)), { uid, tonumber(Config.HistoryLimit or 80) or 80 }) or {}
    end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for _, row in ipairs(rows) do
        local num = cleanNumber(row.other_number)
        out[#out + 1] = {
            id = tonumber(row.id or 0) or 0,
            number = num,
            name = getContactName(uid, num) or tostring(row.other_name or '') or '',
            direction = tostring(row.direction or ''),
            status = tostring(row.status or ''),
            duration = tonumber(row.duration or 0) or 0,
            created_at = tostring(row.created_at or '')
        }
    end
    return out
end

local function getMessages(uid)
    uid = tonumber(uid)
    if not uid then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await(([=[
            SELECT id, sender_uid, receiver_uid, sender_number, receiver_number, message, message_type, location_json, created_at
            FROM %s
            WHERE sender_uid = ? OR receiver_uid = ?
            ORDER BY id DESC
            LIMIT ?
        ]=]):format(sqlName(Config.MessageHistoryTable)), { uid, uid, tonumber(Config.MessageLimit or 250) or 250 }) or {}
    end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for i = #rows, 1, -1 do
        local row = rows[i]
        local mine = tonumber(row.sender_uid or 0) == uid
        local otherNumber = mine and cleanNumber(row.receiver_number) or cleanNumber(row.sender_number)
        out[#out + 1] = {
            id = tonumber(row.id or 0) or 0,
            mine = mine,
            otherNumber = otherNumber,
            otherName = getContactName(uid, otherNumber) or otherNumber,
            from = cleanNumber(row.sender_number),
            to = cleanNumber(row.receiver_number),
            text = tostring(row.message or ''),
            type = tostring(row.message_type or 'text'),
            location = jsonDecode(row.location_json),
            created_at = tostring(row.created_at or '')
        }
    end
    return out
end

local function makeCallId()
    NextCallId = NextCallId + 1
    return ('dzcall_%s_%s'):format(os.time(), NextCallId)
end

local function getCallForPlayer(src)
    local callId = PlayerCall[tonumber(src)]
    if not callId then return nil, nil end
    local call = Calls[callId]
    if not call then PlayerCall[tonumber(src)] = nil return nil, nil end
    return callId, call
end

local function otherParticipant(call, src)
    src = tonumber(src)
    if call.a == src then return call.b end
    if call.b == src then return call.a end
    return nil
end


-- =========================
-- GARAGE PHONE APP
-- =========================

local function garageCfg()
    return Config.Garage or {}
end

local function garageTable()
    return garageCfg().GaragesTable or 'garages'
end

local function ownedVehiclesTable()
    return garageCfg().OwnedVehiclesTable or 'ownedvehicles'
end

local function garageColumn()
    return garageCfg().GarageColumn or 'garage'
end

local function cashColumn()
    return Config.UsersCashColumn or 'cash'
end

local function vehicleExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function getServerVehiclesSafe()
    local ok, vehicles = pcall(GetAllVehicles)
    if ok and type(vehicles) == 'table' then return vehicles end
    return {}
end

local function decodeJsonList(raw)
    if type(raw) == 'table' then return raw end
    local ok, data = pcall(json.decode, tostring(raw or '[]'))
    if ok and type(data) == 'table' then return data end
    return {}
end

local function encodeJson(data)
    local ok, encoded = pcall(json.encode, data or {})
    return ok and encoded or '{}'
end

local function normalizeTuning(raw)
    if type(raw) == 'table' then return encodeJson(raw) end
    raw = tostring(raw or '{}')
    if raw == '' or raw == 'null' or raw == 'nil' then return '{}' end
    return raw
end

local function normalizeGradient(raw)
    if type(raw) == 'table' then return encodeJson(raw) end
    raw = tostring(raw or '')
    if raw == '' or raw == 'null' or raw == 'nil' or raw == '{}' then return '' end
    return raw
end

local function getEntityVehicleId(entity)
    if not vehicleExists(entity) then return 0 end
    local state = Entity(entity).state
    return tonumber(state.dz_phone_garage_vehicle_id or state.dz_garage_db_id or state.ownedVehicleId or state.vehicle_id or 0) or 0
end

local function getGarageById(id)
    id = tonumber(id or 0) or 0
    if id <= 0 then return nil end
    local garages = loadPhoneGarages()
    for _, g in ipairs(garages) do
        if tonumber(g.id or 0) == id then return g end
    end
    return nil
end

function loadPhoneGarages(force)
    local now = GetGameTimer()
    if force ~= true and GaragesCache and GaragesCacheExpires > now then return GaragesCache end

    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT * FROM %s WHERE active = 1 ORDER BY id ASC'):format(sqlName(garageTable())), {}) or {}
    end)

    local garages = {}

    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            local spots = {}
            for _, spot in ipairs(decodeJsonList(row.parking_spots or '[]')) do
                local x = tonumber(spot.x or spot[1])
                local y = tonumber(spot.y or spot[2])
                local z = tonumber(spot.z or spot[3])
                local h = tonumber(spot.h or spot.w or spot[4] or spot.heading or 0) or 0
                if x and y and z then
                    spots[#spots + 1] = { x = x + 0.0, y = y + 0.0, z = z + 0.0, h = h + 0.0 }
                end
            end

            garages[#garages + 1] = {
                id = tonumber(row.id or 0) or 0,
                name = tostring(row.name or 'Garage'),
                x = tonumber(row.x or 0) or 0,
                y = tonumber(row.y or 0) or 0,
                z = tonumber(row.z or 0) or 0,
                radius = tonumber(row.radius or 4) or 4,
                park_radius = tonumber(row.park_radius or row.radius or 12) or 12,
                parking_spots = spots,
                visible_radius = tonumber(row.visible_radius or 1) == 1
            }
        end
    end

    GaragesCache = garages
    GaragesCacheExpires = now + 8000
    return garages
end

local function distance3(a, b)
    local ax, ay, az = tonumber(a.x or 0) or 0, tonumber(a.y or 0) or 0, tonumber(a.z or 0) or 0
    local bx, by, bz = tonumber(b.x or 0) or 0, tonumber(b.y or 0) or 0, tonumber(b.z or 0) or 0
    return math.sqrt((ax - bx)^2 + (ay - by)^2 + (az - bz)^2)
end

local function getPlayerCoordsTable(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
end

local function getGarageForPlayerPhone(src)
    local coords = getPlayerCoordsTable(src)
    if not coords then return nil end

    local best, bestDist = nil, 999999.0
    for _, garage in ipairs(loadPhoneGarages()) do
        local dist = distance3(coords, garage)
        local radius = tonumber(garage.radius or 4) or 4
        if dist <= radius and dist < bestDist then
            best, bestDist = garage, dist
        end
    end

    return best, bestDist
end

local function getParkGarageForPlayerPhone(src)
    local coords = getPlayerCoordsTable(src)
    if not coords then return nil end

    local best, bestDist = nil, 999999.0
    for _, garage in ipairs(loadPhoneGarages()) do
        local dist = distance3(coords, garage)
        local radius = tonumber(garage.park_radius or garage.radius or 12) or 12
        if dist <= radius and dist < bestDist then
            best, bestDist = garage, dist
        end
    end

    return best, bestDist
end


local function getGarageForCoordsPhone(coords, useParkRadius)
    if not coords then return nil end

    local best, bestDist = nil, 999999.0

    for _, garage in ipairs(loadPhoneGarages()) do
        local dist = distance3(coords, garage)
        local radius = tonumber(garage.radius or 4) or 4

        if useParkRadius == true then
            radius = tonumber(garage.park_radius or garage.radius or radius) or radius
        end

        if dist <= radius and dist < bestDist then
            best, bestDist = garage, dist
        end
    end

    return best, bestDist
end

local function getGarageForVehiclePhone(entity)
    if not vehicleExists(entity) then return nil end
    local c = GetEntityCoords(entity)
    return getGarageForCoordsPhone({ x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }, true)
end


local function findGarageVehicleEntity(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return 0 end

    local data = GarageVehicles[vehicleId]
    if data and vehicleExists(data.entity) then return data.entity end

    for _, entity in ipairs(getServerVehiclesSafe()) do
        if vehicleExists(entity) and getEntityVehicleId(entity) == vehicleId then
            return entity
        end
    end

    return 0
end

local function isGarageVehicleSpawned(vehicleId)
    return vehicleExists(findGarageVehicleEntity(vehicleId))
end

local function getOutsideLimit(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return 1 end

    local col = garageCfg().OutsideVehiclesColumn or 'outsidevehicles'
    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT COALESCE(%s, 1) AS lim FROM %s WHERE %s = ? LIMIT 1'):format(
            sqlName(col), sqlName(Config.UsersTable or 'users'), sqlName(Config.UsersIdColumn or 'uid')
        ), { uid })
    end)

    local limit = ok and row and tonumber(row.lim or 1) or 1
    limit = math.floor(tonumber(limit or 1) or 1)
    if limit < 0 then limit = 0 end
    if limit > 50 then limit = 50 end
    return limit
end

local function getOutsideCount(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return 0 end

    local ids = {}

    for vehicleId, data in pairs(GarageVehicles or {}) do
        if data and tonumber(data.ownerUid or 0) == uid and vehicleExists(data.entity) then
            ids[tonumber(vehicleId) or 0] = true
        end
    end

    for _, entity in ipairs(getServerVehiclesSafe()) do
        if vehicleExists(entity) then
            local state = Entity(entity).state
            local ownerUid = tonumber(state.dz_phone_garage_owner_uid or state.dz_garage_owner_uid or 0) or 0
            local vehicleId = tonumber(state.dz_phone_garage_vehicle_id or state.dz_garage_db_id or state.ownedVehicleId or 0) or 0
            if ownerUid == uid and vehicleId > 0 then ids[vehicleId] = true end
        end
    end

    local count = 0
    for id in pairs(ids) do
        if tonumber(id or 0) and tonumber(id or 0) > 0 then count = count + 1 end
    end

    return count
end

local function isSpotFreePhone(spot, bucket)
    local radius = tonumber(garageCfg().ParkingSpotClearRadius or 3.2) or 3.2

    for _, entity in ipairs(getServerVehiclesSafe()) do
        if vehicleExists(entity) then
            local sameBucket = true
            local ok, vehBucket = pcall(GetEntityRoutingBucket, entity)
            if ok and vehBucket ~= nil then sameBucket = tonumber(vehBucket or 0) == tonumber(bucket or 0) end

            if sameBucket then
                local c = GetEntityCoords(entity)
                local dist = math.sqrt((c.x - spot.x)^2 + (c.y - spot.y)^2 + (c.z - spot.z)^2)
                if dist <= radius then return false end
            end
        end
    end

    return true
end

local function findFreeSpotPhone(garage, bucket)
    if not garage or type(garage.parking_spots) ~= 'table' then return nil end
    for index, spot in ipairs(garage.parking_spots) do
        if isSpotFreePhone(spot, bucket) then return spot, index end
    end
    return nil
end

local function getPhoneGarageVehicleRows(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return {} end

    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT id, owner_id, vehicle_model, vehicle_plate, vehicle_tunning, gradient,
                   COALESCE(vip, 0) AS vip, COALESCE(%s, 0) AS garage
            FROM %s
            WHERE owner_id = ?
            ORDER BY id DESC
        ]]):format(sqlName(garageColumn()), sqlName(ownedVehiclesTable())), { uid }) or {}
    end)

    if not ok or type(rows) ~= 'table' then
        print('[DRIFTZONE_PHONE] garage vehicle query failed: ' .. tostring(rows))
        return {}
    end

    -- Optional name lookup. Daca tabela nu exista, nu opreste aplicatia.
    local nameByModel = {}
    pcall(function()
        local namesTable = (garageCfg().VehicleNamesTable or Config.VehicleNamesTable or 'vehiclesnames')
        local nameRows = MySQL.query.await(('SELECT vehicle_model, vehicle_name FROM %s'):format(sqlName(namesTable)), {}) or {}
        for _, n in ipairs(nameRows) do
            local model = tostring(n.vehicle_model or ''):lower()
            if model ~= '' then nameByModel[model] = tostring(n.vehicle_name or model) end
        end
    end)

    local garagesById = {}
    for _, g in ipairs(loadPhoneGarages()) do garagesById[tonumber(g.id or 0) or 0] = g end

    local out = {}
    for _, row in ipairs(rows) do
        local vehicleId = tonumber(row.id or 0) or 0
        local rawGarageId = tonumber(row.garage or 0) or 0
        local garageId = rawGarageId
        if garageId <= 0 then
            garageId = tonumber((garageCfg() or {}).DefaultGarageId or 1) or 1
        end

        local active = GarageVehicles[vehicleId]
        local entity = findGarageVehicleEntity(vehicleId)
        local activeSpawned = active ~= nil and tonumber(active.netId or 0) > 0
        local entitySpawned = vehicleExists(entity) or activeSpawned

        -- Stabil:
        -- AFARA este doar masina spawnata in sesiunea curenta.
        -- garage=0 ramas pe masini vechi nu mai face toate masinile AFARA.
        local spawned = entitySpawned
        local stored = not spawned

        local currentGarageId = active and tonumber(active.garageId or 0) or 0
        local garage = garagesById[garageId]
        local model = tostring(row.vehicle_model or ''):lower()
        local displayName = nameByModel[model] or model or 'Vehicle'

        out[#out + 1] = {
            id = vehicleId,
            model = model,
            name = displayName,
            plate = tostring(row.vehicle_plate or 'DRIFT'),
            vip = tonumber(row.vip or 0) == 1,
            garage = garageId,
            rawGarage = rawGarageId,
            garageId = garageId,
            garageName = garage and garage.name or (garageId > 0 and ('Garaj #' .. garageId) or 'Pe strada'),
            stored = stored,
            spawned = spawned,
            entitySpawned = entitySpawned,
            activeGarageId = currentGarageId,
            image = ''
        }
    end

    return out
end

local function getPhoneGarageState(src, uid)
    uid = tonumber(uid or 0) or 0
    local openGarage = getGarageForPlayerPhone(src)
    local parkGarage = getParkGarageForPlayerPhone(src)
    local currentGarage = openGarage or parkGarage
    local garages = loadPhoneGarages()

    return {
        enabled = (garageCfg().Enabled ~= false),
        towPrice = tonumber(garageCfg().TowPrice or 5000) or 5000,
        atGarage = currentGarage ~= nil,
        currentGarage = currentGarage,
        openGarage = openGarage,
        parkGarage = parkGarage,
        garages = garages,
        vehicles = uid > 0 and getPhoneGarageVehicleRows(uid) or {},
        outsideLimit = uid > 0 and getOutsideLimit(uid) or 1,
        outsideCount = uid > 0 and getOutsideCount(uid) or 0
    }
end

local function notifyPhone(src, typ, message, duration)
    TriggerClientEvent('client:notify', src, typ or 'info', duration or 4500, tostring(message or ''))
end

local function refreshPhoneGarage(src)
    src = tonumber(src or 0) or 0
    if src > 0 and isLogged(src) then
        if sendState then
            sendState(src)
        else
            TriggerClientEvent('driftzone_phone:client:state', src, publicCallStateFor(src))
        end
    end
end

local function setVehicleStatePhone(entity, data)
    if not vehicleExists(entity) then return end
    local state = Entity(entity).state
    state:set('dz_phone_garage_vehicle', true, true)
    state:set('dz_phone_garage_vehicle_id', tonumber(data.vehicleId or 0) or 0, true)
    state:set('dz_phone_garage_owner_uid', tonumber(data.ownerUid or 0) or 0, true)
    state:set('dz_phone_garage_plate', tostring(data.plate or ''), true)
    state:set('dz_phone_garage_model', tostring(data.model or ''), true)
    state:set('dz_garage_vehicle', true, true)
    state:set('dz_garage_db_id', tonumber(data.vehicleId or 0) or 0, true)
    state:set('ownedVehicleId', tonumber(data.vehicleId or 0) or 0, true)
    state:set('dz_garage_owner_uid', tonumber(data.ownerUid or 0) or 0, true)
    state:set('dz_garage_tuning', normalizeTuning(data.tuning or '{}'), true)
    state:set('dz_garage_gradient', normalizeGradient(data.gradient or ''), true)
end

local function cleanupPhoneGarageVehicle(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return end

    local entity = findGarageVehicleEntity(vehicleId)
    if vehicleExists(entity) then
        DeleteEntity(entity)
    end

    GarageVehicles[vehicleId] = nil
end

local function ensurePhoneGarageTables()
    pcall(function()
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT NOT NULL AUTO_INCREMENT,
                name VARCHAR(96) NOT NULL DEFAULT 'Garage',
                x DOUBLE NOT NULL DEFAULT 0,
                y DOUBLE NOT NULL DEFAULT 0,
                z DOUBLE NOT NULL DEFAULT 0,
                radius DOUBLE NOT NULL DEFAULT 4,
                park_radius DOUBLE NOT NULL DEFAULT 12,
                visible_radius TINYINT(1) NOT NULL DEFAULT 1,
                parking_spots LONGTEXT NULL,
                active TINYINT(1) NOT NULL DEFAULT 1,
                created_by INT NOT NULL DEFAULT 0,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_garages_active (active)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]]):format(sqlName(garageTable())), {})
    end)

    pcall(function()
        MySQL.query.await(('ALTER TABLE %s ADD COLUMN IF NOT EXISTS %s INT NOT NULL DEFAULT %s'):format(
            sqlName(ownedVehiclesTable()),
            sqlName(garageColumn()),
            tonumber(garageCfg().DefaultGarageId or 1) or 1
        ))
    end)

    pcall(function()
        MySQL.query.await(('ALTER TABLE %s ADD COLUMN IF NOT EXISTS `%s` INT NOT NULL DEFAULT 1'):format(
            sqlName(Config.UsersTable or 'users'),
            tostring(garageCfg().OutsideVehiclesColumn or 'outsidevehicles'):gsub('`', '')
        ))
    end)
end




local function publicCallStateFor(src)
    local uid = getUid(src)
    local myPhone = uid and getPhoneByUid(uid, true) or nil
    local callId, call = getCallForPlayer(src)
    local state = {
        myNumber = myPhone or '',
        inCall = false,
        incoming = false,
        outgoing = false,
        active = false,
        otherNumber = '',
        otherName = '',
        callId = nil,
        startedAt = 0,
        contacts = uid and getContacts(uid) or {},
        callHistory = uid and getCallHistory(uid) or {},
        messages = uid and getMessages(uid) or {},
        garage = uid and getPhoneGarageState(src, uid) or { enabled = false, vehicles = {}, garages = {}, atGarage = false }
    }
    if call then
        local otherSrc = otherParticipant(call, src)
        local otherPhone = call.a == src and call.bPhone or call.aPhone
        state.inCall = true
        state.active = call.state == 'active'
        state.incoming = call.state == 'ringing' and call.to == src
        state.outgoing = call.state == 'ringing' and call.from == src
        state.otherNumber = tostring(otherPhone or '')
        state.otherName = uid and (getContactName(uid, otherPhone) or tostring(otherPhone or '')) or tostring(otherPhone or '')
        state.callId = callId
        state.startedAt = call.startedAt or 0
    end
    return state
end

sendState = function(src)
    src = tonumber(src)
    if src and src > 0 then
        TriggerClientEvent('driftzone_phone:client:state', src, publicCallStateFor(src))
    end
end

local function sendCallStates(call)
    if not call then return end
    sendState(call.a)
    sendState(call.b)
end

local function failCall(src, title, text)
    sendFeedback(src, { kind = 'call_fail', title = title or 'Apel esuat', text = text or '', sound = 'decline' })
    sendState(src)
end

local function endCall(callId, reason, endedBy)
    local call = Calls[callId]
    if not call then return end
    Calls[callId] = nil
    PlayerCall[call.a] = nil
    PlayerCall[call.b] = nil
    TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId)

    local aUid = getUid(call.a)
    local bUid = getUid(call.b)
    local duration = 0
    if call.startedAt and call.startedAt > 0 then duration = math.max(0, os.time() - call.startedAt) end

    if reason == 'missed' then
        if aUid then addCallHistory(aUid, call.bPhone, call.bName, 'outgoing', 'missed', 0) end
        if bUid then addCallHistory(bUid, call.aPhone, call.aName, 'missed', 'missed', 0) end
        sendFeedback(call.from, { kind = 'missed', sound = 'decline' })
    elseif reason == 'declined' then
        if aUid then addCallHistory(aUid, call.bPhone, call.bName, 'outgoing', 'declined', 0) end
        if bUid then addCallHistory(bUid, call.aPhone, call.aName, 'incoming', 'declined', 0) end
        sendFeedback(call.from, { kind = 'declined', sound = 'decline' })
    elseif reason == 'ended' then
        local status = call.state == 'active' and 'answered' or 'ended'
        if aUid then addCallHistory(aUid, call.bPhone, call.bName, call.from == call.a and 'outgoing' or 'incoming', status, duration) end
        if bUid then addCallHistory(bUid, call.aPhone, call.aName, call.from == call.b and 'outgoing' or 'incoming', status, duration) end
        local other = endedBy and otherParticipant(call, endedBy) or nil
        if other then sendFeedback(other, { kind = 'ended' }) end
    end

    sendFeedback(call.a, { kind = 'call_closed' })
    sendFeedback(call.b, { kind = 'call_closed' })
    sendState(call.a)
    sendState(call.b)
end



-- =========================
-- GARAGE ADMIN COMMANDS / EDITOR
-- =========================
local function phoneAdutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getGarageAdmin(src)
    local uid = getUid(src)
    if not uid then return nil end

    local adminColumn = (Config.Admin and Config.Admin.adminColumn) or 'admin_level'
    local adutyColumn = (Config.Admin and Config.Admin.adutyColumn) or 'aduty'

    local row = MySQL.single.await(('SELECT %s AS admin_level, %s AS aduty FROM %s WHERE %s = ? LIMIT 1'):format(
        sqlName(adminColumn),
        sqlName(adutyColumn),
        sqlName(Config.UsersTable or 'users'),
        sqlName(Config.UsersIdColumn or 'uid')
    ), { uid })

    if not row then return nil end

    return {
        uid = uid,
        level = tonumber(row.admin_level or 0) or 0,
        aduty = phoneAdutyValue(row.aduty)
    }
end

local function requireGarageAdmin(src)
    local minLevel = tonumber((Config.Admin and Config.Admin.minLevelGarage) or 6) or 6
    local admin = getGarageAdmin(src)

    if not admin or admin.level < minLevel then
        notifyPhone(src, 'warning', 'Nu ai acces la aceasta comanda.')
        return nil
    end

    if not admin.aduty then
        notifyPhone(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return admin
end

local function sanitizeGaragePayload(data)
    data = type(data) == 'table' and data or {}
    local coords = type(data.coords) == 'table' and data.coords or {}

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then return nil, 'Coordonate garaj invalide.' end

    local name = tostring(data.name or 'Garaj'):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = 'Garaj' end

    local radius = tonumber(data.radius or 4.0) or 4.0
    local parkRadius = tonumber(data.park_radius or data.parkRadius or 12.0) or 12.0
    if radius < 1.0 then radius = 1.0 end
    if radius > 60.0 then radius = 60.0 end
    if parkRadius < 1.0 then parkRadius = 1.0 end
    if parkRadius > 120.0 then parkRadius = 120.0 end

    local spots = {}
    for _, spot in ipairs(type(data.parking_spots) == 'table' and data.parking_spots or {}) do
        local sx = tonumber(spot.x)
        local sy = tonumber(spot.y)
        local sz = tonumber(spot.z)
        local sh = tonumber(spot.h or spot.heading or 0) or 0
        if sx and sy and sz then
            spots[#spots + 1] = { x = sx + 0.0, y = sy + 0.0, z = sz + 0.0, h = sh + 0.0 }
        end
    end

    if #spots <= 0 then return nil, 'Adauga minim un loc de parcare.' end

    local ok, encoded = pcall(json.encode, spots)
    return {
        id = tonumber(data.id or 0) or 0,
        name = name,
        x = x + 0.0,
        y = y + 0.0,
        z = z + 0.0,
        radius = radius + 0.0,
        park_radius = parkRadius + 0.0,
        visible_radius = (data.visible_radius == false or data.visible_radius == 0 or tostring(data.visible_radius):lower() == 'false' or tostring(data.visible_radius) == '0') and 0 or 1,
        parking_spots = ok and encoded or '[]'
    }
end

local function openGarageAdminPanel(src, mode)
    if not requireGarageAdmin(src) then return false end
    TriggerClientEvent('driftzone_phone:client:garageAdminOpen', src, {
        mode = mode or 'edit',
        garages = loadPhoneGarages(true)
    })
    return true
end

RegisterNetEvent('driftzone_phone:server:garageAdminSave', function(data)
    local src = source
    local admin = requireGarageAdmin(src)
    if not admin then return end

    local payload, err = sanitizeGaragePayload(data or {})
    if not payload then
        notifyPhone(src, 'warning', err or 'Date invalide.')
        TriggerClientEvent('driftzone_phone:client:garageAdminResult', src, false, err or 'Date invalide.')
        return
    end

    local ok, sqlErr = pcall(function()
        if payload.id > 0 then
            MySQL.update.await(('UPDATE %s SET name = ?, x = ?, y = ?, z = ?, radius = ?, park_radius = ?, visible_radius = ?, parking_spots = ?, active = 1 WHERE id = ?'):format(sqlName(garageTable())), {
                payload.name,
                payload.x,
                payload.y,
                payload.z,
                payload.radius,
                payload.park_radius,
                payload.visible_radius,
                payload.parking_spots,
                payload.id
            })
        else
            local id = MySQL.insert.await(('INSERT INTO %s (name, x, y, z, radius, park_radius, visible_radius, parking_spots, active, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)'):format(sqlName(garageTable())), {
                payload.name,
                payload.x,
                payload.y,
                payload.z,
                payload.radius,
                payload.park_radius,
                payload.visible_radius,
                payload.parking_spots,
                admin.uid or 0
            })
            payload.id = tonumber(id or 0) or 0
        end
    end)

    if not ok then
        print('[DRIFTZONE_PHONE] garage save SQL error: ' .. tostring(sqlErr))
        notifyPhone(src, 'error', 'Garajul nu a putut fi salvat. Verifica consola.')
        TriggerClientEvent('driftzone_phone:client:garageAdminResult', src, false, 'Garajul nu a putut fi salvat.')
        return
    end

    GaragesCache = nil
    local garages = loadPhoneGarages(true)

    notifyPhone(src, 'success', 'Garaj salvat.')
    TriggerClientEvent('driftzone_phone:client:garageAdminResult', src, true, 'Garaj salvat.', garages)
    TriggerClientEvent('driftzone_phone:client:garageWorld', -1, garages)

    SetTimeout(500, function()
        TriggerClientEvent('driftzone_phone:client:garageWorld', -1, loadPhoneGarages(true))
    end)
end)

RegisterNetEvent('driftzone_phone:server:garageAdminDelete', function(id)
    local src = source
    if not requireGarageAdmin(src) then return end

    id = tonumber(id or 0) or 0
    if id <= 0 then return end

    MySQL.update.await(('UPDATE %s SET active = 0 WHERE id = ?'):format(sqlName(garageTable())), { id })
    GaragesCache = nil
    local garages = loadPhoneGarages(true)
    TriggerClientEvent('driftzone_phone:client:garageAdminResult', src, true, 'Garaj dezactivat.', garages)
    TriggerClientEvent('driftzone_phone:client:garageWorld', -1, garages)
end)

RegisterNetEvent('driftzone_phone:server:garageAdminReload', function()
    local src = source
    if not requireGarageAdmin(src) then return end

    GaragesCache = nil
    local garages = loadPhoneGarages(true)
    notifyPhone(src, 'success', 'Garajele au fost reincarcate.')
    TriggerClientEvent('driftzone_phone:client:garageAdminOpen', src, { mode = 'edit', garages = garages })
    TriggerClientEvent('driftzone_phone:client:garageWorld', src, garages)
end)

RegisterCommand('addgarage', function(src)
    if src ~= 0 then openGarageAdminPanel(src, 'add') end
end, false)

RegisterCommand('editgarages', function(src)
    if src ~= 0 then openGarageAdminPanel(src, 'edit') end
end, false)

RegisterCommand('resetgarages', function(src)
    if src ~= 0 then
        if not requireGarageAdmin(src) then return end
        GaragesCache = nil
        local garages = loadPhoneGarages(true)
        notifyPhone(src, 'success', 'Garajele au fost reincarcate.')
        TriggerClientEvent('driftzone_phone:client:garageAdminOpen', src, { mode = 'edit', garages = garages })
        TriggerClientEvent('driftzone_phone:client:garageWorld', src, garages)
    else
        GaragesCache = nil
        loadPhoneGarages(true)
        print('[DRIFTZONE_PHONE] Garages reloaded.')
    end
end, false)


RegisterNetEvent('driftzone_phone:server:requestGarageWorld', function()
    TriggerClientEvent('driftzone_phone:client:garageWorld', source, loadPhoneGarages(true))
end)

RegisterNetEvent('driftzone_phone:server:requestState', function()
    local src = source
    if isLogged(src) then sendState(src) end
end)

RegisterNetEvent('driftzone_phone:server:startCall', function(rawNumber)
    local src = source
    if not isLogged(src) then return failCall(src, 'Telefon blocat', 'Trebuie sa fii logat.') end
    if PlayerCall[src] then return failCall(src, 'Linie ocupata', 'Esti deja intr-un apel.') end

    local number = cleanNumber(rawNumber)
    if number == '' or #number < (Config.PhoneNumberMinLength or 1) or #number > (Config.PhoneNumberMaxLength or 32) then
        return failCall(src, 'Numar invalid', 'Numarul nu este valid.')
    end

    local uid = getUid(src)
    local myPhone = uid and getPhoneByUid(uid, true) or nil
    if not myPhone then return failCall(src, 'Numar lipsa', 'Nu ai users.phonenumber setat.') end
    if number == myPhone then return failCall(src, 'Numar invalid', 'Nu te poti suna singur.') end

    local target, targetUid = getPlayerByPhone(number)
    if not targetUid then return failCall(src, 'Numar inexistent', 'Numarul nu exista.') end
    if not target then return failCall(src, 'Telefon indisponibil', 'Persoana nu este pe server.') end
    if isBlocked(targetUid, myPhone) then return failCall(src, 'Apel blocat', 'Persoana nu poate fi apelata.') end
    if PlayerCall[target] then return failCall(src, 'Linie ocupata', 'Persoana este deja intr-un apel.') end

    local callId = makeCallId()
    local targetPhone = getPhoneByUid(targetUid, true) or number
    local call = {
        id = callId,
        a = src,
        b = target,
        from = src,
        to = target,
        aPhone = myPhone,
        bPhone = targetPhone,
        aName = getContactName(targetUid, myPhone) or myPhone,
        bName = getContactName(uid, targetPhone) or targetPhone,
        state = 'ringing',
        createdAt = os.time(),
        startedAt = 0
    }
    Calls[callId] = call
    PlayerCall[src] = callId
    PlayerCall[target] = callId

    sendFeedback(src, { kind = 'ringing', sound = 'ring' })
    TriggerClientEvent('driftzone_phone:client:incoming', target, publicCallStateFor(target))
    sendCallStates(call)

    SetTimeout(tonumber(Config.CallTimeoutMs or 30000) or 30000, function()
        local current = Calls[callId]
        if current and current.state == 'ringing' then endCall(callId, 'missed') end
    end)
end)

RegisterNetEvent('driftzone_phone:server:answerCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call or call.state ~= 'ringing' or call.to ~= src then return sendState(src) end
    call.state = 'active'
    call.startedAt = os.time()
    TriggerEvent('driftzone_voicechat:server:startPhoneCall', callId, call.a, call.b)
    sendCallStates(call)
end)

RegisterNetEvent('driftzone_phone:server:declineCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end
    if call.state == 'ringing' and call.to == src then endCall(callId, 'declined', src) else endCall(callId, 'ended', src) end
end)

RegisterNetEvent('driftzone_phone:server:hangupCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end
    endCall(callId, 'ended', src)
end)

RegisterNetEvent('driftzone_phone:server:saveContact', function(data)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    if not uid then return end
    data = type(data) == 'table' and data or {}
    local id = tonumber(data.id or 0) or 0
    local name = trim(data.name)
    local number = cleanNumber(data.number)
    if name == '' or number == '' then return sendState(src) end

    if id > 0 then
        pcall(function()
            MySQL.update.await(('UPDATE %s SET contact_name = ?, phone_number = ?, updated_at = NOW() WHERE id = ? AND owner_uid = ?'):format(sqlName(Config.ContactsTable)), { name, number, id, uid })
        end)
    else
        pcall(function()
            MySQL.update.await(('INSERT INTO %s (owner_uid, contact_name, phone_number, blocked, created_at, updated_at) VALUES (?, ?, ?, 0, NOW(), NOW()) ON DUPLICATE KEY UPDATE contact_name = VALUES(contact_name), updated_at = NOW()'):format(sqlName(Config.ContactsTable)), { uid, name, number })
        end)
    end
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:toggleBlock', function(contactId)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    contactId = tonumber(contactId or 0) or 0
    if not uid or contactId <= 0 then return end
    pcall(function()
        MySQL.update.await(('UPDATE %s SET blocked = IF(blocked = 1, 0, 1), updated_at = NOW() WHERE id = ? AND owner_uid = ?'):format(sqlName(Config.ContactsTable)), { contactId, uid })
    end)
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:deleteContact', function(contactId)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    contactId = tonumber(contactId or 0) or 0
    if not uid or contactId <= 0 then return end
    pcall(function()
        MySQL.update.await(('DELETE FROM %s WHERE id = ? AND owner_uid = ? LIMIT 1'):format(sqlName(Config.ContactsTable)), { contactId, uid })
    end)
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:sendMessage', function(data)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    if not uid then return end
    data = type(data) == 'table' and data or {}
    local toNumber = cleanNumber(data.number)
    local text = trim(data.text)
    local msgType = tostring(data.type or 'text')
    local location = type(data.location) == 'table' and data.location or {}
    if toNumber == '' then return sendState(src) end
    if msgType ~= 'location' and text == '' then return sendState(src) end
    if msgType == 'location' then text = 'Locatie partajata' end

    local myPhone = getPhoneByUid(uid, true)
    if not myPhone then return sendState(src) end
    local targetUid = getUidByPhone(toNumber)
    if not targetUid then return sendFeedback(src, { kind = 'message_failed', sound = 'decline' }) end
    if isBlocked(targetUid, myPhone) then return sendFeedback(src, { kind = 'message_blocked', sound = 'decline' }) end

    local clientToken = tostring(data.clientToken or '')
    local insertedId = 0
    pcall(function()
        insertedId = MySQL.insert.await(('INSERT INTO %s (sender_uid, receiver_uid, sender_number, receiver_number, message, message_type, location_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.MessageHistoryTable)), {
            uid, targetUid, myPhone, toNumber, text, msgType, jsonEncode(location)
        }) or 0
    end)

    local senderMessage = {
        id = insertedId,
        mine = true,
        otherNumber = toNumber,
        otherName = getContactName(uid, toNumber) or toNumber,
        from = myPhone,
        to = toNumber,
        text = text,
        type = msgType,
        location = location,
        clientToken = clientToken,
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }

    TriggerClientEvent('driftzone_phone:client:messageSync', src, senderMessage)
    sendFeedback(src, { kind = 'message_sent', sound = 'message' })

    local target = getPlayerByUid(targetUid)
    if target then
        local receiverMessage = {
            id = insertedId,
            mine = false,
            otherNumber = myPhone,
            otherName = getContactName(targetUid, myPhone) or myPhone,
            from = myPhone,
            to = toNumber,
            text = text,
            type = msgType,
            location = location,
            created_at = os.date('%Y-%m-%d %H:%M:%S')
        }
        TriggerClientEvent('driftzone_phone:client:messageSync', target, receiverMessage)
        TriggerClientEvent('driftzone_phone:client:messageReceived', target, {
            id = insertedId,
            from = myPhone,
            name = getContactName(targetUid, myPhone) or myPhone,
            text = text,
            type = msgType,
            location = location,
            sound = 'message'
        })
    end
end)



RegisterNetEvent('driftzone_phone:server:garageSpawn', function(vehicleId)
    local src = source
    if not isLogged(src) then return end

    local uid = getUid(src)
    if not uid then return notifyPhone(src, 'warning', 'Trebuie sa fii logat.') end

    local garage = getGarageForPlayerPhone(src) or getParkGarageForPlayerPhone(src)
    if not garage then
        notifyPhone(src, 'warning', 'Nu esti la garaj.')
        return refreshPhoneGarage(src)
    end

    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return notifyPhone(src, 'warning', 'Vehicul invalid.') end

    if GarageSpawnLocks[src] or PendingGarageSpawns[vehicleId] then
        notifyPhone(src, 'warning', 'Ai deja o masina in curs de spawn.')
        return
    end

    if isGarageVehicleSpawned(vehicleId) then
        notifyPhone(src, 'warning', 'Masina este deja scoasa.')
        return refreshPhoneGarage(src)
    end

    local now = GetGameTimer()
    local cooldown = tonumber(garageCfg().SpawnCooldownMs or 3000) or 3000
    if (GarageSpawnCooldowns[src] or 0) > now then return end
    GarageSpawnCooldowns[src] = now + cooldown

    local outsideLimit = getOutsideLimit(uid)
    local outsideCount = getOutsideCount(uid)
    if outsideCount >= outsideLimit then
        notifyPhone(src, 'warning', ('Ai limita de masini spawnate: %s/%s.'):format(outsideCount, outsideLimit))
        return refreshPhoneGarage(src)
    end

    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT id, owner_id, vehicle_model, vehicle_plate, vehicle_tunning, gradient,
                   COALESCE(vip, 0) AS vip, COALESCE(%s, 0) AS garage
            FROM %s
            WHERE id = ? AND owner_id = ?
            LIMIT 1
        ]]):format(sqlName(garageColumn()), sqlName(ownedVehiclesTable())), { vehicleId, uid }) or {}
    end)

    local row = ok and rows and rows[1] or nil
    if not row then
        notifyPhone(src, 'warning', 'Acest vehicul nu iti apartine.')
        return refreshPhoneGarage(src)
    end

    local storedGarage = tonumber(row.garage or 0) or 0
    if storedGarage <= 0 then
        storedGarage = tonumber((garageCfg() or {}).DefaultGarageId or 1) or 1
    end

    if storedGarage ~= tonumber(garage.id or 0) then
        notifyPhone(src, 'warning', 'Masina nu se afla in acest garaj.')
        return refreshPhoneGarage(src)
    end

    local bucket = GetPlayerRoutingBucket(src) or 0
    local spot, spotIndex = findFreeSpotPhone(garage, bucket)
    if not spot then
        notifyPhone(src, 'warning', 'Nu este niciun loc liber momentan.')
        return refreshPhoneGarage(src)
    end

    local model = tostring(row.vehicle_model or ''):lower()
    if model == '' then
        notifyPhone(src, 'warning', 'Model vehicul invalid.')
        return refreshPhoneGarage(src)
    end

    local plate = tostring(row.vehicle_plate or 'DRIFT'):upper():gsub('%s+', ''):sub(1, 8)
    local tuningRaw = normalizeTuning(row.vehicle_tunning or '{}')
    local gradientRaw = normalizeGradient(row.gradient or '')

    PendingGarageSpawns[vehicleId] = {
        src = src,
        uid = uid,
        vehicleId = vehicleId,
        model = model,
        plate = plate,
        tuning = tuningRaw,
        gradient = gradientRaw,
        garageId = tonumber(garage.id or 0) or 0,
        garage = garage,
        spotIndex = spotIndex,
        bucket = bucket,
        createdAt = GetGameTimer()
    }
    GarageSpawnLocks[src] = vehicleId

    TriggerClientEvent('driftzone_phone:client:garageCreateVehicle', src, {
        id = vehicleId,
        model = model,
        plate = plate,
        name = model,
        tuning = tuningRaw,
        gradient = gradientRaw,
        spawn = {
            x = tonumber(spot.x or 0) or 0,
            y = tonumber(spot.y or 0) or 0,
            z = tonumber(spot.z or 0) or 0,
            h = tonumber(spot.h or 0) or 0
        }
    })

    SetTimeout(15000, function()
        local pending = PendingGarageSpawns[vehicleId]
        if pending and pending.src == src then
            PendingGarageSpawns[vehicleId] = nil
            GarageSpawnLocks[src] = nil
            TriggerClientEvent('driftzone_phone:client:garageDeletePending', src, vehicleId)
            notifyPhone(src, 'error', 'Masina nu a putut fi scoasa.')
            refreshPhoneGarage(src)
        end
    end)
end)

RegisterNetEvent('driftzone_phone:server:garageConfirmSpawn', function(vehicleId, netId)
    local src = source
    vehicleId = tonumber(vehicleId or 0) or 0
    netId = tonumber(netId or 0) or 0

    local pending = PendingGarageSpawns[vehicleId]
    if not pending or pending.src ~= src or netId <= 0 then
        if netId > 0 then TriggerClientEvent('driftzone_phone:client:garageDeleteNet', src, netId) end
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local timeout = GetGameTimer() + 5000
    while not vehicleExists(entity) and GetGameTimer() < timeout do
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
    end

    if not vehicleExists(entity) then
        PendingGarageSpawns[vehicleId] = nil
        GarageSpawnLocks[src] = nil
        notifyPhone(src, 'error', 'Masina a fost creata, dar serverul nu o poate citi.')
        return refreshPhoneGarage(src)
    end

    SetEntityRoutingBucket(entity, pending.bucket or 0)
    SetEntityHeading(entity, tonumber((pending.garage.parking_spots[pending.spotIndex] or {}).h or 0) or 0)
    SetVehicleNumberPlateText(entity, pending.plate)
    SetVehicleDoorsLocked(entity, 2)

    setVehicleStatePhone(entity, {
        vehicleId = vehicleId,
        ownerUid = pending.uid,
        model = pending.model,
        plate = pending.plate,
        tuning = pending.tuning,
        gradient = pending.gradient
    })

    GarageVehicles[vehicleId] = {
        entity = entity,
        netId = netId,
        ownerUid = pending.uid,
        ownerSrc = src,
        model = pending.model,
        plate = pending.plate,
        garageId = pending.garageId
    }

    pcall(function()
        MySQL.update.await(('UPDATE %s SET %s = 0 WHERE id = ? AND owner_id = ? LIMIT 1'):format(sqlName(ownedVehiclesTable()), sqlName(garageColumn())), {
            vehicleId, pending.uid
        })
    end)

    pcall(function()
        TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', vehicleId, true)
        TriggerEvent('driftzone_vehicleconfig:server:setEngineOff', netId)
    end)

    PendingGarageSpawns[vehicleId] = nil
    GarageSpawnLocks[src] = nil

    notifyPhone(src, 'success', 'Masina a fost scoasa din garaj.')
    TriggerClientEvent('driftzone_phone:client:garageSpawnSuccess', src, vehicleId)
    refreshPhoneGarage(src)

    SetTimeout(900, function()
        refreshPhoneGarage(src)
    end)
end)

RegisterNetEvent('driftzone_phone:server:garageSpawnFailed', function(vehicleId, reason)
    local src = source
    vehicleId = tonumber(vehicleId or 0) or 0

    local pending = PendingGarageSpawns[vehicleId]
    if pending and pending.src == src then
        PendingGarageSpawns[vehicleId] = nil
        GarageSpawnLocks[src] = nil
    end

    notifyPhone(src, 'error', tostring(reason or 'Nu am putut scoate masina.'))
    refreshPhoneGarage(src)
end)

RegisterNetEvent('driftzone_phone:server:garagePark', function(vehicleId)
    local src = source
    if not isLogged(src) then return end

    local uid = getUid(src)
    if not uid then return notifyPhone(src, 'warning', 'Trebuie sa fii logat.') end

    local playerGarage = getParkGarageForPlayerPhone(src) or getGarageForPlayerPhone(src)
    if not playerGarage then
        notifyPhone(src, 'warning', 'Nu esti la garaj.')
        return refreshPhoneGarage(src)
    end

    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return notifyPhone(src, 'warning', 'Vehicul invalid.') end

    local row = MySQL.single.await(('SELECT id, owner_id FROM %s WHERE id = ? AND owner_id = ? LIMIT 1'):format(sqlName(ownedVehiclesTable())), { vehicleId, uid })
    if not row then
        notifyPhone(src, 'warning', 'Acest vehicul nu iti apartine.')
        return refreshPhoneGarage(src)
    end

    local entity = findGarageVehicleEntity(vehicleId)
    if not vehicleExists(entity) then
        notifyPhone(src, 'warning', 'Masina nu este scoasa.')
        return refreshPhoneGarage(src)
    end

    local vehicleGarage = getGarageForVehiclePhone(entity)
    if not vehicleGarage then
        notifyPhone(src, 'warning', 'Masina nu este langa niciun garaj.')
        return refreshPhoneGarage(src)
    end

    if tonumber(vehicleGarage.id or 0) ~= tonumber(playerGarage.id or 0) then
        notifyPhone(src, 'warning', 'Tu si masina trebuie sa fiti la acelasi garaj.')
        return refreshPhoneGarage(src)
    end

    cleanupPhoneGarageVehicle(vehicleId)

    MySQL.update.await(('UPDATE %s SET %s = ? WHERE id = ? AND owner_id = ? LIMIT 1'):format(sqlName(ownedVehiclesTable()), sqlName(garageColumn())), {
        tonumber(playerGarage.id or 0) or 0, vehicleId, uid
    })

    notifyPhone(src, 'success', 'Masina a fost parcata.')
    refreshPhoneGarage(src)
end)


RegisterNetEvent('driftzone_phone:server:garageParkCurrent', function(netId)
    local src = source
    if not isLogged(src) then return end

    local uid = getUid(src)
    if not uid then return notifyPhone(src, 'warning', 'Trebuie sa fii logat.') end

    local entity = NetworkGetEntityFromNetworkId(tonumber(netId or 0) or 0)
    if not vehicleExists(entity) then
        notifyPhone(src, 'warning', 'Nu esti intr-o masina valida.')
        return
    end

    local state = Entity(entity).state
    local ownerUid = tonumber(state.dz_phone_garage_owner_uid or state.dz_garage_owner_uid or 0) or 0
    local vehicleId = tonumber(state.dz_phone_garage_vehicle_id or state.dz_garage_db_id or state.ownedVehicleId or 0) or 0

    if ownerUid ~= uid or vehicleId <= 0 then
        notifyPhone(src, 'warning', 'Aceasta masina nu iti apartine.')
        return
    end

    TriggerEvent('driftzone_phone:server:garagePark', vehicleId)
end)


RegisterNetEvent('driftzone_phone:server:garageTow', function(vehicleId)
    local src = source
    if not isLogged(src) then return end

    local uid = getUid(src)
    if not uid then return notifyPhone(src, 'warning', 'Trebuie sa fii logat.') end

    local garage = getGarageForPlayerPhone(src) or getParkGarageForPlayerPhone(src)
    if not garage then
        notifyPhone(src, 'warning', 'Nu esti la garaj.')
        return refreshPhoneGarage(src)
    end

    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return notifyPhone(src, 'warning', 'Vehicul invalid.') end

    if isGarageVehicleSpawned(vehicleId) then
        notifyPhone(src, 'warning', 'Masina este scoasa. Nu poate fi tractata.')
        return refreshPhoneGarage(src)
    end

    local row = MySQL.single.await(('SELECT id, owner_id, COALESCE(%s, 0) AS garage FROM %s WHERE id = ? AND owner_id = ? LIMIT 1'):format(
        sqlName(garageColumn()), sqlName(ownedVehiclesTable())
    ), { vehicleId, uid })

    if not row then
        notifyPhone(src, 'warning', 'Acest vehicul nu iti apartine.')
        return refreshPhoneGarage(src)
    end

    local currentGarageId = tonumber(row.garage or 0) or 0
    local targetGarageId = tonumber(garage.id or 0) or 0

    if isGarageVehicleSpawned(vehicleId) then
        notifyPhone(src, 'warning', 'Masina este scoasa. Nu poate fi tractata.')
        return refreshPhoneGarage(src)
    end

    if currentGarageId <= 0 then
        currentGarageId = tonumber((garageCfg() or {}).DefaultGarageId or 1) or 1
    end

    if currentGarageId == targetGarageId then
        notifyPhone(src, 'info', 'Masina este deja la cel mai apropiat garaj.')
        return refreshPhoneGarage(src)
    end

    local price = tonumber(garageCfg().TowPrice or 5000) or 5000

    local affected = MySQL.update.await(('UPDATE %s SET %s = COALESCE(%s, 0) - ? WHERE %s = ? AND COALESCE(%s, 0) >= ?'):format(
        sqlName(Config.UsersTable or 'users'),
        sqlName(cashColumn()),
        sqlName(cashColumn()),
        sqlName(Config.UsersIdColumn or 'uid'),
        sqlName(cashColumn())
    ), { price, uid, price })

    if not affected or affected <= 0 then
        notifyPhone(src, 'warning', ('Nu ai suma de %s pentru tractare.'):format(price))
        return refreshPhoneGarage(src)
    end

    MySQL.update.await(('UPDATE %s SET %s = ? WHERE id = ? AND owner_id = ? LIMIT 1'):format(sqlName(ownedVehiclesTable()), sqlName(garageColumn())), {
        targetGarageId, vehicleId, uid
    })

    notifyPhone(src, 'success', 'Masina a fost tractata la cel mai apropiat garaj.')
    refreshPhoneGarage(src)
end)

RegisterNetEvent('driftzone_phone:server:garageLocate', function(vehicleId)
    local src = source
    if not isLogged(src) then return end

    local uid = getUid(src)
    if not uid then return end

    vehicleId = tonumber(vehicleId or 0) or 0
    local entity = findGarageVehicleEntity(vehicleId)
    if not vehicleExists(entity) then
        notifyPhone(src, 'warning', 'Masina nu este scoasa.')
        return refreshPhoneGarage(src)
    end

    local state = Entity(entity).state
    local ownerUid = tonumber(state.dz_phone_garage_owner_uid or state.dz_garage_owner_uid or 0) or 0
    if ownerUid ~= uid then
        notifyPhone(src, 'warning', 'Acest vehicul nu iti apartine.')
        return
    end

    local c = GetEntityCoords(entity)
    TriggerClientEvent('driftzone_phone:client:garageWaypoint', src, {
        x = c.x + 0.0,
        y = c.y + 0.0,
        z = c.z + 0.0
    })
    notifyPhone(src, 'success', 'Am pus waypoint la masina.')
end)


AddEventHandler('playerDropped', function()
    local src = source
    UidCache[src] = nil
    local callId = PlayerCall[src]
    if callId then endCall(callId, 'ended', src) end
    GarageSpawnLocks[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for callId in pairs(Calls) do TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId) end
end)

CreateThread(function()
    Wait(1000)
    pcall(ensurePhoneGarageTables)
    GaragesCache = nil
    loadPhoneGarages(true)
    print('[DRIFTZONE_PHONE] Loaded. Command: /' .. tostring(Config.Command or 'phone'))
end)
