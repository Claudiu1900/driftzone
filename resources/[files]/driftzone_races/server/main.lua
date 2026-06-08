local Rooms = {}
local PlayerRoom = {}
local ActiveRaces = {}
local RoomCounter = 1000

local function log(...)
    if Config.Debug then print('[DRIFTZONE_RACES]', ...) end
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 5000, tostring(msg or ''))
end

local function cleanName(v)
    return tostring(v or ''):gsub('`', '')
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function playerOnline(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return false end
    return GetPlayerPing(src) > 0
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

local function vecToTable(v)
    if type(v) ~= 'vector3' and type(v) ~= 'vector4' then return v end
    return { x = v.x, y = v.y, z = v.z, h = v.w }
end

local function raceById(id)
    return (Config.RaceTypes or {})[tostring(id or '')]
end


local function normalizeTuningRaw(raw)
    if type(raw) == 'table' then
        local ok, encoded = pcall(json.encode, raw)
        if ok and encoded and encoded ~= '' then return encoded end
        return '{}'
    end

    local text = tostring(raw or '{}')
    if text == '' or text == 'null' or text == 'nil' or text:find('^table:') then
        return '{}'
    end

    -- Daca este JSON dublu encodat, il lasam intr-o forma curata JSON.
    local probe = text
    for _ = 1, 3 do
        local ok, decoded = pcall(json.decode, probe)
        if not ok then break end
        if type(decoded) == 'table' then
            local ok2, encoded = pcall(json.encode, decoded)
            if ok2 and encoded and encoded ~= '' then return encoded end
            return probe
        elseif type(decoded) == 'string' then
            probe = decoded
        else
            break
        end
    end

    return text
end

local function normalizeModel(raw)
    local function pick(t)
        if type(t) ~= 'table' then return nil end
        local keys = { 'model', 'vehicle_model', 'spawn', 'spawnName', 'hash', 'name', 'vehicle', 'vehicleName' }
        for _, key in ipairs(keys) do
            local v = t[key]
            if v ~= nil and tostring(v) ~= '' then return v end
        end
        for _, v in pairs(t) do
            if type(v) == 'table' then
                local found = pick(v)
                if found then return found end
            elseif type(v) == 'string' or type(v) == 'number' then
                local text = tostring(v)
                if text ~= '' and text ~= '0' and not text:find('[{}%[%]]') then return text end
            end
        end
    end

    if type(raw) == 'table' then raw = pick(raw) end
    local text = tostring(raw or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text:sub(1,1) == '{' or text:sub(1,1) == '[' then
        local ok, decoded = pcall(json.decode, text)
        if ok and type(decoded) == 'table' then
            local p = pick(decoded)
            if p then text = tostring(p) end
        end
    end
    text = text:gsub('^"', ''):gsub('"$', ''):gsub('^`', ''):gsub('`$', '')
    return text:gsub('^%s+', ''):gsub('%s+$', '')
end

local function ensureStats(uid, name)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return end
    local t = cleanName(Config.StatsTable or 'races')
    pcall(function()
        MySQL.insert.await(('INSERT INTO `%s` (`uid`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)'):format(t), { uid, tostring(name or 'Unknown') })
    end)
end

local function addStats(uid, name, won, cashAmount)
    uid = tonumber(uid or 0) or 0
    cashAmount = math.max(0, math.floor(tonumber(cashAmount or 0) or 0))
    if uid <= 0 then return end
    local t = cleanName(Config.StatsTable or 'races')
    ensureStats(uid, name)
    if won then
        pcall(function()
            MySQL.update.await(('UPDATE `%s` SET `wins` = `wins` + 1, `races` = `races` + 1, `cashwin` = `cashwin` + ? WHERE `uid` = ?'):format(t), { cashAmount, uid })
        end)
    else
        pcall(function()
            MySQL.update.await(('UPDATE `%s` SET `losses` = `losses` + 1, `races` = `races` + 1, `cashlost` = `cashlost` + ? WHERE `uid` = ?'):format(t), { cashAmount, uid })
        end)
    end
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

local function addCash(uid, amount)
    uid = tonumber(uid or 0) or 0
    amount = math.floor(tonumber(amount or 0) or 0)
    if uid <= 0 or amount == 0 then return false end
    local usersTable = cleanName(Config.UsersTable or 'users')
    local uidCol = cleanName(Config.UsersIdColumn or 'uid')
    local cashCol = cleanName(Config.UsersCashColumn or 'cash')
    local current = getCash(uid)
    local newValue = current + amount
    if newValue < 0 then return false end
    local ok = pcall(function()
        MySQL.update.await(('UPDATE `%s` SET `%s` = ? WHERE `%s` = ? LIMIT 1'):format(usersTable, cashCol, uidCol), { newValue, uid })
    end)
    return ok == true
end

local function addXp(uid, amount)
    uid = tonumber(uid or 0) or 0
    amount = math.max(0, math.floor(tonumber(amount or 0) or 0))
    if uid <= 0 or amount <= 0 then return false end

    local usersTable = cleanName(Config.UsersTable or 'users')
    local uidCol = cleanName(Config.UsersIdColumn or 'uid')
    local xpCol = cleanName(Config.UsersXpColumn or 'xp')

    local ok, err = pcall(function()
        MySQL.update.await(('UPDATE `%s` SET `%s` = COALESCE(`%s`, 0) + ? WHERE `%s` = ? LIMIT 1'):format(usersTable, xpCol, xpCol, uidCol), { amount, uid })
    end)

    if not ok then
        print('[DRIFTZONE_RACES] addXp failed. Ruleaza sql.sql pentru users.xp. Error: ' .. tostring(err))
        return false
    end

    return true
end

local function getRaceXp(race, won)
    race = type(race) == 'table' and race or {}
    local xp = type(race.xp) == 'table' and race.xp or {}

    if won == true then
        return math.max(0, math.floor(tonumber(xp.winner or race.winnerXp or 0) or 0))
    end

    return math.max(0, math.floor(tonumber(xp.loser or race.loserXp or 0) or 0))
end

local function takeCash(uid, amount)
    amount = math.max(0, math.floor(tonumber(amount or 0) or 0))
    if amount <= 0 then return true end
    if getCash(uid) < amount then return false end
    return addCash(uid, -amount)
end

local function refund(uid, amount)
    amount = math.max(0, math.floor(tonumber(amount or 0) or 0))
    if amount > 0 then addCash(uid, amount) end
end

local function getVehicleRows(uid, raceType)
    local ovt = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanName(Config.OwnedVehicleIdColumn or 'id')
    local ownerCol = cleanName(Config.OwnedVehicleOwnerColumn or 'owner_id')
    local modelCol = cleanName(Config.OwnedVehicleModelColumn or 'vehicle_model')
    local plateCol = cleanName(Config.OwnedVehiclePlateColumn or 'vehicle_plate')
    local tuningCol = cleanName(Config.OwnedVehicleTuningColumn or 'vehicle_tunning')
    local vnt = cleanName(Config.VehicleNamesTable or 'vehiclenames')
    local vnModel = cleanName(Config.VehicleNamesModelColumn or 'vehicle_model')
    local vnName = cleanName(Config.VehicleNamesNameColumn or 'vehicle_name')
    local vnImage = cleanName(Config.VehicleNamesImageColumn or 'vehicle_image')
    local vnType = cleanName(Config.VehicleNamesTypeColumn or 'type')

    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS owner_id, ov.`%s` AS model, ov.`%s` AS plate, ov.`%s` AS tuning,
                   vn.`%s` AS vehicle_name, vn.`%s` AS vehicle_image, vn.`%s` AS vehicle_type
            FROM `%s` ov
            LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
            WHERE ov.`%s` = ? AND LOWER(COALESCE(vn.`%s`, '')) = LOWER(?)
            ORDER BY ov.`%s` DESC
        ]]):format(idCol, ownerCol, modelCol, plateCol, tuningCol, vnName, vnImage, vnType, ovt, vnt, vnModel, modelCol, ownerCol, vnType, idCol), { uid, raceType })
    end)
    if not ok then
        print('[DRIFTZONE_RACES] vehicle query failed: ' .. tostring(rows))
        return {}
    end
    return rows or {}
