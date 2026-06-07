local ActiveSolo = {}
local ActiveDuoByPlayer = {}
local DuoInvites = {}
local DuoSessions = {}
local Cooldowns = {}
local SessionCounter = 1000

local function debugPrint(...)
    if Config.Debug then print('[DRIFTZONE_RACEJOB]', ...) end
end

local function notify(src, notifyType, message, duration)
    TriggerClientEvent((Config.Notify and Config.Notify.event) or 'client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function cleanName(value)
    return tostring(value or ''):gsub('`', '')
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local getUid

local function playerExists(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return false end

    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) == src then
            return true
        end
    end

    return false
end

local function resolvePlayerByUid(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return nil end

    -- Duo Race foloseste DOAR UID-ul din users.uid, nu server ID.
    -- Cautam printre jucatorii online si comparam cu UID-ul real din auth/state.
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local playerUid = src and getUid(src) or nil
        if playerUid and tonumber(playerUid) == uid then
            return src
        end
    end

    return nil
end

local function inviteResult(src, ok, message)
    TriggerClientEvent('driftzone_racejob:client:duoInviteResult', src, {
        ok = ok == true,
        message = tostring(message or '')
    })
end

local function failInvite(src, message)
    notify(src, 'warning', message, 4000)
    inviteResult(src, false, message)
end

function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    local state = Player(src).state
    if state then
        local keys = { 'dz_uid', 'uid', 'user_id', 'userId' }
        for i = 1, #keys do
            local value = tonumber(state[keys[i]])
            if value and value > 0 then return value end
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

    for i = 1, #attempts do
        local ok, uid = pcall(attempts[i])
        uid = tonumber(uid)
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
    for i = 1, #attempts do
        local ok, res = pcall(attempts[i])
        if ok and res == true then return true end
    end
    return getUid(src) ~= nil
end

local function getAdminLevel(src)
    local uid = getUid(src)
    if not uid then return 0 end
    local usersTable = cleanName(Config.UsersTable or 'users')
    local uidCol = cleanName(Config.UsersIdColumn or 'uid')
    for _, adminColRaw in ipairs(Config.AdminColumns or { 'admin_level' }) do
        local adminCol = cleanName(adminColRaw)
        local ok, row = pcall(function()
            return MySQL.single.await(('SELECT `%s` AS admin_level FROM `%s` WHERE `%s` = ? LIMIT 1'):format(adminCol, usersTable, uidCol), { uid })
        end)
        if ok and row and tonumber(row.admin_level) then return tonumber(row.admin_level) or 0 end
    end
    return 0
end

local function vecToTable(v)
    if type(v) ~= 'vector3' and type(v) ~= 'vector4' then return v end
    return { x = v.x, y = v.y, z = v.z, h = v.w }
end

local function getRace(raceId)
    raceId = tostring(raceId or '')
    return (Config.Races or {})[raceId]
end

local function cooldownKey(uid, raceId)
    return ('racecd:%s:%s'):format(tostring(uid), tostring(raceId))
end

local function getCooldownLeft(uid, raceId)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return 0 end
    local key = tostring(uid) .. ':' .. tostring(raceId)
    local untilTime = tonumber(Cooldowns[key] or 0) or 0
    if untilTime <= 0 then
        untilTime = tonumber(GetResourceKvpString(cooldownKey(uid, raceId)) or 0) or 0
        if untilTime > 0 then Cooldowns[key] = untilTime end
    end
    local left = untilTime - os.time()
    if left <= 0 then
        Cooldowns[key] = 0
        DeleteResourceKvp(cooldownKey(uid, raceId))
        return 0
    end
    return left
end

local function setCooldown(uid, raceId, seconds)
    uid = tonumber(uid or 0) or 0
    seconds = tonumber(seconds or 0) or 0
    if uid <= 0 or seconds <= 0 then return end
    local untilTime = os.time() + seconds
    local key = tostring(uid) .. ':' .. tostring(raceId)
    Cooldowns[key] = untilTime
    SetResourceKvp(cooldownKey(uid, raceId), tostring(untilTime))
end

local function getResultCooldown(race, won)
    race = type(race) == 'table' and race or {}
    if won == true then
        return tonumber(race.winCooldown or race.finishCooldown or race.cooldown or 0) or 0
    end
    return tonumber(race.failCooldown or 0) or 0
end

local function resetCooldownsFor(src, targetUid)
    targetUid = tonumber(targetUid or 0) or 0
    if targetUid <= 0 then return false, 'Foloseste /rracecd <uid>.' end

    for raceId in pairs(Config.Races or {}) do
        local key = tostring(targetUid) .. ':' .. tostring(raceId)
        Cooldowns[key] = 0
        DeleteResourceKvp(cooldownKey(targetUid, raceId))
    end

    local targetSrc = resolvePlayerByUid(targetUid)
    if targetSrc then
        TriggerClientEvent('driftzone_racejob:client:cooldownsReset', targetSrc)
    end

    return true
end

local function cooldownPayload(uid)
    local data = {}
    for raceId in pairs(Config.Races or {}) do
        data[raceId] = getCooldownLeft(uid, raceId)
    end
    return data
end

local function normalizeModel(raw)
    local function pickFromTable(t)
        if type(t) ~= 'table' then return nil end
        local keys = { 'model', 'vehicle_model', 'spawn', 'spawnName', 'hash', 'name', 'vehicle', 'vehicleName' }
        for _, key in ipairs(keys) do
            local v = t[key]
            if v ~= nil and tostring(v) ~= '' then return v end
        end
        for _, v in pairs(t) do
            if type(v) == 'table' then
                local found = pickFromTable(v)
                if found then return found end
            elseif type(v) == 'string' or type(v) == 'number' then
                local text = tostring(v)
                if text ~= '' and text ~= '0' and not text:find('[{}%[%]]') then return text end
            end
        end
        return nil
    end

    if type(raw) == 'table' then
        raw = pickFromTable(raw)
    end

    local text = tostring(raw or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text:sub(1, 1) == '{' or text:sub(1, 1) == '[' then
        local ok, decoded = pcall(json.decode, text)
        if ok and type(decoded) == 'table' then
            local picked = pickFromTable(decoded)
            if picked then text = tostring(picked) end
        end
    end

    text = text:gsub('^"', ''):gsub('"$', ''):gsub('^`', ''):gsub('`$', '')
    return text:gsub('^%s+', ''):gsub('%s+$', '')
end

local function getVehicleRows(uid)
    local t = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanName(Config.OwnedVehicleIdColumn or 'id')
    local ownerCol = cleanName(Config.OwnedVehicleOwnerColumn or 'owner_id')
    local modelCol = cleanName(Config.OwnedVehicleModelColumn or 'vehicle_model')
    local plateCol = cleanName(Config.OwnedVehiclePlateColumn or 'vehicle_plate')
    local tuningCol = cleanName(Config.OwnedVehicleTuningColumn or 'vehicle_tunning')
    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS owner_id, ov.`%s` AS model, ov.`%s` AS plate, ov.`%s` AS tuning,
                   vn.vehicle_name, vn.vehicle_image, vn.image
            FROM `%s` ov
            LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.`%s`
            WHERE ov.`%s` = ?
            ORDER BY ov.`%s` DESC
        ]]):format(idCol, ownerCol, modelCol, plateCol, tuningCol, t, modelCol, ownerCol, idCol), { uid })
    end)
    if not ok then
        print('[DRIFTZONE_RACEJOB] vehicle query failed: ' .. tostring(rows))
        return {}
    end
    return rows or {}
