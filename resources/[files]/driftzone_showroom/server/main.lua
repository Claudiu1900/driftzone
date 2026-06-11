local Sessions = {}
local VehicleColumns = nil
local VehicleCache = nil
local VehicleCacheUntil = 0

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function jsonSafe(data)
    local ok, result = pcall(json.encode, data or {})
    if ok then return result end
    return '{}'
end

local function loadVehicleColumns(force)
    if VehicleColumns and not force then return VehicleColumns end
    VehicleColumns = {}
    local ok, rows = pcall(function()
        return MySQL.query.await('SHOW COLUMNS FROM `vehiclenames`', {}) or {}
    end)
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row.Field then VehicleColumns[tostring(row.Field)] = true end
        end
    end
    return VehicleColumns
end

local function clearVehicleCache()
    VehicleCache = nil
    VehicleCacheUntil = 0
    VehicleColumns = nil
end

local function colExpr(cols, names, fallback)
    for _, name in ipairs(names) do
        if cols[name] then return ('COALESCE(%s, %s)'):format(sqlName(name), fallback or "''") end
    end
    return fallback or "''"
end

local function getVehicleSelectParts()
    local cols = loadVehicleColumns()

    local imageExpr = "''"
    if cols.vehicle_image and cols.image then
        imageExpr = "COALESCE(NULLIF(`vehicle_image`, ''), NULLIF(`image`, ''), '')"
    elseif cols.vehicle_image then
        imageExpr = "COALESCE(`vehicle_image`, '')"
    elseif cols.image then
        imageExpr = "COALESCE(`image`, '')"
    end

    local priceExpr = "0"
    if cols.vehicle_price and cols.price then
        priceExpr = "COALESCE(NULLIF(`vehicle_price`, 0), NULLIF(`price`, 0), 0)"
    elseif cols.price then
        priceExpr = "COALESCE(`price`, 0)"
    elseif cols.vehicle_price then
        priceExpr = "COALESCE(`vehicle_price`, 0)"
    end

    local dzcoinsExpr = "0"
    if cols.dzcoins_price then dzcoinsExpr = "COALESCE(`dzcoins_price`, 0)"
    elseif cols.price_dzcoins then dzcoinsExpr = "COALESCE(`price_dzcoins`, 0)"
    elseif cols.vehicle_dzcoins then dzcoinsExpr = "COALESCE(`vehicle_dzcoins`, 0)" end

    local sectionExpr = "'DRIFT'"
    if cols.showroom_section then sectionExpr = "COALESCE(NULLIF(`showroom_section`, ''), 'DRIFT')"
    elseif cols.shop_type then sectionExpr = "COALESCE(NULLIF(`shop_type`, ''), 'DRIFT')"
    elseif cols.type then sectionExpr = "COALESCE(NULLIF(`type`, ''), 'DRIFT')" end

    local subExpr = "'starter'"
    if cols.showroom_subcategory then subExpr = "COALESCE(NULLIF(`showroom_subcategory`, ''), 'starter')"
    elseif cols.showroom_sub then subExpr = "COALESCE(NULLIF(`showroom_sub`, ''), 'starter')"
    elseif cols.subcategory then subExpr = "COALESCE(NULLIF(`subcategory`, ''), 'starter')"
    elseif cols.category_name then subExpr = "COALESCE(NULLIF(`category_name`, ''), 'starter')" end

    local categoryExpr = cols.category and "COALESCE(`category`, 1)" or "1"
    local sellingExpr = cols.selling and "COALESCE(`selling`, 1)" or "1"
    local vipExpr = cols.vip and "COALESCE(`vip`, 0)" or "0"
    local apearExpr = cols.apear and "COALESCE(`apear`, 1)" or "1"
    local nameExpr = cols.vehicle_name and "COALESCE(NULLIF(`vehicle_name`, ''), `vehicle_model`)" or "`vehicle_model`"

    return { image = imageExpr, price = priceExpr, dzcoins = dzcoinsExpr, category = categoryExpr, selling = sellingExpr, vip = vipExpr, apear = apearExpr, name = nameExpr, section = sectionExpr, sub = subExpr }