end

local function getVehicles(uid, raceType)
    local list = {}
    for _, row in ipairs(getVehicleRows(uid, raceType)) do
        local model = normalizeModel(row.model)
        if model ~= '' then
            list[#list + 1] = {
                id = tonumber(row.id) or 0,
                model = model,
                name = tostring(row.vehicle_name or model),
                plate = tostring(row.plate or 'DRIFT'),
                image = tostring(row.vehicle_image or ''),
                type = tostring(row.vehicle_type or raceType or '')
            }
        end
    end
    return list
end

local function getVehicleData(uid, vehicleId, raceType)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return nil end
    local ovt = cleanName(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanName(Config.OwnedVehicleIdColumn or 'id')
    local ownerCol = cleanName(Config.OwnedVehicleOwnerColumn or 'owner_id')
    local modelCol = cleanName(Config.OwnedVehicleModelColumn or 'vehicle_model')
    local plateCol = cleanName(Config.OwnedVehiclePlateColumn or 'vehicle_plate')
    local tuningCol = cleanName(Config.OwnedVehicleTuningColumn or 'vehicle_tunning')
    local vnt = cleanName(Config.VehicleNamesTable or 'vehiclenames')
    local vnModel = cleanName(Config.VehicleNamesModelColumn or 'vehicle_model')
    local vnName = cleanName(Config.VehicleNamesNameColumn or 'vehicle_name')
    local vnImage = cleanName(Config.VehicleNamesImageColumn or 'vehicle_image')
    local vnType = cleanName(Config.VehicleNamesTypeColumn or 'type')

    local ok, row = pcall(function()
        return MySQL.single.await(([[
            SELECT ov.`%s` AS id, ov.`%s` AS owner_id, ov.`%s` AS model, ov.`%s` AS plate, ov.`%s` AS tuning,
                   vn.`%s` AS vehicle_name, vn.`%s` AS vehicle_image, vn.`%s` AS vehicle_type
            FROM `%s` ov
            LEFT JOIN `%s` vn ON vn.`%s` = ov.`%s`
            WHERE ov.`%s` = ? AND ov.`%s` = ? AND LOWER(COALESCE(vn.`%s`, '')) = LOWER(?)
            LIMIT 1
        ]]):format(idCol, ownerCol, modelCol, plateCol, tuningCol, vnName, vnImage, vnType, ovt, vnt, vnModel, modelCol, idCol, ownerCol, vnType), { vehicleId, uid, raceType })
    end)
    if not ok then
        print('[DRIFTZONE_RACES] get vehicle failed: ' .. tostring(row))
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
        tuning = normalizeTuningRaw(row.tuning),
        image = tostring(row.vehicle_image or ''),
        type = tostring(row.vehicle_type or raceType or '')
    }
