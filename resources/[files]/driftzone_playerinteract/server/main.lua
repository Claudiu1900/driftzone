local PayCooldowns = {}
local TradesById = {}
local ActiveTradeByPlayer = {}
local NextTradeId = 0

local function cleanName(value)
    return tostring(value or ''):gsub('`', '')
end


local VehicleNameColumns = nil

local function loadVehicleNameColumns()
    if VehicleNameColumns then return VehicleNameColumns end

    VehicleNameColumns = {}
    local tableName = cleanName(Config.VehicleNamesTable or 'vehiclenames')

    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(tableName), {})
    end)

    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row.Field then
                VehicleNameColumns[tostring(row.Field)] = true
            end
        end
    end

    return VehicleNameColumns
end

local function getTradableSql(alias)
    alias = alias or 'vn'
    local cols = loadVehicleNameColumns()
    local configured = Config.VehicleNamesTradableColumn or 'tradable'
    local configuredClean = cleanName(configured)

    if cols[configuredClean] then
        return ('COALESCE(%s.`%s`, 1)'):format(alias, configuredClean)
    end

    -- Compatibilitate cu varianta veche scrisa ca `tradeble`.
    if cols.tradable and cols.tradeble then
        return ('COALESCE(%s.`tradable`, %s.`tradeble`, 1)'):format(alias, alias)
    elseif cols.tradable then
        return ('COALESCE(%s.`tradable`, 1)'):format(alias)
    elseif cols.tradeble then
        return ('COALESCE(%s.`tradeble`, 1)'):format(alias)
    end

    return nil
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
    local tradableExpr = getTradableSql('vn')
    local tradableWhere = tradableExpr and (' AND %s = 1'):format(tradableExpr) or ''

    local ok, row = pcall(function()
        return MySQL.single.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS owner_id, ov.`%s` AS model, ov.`%s` AS plate,
                   COALESCE(vn.`%s`, ov.`%s`) AS name
            FROM `%s` ov
            LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
            WHERE ov.`%s` = ? AND ov.`%s` = ?%s
            LIMIT 1
        ]]):format(idCol, ownerCol, modelCol, plateCol, namesName, modelCol, t, namesT, namesModel, modelCol, idCol, ownerCol, tradableWhere), { vehicleId, ownerUid })
    end)

    if ok and row then return row end
    return nil
end


local function normalizeVehicleIds(value)
    local result = {}
    local seen = {}
    if type(value) == 'table' then
        for _, v in ipairs(value) do
            local id = tonumber(v or 0) or 0
            if id > 0 and not seen[id] then
                seen[id] = true
                result[#result + 1] = id
            end
        end
    else
        local id = tonumber(value or 0) or 0
        if id > 0 then result[#result + 1] = id end
    end
    return result
end

local function getVehiclesByIds(vehicleIds, ownerUid)
    local vehicles = {}
    local validIds = {}
    for _, id in ipairs(normalizeVehicleIds(vehicleIds)) do
        local v = getVehicleById(id, ownerUid)
        if not v then return nil end
        vehicles[#vehicles + 1] = v
        validIds[#validIds + 1] = id
    end
    return vehicles, validIds
end

local function offerSignature(offer)
    offer = offer or {}
    local ids = normalizeVehicleIds(offer.vehicleIds or offer.vehicleId)
    table.sort(ids)
    return table.concat(ids, ',') .. '|' .. tostring(tonumber(offer.money or 0) or 0)
end

local function sameOffer(a, b)
    return offerSignature(a) == offerSignature(b)
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
    local tradableExpr = getTradableSql('vn')
    local tradableWhere = tradableExpr and (' AND %s = 1'):format(tradableExpr) or ''

    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS model, ov.`%s` AS plate,
                   COALESCE(vn.`%s`, ov.`%s`) AS name
            FROM `%s` ov
            LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
            WHERE ov.`%s` = ?%s
            ORDER BY ov.`%s` DESC
            LIMIT %d
        ]]):format(idCol, modelCol, plateCol, namesName, modelCol, t, namesT, namesModel, modelCol, ownerCol, tradableWhere, idCol, limit), { uid })
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
            trade.fromOffer and (trade.fromOffer.vehicleId or (trade.fromOffer.vehicleIds and trade.fromOffer.vehicleIds[1]) or 0) or 0,
            trade.toOffer and (trade.toOffer.vehicleId or (trade.toOffer.vehicleIds and trade.toOffer.vehicleIds[1]) or 0) or 0,
            trade.fromOffer and trade.fromOffer.money or 0,
            trade.toOffer and trade.toOffer.money or 0,
            accepted and 1 or 0,
            tostring(reason or ''),
            jsonEncode(trade)
        })
    end)
    if not ok then print('[DRIFTZONE_PLAYERINTERACT] trade log failed: ' .. tostring(err)) end
end