end

local function getPlayerVehicles(uid)
    local list = {}
    for _, row in ipairs(getVehicleRows(uid)) do
        local model = normalizeModel(row.model)
        if model ~= '' then
            list[#list + 1] = {
                id = tonumber(row.id) or 0,
                model = model,
                name = tostring(row.vehicle_name or model),
                plate = tostring(row.plate or 'DRIFT'),
                image = tostring(row.vehicle_image or row.image or '')
            }
        end
    end
    return list
end

local function getVehicleData(uid, vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return nil end
    local t = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanName(Config.OwnedVehicleIdColumn or 'id')
    local ownerCol = cleanName(Config.OwnedVehicleOwnerColumn or 'owner_id')
    local modelCol = cleanName(Config.OwnedVehicleModelColumn or 'vehicle_model')
    local plateCol = cleanName(Config.OwnedVehiclePlateColumn or 'vehicle_plate')
    local tuningCol = cleanName(Config.OwnedVehicleTuningColumn or 'vehicle_tunning')
    local ok, row = pcall(function()
        return MySQL.single.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS owner_id, ov.`%s` AS model, ov.`%s` AS plate, ov.`%s` AS tuning,
                   vn.vehicle_name, vn.vehicle_image, vn.image
            FROM `%s` ov
            LEFT JOIN vehiclenames vn ON vn.vehicle_model = ov.`%s`
            WHERE ov.`%s` = ? AND ov.`%s` = ?
            LIMIT 1
        ]]):format(idCol, ownerCol, modelCol, plateCol, tuningCol, t, modelCol, idCol, ownerCol), { vehicleId, uid })
    end)
    if not ok then
        print('[DRIFTZONE_RACEJOB] getVehicleData failed: ' .. tostring(row))
        return nil
    end
    if not row then return nil end
    local model = normalizeModel(row.model)
    if model == '' then return nil end
    return {
        id = tonumber(row.id) or 0,
        model = model,
        name = tostring(row.vehicle_name or model),
        plate = tostring(row.plate or 'DRIFT'),
        tuning = tostring(row.tuning or '{}'),
        image = tostring(row.vehicle_image or row.image or '')
    }