end

local function raceListPayload()
    local list = {}
    for id, race in pairs(Config.RaceTypes or {}) do
        list[#list + 1] = {
            id = race.id or id,
            label = race.label or id,
            type = race.type or 'drift',
            description = race.description or '',
            maxPlayers = race.maxPlayers or 4,
            minPlayers = race.minPlayers or Config.MinPlayers,
            checkpoints = #(race.checkpoints or {}),
            winnerXp = getRaceXp(race, true),
            loserXp = getRaceXp(race, false)
        }
    end
    table.sort(list, function(a,b) return tostring(a.label) < tostring(b.label) end)
    return list
end

local function roomPayload(room, forSrc)
    local members = {}
    for _, m in ipairs(room.members) do
        members[#members + 1] = {
            uid = m.uid,
            name = m.name,
            ready = m.ready == true,
            owner = m.src == room.ownerSrc
        }
    end
    return {
        id = room.id,
        raceId = room.raceId,
        raceLabel = room.race.label,
        raceType = room.race.type,
        maxPlayers = room.maxPlayers,
        entryFee = room.entryFee,
        private = room.private == true,
        locked = room.private == true,
        ownerUid = room.ownerUid,
        ownerName = room.ownerName,
        members = members,
        minPlayers = room.race.minPlayers or Config.MinPlayers,
        startIn = math.max(0, Config.LobbyStartAfterNoJoinSeconds - (os.time() - room.lastJoinAt)),
        meReady = false
    }
