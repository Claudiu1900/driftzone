local ActiveVehicles = {}
local SpawnCooldowns = {}
local SpawnLocks = {}
local VehicleSpawnLocks = {}
local GarageBlocked = {}

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function setGarageBlocked(src, state, reason)
    src = tonumber(src or 0) or 0
    if src <= 0 then return false end

    if state == true then
        GarageBlocked[src] = tostring(reason or 'Garaj indisponibil.')
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


local function getServerVehiclesSafe()
    local ok, vehicles = pcall(GetAllVehicles)
    if ok and type(vehicles) == 'table' then return vehicles end
    return {}
end

local function getGarageVehicleIdFromEntity(entity)
    if not vehicleExists(entity) then return 0 end
    local state = Entity(entity).state
    return tonumber(state.dz_garage_db_id or state.vehicleDbId or state.ownedVehicleId or 0) or 0
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
    local deleted = {}

    if data and vehicleExists(data.entity) then
        deleted[data.entity] = true
        DeleteEntity(data.entity)
    end

    -- Siguranta anti-duplicate: sterge orice entitate ramasa cu acelasi SQL ID.
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
    state:set('dz_garage_model', tostring(data.model or ''), true)
    state:set('dz_garage_name', tostring(data.name or 'Vehiculul tau'), true)
    state:set('dz_garage_plate', tostring(data.plate or ''), true)
    state:set('dz_garage_is_vip', data.vip == true, true)
    state:set('dz_garage_godmode', true, true)

    -- Tuning raw ramane pe statebag, ca orice client/resource sa il poata reaplica daca e nevoie.
    state:set('dz_garage_tuning', tuningRaw, true)
    state:set('vehicleTunning', tuningRaw, true)
    state:set('dz_vehicle_tunning', tuningRaw, true)

    -- Gradient/chameleon salvat in ownedvehicles.gradient, disponibil pentru orice client/resource.
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

            -- Daca masina a fost data prin trade cat timp era spawnata, actualizam owner-ul in statebag.
            if isVehicleSpawned(row.id) then
                updateActiveVehicleOwner(row.id, uid)
            end

            list[#list + 1] = {
                id = tonumber(row.id),
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

RegisterNetEvent('driftzone_garage:server:open', function()
    local src = source
    if isGarageBlocked(src) then denyGarageOpen(src) return end
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end
    sendGarageList(src)
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

RegisterNetEvent('driftzone_garage:server:spawn', function(vehicleId)
    local src = source

    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return end

    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.') return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId or vehicleId <= 0 then notify(src, 'warning', 'Vehicul invalid.') return end

    if SpawnLocks[src] or VehicleSpawnLocks[vehicleId] then
        notify(src, 'warning', 'Ai deja aceasta masina in curs de spawn.')
        return
    end

    -- Verificare inainte de cooldown, ca spam-ul pe o masina deja scoasa sa nu consume cooldown.
    if isVehicleSpawned(vehicleId) then
        updateActiveVehicleOwner(vehicleId, uid, src)
        notify(src, 'warning', 'Acest vehicul este deja spawnat.')
        refreshGarageList(src)
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
            refreshGarageList(src)
            return
        end

        local model = tostring(row.vehicle_model or ''):lower()

        if model == '' then notify(src, 'warning', 'Model vehicul invalid.') return end

        local hash = joaat(model)

        if not hash or hash == 0 then notify(src, 'warning', 'Model vehicul invalid.') return end

        local spawn = getSpawnCoords(src)
        local plate = tostring(row.vehicle_plate or randomPlate()):upper():gsub('%s+', ''):sub(1, 8)
        local vehicleName = tostring(row.vehicle_name or model)
        local tuningRaw = normalizeTuning(row.vehicle_tunning or '{}')
        local gradientRaw = normalizeGradient(row.gradient or '')

        local entity = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.h, true, true)

        local timeout = GetGameTimer() + 6000
        while not vehicleExists(entity) and GetGameTimer() < timeout do Wait(50) end

        if not vehicleExists(entity) then
            notify(src, 'warning', 'Nu am putut crea vehiculul. Verifica daca modelul este streamat corect.')
            return
        end

        SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(src))
        SetVehicleNumberPlateText(entity, plate)

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
            gradient = gradientRaw
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
            gradient = gradientRaw
        })

        TriggerClientEvent('driftzone_garage:client:spawnedSuccess', src)
        notify(src, 'info', ('Vehiculul %s a fost scos din garaj.'):format(vehicleName))
        refreshGarageList(src)

        -- Aplica tuning-ul fortat de mai multe ori client-side, pentru race conditions de streaming/control.
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

    if data and tonumber(data.ownerSrc) == tonumber(src) then
        data.preparedAt = os.time()
    end
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
        refreshGarageList(src)
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
    refreshGarageList(src)
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
        return
    end
end

RegisterCommand('garage', function(src) if src ~= 0 then runCommand(src, 'garage', {}) end end, false)
RegisterCommand('garaj', function(src) if src ~= 0 then runCommand(src, 'garaj', {}) end end, false)
RegisterCommand('park', function(src) if src ~= 0 then runCommand(src, 'park', {}) end end, false)

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
    print('[DRIFTZONE_GARAGE] Server-side loaded. Forced tuning + 3s cooldown.')
end)
