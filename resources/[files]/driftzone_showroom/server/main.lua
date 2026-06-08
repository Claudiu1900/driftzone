local Sessions = {}

local VehicleColumns = nil
local VehicleCache = nil
local VehicleCacheUntil = 0

local function loadVehicleColumns()
    if VehicleColumns then return VehicleColumns end

    VehicleColumns = {}

    local rows = MySQL.query.await('SHOW COLUMNS FROM `vehiclenames`', {}) or {}
    for _, row in ipairs(rows) do
        if row.Field then
            VehicleColumns[tostring(row.Field)] = true
        end
    end

    return VehicleColumns
end

local function getVehicleSelectParts()
    local cols = loadVehicleColumns()

    local imageExpr = "''"
    if cols.vehicle_image and cols.image then
        imageExpr = "COALESCE(NULLIF(vehicle_image, ''), NULLIF(image, ''), '')"
    elseif cols.vehicle_image then
        imageExpr = "COALESCE(vehicle_image, '')"
    elseif cols.image then
        imageExpr = "COALESCE(image, '')"
    end

    local priceExpr = "0"
    if cols.vehicle_price and cols.price then
        priceExpr = "COALESCE(NULLIF(vehicle_price, 0), NULLIF(price, 0), 0)"
    elseif cols.price then
        priceExpr = "COALESCE(price, 0)"
    elseif cols.vehicle_price then
        priceExpr = "COALESCE(vehicle_price, 0)"
    end

    local categoryExpr = cols.category and "COALESCE(category, 1)" or "1"
    local sellingExpr = cols.selling and "COALESCE(selling, 1)" or "1"
    local vipExpr = cols.vip and "COALESCE(vip, 0)" or "0"
    local apearExpr = cols.apear and "COALESCE(apear, 1)" or "1"
    local nameExpr = cols.vehicle_name and "COALESCE(NULLIF(vehicle_name, ''), vehicle_model)" or "vehicle_model"

    return {
        image = imageExpr,
        price = priceExpr,
        category = categoryExpr,
        selling = sellingExpr,
        vip = vipExpr,
        apear = apearExpr,
        name = nameExpr
    }
end

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
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

local function getPlayerPedSafe(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 0 end
    return ped
end

local function getCash(uid)
    local row = MySQL.single.await(
        ('SELECT `%s` AS cash FROM `%s` WHERE `%s` = ? LIMIT 1'):format(Config.CashColumn, Config.UsersTable, Config.UsersIdColumn),
        { uid }
    )

    if not row then return 0 end
    return tonumber(row.cash or 0) or 0
end

local function hasVip(uid)
    local vipColumn = Config.UsersVipColumn or 'vip'

    local row = MySQL.single.await(
        ('SELECT `%s` AS vip FROM `%s` WHERE `%s` = ? LIMIT 1'):format(vipColumn, Config.UsersTable, Config.UsersIdColumn),
        { uid }
    )

    if not row then return false end

    local value = row.vip
    if value == true then return true end

    value = tostring(value or '0'):lower()
    return value == '1' or value == 'true' or value == 'yes'
end

local function takeCash(uid, amount)
    amount = tonumber(amount or 0) or 0
    if amount <= 0 then return true end

    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `%s` = `%s` - ? WHERE `%s` = ? AND `%s` >= ?'):format(Config.UsersTable, Config.CashColumn, Config.CashColumn, Config.UsersIdColumn, Config.CashColumn),
        { amount, uid, amount }
    )

    return affected and affected > 0
end