end

local function getRaceList(uid)
    local list = {}
    local order = { 'short', 'medium', 'long', 'special' }
    for _, id in ipairs(order) do
        local race = getRace(id)
        if race then
            list[#list + 1] = {
                id = race.id or id,
                label = race.label or id,
                subLabel = race.subLabel or '',
                description = race.description or '',
                special = race.special == true,
                rewardMin = race.reward and race.reward.min or 0,
                rewardMax = race.reward and race.reward.max or 0,
                xpMin = race.xp and race.xp.min or 0,
                xpMax = race.xp and race.xp.max or 0,
                timeLimit = race.timeLimit or 0,
                cooldownLeft = getCooldownLeft(uid, id)
            }
        end
    end
    return list
end

local function addStats(uid, cash, xp, addRace)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return false end
    cash = math.max(0, math.floor(tonumber(cash or 0) or 0))
    xp = math.max(0, math.floor(tonumber(xp or 0) or 0))

    local usersTable = cleanName(Config.UsersTable or 'users')
    local uidCol = cleanName(Config.UsersIdColumn or 'uid')
    local cashCol = cleanName(Config.CashColumn or 'cash')
    local racesCol = cleanName(Config.RacesColumn or 'races')
    local xpCol = cleanName(Config.XpColumn or 'xp')

    local function readCash()
        return MySQL.single.await(('SELECT `%s` AS cash_value FROM `%s` WHERE `%s` = ? LIMIT 1'):format(cashCol, usersTable, uidCol), { uid })
    end

    local row = readCash()
    if not row then return false end

    local currentCash = tonumber(row.cash_value or 0) or 0
    local maxCash = tonumber(Config.SafeCashMax or 2147483647) or 2147483647
    local newCash = currentCash + cash
    if newCash > maxCash then newCash = maxCash end
    if newCash < 0 then newCash = 0 end

    local ok, err = pcall(function()
        MySQL.update.await(('UPDATE `%s` SET `%s` = ?, `%s` = COALESCE(`%s`, 0) + ?, `%s` = COALESCE(`%s`, 0) + ? WHERE `%s` = ? LIMIT 1'):format(usersTable, cashCol, racesCol, racesCol, xpCol, xpCol, uidCol), {
            math.floor(newCash), addRace and 1 or 0, xp, uid
        })
    end)

    if not ok then
        print('[DRIFTZONE_RACEJOB] addStats with xp failed; trying without xp. Run sql.sql. Error: ' .. tostring(err))
        local ok2, err2 = pcall(function()
            MySQL.update.await(('UPDATE `%s` SET `%s` = ?, `%s` = COALESCE(`%s`, 0) + ? WHERE `%s` = ? LIMIT 1'):format(usersTable, cashCol, racesCol, racesCol, uidCol), {
                math.floor(newCash), addRace and 1 or 0, uid
            })
        end)
        if not ok2 then
            print('[DRIFTZONE_RACEJOB] addStats fallback failed: ' .. tostring(err2))
            return false
        end
    end

    return true
end

local function randomBetween(range)
    range = type(range) == 'table' and range or {}
    local min = tonumber(range.min or 0) or 0
    local max = tonumber(range.max or min) or min
    if max < min then max = min end
    return math.random(min, max)
end

local function setPlayerBucket(src, bucket)
    src = tonumber(src or 0) or 0
    if src > 0 and GetPlayerPing(src) > 0 then
        SetPlayerRoutingBucket(src, tonumber(bucket or 0) or 0)
    end