end

local function roomsPayload()
    local list = {}
    for _, room in pairs(Rooms) do
        if not room.started then
            list[#list + 1] = {
                id = room.id,
                raceId = room.raceId,
                raceLabel = room.race.label,
                raceType = room.race.type,
                maxPlayers = room.maxPlayers,
                players = #room.members,
                entryFee = room.entryFee,
                private = room.private == true,
                ownerName = room.ownerName,
                checkpoints = #(room.race.checkpoints or {})
            }
        end
    end
    table.sort(list, function(a,b) return a.id > b.id end)
    return list
end

local function broadcastRoom(room, forceSrc)
    for _, m in ipairs(room.members) do
        if playerOnline(m.src) then
            local payload = roomPayload(room, m.src)
            payload.meReady = m.ready == true
            TriggerClientEvent('driftzone_races:client:roomUpdate', m.src, payload, forceSrc ~= nil and tonumber(forceSrc) == tonumber(m.src))
        end
    end
end

local function clearPlayerRoom(src)
    PlayerRoom[tonumber(src)] = nil
end

local function findMember(room, src)
    for idx, m in ipairs(room.members) do
        if m.src == src then return m, idx end
    end
    return nil, nil
end

local function canStartRoom(room)
    if room.started then return false end
    local count = #room.members
    local minPlayers = room.race.minPlayers or Config.MinPlayers
    if count < minPlayers then return false end
    if count >= room.maxPlayers then return true end
    local allReady = true
    for _, m in ipairs(room.members) do
        if m.ready ~= true then allReady = false break end
    end
    if allReady then return true end
    return (os.time() - room.lastJoinAt) >= Config.LobbyStartAfterNoJoinSeconds
end

local function setBucket(src, bucket)
    if playerOnline(src) then SetPlayerRoutingBucket(src, tonumber(bucket or 0) or 0) end
end

local function setGarageBlocked(src, state)
    src = tonumber(src or 0) or 0
    if src <= 0 or not playerOnline(src) then return end

    -- driftzone_garage are export server-side. Daca resource-ul nu exista / nu este pornit,
    -- nu blocam race-ul, doar ignoram safe.
    if GetResourceState('driftzone_garage') == 'started' then
        pcall(function()
            exports['driftzone_garage']:SetGarageBlocked(src, state == true, 'Garaj indisponibil.')
        end)
    end

    -- Backup client-side pentru cazul in care playerul incearca trigger-uri locale.
    TriggerClientEvent('driftzone_garage:client:setBlocked', src, state == true, 'Garaj indisponibil.')
end

local function setRoomGarageBlocked(room, state)
    if not room or type(room.members) ~= 'table' then return end
    for _, m in ipairs(room.members) do
        if m and m.src then
            setGarageBlocked(m.src, state == true)
        end
    end
end

