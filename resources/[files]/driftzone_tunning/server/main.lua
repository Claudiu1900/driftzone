local UidCache = {}
local CashCache = {}

local function sqlName(name)
    return ('`%s`'):format(tostring(name):gsub('`', ''))
end

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function getUid(src)
    local state = Player(src).state

    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then
        return cached.uid
    end

    local ok, uid = pcall(function()
        return exports.driftzone_auth:GetUID(src)
    end)

    if ok and tonumber(uid) and tonumber(uid) > 0 then
        uid = tonumber(uid)

        UidCache[src] = {
            uid = uid,
            expires = GetGameTimer() + 30000
        }

        return uid
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

local function safeDecode(raw)
    if type(raw) == 'table' then return raw end

    local ok, decoded = pcall(json.decode, tostring(raw or '{}'))

    if ok and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

local function getCash(uid, force)
    uid = tonumber(uid)
    if not uid then return 0 end

    local cached = CashCache[uid]
    if not force and cached and cached.expires > GetGameTimer() then
        return cached.cash
    end

    local row = MySQL.single.await(
        ('SELECT %s AS cash FROM %s WHERE %s = ? LIMIT 1'):format(
            sqlName(Config.CashColumn),
            sqlName(Config.UsersTable),
            sqlName(Config.UsersIdColumn)
        ),
        { uid }
    )

    local cash = row and tonumber(row.cash or 0) or 0

    CashCache[uid] = {
        cash = cash,
        expires = GetGameTimer() + 1500
    }

    return cash
end

local function setCashCache(uid, cash)
    uid = tonumber(uid)
    if not uid then return end

    CashCache[uid] = {
        cash = tonumber(cash or 0) or 0,
        expires = GetGameTimer() + 1500
    }
end

local function takeCash(uid, amount)
    uid = tonumber(uid)
    amount = tonumber(amount or 0) or 0

    if not uid then return false end
    if amount <= 0 then return true end

    local affected = MySQL.update.await(
        ('UPDATE %s SET %s = %s - ? WHERE %s = ? AND %s >= ?'):format(
            sqlName(Config.UsersTable),
            sqlName(Config.CashColumn),
            sqlName(Config.CashColumn),
            sqlName(Config.UsersIdColumn),
            sqlName(Config.CashColumn)
        ),
        { amount, uid, amount }
    )

    if affected and affected > 0 then
        local current = getCash(uid, true)
        setCashCache(uid, current)
        return true, current
    end

    return false, getCash(uid, true)
end

local function vehicleExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function getCurrentVehicle(src)
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then return 0 end

    local veh = GetVehiclePedIsIn(ped, false)

    if not vehicleExists(veh) then return 0 end

    return veh
end

local function getVehicleStateData(vehicle)
    if not vehicleExists(vehicle) then return nil end

    local s = Entity(vehicle).state

    return {
        vehicleId = tonumber(s.dz_garage_db_id or s.vehicleDbId or s.ownedVehicleId or s.dz_vs_sql_id or 0) or 0,
        ownerUid = tonumber(s.dz_garage_owner_uid or s.dz_vs_owner_id or 0) or 0,
        plate = tostring(s.dz_garage_plate or s.dz_vs_plate or GetVehicleNumberPlateText(vehicle) or ''),
        model = tostring(s.dz_garage_model or s.dz_vs_model or ''),
        name = tostring(s.dz_garage_name or 'Vehicle')
    }
end

local function getOwnedVehicleForPlayer(vehicleId, uid)
    return MySQL.single.await([[
        SELECT ov.id, ov.owner_id, ov.vehicle_model, ov.vehicle_plate, ov.vehicle_tunning,
               COALESCE(vn.vehicle_name, ov.vehicle_model) AS vehicle_name,
               COALESCE(vn.price, 0) AS vehicle_price
        FROM ownedvehicles ov
        LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.vehicle_model
        WHERE ov.id = ? AND ov.owner_id = ?
        LIMIT 1
    ]], { vehicleId, uid })
end

local function cleanTuningObject(value)
    local tuning = safeDecode(value)
    local clean = {}

    for i = 1, #(Config.Categories or {}) do
        local category = Config.Categories[i]

        if tuning[category.key] ~= nil then
            clean[category.key] = tuning[category.key]
        end
    end

    return clean
end

local function calculatePrice(basePrice, changes)
    basePrice = tonumber(basePrice or 0) or 0

    if type(changes) ~= 'table' then return 0 end

    local total = 0
    local used = {}

    for i = 1, #changes do
        local item = changes[i]

        if item and item.key and not used[item.key] then
            used[item.key] = true

            local percent = tonumber((Config.PricePercent or {})[item.key] or 1) or 1
            total = total + math.max(1, math.ceil(basePrice * (percent / 100)))
        end
    end

    return total