end

local function buildSoloPayload(src, race, vehicle)
    return {
        race = {
            id = race.id,
            label = race.label,
            timeLimit = race.timeLimit,
            start = vecToTable(race.start),
            finish = vecToTable(race.finish)
        },
        vehicle = vehicle,
        returnPosition = vecToTable(Config.ReturnPosition),
        finishRadius = Config.FinishRadius or 9.0,
        countdown = Config.CountdownSeconds or 3,
        mainColor = Config.MainColor
    }
end

local function openMenu(src)
    if not isLogged(src) then notify(src, 'warning', 'Nu esti logat.', 4000) return end
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.', 4000) return end
    TriggerClientEvent('driftzone_racejob:client:openMenu', src, {
        races = getRaceList(uid),
        vehicles = getPlayerVehicles(uid),
        mainColor = Config.MainColor,
        cooldowns = cooldownPayload(uid)
    })
end

local function failSolo(src, reason)
    local data = ActiveSolo[src]
    if not data then return end
    ActiveSolo[src] = nil
    local race = getRace(data.raceId)
    if race and data.uid then
        setCooldown(data.uid, data.raceId, getResultCooldown(race, false))
    end
    setPlayerBucket(src, Config.ReturnBucket or 0)
    TriggerClientEvent('driftzone_racejob:client:raceFailed', src, reason or 'Ai esuat livrarea.')
end

local function finishSolo(src)
    local data = ActiveSolo[src]
    if not data then return end
    ActiveSolo[src] = nil
    local race = getRace(data.raceId)
    if not race then return end
    local cash = randomBetween(race.reward)
    local xp = randomBetween(race.xp)
    addStats(data.uid, cash, xp, true)
    setCooldown(data.uid, data.raceId, getResultCooldown(race, true))
    setPlayerBucket(src, Config.ReturnBucket or 0)
    TriggerClientEvent('driftzone_racejob:client:raceCompleted', src, {
        cash = cash,
        xp = xp,
        message = ('Ai finalizat livrarea si ai primit suma de: $%s!'):format(cash),
        returnPosition = vecToTable(Config.ReturnPosition)
    })
end

RegisterNetEvent('driftzone_racejob:server:open', function()
    openMenu(source)
end)

RegisterNetEvent('driftzone_racejob:server:close', function() end)

RegisterNetEvent('driftzone_racejob:server:startSolo', function(raceId, vehicleId)
    local src = source
    if ActiveSolo[src] or ActiveDuoByPlayer[src] then notify(src, 'warning', 'Ai deja o livrare activa.', 4000) return end
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.', 4000) return end
    local race = getRace(raceId)
    if not race or race.special == true then notify(src, 'warning', 'Livrarea invalida.', 4000) return end
    local cd = getCooldownLeft(uid, race.id)
    if cd > 0 then notify(src, 'warning', 'Mai ai cooldown la aceasta livrare.', 4000) return end
    local vehicle = getVehicleData(uid, vehicleId)
    if not vehicle then notify(src, 'warning', 'Masina nu a fost gasita in garaj.', 5000) return end

    local bucket = (Config.RaceBucketBase or 62000) + src
    ActiveSolo[src] = { uid = uid, raceId = race.id, bucket = bucket, startedAt = os.time() }
    setPlayerBucket(src, bucket)
    TriggerClientEvent('driftzone_racejob:client:startSolo', src, buildSoloPayload(src, race, vehicle))
end)

RegisterNetEvent('driftzone_racejob:server:soloFinish', function()
    finishSolo(source)
end)

RegisterNetEvent('driftzone_racejob:server:soloFail', function(reason)
    failSolo(source, tostring(reason or 'Ai esuat livrarea.'))
end)

local function cleanupDuo(sessionId, reason)
    local session = DuoSessions[sessionId]
    if not session then return end
    DuoSessions[sessionId] = nil
    for _, src in ipairs({ session.p1, session.p2 }) do
        if src and GetPlayerPing(src) > 0 then
            local playerData = session.players and session.players[src]
            local race = getRace(session.raceId or 'special')
            if playerData and playerData.uid and race then
                setCooldown(playerData.uid, session.raceId or 'special', getResultCooldown(race, false))
            end
            ActiveDuoByPlayer[src] = nil
            setPlayerBucket(src, Config.ReturnBucket or 0)
            TriggerClientEvent('driftzone_racejob:client:duoFailed', src, reason or 'Ati esuat livrarea.')
        end
    end