local function startRoom(room)
    if not room or room.started then return end
    if #room.members < (room.race.minPlayers or Config.MinPlayers) then return end
    room.started = true
    local bucket = Config.RaceBucketBase + room.id
    ActiveRaces[room.id] = room
    setRoomGarageBlocked(room, true)

    for index, m in ipairs(room.members) do
        setBucket(m.src, bucket)
    end

    SetTimeout(450, function()
        for index, m in ipairs(room.members) do
            if playerOnline(m.src) then
                TriggerClientEvent('driftzone_races:client:startRace', m.src, {
                    roomId = room.id,
                    bucket = bucket,
                    positionIndex = index,
                    start = vecToTable(room.race.startPositions[index]),
                    checkpoints = (function()
                        local cps = {}
                        for i, cp in ipairs(room.race.checkpoints or {}) do
                            cps[#cps + 1] = { coords = vecToTable(cp.coords), direction = cp.direction or 'straight' }
                        end
                        return cps
                    end)(),
                    checkpointRadius = Config.CheckpointRadius,
                    finishRadius = Config.FinishRadius,
                    countdown = Config.CountdownSeconds,
                    vehicle = m.vehicle,
                    mainColor = Config.MainColor
                })
            end
        end
    end)
end

local function leaveRoom(src, silent)
    local roomId = PlayerRoom[src]
    if not roomId then return false end
    local room = Rooms[roomId]
    if not room or room.started then return false end
    local member, idx = findMember(room, src)
    if not member then return false end

    refund(member.uid, member.entryFee)
    table.remove(room.members, idx)
    clearPlayerRoom(src)
    TriggerClientEvent('driftzone_races:client:leftRoom', src)
    if not silent then notify(src, 'info', 'Ai iesit din party. Banii au fost returnati.', 5000) end

    if #room.members == 0 then
        Rooms[room.id] = nil
    else
        if room.ownerSrc == src then
            room.ownerSrc = room.members[1].src
            room.ownerUid = room.members[1].uid
            room.ownerName = room.members[1].name
        end
        broadcastRoom(room)
    end
    return true
end

local function finishRace(room, winnerSrc)
    if not room or room.finished then return end
    room.finished = true
    local winner = nil
    for _, m in ipairs(room.members) do
        if m.src == winnerSrc then winner = m break end
    end
    if not winner then return end

    local pot = 0
    for _, m in ipairs(room.members) do pot = pot + (tonumber(m.entryFee) or 0) end
    local tax = math.floor(pot * ((Config.HouseTaxPercent or 10) / 100))
    local prize = math.max(0, pot - tax)

    local winnerXp = getRaceXp(room.race, true)
    local loserXp = getRaceXp(room.race, false)

    addCash(winner.uid, prize)
    addXp(winner.uid, winnerXp)
    addStats(winner.uid, winner.name, true, prize)

    for _, m in ipairs(room.members) do
        if m.src ~= winner.src then
            addXp(m.uid, loserXp)
            addStats(m.uid, m.name, false, m.entryFee)
        end
    end

    for _, m in ipairs(room.members) do
        if playerOnline(m.src) then
            setGarageBlocked(m.src, false)
            TriggerClientEvent('driftzone_races:client:raceFinished', m.src, {
                winnerUid = winner.uid,
                winnerName = winner.name,
                prize = prize,
                pot = pot,
                tax = tax,
                won = m.src == winner.src,
                xp = (m.src == winner.src) and winnerXp or loserXp,
                returnPosition = vecToTable(Config.ReturnPosition)
            })
            setBucket(m.src, Config.ReturnBucket or 0)
            PlayerRoom[m.src] = nil
        end
    end

    Rooms[room.id] = nil
    ActiveRaces[room.id] = nil
end

RegisterNetEvent('driftzone_races:server:open', function()
    local src = source
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.', 4000) return end

    local roomId = PlayerRoom[src]
    local room = roomId and Rooms[roomId] or nil

    -- Daca jucatorul este deja intr-un party si apasa E la interactiune,
    -- nu mai deschidem meniul principal. Ii redeschidem direct party-ul.
    if room and not room.started and not room.finished then
        local payload = roomPayload(room, src)
        local member = findMember(room, src)
        payload.meReady = member and member.ready == true or false
        TriggerClientEvent('driftzone_races:client:roomUpdate', src, payload, true)
        return
    end

    TriggerClientEvent('driftzone_races:client:open', src, {
        mainColor = Config.MainColor,
        races = raceListPayload(),
        rooms = roomsPayload()
    })
end)

RegisterNetEvent('driftzone_races:server:getVehicles', function(raceId)
    local src = source
    local uid = getUid(src)
    local race = raceById(raceId)
    if not uid or not race then return end
    TriggerClientEvent('driftzone_races:client:vehicles', src, {
        raceId = race.id,
        vehicles = getVehicles(uid, race.type)
    })
end)

RegisterNetEvent('driftzone_races:server:refreshRooms', function()
    TriggerClientEvent('driftzone_races:client:rooms', source, roomsPayload())
end)

RegisterNetEvent('driftzone_races:server:createRoom', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    if PlayerRoom[src] then notify(src, 'warning', 'Esti deja intr-un party.', 4000) return end
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.', 4000) return end
    local race = raceById(data.raceId)
    if not race then notify(src, 'warning', 'Cursa invalida.', 4000) return end

    local maxPlayers = math.floor(tonumber(data.maxPlayers or 2) or 2)
    maxPlayers = math.max(race.minPlayers or Config.MinPlayers, math.min(maxPlayers, race.maxPlayers or 4))

    local entryFee = math.floor(tonumber(data.entryFee or 0) or 0)
    if entryFee < (Config.EntryFeeMin or 1) or entryFee > (Config.EntryFeeMax or 500000000) then
        notify(src, 'warning', 'Suma invalida.', 4000)
        return
    end

    local private = data.private == true
    local password = tostring(data.password or ''):gsub('%s+', '')
    local pin = tostring(data.pin or ''):gsub('%D', '')
    if private and (password == '' and #pin ~= 4) then
        notify(src, 'warning', 'Pentru privat ai nevoie de parola sau PIN de 4 cifre.', 5000)
        return
    end

    local vehicle = getVehicleData(uid, data.vehicleId, race.type)
    if not vehicle then notify(src, 'warning', 'Masina selectata nu este valida pentru tipul cursei.', 5000) return end
    if getCash(uid) < entryFee then notify(src, 'warning', 'Nu ai suma necesara pentru aceasta cursa.', 5000) return end
    if not takeCash(uid, entryFee) then notify(src, 'warning', 'Nu am putut retrage suma.', 5000) return end

    RoomCounter = RoomCounter + 1
    local room = {
        id = RoomCounter,
        raceId = race.id,
        race = race,
        ownerSrc = src,
        ownerUid = uid,
        ownerName = getPlayerNameSafe(src),
        maxPlayers = maxPlayers,
        entryFee = entryFee,
        private = private,
        password = password,
        pin = pin,
        started = false,
        finished = false,
        createdAt = os.time(),
        lastJoinAt = os.time(),
        members = {}
    }
    room.members[#room.members + 1] = { src = src, uid = uid, name = room.ownerName, ready = false, vehicle = vehicle, entryFee = entryFee, joinedAt = os.time() }
    Rooms[room.id] = room
    PlayerRoom[src] = room.id
    ensureStats(uid, room.ownerName)
    notify(src, 'success', 'Party-ul a fost creat cu succes.', 5000)
    TriggerClientEvent('driftzone_races:client:createdRoom', src, roomPayload(room, src))
    TriggerClientEvent('driftzone_races:client:roomUpdate', src, roomPayload(room, src), true)
    TriggerClientEvent('driftzone_races:client:rooms', -1, roomsPayload())
end)

RegisterNetEvent('driftzone_races:server:joinRoom', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    if PlayerRoom[src] then notify(src, 'warning', 'Esti deja intr-un party.', 4000) return end
    local uid = getUid(src)
    if not uid then notify(src, 'warning', 'Nu ti-am gasit UID-ul.', 4000) return end
    local room = Rooms[tonumber(data.roomId or 0)]
    if not room or room.started then notify(src, 'warning', 'Party-ul nu mai este disponibil.', 4000) return end
    if #room.members >= room.maxPlayers then notify(src, 'warning', 'Party-ul este plin.', 4000) return end
    if room.private then
        local pass = tostring(data.password or ''):gsub('%s+', '')
        local pin = tostring(data.pin or ''):gsub('%D', '')
        if pass ~= room.password and pin ~= room.pin then
            notify(src, 'warning', 'Parola/PIN invalid.', 4000)
            return
        end
    end
    local vehicle = getVehicleData(uid, data.vehicleId, room.race.type)
    if not vehicle then notify(src, 'warning', 'Masina selectata nu este valida pentru tipul cursei.', 5000) return end
    if getCash(uid) < room.entryFee then notify(src, 'warning', 'Nu ai suma necesara pentru aceasta cursa.', 5000) return end
    if not takeCash(uid, room.entryFee) then notify(src, 'warning', 'Nu am putut retrage suma.', 5000) return end
    local name = getPlayerNameSafe(src)
    room.members[#room.members + 1] = { src = src, uid = uid, name = name, ready = false, vehicle = vehicle, entryFee = room.entryFee, joinedAt = os.time() }
    room.lastJoinAt = os.time()
    PlayerRoom[src] = room.id
    ensureStats(uid, name)
    notify(src, 'success', 'Ai intrat in party.', 5000)
    TriggerClientEvent('driftzone_races:client:joinedRoom', src, roomPayload(room, src))
    broadcastRoom(room, src)
    TriggerClientEvent('driftzone_races:client:rooms', -1, roomsPayload())
    if canStartRoom(room) then startRoom(room) end
end)

RegisterNetEvent('driftzone_races:server:setReady', function(state)
    local src = source
    local room = Rooms[PlayerRoom[src] or 0]
    if not room or room.started then return end
    local m = findMember(room, src)
    if not m then return end
    m.ready = state == true
    broadcastRoom(room)
    if canStartRoom(room) then startRoom(room) end
end)

RegisterNetEvent('driftzone_races:server:closeUi', function()
    local src = source
    local room = Rooms[PlayerRoom[src] or 0]
    if not room or room.started then return end
    local m = findMember(room, src)
    if m then
        m.ready = true
        notify(src, 'info', 'Ai iesit din meniu si ai fost pus READY automat.', 5000)
        broadcastRoom(room)
        if canStartRoom(room) then startRoom(room) end
    end
end)

RegisterNetEvent('driftzone_races:server:leaveRoom', function()
    leaveRoom(source, false)
end)

RegisterNetEvent('driftzone_races:server:checkpoint', function(roomId, checkpointIndex)
    local src = source
    local room = ActiveRaces[tonumber(roomId or 0)]
    if not room or room.finished then return end
    local m = findMember(room, src)
    if not m then return end
    m.lastCheckpoint = tonumber(checkpointIndex or 0) or 0
end)

RegisterNetEvent('driftzone_races:server:finish', function(roomId)
    local src = source
    local room = ActiveRaces[tonumber(roomId or 0)]
    if not room or room.finished then return end
    finishRace(room, src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local roomId = PlayerRoom[src]
    local room = Rooms[roomId or 0]
    if room and not room.started then
        leaveRoom(src, true)
    elseif room and room.started and not room.finished then
        local m = findMember(room, src)
        if m then
            addXp(m.uid, getRaceXp(room.race, false))
            addStats(m.uid, m.name, false, m.entryFee)
        end
        setGarageBlocked(src, false)
        PlayerRoom[src] = nil
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, room in pairs(ActiveRaces) do
        setRoomGarageBlocked(room, false)
    end
    for _, room in pairs(Rooms) do
        if room and room.started then
            setRoomGarageBlocked(room, false)
        end
    end
end)

CreateThread(function()
    while true do
        for _, room in pairs(Rooms) do
            if room and not room.started and canStartRoom(room) then
                startRoom(room)
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_RACES] Loaded. Interaction: -1336.180176, -3044.254882, 14.890136')
end)
