local PayCooldowns = {}
local TradesById = {}
local ActiveTradeByPlayer = {}
local NextTradeId = 0

local function cleanName(value)
    return tostring(value or ''):gsub('`', '')
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
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end,
        function() return exports.driftzone_auth:getUserId(src) end
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

local function playerOnline(src)
    src = tonumber(src or 0) or 0
    return src > 0 and GetPlayerPing(src) > 0
end

local function getCash(uid)
    local usersTable = cleanName(Config.UsersTable or 'users')
    local uidCol = cleanName(Config.UsersIdColumn or 'uid')
    local cashCol = cleanName(Config.UsersCashColumn or 'cash')
    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT `%s` AS cash FROM `%s` WHERE `%s` = ? LIMIT 1'):format(cashCol, usersTable, uidCol), { uid })
    end)
    if ok and row then return tonumber(row.cash or 0) or 0 end
    return 0
end

local function setCash(uid, newCash)
    uid = tonumber(uid or 0) or 0
    newCash = math.max(0, math.floor(tonumber(newCash or 0) or 0))
    if uid <= 0 then return false end
    local usersTable = cleanName(Config.UsersTable or 'users')
    local uidCol = cleanName(Config.UsersIdColumn or 'uid')
    local cashCol = cleanName(Config.UsersCashColumn or 'cash')
    local ok, err = pcall(function()
        MySQL.update.await(('UPDATE `%s` SET `%s` = ? WHERE `%s` = ? LIMIT 1'):format(usersTable, cashCol, uidCol), { newCash, uid })
    end)
    if not ok then print('[DRIFTZONE_PLAYERINTERACT] setCash failed: ' .. tostring(err)) end
    return ok == true
end

local function addCash(uid, amount)
    uid = tonumber(uid or 0) or 0
    amount = math.floor(tonumber(amount or 0) or 0)
    if uid <= 0 or amount == 0 then return false end
    local current = getCash(uid)
    local newValue = current + amount
    if newValue < 0 then return false end
    local maxCash = tonumber(Config.SafeCashMax or 2147483647) or 2147483647
    if newValue > maxCash then newValue = maxCash end
    return setCash(uid, newValue)
end

local function logPay(src, target, fromUid, toUid, amount)
    local tableName = cleanName(Config.PayLogsTable or 'pay_logs')
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local ok, err = pcall(function()
        MySQL.insert.await(([[
            INSERT INTO `%s`
            (`from_uid`, `from_name`, `to_uid`, `to_name`, `amount`, `x`, `y`, `z`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]]):format(tableName), {
            fromUid, getPlayerNameSafe(src), toUid, getPlayerNameSafe(target), amount, coords.x, coords.y, coords.z
        })
    end)
    if not ok then print('[DRIFTZONE_PLAYERINTERACT] pay log failed: ' .. tostring(err)) end
end

local function getVehicleById(vehicleId, ownerUid)
    vehicleId = tonumber(vehicleId or 0) or 0
    ownerUid = tonumber(ownerUid or 0) or 0
    if vehicleId <= 0 or ownerUid <= 0 then return nil end

    local t = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanName(Config.OwnedVehiclesIdColumn or 'id')
    local ownerCol = cleanName(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local modelCol = cleanName(Config.OwnedVehiclesModelColumn or 'vehicle_model')
    local plateCol = cleanName(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')
    local namesT = cleanName(Config.VehicleNamesTable or 'vehiclenames')
    local namesModel = cleanName(Config.VehicleNamesModelColumn or 'vehicle_model')
    local namesName = cleanName(Config.VehicleNamesNameColumn or 'vehicle_name')

    local ok, row = pcall(function()
        return MySQL.single.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS owner_id, ov.`%s` AS model, ov.`%s` AS plate,
                   COALESCE(vn.`%s`, ov.`%s`) AS name
            FROM `%s` ov
            LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
            WHERE ov.`%s` = ? AND ov.`%s` = ?
            LIMIT 1
        ]]):format(idCol, ownerCol, modelCol, plateCol, namesName, modelCol, t, namesT, namesModel, modelCol, idCol, ownerCol), { vehicleId, ownerUid })
    end)

    if ok and row then return row end
    return nil
end