end

local function tryStartDuo(sessionId)
    local session = DuoSessions[sessionId]
    if not session or session.started then return end
    local p1 = session.players[session.p1]
    local p2 = session.players[session.p2]
    if not (p1 and p2 and p1.vehicle and p2.vehicle and p1.spawned and p2.spawned) then return end
    session.started = true
    local race = getRace('special')
    TriggerClientEvent('driftzone_racejob:client:beginDuoRace', session.p1, { sessionId = sessionId, countdown = Config.CountdownSeconds or 3 })
    TriggerClientEvent('driftzone_racejob:client:beginDuoRace', session.p2, { sessionId = sessionId, countdown = Config.CountdownSeconds or 3 })
    SetTimeout((tonumber(race.timeLimit or 900) + 20) * 1000, function()
        local s = DuoSessions[sessionId]
        if s and not s.completed then cleanupDuo(sessionId, 'Timpul a expirat. Ati esuat livrarea.') end
    end)
end

RegisterNetEvent('driftzone_racejob:server:duoInvite', function(targetUidInput)
    local src = source
    local targetUidInput = tonumber(targetUidInput or 0) or 0

    if targetUidInput <= 0 then
        failInvite(src, 'Pune un UID valid.')
        return
    end

    local inviterUid = getUid(src)
    if not inviterUid then
        failInvite(src, 'Nu ti-am gasit UID-ul.')
        return
    end

    if tonumber(inviterUid) == tonumber(targetUidInput) then
        failInvite(src, 'Nu iti poti da invite singur.')
        return
    end

    local targetSrc = resolvePlayerByUid(targetUidInput)

    if not targetSrc then
        failInvite(src, 'UID invalid sau jucatorul nu este online.')
        return
    end

    if ActiveSolo[src] or ActiveDuoByPlayer[src] then
        failInvite(src, 'Ai deja o livrare activa.')
        return
    end

    if ActiveSolo[targetSrc] or ActiveDuoByPlayer[targetSrc] then
        failInvite(src, 'Jucatorul are deja o livrare activa.')
        return
    end

    local uid = inviterUid
    local targetUid = getUid(targetSrc)

    if not uid or not targetUid then
        failInvite(src, 'Nu am gasit UID-ul unuia dintre jucatori.')
        return
    end

    local race = getRace('special')
    if not race then
        failInvite(src, 'Duo Race nu este configurat corect.')
        return
    end

    if getCooldownLeft(uid, 'special') > 0 then
        failInvite(src, 'Ai cooldown la Duo Race.')
        return
    end

    if getCooldownLeft(targetUid, 'special') > 0 then
        failInvite(src, 'Prietenul tau are cooldown la Duo Race.')
        return
    end

    DuoInvites[uid] = { from = src, fromUid = uid, target = targetSrc, targetUid = targetUid, created = os.time() }
    notify(src, 'success', 'Invitatia a fost trimisa.', 4000)
    inviteResult(src, true, 'Invitatia a fost trimisa.')

    notify(targetSrc, 'info', ('Ai fost invitat la o livrare de catre %s (UID %s), foloseste comanda /jobaccept %s!'):format(getPlayerNameSafe(src), uid, uid), 7000)

    SetTimeout(5000, function()
        local invite = DuoInvites[uid]
        if invite and invite.target == targetSrc and playerExists(targetSrc) then
            notify(targetSrc, 'info', ('Reminder: /jobaccept %s pentru Duo Race cu %s.'):format(uid, getPlayerNameSafe(src)), 7000)
        end
    end)
end)