end

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

local function getPlayerPedSafe(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 0 end
    return ped
end

local function getCash(uid)
    local row = MySQL.single.await(('SELECT %s AS cash FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(Config.CashColumn or 'cash'), sqlName(Config.UsersTable or 'users'), sqlName(Config.UsersIdColumn or 'uid')), { uid })
    return row and tonumber(row.cash or 0) or 0
end

local function getDzCoins(uid)
    local col = Config.DzCoinsColumn or 'dzcoins'
    local row = MySQL.single.await(('SELECT %s AS coins FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(col), sqlName(Config.UsersTable or 'users'), sqlName(Config.UsersIdColumn or 'uid')), { uid })
    return row and tonumber(row.coins or 0) or 0
end

local function hasVip(uid)
    local vipColumn = Config.UsersVipColumn or 'vip'
    local row = MySQL.single.await(('SELECT %s AS vip FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(vipColumn), sqlName(Config.UsersTable or 'users'), sqlName(Config.UsersIdColumn or 'uid')), { uid })
    if not row then return false end
    local value = row.vip
    if value == true then return true end
    value = tostring(value or '0'):lower()
    return value == '1' or value == 'true' or value == 'yes'
end

local function takeCurrency(uid, vehicle)
    local dzPrice = tonumber(vehicle.dzcoins_price or 0) or 0
    local cashPrice = tonumber(vehicle.price or 0) or 0

    if dzPrice > 0 then
        local affected = MySQL.update.await(('UPDATE %s SET %s = %s - ? WHERE %s = ? AND %s >= ?'):format(sqlName(Config.UsersTable or 'users'), sqlName(Config.DzCoinsColumn or 'dzcoins'), sqlName(Config.DzCoinsColumn or 'dzcoins'), sqlName(Config.UsersIdColumn or 'uid'), sqlName(Config.DzCoinsColumn or 'dzcoins')), { dzPrice, uid, dzPrice })
        if affected and affected > 0 then return true, dzPrice, 'dzcoins' end
        return false, dzPrice, 'dzcoins'
    end

    if cashPrice > 0 then
        local affected = MySQL.update.await(('UPDATE %s SET %s = %s - ? WHERE %s = ? AND %s >= ?'):format(sqlName(Config.UsersTable or 'users'), sqlName(Config.CashColumn or 'cash'), sqlName(Config.CashColumn or 'cash'), sqlName(Config.UsersIdColumn or 'uid'), sqlName(Config.CashColumn or 'cash')), { cashPrice, uid, cashPrice })
        if affected and affected > 0 then return true, cashPrice, 'cash' end
        return false, cashPrice, 'cash'
    end

    return false, 0, 'cash'
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

local function normalizeSection(value, category, vip)
    local s = trim(value):upper():gsub('%s+', '')
    if s == 'HIGHSPEED' then s = 'HS' end
    if s ~= 'DRIFT' and s ~= 'HS' and s ~= 'PREMIUM' and s ~= 'CUSTOM' then
        if tonumber(vip or 0) == 1 then return 'PREMIUM' end
        if tonumber(category or 1) == 6 then return 'CUSTOM' end
        return 'DRIFT'
    end
    return s
end

local function normalizeSub(value, section, category)
    local raw = trim(value):lower():gsub('%s+', '_'):gsub('%-', '_')
    if raw == '' or raw == 'all' then raw = 'starter' end
    if section == 'DRIFT' then
        if raw == 'drifter' or raw == 'pro_drift' then return 'drifter' end
        if raw == 'jdm' or raw == 'jdm_legend' or raw == 'jdm_legends' then return 'jdm_legends' end
        if tonumber(category) == 3 then return 'jdm_legends' end
        if tonumber(category) == 4 then return 'drifter' end
        return 'starter'
    elseif section == 'HS' then
        if raw == 'racer' or tonumber(category) == 2 then return 'racer' end
        if raw == 'legend' or raw == 'legends' or tonumber(category) == 5 then return 'legend' end
        return 'starter'
    elseif section == 'PREMIUM' then
        if raw == 'hs' or raw == 'highspeed' then return 'hs' end
        return 'drift'
    elseif section == 'CUSTOM' then
        return 'all'
    end
    return raw
end

local function normalizeVehicle(row)
    local category = tonumber(row.category or 1) or 1
    local selling = row.selling == nil or tonumber(row.selling or 1) == 1
    local vip = tonumber(row.vip or 0) == 1 and 1 or 0
    local model = tostring(row.vehicle_model or ''):lower():gsub('%s+', '')
    local section = normalizeSection(row.showroom_section, category, vip)
    local subcategory = normalizeSub(row.showroom_subcategory, section, category)
    local dzPrice = tonumber(row.dzcoins_price or row.price_dzcoins or 0) or 0
    local cashPrice = tonumber(row.vehicle_price or row.price or 0) or 0

    return {
        model = model,
        name = tostring(row.vehicle_name or model or 'Vehicle'),
        image = tostring(row.vehicle_image or row.image or ''),
        price = cashPrice,
        dzcoins_price = dzPrice,
        payment = dzPrice > 0 and 'dzcoins' or 'cash',
        category = category,
        categoryName = Config.CategoryNames[category] or 'UNKNOWN',
        section = section,
        subcategory = subcategory,
        selling = selling,
        vip = vip
    }
end

local function getShowroomVehicles()
    local now = os.time()
    if VehicleCache and now < VehicleCacheUntil then return VehicleCache end
    local parts = getVehicleSelectParts()

    local rows = MySQL.query.await(([[
        SELECT
            `vehicle_model`,
            %s AS `vehicle_name`,
            %s AS `vehicle_image`,
            %s AS `vehicle_price`,
            %s AS `dzcoins_price`,
            %s AS `category`,
            %s AS `selling`,
            %s AS `vip`,
            %s AS `showroom_section`,
            %s AS `showroom_subcategory`
        FROM `vehiclenames`
        WHERE %s = 1
        ORDER BY `showroom_section` ASC, `showroom_subcategory` ASC, `vehicle_price` ASC, `vehicle_name` ASC
    ]]):format(parts.name, parts.image, parts.price, parts.dzcoins, parts.category, parts.selling, parts.vip, parts.section, parts.sub, parts.apear), {}) or {}

    local list = {}
    for _, row in ipairs(rows) do
        local veh = normalizeVehicle(row)
        if veh.model ~= '' then list[#list + 1] = veh end
    end
    VehicleCache = list
    VehicleCacheUntil = now + (Config.VehicleCacheSeconds or 30)
    return list
end

local function getVehicleByModel(model)
    model = tostring(model or ''):lower():gsub('%s+', '')
    if model == '' then return nil end
    local parts = getVehicleSelectParts()
    local row = MySQL.single.await(([[
        SELECT
            `vehicle_model`,
            %s AS `vehicle_name`,
            %s AS `vehicle_image`,
            %s AS `vehicle_price`,
            %s AS `dzcoins_price`,
            %s AS `category`,
            %s AS `selling`,
            %s AS `vip`,
            %s AS `showroom_section`,
            %s AS `showroom_subcategory`
        FROM `vehiclenames`
        WHERE LOWER(`vehicle_model`) = ? AND %s = 1
        LIMIT 1
    ]]):format(parts.name, parts.image, parts.price, parts.dzcoins, parts.category, parts.selling, parts.vip, parts.section, parts.sub, parts.apear), { model })
    if not row then return nil end
    return normalizeVehicle(row)
end

local function defaultTuningJson()
    local t = {
        primaryColor = '#ffffff', secondaryColor = '#ffffff', pearlescentColor = 111, wheelColor = 111,
        windowTint = 0, xenonColor = 0, turbo = false,
        spoiler = -1, frontBumper = -1, rearBumper = -1, sideSkirt = -1, exhaust = -1, frame = -1,
        grille = -1, hood = -1, fender = -1, rightFender = -1, roof = -1, engine = -1, brakes = -1,
        transmission = -1, suspension = -1, wheels = -1, horn = -1, plateHolder = -1, vanityPlates = -1,
        trim = -1, ornaments = -1, dashboard = -1, dial = -1, doorSpeaker = -1, seats = -1,
        steeringWheel = -1, shifterLeavers = -1, plaques = -1, speakers = -1, trunk = -1, hydraulics = -1,
        engineBlock = -1, airFilter = -1, struts = -1, archCover = -1, aerials = -1, tank = -1,
        windows = -1, livery = -1, extras = {}
    }
    return jsonSafe(t)
end

local function getShowroomPayload(src, selectedModel)
    local uid = getUid(src)
    return {
        vehicles = getShowroomVehicles(),
        categories = Config.CategoryNames,
        groups = Config.ShowroomGroups,
        cash = uid and getCash(uid) or 0,
        dzcoins = uid and getDzCoins(uid) or 0,
        selectedModel = selectedModel or '',
        fallbackImage = Config.FallbackImage,
        camera = { x = Config.Showroom.Camera.coords.x, y = Config.Showroom.Camera.coords.y, z = Config.Showroom.Camera.coords.z, lookX = Config.Showroom.Camera.lookAt.x, lookY = Config.Showroom.Camera.lookAt.y, lookZ = Config.Showroom.Camera.lookAt.z, fov = Config.Showroom.Camera.fov },
        preview = { x = Config.Showroom.PreviewVehicle.coords.x, y = Config.Showroom.PreviewVehicle.coords.y, z = Config.Showroom.PreviewVehicle.coords.z, heading = Config.Showroom.PreviewVehicle.heading },
        testDrive = { seconds = Config.TestDriveSeconds, spawn = { x = Config.Showroom.TestDriveSpawn.coords.x, y = Config.Showroom.TestDriveSpawn.coords.y, z = Config.Showroom.TestDriveSpawn.coords.z, heading = Config.Showroom.TestDriveSpawn.heading } }
    }
end

local function saveSession(src)
    local ped = getPlayerPedSafe(src)
    if ped == 0 then return false end
    Sessions[src] = Sessions[src] or {}
    Sessions[src].original = { coords = GetEntityCoords(ped), heading = GetEntityHeading(ped), bucket = GetPlayerRoutingBucket(src) }
    return true
end

local function getPrivateBucket(src)
    return (Config.PrivateBucketBase or 80000) + tonumber(src)
end

local function teleportPlayer(src, coords, heading, bucket)
    local ped = getPlayerPedSafe(src)
    if ped == 0 then return end
    if bucket ~= nil then SetPlayerRoutingBucket(src, tonumber(bucket) or 0) end
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
end

local function closeShowroom(src, toBuyExit)
    local session = Sessions[src]
    local ped = getPlayerPedSafe(src)
    if session and session.original and ped ~= 0 then
        if toBuyExit then teleportPlayer(src, Config.Showroom.BuyExit.coords, Config.Showroom.BuyExit.heading, session.original.bucket or 0)
        else teleportPlayer(src, session.original.coords, session.original.heading, session.original.bucket or 0) end
    elseif ped ~= 0 then SetPlayerRoutingBucket(src, 0) end
    Sessions[src] = nil
    TriggerClientEvent('driftzone_showroom:client:forceClose', src)
end

local function openShowroom(src, selectedModel)
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat ca sa intri in showroom.') end
    local uid = getUid(src)
    if not uid then return notify(src, 'warning', 'Nu ti-am gasit UID-ul.') end
    if not Sessions[src] then saveSession(src) end
    Sessions[src] = Sessions[src] or {}
    Sessions[src].selectedModel = selectedModel or Sessions[src].selectedModel or ''
    Sessions[src].inTest = false
    teleportPlayer(src, Config.Showroom.PlayerPosition.coords, Config.Showroom.PlayerPosition.heading, getPrivateBucket(src))
    TriggerClientEvent('driftzone_showroom:client:open', src, getShowroomPayload(src, Sessions[src].selectedModel))
end

local function buyVehicle(src, model)
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.') end
    local uid = getUid(src)
    if not uid then return end
    local vehicle = getVehicleByModel(model)
    if not vehicle then return notify(src, 'warning', 'Masina nu exista in showroom.') end
    if not vehicle.selling then return notify(src, 'warning', 'Aceasta masina nu este de vanzare.') end
    if tonumber(vehicle.vip or 0) == 1 and not hasVip(uid) then return notify(src, 'warning', 'Ai nevoie de VIP ca sa cumperi aceasta masina.') end

    local price = tonumber(vehicle.dzcoins_price or 0) > 0 and tonumber(vehicle.dzcoins_price) or tonumber(vehicle.price or 0)
    if not price or price <= 0 then return notify(src, 'warning', 'Aceasta masina nu are pret valid.') end

    local ok, amount, payment = takeCurrency(uid, vehicle)
    if not ok then
        if payment == 'dzcoins' then return notify(src, 'warning', ('Nu ai suficiente DriftZone Coins. Pret: %s DZC'):format(amount)) end
        return notify(src, 'warning', ('Nu ai suficient cash. Pret: $%s'):format(amount))
    end

    local plate = generateUniquePlate()
    MySQL.insert.await([[INSERT INTO `ownedvehicles` (`owner_id`, `vehicle_model`, `vehicle_plate`, `vehicle_tunning`, `vehicle_fuel`, `vehicle_engine`, `vehicle_body`, `stored`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], {
        uid, vehicle.model, plate, defaultTuningJson(), 100, 1000, 1000, 1
    })

    if payment == 'dzcoins' then notify(src, 'success', ('Ai cumparat %s pentru %s DZC.'):format(vehicle.name, amount))
    else notify(src, 'success', ('Ai cumparat %s pentru $%s.'):format(vehicle.name, amount)) end
    closeShowroom(src, true)
end

local function startTestDrive(src, model)
    if not isLogged(src) then return end
    local vehicle = getVehicleByModel(model)
    if not vehicle then return notify(src, 'warning', 'Masina nu exista in showroom.') end
    Sessions[src] = Sessions[src] or {}
    Sessions[src].selectedModel = vehicle.model
    Sessions[src].inTest = true
    SetPlayerRoutingBucket(src, getPrivateBucket(src))
    TriggerClientEvent('driftzone_showroom:client:startTestDrive', src, { vehicle = vehicle, seconds = Config.TestDriveSeconds, warnings = Config.TestDriveWarnings, spawn = { x = Config.Showroom.TestDriveSpawn.coords.x, y = Config.Showroom.TestDriveSpawn.coords.y, z = Config.Showroom.TestDriveSpawn.coords.z, heading = Config.Showroom.TestDriveSpawn.heading } })
end

local function endTestDrive(src, reason)
    local session = Sessions[src]
    local selected = session and session.selectedModel or ''
    if reason == 'left' then notify(src, 'warning', 'Test drive-ul a fost oprit pentru ca ai iesit din masina.')
    elseif reason == 'time' then notify(src, 'info', 'Test drive-ul s-a terminat.') end
    openShowroom(src, selected)
end

RegisterNetEvent('driftzone_showroom:server:open', function() openShowroom(source) end)
RegisterNetEvent('driftzone_showroom:server:close', function() closeShowroom(source, false) end)
RegisterNetEvent('driftzone_showroom:server:buy', function(model) buyVehicle(source, model) end)
RegisterNetEvent('driftzone_showroom:server:testDrive', function(model) startTestDrive(source, model) end)
RegisterNetEvent('driftzone_showroom:server:endTestDrive', function(reason) endTestDrive(source, reason or 'time') end)

RegisterCommand('showroom', function(src) if src ~= 0 then openShowroom(src) end end, false)
RegisterCommand('sr', function(src) if src ~= 0 then openShowroom(src) end end, false)

exports('ClearVehicleCache', clearVehicleCache)

AddEventHandler('playerDropped', function() Sessions[source] = nil end)

CreateThread(function()
    Wait(500)
    print('[DRIFTZONE_SHOWROOM] Loaded. Cash=' .. tostring(Config.CashColumn) .. ' DZC=' .. tostring(Config.DzCoinsColumn or 'dzcoins'))
end)