local function randomPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = 'DZ'

    for _ = 1, 6 do
        local index = math.random(1, #chars)
        plate = plate .. chars:sub(index, index)
    end

    return plate:sub(1, 8)
end

local function generateUniquePlate()
    for _ = 1, 60 do
        local plate = randomPlate()
        local row = MySQL.single.await('SELECT id FROM ownedvehicles WHERE vehicle_plate = ? LIMIT 1', { plate })
        if not row then return plate end
    end

    return randomPlate()
end

local function normalizeVehicle(row)
    local category = tonumber(row.category or 1) or 1
    local selling = row.selling == nil or tonumber(row.selling or 1) == 1
    local vip = tonumber(row.vip or 0) == 1 and 1 or 0
    local model = tostring(row.vehicle_model or ''):lower():gsub('%s+', '')

    return {
        model = model,
        name = tostring(row.vehicle_name or model or 'Vehicle'),
        image = tostring(row.vehicle_image or row.image or ''),
        price = tonumber(row.vehicle_price or row.price or 0) or 0,
        category = category,
        categoryName = Config.CategoryNames[category] or 'UNKNOWN',
        selling = selling,
        vip = vip
    }
end

local function getShowroomVehicles()
    local now = os.time()

    if VehicleCache and now < VehicleCacheUntil then
        return VehicleCache
    end

    local parts = getVehicleSelectParts()

    local rows = MySQL.query.await(([[ 
        SELECT
            vehicle_model,
            %s AS vehicle_name,
            %s AS vehicle_image,
            %s AS vehicle_price,
            %s AS category,
            %s AS selling,
            %s AS vip
        FROM vehiclenames
        WHERE %s BETWEEN 1 AND 6
          AND %s = 1
        ORDER BY %s ASC, vehicle_name ASC
    ]]):format(parts.name, parts.image, parts.price, parts.category, parts.selling, parts.vip, parts.category, parts.apear, parts.price), {}) or {}

    local list = {}

    for _, row in ipairs(rows) do
        local veh = normalizeVehicle(row)
        if veh.model ~= '' then
            list[#list + 1] = veh
        end
    end

    VehicleCache = list
    VehicleCacheUntil = now + 30

    return list
end

local function clearVehicleCache()
    VehicleCache = nil
    VehicleCacheUntil = 0
end

local function getVehicleByModel(model)
    model = tostring(model or ''):lower():gsub('%s+', '')
    if model == '' then return nil end

    local parts = getVehicleSelectParts()

    local row = MySQL.single.await(([[
        SELECT
            vehicle_model,
            %s AS vehicle_name,
            %s AS vehicle_image,
            %s AS vehicle_price,
            %s AS category,
            %s AS selling,
            %s AS vip
        FROM vehiclenames
        WHERE LOWER(vehicle_model) = ?
          AND %s = 1
        LIMIT 1
    ]]):format(parts.name, parts.image, parts.price, parts.category, parts.selling, parts.vip, parts.apear), { model })

    if not row then return nil end
    return normalizeVehicle(row)
end

local function vectorToTable(v)
    return { x = v.x, y = v.y, z = v.z }
end

local function getShowroomPayload(src, selectedModel)
    local uid = getUid(src)
    local vehicles = getShowroomVehicles()

    return {
        vehicles = vehicles,
        categories = Config.CategoryNames,
        cash = uid and getCash(uid) or 0,
        selectedModel = selectedModel or '',
        fallbackImage = Config.FallbackImage,
        camera = {
            x = Config.Showroom.Camera.coords.x,
            y = Config.Showroom.Camera.coords.y,
            z = Config.Showroom.Camera.coords.z,
            lookX = Config.Showroom.Camera.lookAt.x,
            lookY = Config.Showroom.Camera.lookAt.y,
            lookZ = Config.Showroom.Camera.lookAt.z,
            fov = Config.Showroom.Camera.fov
        },
        preview = {
            x = Config.Showroom.PreviewVehicle.coords.x,
            y = Config.Showroom.PreviewVehicle.coords.y,
            z = Config.Showroom.PreviewVehicle.coords.z,
            heading = Config.Showroom.PreviewVehicle.heading
        },
        testDrive = {
            seconds = Config.TestDriveSeconds,
            spawn = {
                x = Config.Showroom.TestDriveSpawn.coords.x,
                y = Config.Showroom.TestDriveSpawn.coords.y,
                z = Config.Showroom.TestDriveSpawn.coords.z,
                heading = Config.Showroom.TestDriveSpawn.heading
            }
        }
    }
end

local function saveSession(src)
    local ped = getPlayerPedSafe(src)
    if ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local bucket = GetPlayerRoutingBucket(src)

    Sessions[src] = Sessions[src] or {}
    Sessions[src].original = {
        coords = coords,
        heading = heading,
        bucket = bucket
    }

    return true
end

local function getPrivateBucket(src)
    return (Config.PrivateBucketBase or 80000) + tonumber(src)
end

local function teleportPlayer(src, coords, heading, bucket)
    local ped = getPlayerPedSafe(src)
    if ped == 0 then return end

    if bucket ~= nil then
        SetPlayerRoutingBucket(src, tonumber(bucket) or 0)
    end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
end

local function closeShowroom(src, toBuyExit)
    local session = Sessions[src]
    local ped = getPlayerPedSafe(src)

    if session and session.original and ped ~= 0 then
        if toBuyExit then
            teleportPlayer(src, Config.Showroom.BuyExit.coords, Config.Showroom.BuyExit.heading, session.original.bucket or 0)
        else
            teleportPlayer(src, session.original.coords, session.original.heading, session.original.bucket or 0)
        end
    elseif ped ~= 0 then
        SetPlayerRoutingBucket(src, 0)
    end

    Sessions[src] = nil
    TriggerClientEvent('driftzone_showroom:client:forceClose', src)
end

local function openShowroom(src, selectedModel)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat ca sa intri in showroom.')
        return
    end

    local uid = getUid(src)
    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    if not Sessions[src] then
        saveSession(src)
    end

    Sessions[src] = Sessions[src] or {}
    Sessions[src].selectedModel = selectedModel or Sessions[src].selectedModel or ''
    Sessions[src].inTest = false

    teleportPlayer(src, Config.Showroom.PlayerPosition.coords, Config.Showroom.PlayerPosition.heading, getPrivateBucket(src))

    TriggerClientEvent('driftzone_showroom:client:open', src, getShowroomPayload(src, Sessions[src].selectedModel))
end

local function buyVehicle(src, model)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)
    if not uid then return end

    local vehicle = getVehicleByModel(model)
    if not vehicle then
        notify(src, 'warning', 'Masina nu exista in showroom.')
        return
    end

    if not vehicle.selling then
        notify(src, 'warning', 'Aceasta masina nu este de vanzare.')
        return
    end

    if tonumber(vehicle.vip or 0) == 1 and not hasVip(uid) then
        notify(src, 'warning', 'Ai nevoie de VIP ca sa cumperi aceasta masina.')
        return
    end

    local price = tonumber(vehicle.price or 0) or 0
    if price <= 0 then
        notify(src, 'warning', 'Aceasta masina nu are pret valid.')
        return
    end

    if not takeCash(uid, price) then
        notify(src, 'warning', ('Nu ai suficient cash. Pret: $%s'):format(price))
        return
    end

    local plate = generateUniquePlate()

    MySQL.insert.await(
        [[
            INSERT INTO ownedvehicles
                (owner_id, vehicle_model, vehicle_plate, vehicle_tunning, vehicle_fuel, vehicle_engine, vehicle_body, stored)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?)
        ]],
        { uid, vehicle.model, plate, '{}', 100, 1000, 1000, 1 }
    )

    notify(src, 'info', ('Ai cumparat %s pentru $%s.'):format(vehicle.name, price))
    closeShowroom(src, true)