local function getVehicles(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return {} end

    local limit = tonumber(Config.Trade and Config.Trade.maxVehicles or 80) or 80
    local t = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanName(Config.OwnedVehiclesIdColumn or 'id')
    local ownerCol = cleanName(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local modelCol = cleanName(Config.OwnedVehiclesModelColumn or 'vehicle_model')
    local plateCol = cleanName(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')
    local namesT = cleanName(Config.VehicleNamesTable or 'vehiclenames')
    local namesModel = cleanName(Config.VehicleNamesModelColumn or 'vehicle_model')
    local namesName = cleanName(Config.VehicleNamesNameColumn or 'vehicle_name')

    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS model, ov.`%s` AS plate,
                   COALESCE(vn.`%s`, ov.`%s`) AS name
            FROM `%s` ov
            LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
            WHERE ov.`%s` = ?
            ORDER BY ov.`%s` DESC
            LIMIT %d
        ]]):format(idCol, modelCol, plateCol, namesName, modelCol, t, namesT, namesModel, modelCol, ownerCol, idCol, limit), { uid })
    end)

    if not ok or type(rows) ~= 'table' then return {} end
    return rows
end

local function transferVehicle(vehicleId, fromUid, toUid)
    vehicleId = tonumber(vehicleId or 0) or 0
    fromUid = tonumber(fromUid or 0) or 0
    toUid = tonumber(toUid or 0) or 0
    if vehicleId <= 0 or fromUid <= 0 or toUid <= 0 then return false end

    local t = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanName(Config.OwnedVehiclesIdColumn or 'id')
    local ownerCol = cleanName(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local ok, affected = pcall(function()
        return MySQL.update.await(('UPDATE `%s` SET `%s` = ? WHERE `%s` = ? AND `%s` = ? LIMIT 1'):format(t, ownerCol, idCol, ownerCol), { toUid, vehicleId, fromUid })
    end)
    return ok == true and tonumber(affected or 0) > 0
end

local function jsonEncode(data)
    local ok, result = pcall(json.encode, data)
    if ok then return result end
    return '{}'
end

local function logTrade(trade, accepted, reason)
    local tableName = cleanName(Config.TradeLogsTable or 'trade_logs')
    local ok, err = pcall(function()
        MySQL.insert.await(([[
            INSERT INTO `%s`
            (`request_id`, `from_uid`, `from_name`, `to_uid`, `to_name`, `from_vehicle_id`, `to_vehicle_id`, `from_money`, `to_money`, `accepted`, `reason`, `details`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]]):format(tableName), {
            trade.id,
            trade.fromUid,
            trade.fromName,
            trade.toUid,
            trade.toName,
            trade.fromOffer and trade.fromOffer.vehicleId or 0,
            trade.toOffer and trade.toOffer.vehicleId or 0,
            trade.fromOffer and trade.fromOffer.money or 0,
            trade.toOffer and trade.toOffer.money or 0,
            accepted and 1 or 0,
            tostring(reason or ''),
            jsonEncode(trade)
        })
    end)
    if not ok then print('[DRIFTZONE_PLAYERINTERACT] trade log failed: ' .. tostring(err)) end
end

local function clearTrade(trade, message)
    if not trade then return end
    TradesById[trade.id] = nil
    if trade.from then ActiveTradeByPlayer[trade.from] = nil end
    if trade.to then ActiveTradeByPlayer[trade.to] = nil end
    if message and playerOnline(trade.from) then TriggerClientEvent('driftzone_playerinteract:client:tradeClose', trade.from, message) end
    if message and playerOnline(trade.to) then TriggerClientEvent('driftzone_playerinteract:client:tradeClose', trade.to, message) end
end

local function newTradeId()
    NextTradeId = NextTradeId + 1
    return ('DZTR-%s-%s'):format(os.time(), NextTradeId)
end

local function validDistance(src, target, extra)
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if not srcPed or srcPed == 0 or not targetPed or targetPed == 0 then return false end
    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    return dist <= (Config.MaxSelectDistance or 6.0) + (extra or 2.0)
end

RegisterNetEvent('driftzone_playerinteract:server:requestTargetInfo', function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0

    if not playerOnline(targetServerId) or targetServerId == src then
        TriggerClientEvent('driftzone_playerinteract:client:targetInfo', src, false, 'Jucator invalid.')
        return
    end

    if not validDistance(src, targetServerId, 1.5) then
        TriggerClientEvent('driftzone_playerinteract:client:targetInfo', src, false, 'Jucatorul este prea departe.')
        return
    end

    local targetUid = getUid(targetServerId)
    TriggerClientEvent('driftzone_playerinteract:client:targetInfo', src, true, {
        serverId = targetServerId,
        uid = targetUid or targetServerId,
        name = getPlayerNameSafe(targetServerId)
    })
end)

RegisterNetEvent('driftzone_playerinteract:server:pay', function(targetServerId, amount)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0
    amount = math.floor(tonumber(amount or 0) or 0)

    if not Config.Pay or Config.Pay.enabled ~= true then
        notify(src, 'warning', 'Pay este dezactivat.')
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Pay este dezactivat.')
        return
    end

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Trebuie sa fii logat.')
        return
    end

    if not playerOnline(targetServerId) or targetServerId == src then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Jucator invalid.')
        return
    end

    local minPay = tonumber(Config.Pay.min or 1) or 1
    local maxPay = tonumber(Config.Pay.max or 500000000) or 500000000
    if amount < minPay or amount > maxPay then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, ('Suma trebuie sa fie intre %s si %s.'):format(minPay, maxPay))
        return
    end

    local now = GetGameTimer()
    local cooldownUntil = PayCooldowns[src] or 0
    if cooldownUntil > now then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Asteapta putin inainte sa faci alta plata.')
        return
    end
    PayCooldowns[src] = now + (tonumber(Config.Pay.cooldownMs or 1500) or 1500)

    if not validDistance(src, targetServerId, 2.0) then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Jucatorul este prea departe.')
        return
    end

    local fromUid = getUid(src)
    local toUid = getUid(targetServerId)
    if not fromUid or not toUid then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Nu am gasit UID-ul jucatorului.')
        return
    end

    local cash = getCash(fromUid)
    if cash < amount then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Nu ai destui bani.')
        notify(src, 'warning', 'Nu ai destui bani.', 4500)
        return
    end

    local okTake = addCash(fromUid, -amount)
    if not okTake then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Nu s-a putut retrage suma.')
        return
    end

    local okGive = addCash(toUid, amount)
    if not okGive then
        addCash(fromUid, amount)
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Nu s-a putut trimite suma. Banii au fost returnati.')
        return
    end

    logPay(src, targetServerId, fromUid, toUid, amount)
    notify(src, 'success', ('Ai trimis $%s catre %s.'):format(amount, getPlayerNameSafe(targetServerId)), 5000)
    notify(targetServerId, 'success', ('Ai primit $%s de la %s.'):format(amount, getPlayerNameSafe(src)), 5000)
    TriggerClientEvent('driftzone_playerinteract:client:payResult', src, true, ('Ai trimis $%s.'):format(amount))
end)

RegisterNetEvent('driftzone_playerinteract:server:openTrade', function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0

    if not Config.Trade or Config.Trade.enabled ~= true then
        notify(src, 'warning', 'Trade este dezactivat.')
        return
    end

    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.'); return end
    if not playerOnline(targetServerId) or targetServerId == src then notify(src, 'warning', 'Jucator invalid.'); return end
    if ActiveTradeByPlayer[src] then notify(src, 'warning', 'Ai deja un trade activ.'); return end
    if ActiveTradeByPlayer[targetServerId] then notify(src, 'warning', 'Playerul are deja un trade activ.'); return end
    if not validDistance(src, targetServerId, 2.0) then notify(src, 'warning', 'Jucatorul este prea departe.'); return end

    local fromUid = getUid(src)
    local toUid = getUid(targetServerId)
    if not fromUid or not toUid then notify(src, 'warning', 'Nu am gasit UID-ul.'); return end

    TriggerClientEvent('driftzone_playerinteract:client:tradeOpen', src, {
        target = { serverId = targetServerId, uid = toUid, name = getPlayerNameSafe(targetServerId) },
        myVehicles = getVehicles(fromUid),
        targetVehicles = getVehicles(toUid),
        timeout = tonumber(Config.Trade.timeoutSeconds or 30) or 30
    })
end)

RegisterNetEvent('driftzone_playerinteract:server:sendTradeOffer', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local targetServerId = tonumber(data.target or 0) or 0
    local vehicleId = tonumber(data.vehicleId or 0) or 0
    local moneyAmount = math.floor(tonumber(data.money or 0) or 0)
    local maxMoney = tonumber(Config.Trade and Config.Trade.maxMoney or 500000000) or 500000000

    if ActiveTradeByPlayer[src] then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Ai deja un trade activ.' }); return end
    if ActiveTradeByPlayer[targetServerId] then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Playerul are deja un trade activ.' }); return end
    if not playerOnline(targetServerId) or targetServerId == src then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Jucator invalid.' }); return end
    if moneyAmount < 0 or moneyAmount > maxMoney then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Suma cash invalida.' }); return end
    if not validDistance(src, targetServerId, 3.0) then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Jucatorul este prea departe.' }); return end

    local fromUid = getUid(src)
    local toUid = getUid(targetServerId)
    if not fromUid or not toUid then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Nu am gasit UID-ul.' }); return end

    local vehicle = nil
    if vehicleId > 0 then
        vehicle = getVehicleById(vehicleId, fromUid)
        if not vehicle then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Masina aleasa nu iti apartine.' }); return end
    end

    if moneyAmount > 0 and getCash(fromUid) < moneyAmount then
        TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Nu ai destui bani pentru oferta.' })
        return
    end

    NextTradeId = NextTradeId + 1
    local id = newTradeId()
    local trade = {
        id = id,
        from = src,
        to = targetServerId,
        fromUid = fromUid,
        toUid = toUid,
        fromName = getPlayerNameSafe(src),
        toName = getPlayerNameSafe(targetServerId),
        fromOffer = { vehicleId = vehicleId, vehicle = vehicle, money = moneyAmount },
        createdAt = os.time(),
        expiresAt = os.time() + (tonumber(Config.Trade.timeoutSeconds or 30) or 30),
        processing = false
    }

    TradesById[id] = trade
    ActiveTradeByPlayer[src] = id
    ActiveTradeByPlayer[targetServerId] = id

    TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = true, message = 'Trade trimis. Asteapta raspuns.' })
    notify(src, 'info', 'Trade trimis. Asteapta raspuns.', 4500)
    notify(targetServerId, 'info', ('Ai primit trade de la %s.'):format(trade.fromName), 6500)
    TriggerClientEvent('driftzone_playerinteract:client:tradeIncoming', targetServerId, {
        requestId = id,
        from = { serverId = src, uid = fromUid, name = trade.fromName },
        offer = trade.fromOffer,
        myVehicles = getVehicles(toUid),
        fromVehicles = getVehicles(fromUid),
        timeout = tonumber(Config.Trade.timeoutSeconds or 30) or 30
    })

    SetTimeout((tonumber(Config.Trade.timeoutSeconds or 30) or 30) * 1000, function()
        local current = TradesById[id]
        if current and current.expiresAt <= os.time() then
            logTrade(current, false, 'timeout')
            clearTrade(current, 'Trade expirat.')
        end
    end)