end

local function openTuning(src)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local vehicle = getCurrentVehicle(src)

    if vehicle == 0 then
        notify(src, 'warning', 'Trebuie sa fii intr-o masina.')
        return
    end

    local vdata = getVehicleStateData(vehicle)

    if not vdata or vdata.vehicleId <= 0 then
        notify(src, 'warning', 'Aceasta masina trebuie sa fie scoasa din garaj.')
        return
    end

    if vdata.ownerUid > 0 and tonumber(vdata.ownerUid) ~= tonumber(uid) then
        notify(src, 'warning', 'Aceasta masina nu iti apartine.')
        return
    end

    local owned = getOwnedVehicleForPlayer(vdata.vehicleId, uid)

    if not owned then
        notify(src, 'warning', 'Aceasta masina nu iti apartine.')
        return
    end

    TriggerClientEvent('driftzone_tunning:client:open', src, {
        vehicleId = tonumber(owned.id),
        vehicleModel = tostring(owned.vehicle_model or vdata.model or ''),
        vehicleName = tostring(owned.vehicle_name or owned.vehicle_model or vdata.name or 'Vehicle'),
        vehiclePlate = tostring(owned.vehicle_plate or vdata.plate or ''),
        vehiclePrice = tonumber(owned.vehicle_price or 0) or 0,
        playerMoney = getCash(uid),
        categories = Config.Categories or {},
        pricePercent = Config.PricePercent or {},
        savedTuning = safeDecode(owned.vehicle_tunning or '{}')
    })
end

local function buyTuning(src, payload)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local vehicle = getCurrentVehicle(src)

    if vehicle == 0 then
        notify(src, 'warning', 'Trebuie sa fii in masina.')
        return
    end

    local data = safeDecode(payload)
    local vehicleId = tonumber(data.vehicleId or 0) or 0

    if vehicleId <= 0 then
        notify(src, 'warning', 'Vehicul invalid.')
        return
    end

    local vdata = getVehicleStateData(vehicle)

    if not vdata or tonumber(vdata.vehicleId) ~= vehicleId then
        notify(src, 'warning', 'Nu mai esti in masina pe care o modificai.')
        return
    end

    local owned = getOwnedVehicleForPlayer(vehicleId, uid)

    if not owned then
        notify(src, 'warning', 'Aceasta masina nu iti apartine.')
        return
    end

    local changes = data.changes

    if type(changes) ~= 'table' or #changes <= 0 then
        notify(src, 'warning', 'Nu ai selectat nicio modificare.')
        return
    end

    local tuning = cleanTuningObject(data.tuning or {})
    local total = calculatePrice(tonumber(owned.vehicle_price or 0) or 0, changes)

    if total <= 0 then
        notify(src, 'warning', 'Pret invalid.')
        return
    end

    local paid, remainingCash = takeCash(uid, total)

    if not paid then
        notify(src, 'warning', ('Nu ai suficient cash. Cost total: $%s'):format(total))
        return
    end

    MySQL.update.await(
        'UPDATE ownedvehicles SET vehicle_tunning = ? WHERE id = ? AND owner_id = ?',
        { json.encode(tuning), vehicleId, uid }
    )

    local raw = json.encode(tuning)

    Entity(vehicle).state:set('vehicleTunning', raw, true)
    Entity(vehicle).state:set('dz_vehicle_tunning', raw, true)

    notify(src, 'info', ('Tuning aplicat cu succes. Ai platit $%s.'):format(total))

    TriggerClientEvent('driftzone_tunning:client:paid', src, {
        tuning = tuning,
        paid = total,
        money = remainingCash,
        cash = remainingCash
    })
end

RegisterNetEvent('driftzone_tunning:server:open', function()
    openTuning(source)
end)

RegisterNetEvent('driftzone_tunning:server:buy', function(payload)
    buyTuning(source, payload)
end)

RegisterCommand('tuning', function(src)
    if src ~= 0 then
        openTuning(src)
    end
end, false)

RegisterCommand('tune', function(src)
    if src ~= 0 then
        openTuning(src)
    end
end, false)

exports('OpenTuning', openTuning)

AddEventHandler('playerDropped', function()
    local src = source
    local cached = UidCache[src]

    if cached and cached.uid then
        CashCache[cached.uid] = nil
    end

    UidCache[src] = nil
end)

CreateThread(function()
    Wait(500)
    print('[DRIFTZONE_TUNNING] Server-side loaded. Cash column: ' .. tostring(Config.CashColumn))
end)