end

local function startTestDrive(src, model)
    if not isLogged(src) then return end

    local vehicle = getVehicleByModel(model)
    if not vehicle then
        notify(src, 'warning', 'Masina nu exista in showroom.')
        return
    end

    Sessions[src] = Sessions[src] or {}
    Sessions[src].selectedModel = vehicle.model
    Sessions[src].inTest = true

    SetPlayerRoutingBucket(src, getPrivateBucket(src))

    TriggerClientEvent('driftzone_showroom:client:startTestDrive', src, {
        vehicle = vehicle,
        seconds = Config.TestDriveSeconds,
        warnings = Config.TestDriveWarnings,
        spawn = {
            x = Config.Showroom.TestDriveSpawn.coords.x,
            y = Config.Showroom.TestDriveSpawn.coords.y,
            z = Config.Showroom.TestDriveSpawn.coords.z,
            heading = Config.Showroom.TestDriveSpawn.heading
        }
    })
end

local function endTestDrive(src, reason)
    local session = Sessions[src]
    local selected = session and session.selectedModel or ''

    if reason == 'left' then
        notify(src, 'warning', 'Test drive-ul a fost oprit pentru ca ai iesit din masina.')
    elseif reason == 'time' then
        notify(src, 'info', 'Test drive-ul s-a terminat.')
    end

    openShowroom(src, selected)
end

RegisterNetEvent('driftzone_showroom:server:open', function()
    openShowroom(source)
end)

RegisterNetEvent('driftzone_showroom:server:close', function()
    closeShowroom(source, false)
end)

RegisterNetEvent('driftzone_showroom:server:buy', function(model)
    buyVehicle(source, model)
end)

RegisterNetEvent('driftzone_showroom:server:testDrive', function(model)
    startTestDrive(source, model)
end)

RegisterNetEvent('driftzone_showroom:server:endTestDrive', function(reason)
    endTestDrive(source, reason or 'time')
end)

RegisterCommand('showroom', function(src)
    if src == 0 then return end
    openShowroom(src)
end, false)

RegisterCommand('sr', function(src)
    if src == 0 then return end
    openShowroom(src)
end, false)

exports('ClearVehicleCache', clearVehicleCache)

AddEventHandler('playerDropped', function()
    local src = source
    Sessions[src] = nil
end)

CreateThread(function()
    Wait(500)
    print('[DRIFTZONE_SHOWROOM] Server-side loaded. Cash column: ' .. Config.CashColumn)
end)