local function logTradeRequest(req, accepted, reason)
    if not req then return end
    local tableName = cleanName(Config.TradeLogsTable or 'trade_logs')
    local details = {
        type = 'request',
        id = req.id,
        from = req.from,
        to = req.to,
        fromUid = req.fromUid,
        toUid = req.toUid,
        createdAt = req.createdAt,
        expiresAt = req.expiresAt,
        reason = reason
    }
    local ok, err = pcall(function()
        MySQL.insert.await(([[
            INSERT INTO `%s`
            (`request_id`, `from_uid`, `from_name`, `to_uid`, `to_name`, `from_vehicle_id`, `to_vehicle_id`, `from_money`, `to_money`, `accepted`, `reason`, `details`, `created_at`)
            VALUES (?, ?, ?, ?, ?, 0, 0, 0, 0, ?, ?, ?, NOW())
        ]]):format(tableName), {
            tostring(req.id or ''),
            tonumber(req.fromUid or 0) or 0,
            req.from and getPlayerNameSafe(req.from) or 'Unknown',
            tonumber(req.toUid or 0) or 0,
            req.to and getPlayerNameSafe(req.to) or 'Unknown',
            accepted and 1 or 0,
            tostring(reason or ''),
            jsonEncode(details)
        })
    end)
    if not ok then print('[DRIFTZONE_PLAYERINTERACT] trade request log failed: ' .. tostring(err)) end
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


local PendingRequests = {}
local PendingByPlayer = {}

local function removePending(id)
    local p = PendingRequests[id]
    if not p then return end
    if PendingByPlayer[p.from] == id then PendingByPlayer[p.from] = nil end
    PendingRequests[id] = nil
end

local function findPending(fromSrc, toSrc)
    local id = PendingByPlayer[fromSrc]
    local p = id and PendingRequests[id]
    if p and p.to == toSrc and p.expiresAt >= os.time() then return id, p end
    return nil, nil
end

local function tradePayload(trade, src)
    local other = trade.a == src and trade.b or trade.a
    local myUid = trade.a == src and trade.aUid or trade.bUid
    local myOffer = trade.offers[src] or { vehicleIds = {}, vehicles = {}, money = 0 }
    local otherOffer = trade.offers[other] or { vehicleIds = {}, vehicles = {}, money = 0 }
    return {
        sessionId = trade.id,
        target = { serverId = other, uid = (trade.a == src and trade.bUid or trade.aUid), name = getPlayerNameSafe(other) },
        myVehicles = getVehicles(myUid),
        myOffer = myOffer,
        otherOffer = otherOffer,
        myConfirmed = trade.confirmed[src] == true,
        otherConfirmed = trade.confirmed[other] == true
    }
end

local function broadcastTrade(trade)
    if not trade then return end
    if playerOnline(trade.a) then TriggerClientEvent('driftzone_playerinteract:client:tradeUpdate', trade.a, tradePayload(trade, trade.a)) end
    if playerOnline(trade.b) then TriggerClientEvent('driftzone_playerinteract:client:tradeUpdate', trade.b, tradePayload(trade, trade.b)) end
end

local function clearActiveTrade(trade, message)
    if not trade then return end
    TradesById[trade.id] = nil
    if ActiveTradeByPlayer[trade.a] == trade.id then ActiveTradeByPlayer[trade.a] = nil end
    if ActiveTradeByPlayer[trade.b] == trade.id then ActiveTradeByPlayer[trade.b] = nil end
    if message and playerOnline(trade.a) then TriggerClientEvent('driftzone_playerinteract:client:tradeClose', trade.a, message) end
    if message and playerOnline(trade.b) then TriggerClientEvent('driftzone_playerinteract:client:tradeClose', trade.b, message) end
end

local function getOfferUid(trade, src)
    if trade.a == src then return trade.aUid end
    if trade.b == src then return trade.bUid end
    return nil
end

local function startTradeSession(a, b)
    local aUid = getUid(a)
    local bUid = getUid(b)
    if not aUid or not bUid then notify(a, 'warning', 'Nu am gasit UID-ul.'); notify(b, 'warning', 'Nu am gasit UID-ul.'); return end
    local id = newTradeId()
    local trade = {
        id = id,
        a = a,
        b = b,
        aUid = aUid,
        bUid = bUid,
        from = a,
        to = b,
        fromUid = aUid,
        toUid = bUid,
        fromName = getPlayerNameSafe(a),
        toName = getPlayerNameSafe(b),
        offers = {},
        confirmed = {},
        createdAt = os.time(),
        processing = false
    }
    trade.offers[a] = { vehicleIds = {}, vehicles = {}, money = 0 }
    trade.offers[b] = { vehicleIds = {}, vehicles = {}, money = 0 }
    TradesById[id] = trade
    ActiveTradeByPlayer[a] = id
    ActiveTradeByPlayer[b] = id
    notify(a, 'success', 'Trade acceptat.', 4500)
    notify(b, 'success', 'Trade acceptat.', 4500)
    TriggerClientEvent('driftzone_playerinteract:client:tradeOpen', a, tradePayload(trade, a))
    TriggerClientEvent('driftzone_playerinteract:client:tradeOpen', b, tradePayload(trade, b))
end

