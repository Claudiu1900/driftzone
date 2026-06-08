local PayCooldowns = {}

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
    if not ok then
        print('[DRIFTZONE_PLAYERINTERACT] setCash failed: ' .. tostring(err))
    end
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
            fromUid,
            getPlayerNameSafe(src),
            toUid,
            getPlayerNameSafe(target),
            amount,
            coords.x,
            coords.y,
            coords.z
        })
    end)
    if not ok then
        print('[DRIFTZONE_PLAYERINTERACT] pay log failed: ' .. tostring(err))
    end
end

RegisterNetEvent('driftzone_playerinteract:server:requestTargetInfo', function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0

    if not playerOnline(targetServerId) or targetServerId == src then
        TriggerClientEvent('driftzone_playerinteract:client:targetInfo', src, false, 'Jucator invalid.')
        return
    end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetServerId)
    if not srcPed or srcPed == 0 or not targetPed or targetPed == 0 then
        TriggerClientEvent('driftzone_playerinteract:client:targetInfo', src, false, 'Jucator invalid.')
        return
    end

    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > (Config.MaxSelectDistance or 6.0) + 1.5 then
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

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetServerId)
    if not srcPed or srcPed == 0 or not targetPed or targetPed == 0 then
        TriggerClientEvent('driftzone_playerinteract:client:payResult', src, false, 'Jucator invalid.')
        return
    end

    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > (Config.MaxSelectDistance or 6.0) + 2.0 then
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

AddEventHandler('playerDropped', function()
    PayCooldowns[source] = nil
end)