end)

RegisterNetEvent('driftzone_playerinteract:server:answerTrade', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local requestId = tostring(data.requestId or '')
    local trade = TradesById[requestId]
    if not trade or trade.to ~= src then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Trade invalid sau expirat.' }); return end
    if trade.processing then return end
    trade.processing = true

    local toVehicleId = tonumber(data.vehicleId or 0) or 0
    local toMoney = math.floor(tonumber(data.money or 0) or 0)
    local maxMoney = tonumber(Config.Trade and Config.Trade.maxMoney or 500000000) or 500000000

    local function fail(msg)
        trade.processing = false
        TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = msg })
    end

    if os.time() > trade.expiresAt then logTrade(trade, false, 'expired_accept'); clearTrade(trade, 'Trade expirat.'); return end
    if not playerOnline(trade.from) or not playerOnline(trade.to) then logTrade(trade, false, 'player_offline'); clearTrade(trade, 'Trade anulat: player offline.'); return end
    if toMoney < 0 or toMoney > maxMoney then fail('Suma cash invalida.'); return end
    if not validDistance(trade.from, trade.to, 4.0) then logTrade(trade, false, 'distance'); clearTrade(trade, 'Trade anulat: sunteti prea departe.'); return end

    local toVehicle = nil
    if toVehicleId > 0 then
        toVehicle = getVehicleById(toVehicleId, trade.toUid)
        if not toVehicle then fail('Masina aleasa nu iti apartine.'); return end
    end

    trade.toOffer = { vehicleId = toVehicleId, vehicle = toVehicle, money = toMoney }

    local fromVehicleId = tonumber(trade.fromOffer.vehicleId or 0) or 0
    local fromMoney = tonumber(trade.fromOffer.money or 0) or 0
    if fromVehicleId <= 0 and fromMoney <= 0 and toVehicleId <= 0 and toMoney <= 0 then
        fail('Cel putin o persoana trebuie sa ofere masina sau bani.')
        return
    end

    if fromVehicleId > 0 and not getVehicleById(fromVehicleId, trade.fromUid) then logTrade(trade, false, 'from_vehicle_missing'); clearTrade(trade, 'Trade anulat: masina ofertata nu mai exista.'); return end
    if toVehicleId > 0 and not getVehicleById(toVehicleId, trade.toUid) then logTrade(trade, false, 'to_vehicle_missing'); clearTrade(trade, 'Trade anulat: masina ofertata nu mai exista.'); return end
    if fromMoney > 0 and getCash(trade.fromUid) < fromMoney then logTrade(trade, false, 'from_no_cash'); clearTrade(trade, 'Trade anulat: primul player nu mai are banii.'); return end
    if toMoney > 0 and getCash(trade.toUid) < toMoney then fail('Nu ai destui bani pentru oferta.'); return end

    local moved = {}
    if fromMoney > 0 then
        if not addCash(trade.fromUid, -fromMoney) then logTrade(trade, false, 'take_from_cash'); clearTrade(trade, 'Trade esuat: cash.'); return end
        moved.fromCashTaken = true
    end
    if toMoney > 0 then
        if not addCash(trade.toUid, -toMoney) then
            if moved.fromCashTaken then addCash(trade.fromUid, fromMoney) end
            logTrade(trade, false, 'take_to_cash')
            clearTrade(trade, 'Trade esuat: cash.')
            return
        end
        moved.toCashTaken = true
    end

    if fromVehicleId > 0 then
        if not transferVehicle(fromVehicleId, trade.fromUid, trade.toUid) then
            if moved.fromCashTaken then addCash(trade.fromUid, fromMoney) end
            if moved.toCashTaken then addCash(trade.toUid, toMoney) end
            logTrade(trade, false, 'transfer_from_vehicle')
            clearTrade(trade, 'Trade esuat: masina nu a putut fi transferata.')
            return
        end
        moved.fromVehicleMoved = true
    end

    if toVehicleId > 0 then
        if not transferVehicle(toVehicleId, trade.toUid, trade.fromUid) then
            if moved.fromVehicleMoved then transferVehicle(fromVehicleId, trade.toUid, trade.fromUid) end
            if moved.fromCashTaken then addCash(trade.fromUid, fromMoney) end
            if moved.toCashTaken then addCash(trade.toUid, toMoney) end
            logTrade(trade, false, 'transfer_to_vehicle')
            clearTrade(trade, 'Trade esuat: masina nu a putut fi transferata.')
            return
        end
        moved.toVehicleMoved = true
    end

    if fromMoney > 0 then addCash(trade.toUid, fromMoney) end
    if toMoney > 0 then addCash(trade.fromUid, toMoney) end

    logTrade(trade, true, 'accepted')
    notify(trade.from, 'success', 'Trade finalizat cu succes.', 6000)
    notify(trade.to, 'success', 'Trade finalizat cu succes.', 6000)
    clearTrade(trade, 'Trade finalizat cu succes.')
end)

RegisterNetEvent('driftzone_playerinteract:server:cancelTrade', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local requestId = tostring(data.requestId or ActiveTradeByPlayer[src] or '')
    local trade = TradesById[requestId]
    if not trade then return end
    if trade.from ~= src and trade.to ~= src then return end
    logTrade(trade, false, 'cancelled')
    clearTrade(trade, 'Trade anulat.')
end)

AddEventHandler('playerDropped', function()
    local src = source
    PayCooldowns[src] = nil
    local requestId = ActiveTradeByPlayer[src]
    if requestId and TradesById[requestId] then
        local trade = TradesById[requestId]
        logTrade(trade, false, 'player_dropped')
        clearTrade(trade, 'Trade anulat: player deconectat.')
    end
end)