RegisterNetEvent('driftzone_playerinteract:server:requestTrade', function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0
    if not playerOnline(targetServerId) or targetServerId == src then notify(src, 'warning', 'Jucator invalid.'); return end
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.'); return end
    if ActiveTradeByPlayer[src] then notify(src, 'warning', 'Ai deja un trade activ.'); return end
    if ActiveTradeByPlayer[targetServerId] then notify(src, 'warning', 'Playerul are deja un trade activ.'); return end
    if PendingByPlayer[src] then notify(src, 'warning', 'Ai deja o cerere de trade activa.'); return end
    if not validDistance(src, targetServerId, 3.0) then notify(src, 'warning', 'Jucatorul este prea departe.'); return end

    local reverseId, reverse = findPending(targetServerId, src)
    if reverse then
        removePending(reverseId)
        startTradeSession(targetServerId, src)
        return
    end

    local fromUid = getUid(src)
    local toUid = getUid(targetServerId)
    if not fromUid or not toUid then notify(src, 'warning', 'Nu am gasit UID-ul.'); return end

    local id = newTradeId()
    local timeout = tonumber(Config.Trade and Config.Trade.timeoutSeconds or 30) or 30
    PendingRequests[id] = { id = id, from = src, to = targetServerId, fromUid = fromUid, toUid = toUid, createdAt = os.time(), expiresAt = os.time() + timeout }
    PendingByPlayer[src] = id
    logTradeRequest(PendingRequests[id], false, 'request_sent')

    notify(src, 'success', 'Cerere trimisa cu succes.', 4500)
    notify(targetServerId, 'info', 'Ai primit o cerere de trade!', 6500)
    TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = true, close = true, message = 'Cerere trimisa cu succes.' })

    SetTimeout(timeout * 1000, function()
        local p = PendingRequests[id]
        if p and p.expiresAt <= os.time() then
            logTradeRequest(p, false, 'request_expired')
            removePending(id)
            if playerOnline(p.from) then notify(p.from, 'warning', 'Cererea de trade a expirat!', 6000) end
        end
    end)
end)

local function applyOfferUpdate(trade, src, data, silent)
    if not trade or (trade.a ~= src and trade.b ~= src) then return false end
    if trade.processing then return false end
    data = type(data) == 'table' and data or {}

    local vehicleIds = normalizeVehicleIds(data.vehicleIds or data.vehicleId)
    local moneyAmount = math.floor(tonumber(data.money or 0) or 0)
    local maxMoney = tonumber(Config.Trade and Config.Trade.maxMoney or 500000000) or 500000000
    if moneyAmount < 0 or moneyAmount > maxMoney then
        if not silent then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Suma cash invalida.' }) end
        return false
    end

    local ownerUid = getOfferUid(trade, src)
    local vehicles, validIds = getVehiclesByIds(vehicleIds, ownerUid)
    if not vehicles then
        if not silent then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Una dintre masinile alese nu iti apartine.' }) end
        return false
    end
    if moneyAmount > 0 and getCash(ownerUid) < moneyAmount then
        if not silent then TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Nu ai destui bani.' }) end
        return false
    end

    local newOffer = { vehicleIds = validIds, vehicles = vehicles, money = moneyAmount }
    local oldOffer = trade.offers[src] or { vehicleIds = {}, vehicles = {}, money = 0 }
    local changed = not sameOffer(oldOffer, newOffer)
    trade.offers[src] = newOffer
    if changed then
        trade.confirmed[trade.a] = false
        trade.confirmed[trade.b] = false
    end
    return true, changed
end

RegisterNetEvent('driftzone_playerinteract:server:updateTradeOffer', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local sessionId = tostring(data.sessionId or ActiveTradeByPlayer[src] or '')
    local trade = TradesById[sessionId]
    if not trade or (trade.a ~= src and trade.b ~= src) then return end
    local ok = applyOfferUpdate(trade, src, data, false)
    if ok then broadcastTrade(trade) end
end)

