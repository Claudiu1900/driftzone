local OpenCooldown = {}
local BuyCooldown = {}
local VehicleCache = {}

local function cleanName(name)
    return tostring(name or ''):gsub('`', '')
end

local function sqlName(name)
    return ('`%s`'):format(cleanName(name))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function upper(value)
    return trim(value):upper()
end

local function jsonSafe(data)
    local ok, result = pcall(json.encode, data or {})
    if ok then return result end
    return '{}'
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 5000, tostring(msg or ''))
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    local state = Player(src).state
    if state then
        local keys = { 'dz_uid', 'uid', 'user_id', 'userId' }
        for i = 1, #keys do
            local uid = tonumber(state[keys[i]])
            if uid and uid > 0 then return uid end
        end
    end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
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
        function() return exports.driftzone_auth:isLoggedIn(src) end,
        function() return exports.driftzone_auth:IsLogged(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, result = pcall(fn)
        if ok and result == true then return true end
    end

    return getUid(src) ~= nil
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function getUserBalances(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return { cash = 0, dzcoins = 0 } end

    local row = MySQL.single.await(([[
        SELECT COALESCE(%s, 0) AS cash, COALESCE(%s, 0) AS dzcoins
        FROM %s
        WHERE %s = ?
        LIMIT 1
    ]]):format(
        sqlName(Config.UsersCashColumn or 'cash'),
        sqlName(Config.UsersCoinsColumn or 'dzcoins'),
        sqlName(Config.UsersTable or 'users'),
        sqlName(Config.UsersIdColumn or 'uid')
    ), { uid })

    return {
        cash = tonumber(row and row.cash or 0) or 0,
        dzcoins = tonumber(row and row.dzcoins or 0) or 0
    }
end

local function clearVehicleCache(uid)
    if uid then VehicleCache[tonumber(uid)] = nil end
end

local function getOwnedVehicles(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return {} end

    local now = GetGameTimer()
    local cached = VehicleCache[uid]
    if cached and cached.expires > now then
        return cached.vehicles
    end

    local ov = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local ovId = cleanName(Config.OwnedVehiclesIdColumn or 'id')
    local ovOwner = cleanName(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local ovModel = cleanName(Config.OwnedVehiclesModelColumn or 'vehicle_model')
    local ovPlate = cleanName(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')
    local vn = cleanName(Config.VehicleNamesTable or 'vehiclenames')
    local vnModel = cleanName(Config.VehicleNamesModelColumn or 'vehicle_model')
    local vnName = cleanName(Config.VehicleNamesNameColumn or 'vehicle_name')
    local limit = tonumber(Config.MaxVehicles or 120) or 120

    local rows = MySQL.query.await(([[
        SELECT
            ov.`%s` AS id,
            ov.`%s` AS model,
            ov.`%s` AS plate,
            COALESCE(NULLIF(vn.`%s`, ''), ov.`%s`) AS name
        FROM `%s` ov
        LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
        WHERE ov.`%s` = ?
        ORDER BY ov.`%s` DESC
        LIMIT %d
    ]]):format(ovId, ovModel, ovPlate, vnName, ovModel, ov, vn, vnModel, ovModel, ovOwner, ovId, limit), { uid }) or {}

    VehicleCache[uid] = {
        expires = now + (tonumber(Config.CacheMs or 1500) or 1500),
        vehicles = rows
    }

    return rows
end

local function getOwnedVehicle(uid, vehicleId)
    uid = tonumber(uid or 0) or 0
    vehicleId = tonumber(vehicleId or 0) or 0
    if uid <= 0 or vehicleId <= 0 then return nil end

    local ov = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local ovId = cleanName(Config.OwnedVehiclesIdColumn or 'id')
    local ovOwner = cleanName(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local ovModel = cleanName(Config.OwnedVehiclesModelColumn or 'vehicle_model')
    local ovPlate = cleanName(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')
    local vn = cleanName(Config.VehicleNamesTable or 'vehiclenames')
    local vnModel = cleanName(Config.VehicleNamesModelColumn or 'vehicle_model')
    local vnName = cleanName(Config.VehicleNamesNameColumn or 'vehicle_name')

    return MySQL.single.await(([[
        SELECT
            ov.`%s` AS id,
            ov.`%s` AS owner_id,
            ov.`%s` AS model,
            ov.`%s` AS plate,
            COALESCE(NULLIF(vn.`%s`, ''), ov.`%s`) AS name
        FROM `%s` ov
        LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
        WHERE ov.`%s` = ? AND ov.`%s` = ?
        LIMIT 1
    ]]):format(ovId, ovOwner, ovModel, ovPlate, vnName, ovModel, ov, vn, vnModel, ovModel, ovId, ovOwner), { vehicleId, uid })
end

local function plateExists(plate, exceptId)
    plate = upper(plate)
    exceptId = tonumber(exceptId or 0) or 0

    local ov = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local ovId = cleanName(Config.OwnedVehiclesIdColumn or 'id')
    local ovPlate = cleanName(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')

    local row = MySQL.single.await(([[
        SELECT `%s` AS id
        FROM `%s`
        WHERE UPPER(TRIM(`%s`)) = ? AND `%s` <> ?
        LIMIT 1
    ]]):format(ovId, ov, ovPlate, ovId), { plate, exceptId })

    return row ~= nil
end

local function validatePlate(kind, rawPlate)
    kind = tostring(kind or ''):lower()
    local plate = upper(rawPlate):gsub('%s+', '')

    if plate == '' then
        return false, '', 'Introdu un numar de inmatriculare.'
    end

    if not plate:match('^[A-Z0-9]+$') then
        return false, '', 'Numarul poate contine doar litere si cifre.'
    end

    if kind == 'normal' then
        local prefix = upper(Config.Normal and Config.Normal.prefix or 'DZ')
        local minExtra = tonumber(Config.Normal and Config.Normal.minExtra or 3) or 3
        local maxLength = tonumber(Config.Normal and Config.Normal.maxLength or 8) or 8

        if plate:sub(1, #prefix) ~= prefix then
            return false, '', ('Numarul normal trebuie sa inceapa cu %s.'):format(prefix)
        end

        if #plate < (#prefix + minExtra) then
            return false, '', ('Dupa %s trebuie minim %s litere/cifre.'):format(prefix, minExtra)
        end

        if #plate > maxLength then
            return false, '', ('Numarul poate avea maxim %s caractere.'):format(maxLength)
        end

        return true, plate, ''
    end

    if kind == 'premium' then
        local minLength = tonumber(Config.Premium and Config.Premium.minLength or 1) or 1
        local maxLength = tonumber(Config.Premium and Config.Premium.maxLength or 8) or 8

        if #plate < minLength then
            return false, '', ('Numarul premium trebuie sa aiba minim %s caracter.'):format(minLength)
        end

        if #plate > maxLength then
            return false, '', ('Numarul poate avea maxim %s caractere.'):format(maxLength)
        end

        return true, plate, ''
    end

    return false, '', 'Tip invalid.'
end

local function logLicense(data)
    local tableName = cleanName(Config.LogsTable or 'licenses_logs')
    pcall(function()
        MySQL.insert.await(([[
            INSERT INTO `%s`
            (`uid`, `player_name`, `vehicle_id`, `vehicle_model`, `old_plate`, `new_plate`, `license_type`, `price`, `currency`, `status`, `message`, `details`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]]):format(tableName), {
            tonumber(data.uid or 0) or 0,
            tostring(data.player_name or ''),
            tonumber(data.vehicle_id or 0) or 0,
            tostring(data.vehicle_model or ''),
            tostring(data.old_plate or ''),
            tostring(data.new_plate or ''),
            tostring(data.license_type or ''),
            tonumber(data.price or 0) or 0,
            tostring(data.currency or ''),
            tostring(data.status or ''),
            tostring(data.message or ''),
            jsonSafe(data.details or {})
        })
    end)
end

local function buildPayload(uid)
    local balances = getUserBalances(uid)
    return {
        vehicles = getOwnedVehicles(uid),
        balances = balances,
        prices = {
            normal = Config.Normal and Config.Normal.price or 100000,
            premium = Config.Premium and Config.Premium.price or 2000
        },
        limits = {
            normalPrefix = Config.Normal and Config.Normal.prefix or 'DZ',
            normalMinExtra = Config.Normal and Config.Normal.minExtra or 3,
            normalMaxLength = Config.Normal and Config.Normal.maxLength or 8,
            premiumMinLength = Config.Premium and Config.Premium.minLength or 1,
            premiumMaxLength = Config.Premium and Config.Premium.maxLength or 8
        }
    }
end

RegisterNetEvent('driftzone_licenses:server:requestOpen', function()
    local src = source
    local now = GetGameTimer()

    if OpenCooldown[src] and OpenCooldown[src] > now then return end
    OpenCooldown[src] = now + 700

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)
    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    TriggerClientEvent('driftzone_licenses:client:open', src, buildPayload(uid))
end)

RegisterNetEvent('driftzone_licenses:server:buyPlate', function(payload)
    local src = source
    local now = GetGameTimer()

    if BuyCooldown[src] and BuyCooldown[src] > now then return end
    BuyCooldown[src] = now + 1400

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)
    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local data = type(payload) == 'table' and payload or {}
    local kind = tostring(data.licenseType or data.type or ''):lower()
    local vehicleId = tonumber(data.vehicleId or 0) or 0
    local okPlate, plate, plateError = validatePlate(kind, data.plate)

    local baseLog = {
        uid = uid,
        player_name = getPlayerNameSafe(src),
        vehicle_id = vehicleId,
        license_type = kind,
        new_plate = plate,
        status = 'failed'
    }

    if not okPlate then
        baseLog.message = plateError
        logLicense(baseLog)
        TriggerClientEvent('driftzone_licenses:client:result', src, false, plateError)
        return
    end

    local vehicle = getOwnedVehicle(uid, vehicleId)
    if not vehicle then
        local msg = 'Masina selectata nu iti apartine.'
        baseLog.message = msg
        logLicense(baseLog)
        TriggerClientEvent('driftzone_licenses:client:result', src, false, msg)
        return
    end

    baseLog.vehicle_model = vehicle.model
    baseLog.old_plate = vehicle.plate

    if plateExists(plate, vehicleId) then
        local msg = 'Exista deja o masina cu acest numar de inmatriculare.'
        baseLog.message = msg
        logLicense(baseLog)
        TriggerClientEvent('driftzone_licenses:client:result', src, false, msg)
        return
    end

    local price, currency, currencyCol
    if kind == 'normal' then
        price = tonumber(Config.Normal and Config.Normal.price or 100000) or 100000
        currency = 'cash'
        currencyCol = cleanName(Config.UsersCashColumn or 'cash')
    elseif kind == 'premium' then
        price = tonumber(Config.Premium and Config.Premium.price or 2000) or 2000
        currency = 'dzcoins'
        currencyCol = cleanName(Config.UsersCoinsColumn or 'dzcoins')
    else
        local msg = 'Tip invalid.'
        baseLog.message = msg
        logLicense(baseLog)
        TriggerClientEvent('driftzone_licenses:client:result', src, false, msg)
        return
    end

    baseLog.price = price
    baseLog.currency = currency

    local usersT = cleanName(Config.UsersTable or 'users')
    local uidCol = cleanName(Config.UsersIdColumn or 'uid')

    local removed = MySQL.update.await(([[
        UPDATE `%s`
        SET `%s` = `%s` - ?
        WHERE `%s` = ? AND `%s` >= ?
        LIMIT 1
    ]]):format(usersT, currencyCol, currencyCol, uidCol, currencyCol), { price, uid, price })

    if not removed or removed <= 0 then
        local msg = currency == 'cash' and 'Nu ai destui cash.' or 'Nu ai destule DriftZone Coins.'
        baseLog.message = msg
        logLicense(baseLog)
        TriggerClientEvent('driftzone_licenses:client:result', src, false, msg)
        return
    end

    local ov = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local ovId = cleanName(Config.OwnedVehiclesIdColumn or 'id')
    local ovOwner = cleanName(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local ovPlate = cleanName(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')

    local changed = MySQL.update.await(([[
        UPDATE `%s`
        SET `%s` = ?
        WHERE `%s` = ? AND `%s` = ?
        LIMIT 1
    ]]):format(ov, ovPlate, ovId, ovOwner), { plate, vehicleId, uid })

    if not changed or changed <= 0 then
        MySQL.update.await(([[
            UPDATE `%s`
            SET `%s` = `%s` + ?
            WHERE `%s` = ?
            LIMIT 1
        ]]):format(usersT, currencyCol, currencyCol, uidCol), { price, uid })

        local msg = 'Nu am putut schimba numarul. Banii au fost returnati.'
        baseLog.message = msg
        logLicense(baseLog)
        TriggerClientEvent('driftzone_licenses:client:result', src, false, msg)
        return
    end

    clearVehicleCache(uid)

    baseLog.status = 'success'
    baseLog.message = 'Numar schimbat cu succes.'
    baseLog.details = {
        oldPlate = vehicle.plate,
        newPlate = plate,
        vehicleName = vehicle.name,
        price = price,
        currency = currency
    }
    logLicense(baseLog)

    notify(src, 'success', ('Numarul a fost schimbat in %s.'):format(plate), 6000)
    TriggerClientEvent('driftzone_licenses:client:result', src, true, ('Numarul a fost schimbat in %s.'):format(plate), buildPayload(uid))
end)

AddEventHandler('playerDropped', function()
    local src = source
    OpenCooldown[src] = nil
    BuyCooldown[src] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_LICENSES] Loaded.')
end)