RegisterCommand('jobaccept', function(src, args)
    local inviterUid = tonumber(args[1] or 0) or 0
    if inviterUid <= 0 then notify(src, 'warning', 'Foloseste /jobaccept <uid>.', 4000) return end

    local invite = DuoInvites[inviterUid]
    if not invite or invite.target ~= src then notify(src, 'warning', 'Nu ai o invitatie valida de la acest jucator.', 4000) return end

    local inviter = tonumber(invite.from or 0) or 0
    DuoInvites[inviterUid] = nil
    if inviter <= 0 or GetPlayerPing(inviter) <= 0 then notify(src, 'warning', 'Jucatorul nu mai este online.', 4000) return end

    local race = getRace('special')
    local uid1, uid2 = tonumber(invite.fromUid or inviterUid) or getUid(inviter), getUid(src)
    if not uid1 or not uid2 then notify(src, 'warning', 'UID invalid.', 4000) return end
    if getCooldownLeft(uid1, 'special') > 0 or getCooldownLeft(uid2, 'special') > 0 then
        notify(src, 'warning', 'Unul dintre voi are cooldown la Duo Race.', 4000)
        notify(inviter, 'warning', 'Unul dintre voi are cooldown la Duo Race.', 4000)
        return
    end

    SessionCounter = SessionCounter + 1
    local sessionId = SessionCounter
    local bucket = (Config.RaceBucketBase or 62000) + 1000 + sessionId
    DuoSessions[sessionId] = {
        id = sessionId, p1 = inviter, p2 = src, bucket = bucket, raceId = 'special', started = false, completed = false,
        players = {
            [inviter] = { uid = uid1, name = getPlayerNameSafe(inviter), slot = 1, ready = false, spawned = false },
            [src] = { uid = uid2, name = getPlayerNameSafe(src), slot = 2, ready = false, spawned = false }
        },
        finished = {}
    }
    ActiveDuoByPlayer[inviter] = sessionId
    ActiveDuoByPlayer[src] = sessionId
    TriggerClientEvent('driftzone_racejob:client:openDuoGarage', inviter, {
        sessionId = sessionId, vehicles = getPlayerVehicles(uid1), partner = getPlayerNameSafe(src), selfName = getPlayerNameSafe(inviter), mainColor = Config.MainColor
    })
    TriggerClientEvent('driftzone_racejob:client:openDuoGarage', src, {
        sessionId = sessionId, vehicles = getPlayerVehicles(uid2), partner = getPlayerNameSafe(inviter), selfName = getPlayerNameSafe(src), mainColor = Config.MainColor
    })
end, false)

RegisterNetEvent('driftzone_racejob:server:duoReady', function(sessionId, vehicleId)
    local src = source
    sessionId = tonumber(sessionId or 0) or 0
    local session = DuoSessions[sessionId]
    if not session or ActiveDuoByPlayer[src] ~= sessionId then return end
    local player = session.players[src]
    if not player then return end
    local vehicle = getVehicleData(player.uid, vehicleId)
    if not vehicle then notify(src, 'warning', 'Masina nu a fost gasita in garaj.', 5000) return end
    player.vehicle = vehicle
    player.ready = true
    TriggerClientEvent('driftzone_racejob:client:duoStatus', session.p1, { p1Ready = session.players[session.p1].ready, p2Ready = session.players[session.p2].ready })
    TriggerClientEvent('driftzone_racejob:client:duoStatus', session.p2, { p1Ready = session.players[session.p1].ready, p2Ready = session.players[session.p2].ready })
    if session.players[session.p1].ready and session.players[session.p2].ready then
        local race = getRace('special')
        setPlayerBucket(session.p1, session.bucket)
        setPlayerBucket(session.p2, session.bucket)
        local payloadBase = {
            sessionId = sessionId,
            race = { id = 'special', label = 'Duo Race', timeLimit = race.timeLimit, finish = vecToTable(race.finish) },
            finishRadius = Config.FinishRadius or 9.0,
            returnPosition = vecToTable(Config.ReturnPosition),
            mainColor = Config.MainColor
        }
        local p1Payload = payloadBase
        p1Payload.vehicle = session.players[session.p1].vehicle
        p1Payload.start = vecToTable(race.start1)
        p1Payload.slot = 1
        p1Payload.partnerName = session.players[session.p2].name
        TriggerClientEvent('driftzone_racejob:client:prepareDuoRace', session.p1, p1Payload)
        local p2Payload = {
            sessionId = sessionId,
            race = payloadBase.race,
            finishRadius = payloadBase.finishRadius,
            returnPosition = payloadBase.returnPosition,
            mainColor = Config.MainColor,
            vehicle = session.players[session.p2].vehicle,
            start = vecToTable(race.start2),
            slot = 2,
            partnerName = session.players[session.p1].name
        }
        TriggerClientEvent('driftzone_racejob:client:prepareDuoRace', session.p2, p2Payload)
    end
end)