local function finalizeTrade(trade)
    if not trade or trade.processing then return end
    trade.processing = true
    local aOffer = trade.offers[trade.a] or { vehicleIds = {}, vehicles = {}, money = 0 }
    local bOffer = trade.offers[trade.b] or { vehicleIds = {}, vehicles = {}, money = 0 }
    local aVehicleIds = normalizeVehicleIds(aOffer.vehicleIds or aOffer.vehicleId)
    local bVehicleIds = normalizeVehicleIds(bOffer.vehicleIds or bOffer.vehicleId)
    local aMoney = tonumber(aOffer.money or 0) or 0
    local bMoney = tonumber(bOffer.money or 0) or 0

    trade.fromOffer = aOffer
    trade.toOffer = bOffer
    trade.fromUid = trade.aUid
    trade.toUid = trade.bUid
    trade.fromName = getPlayerNameSafe(trade.a)
    trade.toName = getPlayerNameSafe(trade.b)

    if #aVehicleIds <= 0 and #bVehicleIds <= 0 and aMoney <= 0 and bMoney <= 0 then
        trade.processing = false
        trade.confirmed[trade.a] = false
        trade.confirmed[trade.b] = false
        TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', trade.a, { ok = false, myConfirmed = false, otherConfirmed = false, message = 'Macar o persoana trebuie sa ofere ceva.' })
        TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', trade.b, { ok = false, myConfirmed = false, otherConfirmed = false, message = 'Macar o persoana trebuie sa ofere ceva.' })
        broadcastTrade(trade)
        return
    end
    if not playerOnline(trade.a) or not playerOnline(trade.b) then logTrade(trade, false, 'player_offline'); clearActiveTrade(trade, 'Trade anulat: player offline.'); return end
    if not validDistance(trade.a, trade.b, 4.0) then logTrade(trade, false, 'distance'); clearActiveTrade(trade, 'Trade anulat: sunteti prea departe.'); return end

    for _, id in ipairs(aVehicleIds) do
        if not getVehicleById(id, trade.aUid) then logTrade(trade, false, 'a_vehicle_missing'); clearActiveTrade(trade, 'Trade anulat: o masina de la tine nu mai exista.'); return end
    end
    for _, id in ipairs(bVehicleIds) do
        if not getVehicleById(id, trade.bUid) then logTrade(trade, false, 'b_vehicle_missing'); clearActiveTrade(trade, 'Trade anulat: o masina de la celalalt nu mai exista.'); return end
    end
    if aMoney > 0 and getCash(trade.aUid) < aMoney then logTrade(trade, false, 'a_no_cash'); clearActiveTrade(trade, 'Trade anulat: unul dintre playeri nu mai are banii.'); return end
    if bMoney > 0 and getCash(trade.bUid) < bMoney then logTrade(trade, false, 'b_no_cash'); clearActiveTrade(trade, 'Trade anulat: unul dintre playeri nu mai are banii.'); return end

    local movedA, movedB = {}, {}
    local moved = {}
    if aMoney > 0 then
        if not addCash(trade.aUid, -aMoney) then logTrade(trade, false, 'take_a_cash'); clearActiveTrade(trade, 'Trade esuat: cash.'); return end
        moved.aCash = true
    end
    if bMoney > 0 then
        if not addCash(trade.bUid, -bMoney) then if moved.aCash then addCash(trade.aUid, aMoney) end; logTrade(trade, false, 'take_b_cash'); clearActiveTrade(trade, 'Trade esuat: cash.'); return end
        moved.bCash = true
    end

    for _, id in ipairs(aVehicleIds) do
        if transferVehicle(id, trade.aUid, trade.bUid) then movedA[#movedA + 1] = id else
            for _, mid in ipairs(movedA) do transferVehicle(mid, trade.bUid, trade.aUid) end
            if moved.aCash then addCash(trade.aUid, aMoney) end
            if moved.bCash then addCash(trade.bUid, bMoney) end
            logTrade(trade, false, 'move_a_vehicle')
            clearActiveTrade(trade, 'Trade esuat: masina nu a putut fi transferata.')
            return
        end
    end
    for _, id in ipairs(bVehicleIds) do
        if transferVehicle(id, trade.bUid, trade.aUid) then movedB[#movedB + 1] = id else
            for _, mid in ipairs(movedB) do transferVehicle(mid, trade.aUid, trade.bUid) end
            for _, mid in ipairs(movedA) do transferVehicle(mid, trade.bUid, trade.aUid) end
            if moved.aCash then addCash(trade.aUid, aMoney) end
            if moved.bCash then addCash(trade.bUid, bMoney) end
            logTrade(trade, false, 'move_b_vehicle')
            clearActiveTrade(trade, 'Trade esuat: masina nu a putut fi transferata.')
            return
        end
    end

    if aMoney > 0 then addCash(trade.bUid, aMoney) end
    if bMoney > 0 then addCash(trade.aUid, bMoney) end

    logTrade(trade, true, 'confirmed')
    notify(trade.a, 'success', 'Trade finalizat cu succes.', 6000)
    notify(trade.b, 'success', 'Trade finalizat cu succes.', 6000)
    clearActiveTrade(trade, 'Trade finalizat cu succes.')
end


local function offerHasSomething(offer)
    offer = offer or {}
    local ids = normalizeVehicleIds(offer.vehicleIds or offer.vehicleId)
    local money = tonumber(offer.money or 0) or 0
    return #ids > 0 or money > 0
end

RegisterNetEvent('driftzone_playerinteract:server:confirmTrade', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local sessionId = tostring(data.sessionId or ActiveTradeByPlayer[src] or '')
    local trade = TradesById[sessionId]
    if not trade or (trade.a ~= src and trade.b ~= src) then return end
    if trade.processing then return end

    local ok = applyOfferUpdate(trade, src, data, false)
    if not ok then return end

    local aOfferNow = trade.offers[trade.a] or { vehicleIds = {}, vehicles = {}, money = 0 }
    local bOfferNow = trade.offers[trade.b] or { vehicleIds = {}, vehicles = {}, money = 0 }
    if not offerHasSomething(aOfferNow) and not offerHasSomething(bOfferNow) then
        TriggerClientEvent('driftzone_playerinteract:client:tradeStatus', src, { ok = false, message = 'Nu poti confirma un trade gol.' })
        return
    end

    trade.confirmed[src] = true
    broadcastTrade(trade)
    if trade.confirmed[trade.a] == true and trade.confirmed[trade.b] == true then
        finalizeTrade(trade)
    end
end)

RegisterNetEvent('driftzone_playerinteract:server:cancelTrade', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local id = tostring(data.requestId or ActiveTradeByPlayer[src] or PendingByPlayer[src] or '')
    local active = TradesById[id]
    if active and (active.a == src or active.b == src) then logTrade(active, false, 'cancelled'); clearActiveTrade(active, 'Trade anulat.'); return end
    local p = PendingRequests[id]
    if p and p.from == src then logTradeRequest(p, false, 'request_cancelled'); removePending(id); notify(src, 'warning', 'Cerere trade anulata.', 3500) end
end)



-- =========================================================
-- DRIFTZONE BARBUT - player interact dice duel
-- =========================================================
local BarbutPending = {}
local BarbutPendingByFrom = {}
local BarbutSessions = {}
local ActiveBarbutByPlayer = {}
local NextBarbutId = 0
local BarbutReadyCooldowns = {}

local function getBarbutLogTable()
    return cleanName(Config.BarbutLogsTable or 'barbut_logs')
end

local function newBarbutId(prefix)
    NextBarbutId = NextBarbutId + 1
    return ('DZBB-%s-%s'):format(os.time(), NextBarbutId)
end

local function logBarbut(data)
    local tableName = getBarbutLogTable()
    data = data or {}
    pcall(function()
        MySQL.insert.await(([[
            INSERT INTO `%s`
            (`session_id`, `from_uid`, `from_name`, `to_uid`, `to_name`, `amount`, `winner_uid`, `winner_name`, `tax`, `status`, `reason`, `details`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]]):format(tableName), {
            tostring(data.session_id or data.id or ''),
            tonumber(data.from_uid or 0) or 0,
            tostring(data.from_name or ''),
            tonumber(data.to_uid or 0) or 0,
            tostring(data.to_name or ''),
            tonumber(data.amount or 0) or 0,
            tonumber(data.winner_uid or 0) or 0,
            tostring(data.winner_name or ''),
            tonumber(data.tax or 0) or 0,
            tostring(data.status or ''),
            tostring(data.reason or ''),
            jsonEncode(data.details or {})
        })
    end)
end

local function removeBarbutPending(id, reason)
    local p = BarbutPending[id]
    if not p then return end
    if BarbutPendingByFrom[p.from] == id then BarbutPendingByFrom[p.from] = nil end
    BarbutPending[id] = nil
    if reason then
        logBarbut({
            id = id,
            from_uid = p.fromUid,
            from_name = p.fromName,
            to_uid = p.toUid,
            to_name = p.toName,
            amount = p.amount,
            status = 'request',
            reason = reason,
            details = p
        })
    end
end

local function findBarbutPending(fromSrc, toSrc)
    local id = BarbutPendingByFrom[fromSrc]
    local p = id and BarbutPending[id]
    if p and p.to == toSrc and p.expiresAt >= os.time() then return id, p end
    return nil, nil
end

local function barbutPayload(session, src)
    local other = session.a == src and session.b or session.a
    local myDice = session.dice[src] or { 1, 1 }
    local otherDice = session.dice[other] or { 1, 1 }
    return {
        sessionId = session.id,
        amount = session.amount,
        taxPercent = session.taxPercent,
        phase = session.phase,
        me = { serverId = src, uid = session.uids[src], name = getPlayerNameSafe(src) },
        other = { serverId = other, uid = session.uids[other], name = getPlayerNameSafe(other) },
        myReady = session.ready[src] == true,
        otherReady = session.ready[other] == true,
        myRetry = session.retry[src] == true,
        otherRetry = session.retry[other] == true,
        myDice = myDice,
        otherDice = otherDice,
        myTotal = (tonumber(myDice[1] or 0) or 0) + (tonumber(myDice[2] or 0) or 0),
        otherTotal = (tonumber(otherDice[1] or 0) or 0) + (tonumber(otherDice[2] or 0) or 0),
        myScoreLabel = session.scoreLabels and session.scoreLabels[src] or '',
        otherScoreLabel = session.scoreLabels and session.scoreLabels[other] or '',
        resultText = session.resultText or '',
        closeLocked = session.closeLocked == true
    }
end

local function broadcastBarbut(session, eventName)
    if not session then return end
    eventName = eventName or 'driftzone_playerinteract:client:barbutUpdate'
    if playerOnline(session.a) then TriggerClientEvent(eventName, session.a, barbutPayload(session, session.a)) end
    if playerOnline(session.b) then TriggerClientEvent(eventName, session.b, barbutPayload(session, session.b)) end
end

local refundBarbutStake = nil

local function closeBarbut(session, message, statusReason)
    if not session then return end
    refundBarbutStake(session, statusReason or 'closed')
    BarbutSessions[session.id] = nil
    if session.a then ActiveBarbutByPlayer[session.a] = nil end
    if session.b then ActiveBarbutByPlayer[session.b] = nil end
    if statusReason then
        logBarbut({
            id = session.id,
            from_uid = session.uids and session.uids[session.a] or 0,
            from_name = session.a and getPlayerNameSafe(session.a) or '',
            to_uid = session.uids and session.uids[session.b] or 0,
            to_name = session.b and getPlayerNameSafe(session.b) or '',
            amount = session.amount,
            status = 'closed',
            reason = statusReason,
            details = session
        })
    end
    if message and playerOnline(session.a) then TriggerClientEvent('driftzone_playerinteract:client:barbutClose', session.a, message) end
    if message and playerOnline(session.b) then TriggerClientEvent('driftzone_playerinteract:client:barbutClose', session.b, message) end
end

local function createBarbutSession(req)
    if not req then return end
    local a = req.from
    local b = req.to
    local aUid = req.fromUid
    local bUid = req.toUid
    if not playerOnline(a) or not playerOnline(b) then return end
    if ActiveBarbutByPlayer[a] or ActiveBarbutByPlayer[b] then
        notify(a, 'warning', 'Unul dintre voi este deja intr-o partida de barbut.', 4500)
        notify(b, 'warning', 'Unul dintre voi este deja intr-o partida de barbut.', 4500)
        return
    end
    if getCash(aUid) < req.amount or getCash(bUid) < req.amount then
        notify(a, 'warning', 'Unul dintre jucatori nu mai are suma necesara.', 4500)
        notify(b, 'warning', 'Unul dintre jucatori nu mai are suma necesara.', 4500)
        return
    end
    local id = newBarbutId()
    local session = {
        id = id,
        a = a,
        b = b,
        uids = { [a] = aUid, [b] = bUid },
        amount = req.amount,
        taxPercent = tonumber(Config.Barbut and Config.Barbut.taxPercent or 10) or 10,
        phase = 'ready',
        ready = { [a] = false, [b] = false },
        retry = { [a] = false, [b] = false },
        dice = { [a] = { 1, 1 }, [b] = { 1, 1 } },
        resultText = '',
        round = 0,
        createdAt = os.time()
    }
    BarbutSessions[id] = session
    ActiveBarbutByPlayer[a] = id
    ActiveBarbutByPlayer[b] = id
    logBarbut({
        id = id,
        from_uid = aUid,
        from_name = getPlayerNameSafe(a),
        to_uid = bUid,
        to_name = getPlayerNameSafe(b),
        amount = req.amount,
        status = 'started',
        reason = 'accepted',
        details = { request = req }
    })
    broadcastBarbut(session, 'driftzone_playerinteract:client:barbutOpen')
end

local function barbutScore(dice)
    local d1 = tonumber(dice and dice[1] or 0) or 0
    local d2 = tonumber(dice and dice[2] or 0) or 0

    -- Regula DriftZone: 1 + 1 este cea mai mare combinatie posibila.
    if d1 == 1 and d2 == 1 then
        return 99, '1-1'
    end

    return d1 + d2, tostring(d1 + d2)
end

refundBarbutStake = function(session, reason)
    if not session or session.stakeResolved ~= false then return end
    local aUid = session.uids and session.uids[session.a]
    local bUid = session.uids and session.uids[session.b]
    local amount = tonumber(session.amount or 0) or 0
    if amount <= 0 then return end

    if aUid then addCash(aUid, amount) end
    if bUid then addCash(bUid, amount) end
    session.stakeResolved = true
    session.refundReason = tostring(reason or 'refund')
end

local function rollBarbut(session)
    if not session or session.processing then return end
    session.processing = true
    session.closeLocked = true
    session.phase = 'rolling'
    session.round = (tonumber(session.round or 0) or 0) + 1
    local currentRound = session.round

    local aUid = session.uids[session.a]
    local bUid = session.uids[session.b]
    local amount = tonumber(session.amount or 0) or 0
    if getCash(aUid) < amount or getCash(bUid) < amount then
        session.processing = false
        session.closeLocked = false
        closeBarbut(session, 'Partida de barbut anulata: unul dintre jucatori nu mai are banii.', 'no_cash')
        return
    end

    -- Banii sunt blocati imediat cand ambii jucatori au apasat READY.
    if not addCash(aUid, -amount) then session.processing = false; session.closeLocked = false; closeBarbut(session, 'Partida anulata: cash indisponibil.', 'take_a_failed'); return end
    if not addCash(bUid, -amount) then addCash(aUid, amount); session.processing = false; session.closeLocked = false; closeBarbut(session, 'Partida anulata: cash indisponibil.', 'take_b_failed'); return end
    session.stakeResolved = false

    local aDice = { math.random(1, 6), math.random(1, 6) }
    local bDice = { math.random(1, 6), math.random(1, 6) }
    session.dice[session.a] = aDice
    session.dice[session.b] = bDice
    local aTotal = aDice[1] + aDice[2]
    local bTotal = bDice[1] + bDice[2]
    local aScore, aScoreLabel = barbutScore(aDice)
    local bScore, bScoreLabel = barbutScore(bDice)

    session.scoreLabels = { [session.a] = aScoreLabel, [session.b] = bScoreLabel }

    local resultDelay = tonumber(Config.Barbut.resultNotifyDelayMs or 4300) or 4300

    if aScore == bScore then
        session.phase = 'finished'
        session.resultText = 'EGALITATE'
        session.processing = false
        session.ready[session.a] = false
        session.ready[session.b] = false
        session.retry[session.a] = false
        session.retry[session.b] = false
        logBarbut({ id = session.id, from_uid = aUid, from_name = getPlayerNameSafe(session.a), to_uid = bUid, to_name = getPlayerNameSafe(session.b), amount = amount, status = 'draw', reason = 'same_total', details = session })
        broadcastBarbut(session, 'driftzone_playerinteract:client:barbutRoll')
        SetTimeout(resultDelay, function()
            local active = BarbutSessions[session.id]
            if not active or active.round ~= currentRound then return end
            refundBarbutStake(active, 'draw')
            active.closeLocked = false
            broadcastBarbut(active)
            if playerOnline(active.a) then notify(active.a, 'info', ('Egalitate la barbut. Suma $%s a fost returnata.'):format(amount), 5500) end
            if playerOnline(active.b) then notify(active.b, 'info', ('Egalitate la barbut. Suma $%s a fost returnata.'):format(amount), 5500) end
        end)
        return
    end

    local winner = aScore > bScore and session.a or session.b
    local loser = winner == session.a and session.b or session.a
    local winnerUid = session.uids[winner]
    local loserUid = session.uids[loser]
    local pot = amount * 2
    local tax = math.floor(pot * ((tonumber(session.taxPercent or 10) or 10) / 100))
    local payout = pot - tax

    session.phase = 'finished'
    session.resultText = ('CASTIGATOR: %s'):format(getPlayerNameSafe(winner))
    session.processing = false
    session.ready[session.a] = false
    session.ready[session.b] = false
    session.retry[session.a] = false
    session.retry[session.b] = false
    session.pendingPayout = { winner = winner, loser = loser, winnerUid = winnerUid, loserUid = loserUid, amount = amount, payout = payout, tax = tax }

    logBarbut({
        id = session.id,
        from_uid = aUid,
        from_name = getPlayerNameSafe(session.a),
        to_uid = bUid,
        to_name = getPlayerNameSafe(session.b),
        amount = amount,
        winner_uid = winnerUid,
        winner_name = getPlayerNameSafe(winner),
        tax = tax,
        status = 'finished',
        reason = 'winner_pending_payout',
        details = { aDice = aDice, bDice = bDice, aTotal = aTotal, bTotal = bTotal, aScore = aScore, bScore = bScore, payout = payout, loserUid = loserUid }
    })

    broadcastBarbut(session, 'driftzone_playerinteract:client:barbutRoll')

    -- Payout-ul si notificarile apar doar dupa ce UI-ul a afisat numerele finale.
    SetTimeout(resultDelay, function()
        local active = BarbutSessions[session.id]
        if not active or active.round ~= currentRound or active.phase ~= 'finished' then return end
        local pending = active.pendingPayout
        if not pending or active.stakeResolved ~= false then return end

        if not addCash(pending.winnerUid, pending.payout) then
            refundBarbutStake(active, 'payout_failed')
            active.closeLocked = false
            broadcastBarbut(active)
            if playerOnline(active.a) then notify(active.a, 'warning', 'Payout esuat. Banii au fost returnati.', 6000) end
            if playerOnline(active.b) then notify(active.b, 'warning', 'Payout esuat. Banii au fost returnati.', 6000) end
            return
        end

        active.stakeResolved = true
        active.closeLocked = false
        active.pendingPayout = nil
        broadcastBarbut(active)

        if playerOnline(pending.winner) then notify(pending.winner, 'success', ('Ai castigat la barbut $%s.'):format(pending.payout), 6000) end
        if playerOnline(pending.loser) then notify(pending.loser, 'warning', ('Ai pierdut la barbut $%s.'):format(pending.amount), 6000) end
    end)
end

RegisterNetEvent('driftzone_playerinteract:server:openBarbut', function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0
    if not Config.Barbut or Config.Barbut.enabled ~= true then notify(src, 'warning', 'Barbut este dezactivat.', 4000); return end
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.', 4000); return end
    if not playerOnline(targetServerId) or targetServerId == src then notify(src, 'warning', 'Jucator invalid.', 4000); return end
    if not validDistance(src, targetServerId, 2.0) then notify(src, 'warning', 'Jucatorul este prea departe.', 4000); return end

    local pendingId, pending = findBarbutPending(targetServerId, src)
    if pending then
        removeBarbutPending(pendingId, nil)
        createBarbutSession(pending)
        return
    end

    TriggerClientEvent('driftzone_playerinteract:client:barbutInviteMenu', src, {
        target = { serverId = targetServerId, uid = getUid(targetServerId) or targetServerId, name = getPlayerNameSafe(targetServerId) },
        maxBet = 0
    })
end)

RegisterNetEvent('driftzone_playerinteract:server:barbutInvite', function(targetServerId, amount)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0
    amount = math.floor(tonumber(amount or 0) or 0)
    if not Config.Barbut or Config.Barbut.enabled ~= true then return end
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.', 4000); return end
    if not playerOnline(targetServerId) or targetServerId == src then notify(src, 'warning', 'Jucator invalid.', 4000); return end
    if ActiveBarbutByPlayer[src] or ActiveBarbutByPlayer[targetServerId] then notify(src, 'warning', 'Unul dintre voi este deja intr-o partida.', 4000); return end
    if not validDistance(src, targetServerId, 2.0) then notify(src, 'warning', 'Jucatorul este prea departe.', 4000); return end
    local minBet = tonumber(Config.Barbut.minBet or 1) or 1
    if amount < minBet then notify(src, 'warning', ('Suma minima este $%s.'):format(minBet), 4500); return end
    local srcUid = getUid(src)
    local targetUid = getUid(targetServerId)
    if not srcUid or not targetUid then notify(src, 'warning', 'Nu am gasit UID-ul jucatorilor.', 4000); return end
    if getCash(srcUid) < amount then notify(src, 'warning', 'Nu ai destui bani pentru aceasta partida.', 4500); return end
    if getCash(targetUid) < amount then notify(src, 'warning', 'Jucatorul selectat nu are destui bani pentru aceasta partida.', 4500); return end

    local old = BarbutPendingByFrom[src]
    if old then removeBarbutPending(old, 'replaced') end
    local id = newBarbutId()
    local req = {
        id = id,
        from = src,
        to = targetServerId,
        fromUid = srcUid,
        toUid = targetUid,
        fromName = getPlayerNameSafe(src),
        toName = getPlayerNameSafe(targetServerId),
        amount = amount,
        createdAt = os.time(),
        expiresAt = os.time() + (tonumber(Config.Barbut.timeoutSeconds or 30) or 30)
    }
    BarbutPending[id] = req
    BarbutPendingByFrom[src] = id
    notify(src, 'success', 'Invitatie barbut trimisa cu succes.', 4000)
    TriggerClientEvent('driftzone_playerinteract:client:barbutClose', src, 'Invitatie barbut trimisa.')
    notify(targetServerId, 'info', ('Ai fost invitat la o partida de barbut pe suma de $%s. Selecteaza playerul si apasa BARBUT ca sa accepti.'):format(amount), 9000)
    logBarbut({ id = id, from_uid = srcUid, from_name = req.fromName, to_uid = targetUid, to_name = req.toName, amount = amount, status = 'request', reason = 'sent', details = req })

    SetTimeout((tonumber(Config.Barbut.timeoutSeconds or 30) or 30) * 1000, function()
        local p = BarbutPending[id]
        if p then
            local target = p.to
            removeBarbutPending(id, 'expired')
            if playerOnline(src) then notify(src, 'warning', 'Invitatia de barbut a expirat.', 4500) end
            if playerOnline(target) then notify(target, 'warning', 'Invitatia de barbut a expirat.', 4500) end
        end
    end)
end)

RegisterNetEvent('driftzone_playerinteract:server:barbutReady', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local id = tostring(data.sessionId or ActiveBarbutByPlayer[src] or '')
    local session = BarbutSessions[id]
    if not session or (session.a ~= src and session.b ~= src) then return end
    if session.phase ~= 'ready' and session.phase ~= 'finished' then return end

    local now = GetGameTimer()
    local cd = BarbutReadyCooldowns[src] or 0
    if cd > now then return end
    BarbutReadyCooldowns[src] = now + (tonumber(Config.Barbut.readyCooldownMs or 1200) or 1200)

    local amount = tonumber(session.amount or 0) or 0
    local aUid = session.uids[session.a]
    local bUid = session.uids[session.b]

    if getCash(aUid) < amount or getCash(bUid) < amount then
        notify(src, 'warning', 'Nu se poate porni runda: unul dintre jucatori nu are suma necesara.', 4500)
        broadcastBarbut(session)
        return
    end

    session.ready[src] = true

    if session.ready[session.a] == true and session.ready[session.b] == true then
        if getCash(aUid) < amount or getCash(bUid) < amount then
            session.ready[session.a] = false
            session.ready[session.b] = false
            session.resultText = 'CASH INSUFICIENT'
            notify(session.a, 'warning', 'Runda anulata: unul dintre jucatori nu are suma necesara.', 4500)
            notify(session.b, 'warning', 'Runda anulata: unul dintre jucatori nu are suma necesara.', 4500)
            broadcastBarbut(session)
            return
        end

        -- READY dupa final inseamna runda noua, fara buton separat de retry.
        session.phase = 'ready'
        session.resultText = ''
        session.scoreLabels = nil
        session.dice[session.a] = { 1, 1 }
        session.dice[session.b] = { 1, 1 }
        session.retry[session.a] = false
        session.retry[session.b] = false
        rollBarbut(session)
        return
    end

    broadcastBarbut(session)
end)

RegisterNetEvent('driftzone_playerinteract:server:barbutRetry', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local id = tostring(data.sessionId or ActiveBarbutByPlayer[src] or '')
    local session = BarbutSessions[id]
    if not session or (session.a ~= src and session.b ~= src) then return end
    if session.phase ~= 'finished' then return end
    local amount = tonumber(session.amount or 0) or 0
    local aUid = session.uids[session.a]
    local bUid = session.uids[session.b]

    if getCash(aUid) < amount or getCash(bUid) < amount then
        notify(src, 'warning', 'Retry indisponibil: unul dintre jucatori nu are suma necesara.', 4500)
        broadcastBarbut(session)
        return
    end

    session.retry[src] = true
    session.resultText = session.retry[session.a] and session.retry[session.b] and 'READY UP' or 'WAITING RETRY'
    if session.retry[session.a] == true and session.retry[session.b] == true then
        if getCash(aUid) < amount or getCash(bUid) < amount then
            session.retry[session.a] = false
            session.retry[session.b] = false
            session.resultText = 'RETRY ANULAT - CASH INSUFICIENT'
            notify(session.a, 'warning', 'Retry anulat: unul dintre jucatori nu are suma necesara.', 4500)
            notify(session.b, 'warning', 'Retry anulat: unul dintre jucatori nu are suma necesara.', 4500)
            broadcastBarbut(session)
            return
        end

        session.phase = 'ready'
        session.ready[session.a] = false
        session.ready[session.b] = false
        session.retry[session.a] = false
        session.retry[session.b] = false
        session.dice[session.a] = { 1, 1 }
        session.dice[session.b] = { 1, 1 }
        session.scoreLabels = nil
        session.resultText = ''
    end
    broadcastBarbut(session)
end)

RegisterNetEvent('driftzone_playerinteract:server:barbutClose', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local id = tostring(data.sessionId or ActiveBarbutByPlayer[src] or '')
    local session = BarbutSessions[id]
    if session and (session.a == src or session.b == src) then
        if session.closeLocked == true or session.phase == 'rolling' then
            notify(src, 'warning', 'Nu poti inchide cat timp runda este in desfasurare.', 3500)
            return
        end
        closeBarbut(session, 'Partida de barbut a fost inchisa.', 'closed_by_player')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    PayCooldowns[src] = nil
    BarbutReadyCooldowns[src] = nil
    local bp = BarbutPendingByFrom[src]
    if bp then removeBarbutPending(bp, 'player_dropped') end
    for bid, bpdata in pairs(BarbutPending) do
        if bpdata.to == src then removeBarbutPending(bid, 'player_dropped') end
    end
    local bsid = ActiveBarbutByPlayer[src]
    if bsid and BarbutSessions[bsid] then closeBarbut(BarbutSessions[bsid], 'Partida de barbut anulata: player deconectat.', 'player_dropped') end
    local pendingId = PendingByPlayer[src]
    if pendingId then removePending(pendingId) end
    for id, p in pairs(PendingRequests) do
        if p.to == src then removePending(id) end
    end
    local activeId = ActiveTradeByPlayer[src]
    if activeId and TradesById[activeId] then
        local trade = TradesById[activeId]
        logTrade(trade, false, 'player_dropped')
        clearActiveTrade(trade, 'Trade anulat: player deconectat.')
    end
end)