RegisterNetEvent('driftzone_racejob:server:duoSpawned', function(sessionId, ok)
    local src = source
    sessionId = tonumber(sessionId or 0) or 0
    local session = DuoSessions[sessionId]
    if not session or ActiveDuoByPlayer[src] ~= sessionId then return end
    if ok ~= true then cleanupDuo(sessionId, 'O masina nu a putut fi spawnata. Livrarea a fost anulata.') return end
    session.players[src].spawned = true
    tryStartDuo(sessionId)
end)

RegisterNetEvent('driftzone_racejob:server:duoFinish', function(sessionId)
    local src = source
    sessionId = tonumber(sessionId or 0) or 0
    local session = DuoSessions[sessionId]
    if not session or session.completed or ActiveDuoByPlayer[src] ~= sessionId then return end
    session.finished[src] = true
    notify(src, 'success', 'Ai ajuns la finish. Asteapta partenerul.', 3500)
    local other = src == session.p1 and session.p2 or session.p1
    if GetPlayerPing(other) > 0 then notify(other, 'info', 'Partenerul tau a ajuns la finish.', 3500) end
    if session.finished[session.p1] and session.finished[session.p2] then
        session.completed = true
        local race = getRace('special')
        local totalCash = randomBetween(race.reward)
        local totalXp = randomBetween(race.xp)
        local cash1 = math.floor(totalCash / 2)
        local cash2 = totalCash - cash1
        local xp1 = math.floor(totalXp / 2)
        local xp2 = totalXp - xp1
        addStats(session.players[session.p1].uid, cash1, xp1, true)
        addStats(session.players[session.p2].uid, cash2, xp2, true)
        setCooldown(session.players[session.p1].uid, 'special', getResultCooldown(race, true))
        setCooldown(session.players[session.p2].uid, 'special', getResultCooldown(race, true))
        setPlayerBucket(session.p1, Config.ReturnBucket or 0)
        setPlayerBucket(session.p2, Config.ReturnBucket or 0)
        local summary = {
            totalCash = totalCash, totalXp = totalXp,
            p1 = { name = session.players[session.p1].name, cash = cash1, xp = xp1 },
            p2 = { name = session.players[session.p2].name, cash = cash2, xp = xp2 },
            returnPosition = vecToTable(Config.ReturnPosition)
        }
        TriggerClientEvent('driftzone_racejob:client:duoCompleted', session.p1, summary)
        TriggerClientEvent('driftzone_racejob:client:duoCompleted', session.p2, summary)
        ActiveDuoByPlayer[session.p1] = nil
        ActiveDuoByPlayer[session.p2] = nil
        DuoSessions[sessionId] = nil
    end
end)

RegisterNetEvent('driftzone_racejob:server:duoFail', function(sessionId, reason)
    cleanupDuo(tonumber(sessionId or 0) or 0, tostring(reason or 'Ati esuat livrarea.'))
end)

RegisterNetEvent('driftzone_racejob:server:requestRefresh', function()
    openMenu(source)
end)

RegisterCommand(Config.ResetCooldownCommand or 'rracecd', function(src, args)
    if src == 0 then
        local target = tonumber(args[1] or 0) or 0
        local ok, msg = resetCooldownsFor(src, target)
        print(ok and ('[DRIFTZONE_RACEJOB] cooldown reset for UID ' .. tostring(target) .. '.') or ('[DRIFTZONE_RACEJOB] ' .. tostring(msg)))
        return
    end
    if getAdminLevel(src) < (Config.ResetCooldownMinAdminLevel or 6) then notify(src, 'warning', 'Nu ai acces la aceasta comanda.', 4000) return end
    local target = tonumber(args[1] or 0) or 0
    local ok, msg = resetCooldownsFor(src, target)
    if ok then notify(src, 'success', 'Cooldown-ul a fost resetat pentru UID ' .. tostring(target) .. '.', 4000) else notify(src, 'warning', msg, 4000) end
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    if ActiveSolo[src] then ActiveSolo[src] = nil end
    local sessionId = ActiveDuoByPlayer[src]
    if sessionId then cleanupDuo(sessionId, 'Partenerul a iesit de pe server. Livrarea a fost anulata.') end
    for inviteUid, invite in pairs(DuoInvites) do
        if invite.from == src or invite.target == src then DuoInvites[inviteUid] = nil end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do SetPlayerRoutingBucket(tonumber(id), Config.ReturnBucket or 0) end
end)

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())
    Wait(1000)
    print('[DRIFTZONE_RACEJOB] loaded. Solo + Duo ready.')
end)
