local Calls = {}
local PlayerCall = {}
local PhoneCache = {}
local UidCache = {}
local UserColumns = nil
local NextCallId = 0

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function cleanNumber(number)
    number = tostring(number or '')
    number = number:gsub('%s+', '')
    number = number:gsub('[^%d]', '')
    return number
end

local function jsonEncode(data)
    local ok, res = pcall(json.encode, data or {})
    if ok then return res end
    return '{}'
end

local function jsonDecode(raw)
    if type(raw) == 'table' then return raw end
    local ok, res = pcall(json.decode, tostring(raw or '{}'))
    if ok and type(res) == 'table' then return res end
    return {}
end

local function sendFeedback(src, payload)
    src = tonumber(src)
    if src and src > 0 then
        TriggerClientEvent('driftzone_phone:client:feedback', src, payload or {})
    end
end

local function getUserColumns()
    if UserColumns then return UserColumns end
    UserColumns = {}
    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM %s'):format(sqlName(Config.UsersTable or 'users')), {}) or {}
    end)
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row and row.Field then UserColumns[tostring(row.Field)] = true end
        end
    end
    return UserColumns
end

local function getPhoneColumns()
    local cols = getUserColumns()
    local out, added = {}, {}
    local function add(name)
        name = tostring(name or '')
        if name ~= '' and not added[name] and (cols[name] == true or next(cols) == nil) then
            added[name] = true
            out[#out + 1] = name
        end
    end
    add(Config.PhoneColumn or 'phonenumber')
    for _, name in ipairs(Config.PhoneColumns or {}) do add(name) end
    if #out <= 0 then out[1] = Config.PhoneColumn or 'phonenumber' end
    return out
end

local function normalizeSqlExpr(columnName)
    local col = ('COALESCE(CAST(%s AS CHAR), \'\')'):format(sqlName(columnName))
    local chars = { ' ', '-', '.', '+', '(', ')', '/', '_', ':' }
    local expr = col
    for _, ch in ipairs(chars) do
        expr = ("REPLACE(%s, '%s', '')"):format(expr, ch:gsub("'", "\\'"))
    end
    return expr
end

local function getUid(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local state = Player(src).state
    for _, key in ipairs({ 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }) do
        local value = state and tonumber(state[key])
        if value and value > 0 then return value end
    end
    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then return cached.uid end
    local res = Config.AuthResource or 'driftzone_auth'
    if GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:GetUID(src) end,
            function() return exports[res]:GetUid(src) end,
            function() return exports[res]:getUID(src) end,
            function() return exports[res]:GetUserId(src) end,
            function() return exports[res]:getUserId(src) end,
            function() return exports[res]:getUserID(src) end
        }
        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            local uid = tonumber(value)
            if ok and uid and uid > 0 then
                UidCache[src] = { uid = uid, expires = GetGameTimer() + 30000 }
                return uid
            end
        end
    end
    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end
    local res = Config.AuthResource or 'driftzone_auth'
    if GetResourceState(res) == 'started' then
        local attempts = {
            function() return exports[res]:IsLoggedIn(src) end,
            function() return exports[res]:isLoggedIn(src) end,
            function() return exports[res]:IsLogged(src) end
        }
        for _, fn in ipairs(attempts) do
            local ok, result = pcall(fn)
            if ok and result == true then return true end
        end
    end
    return getUid(src) ~= nil
end

local function getPhoneByUid(uid, force)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return nil end
    local cached = PhoneCache[uid]
    if not force and cached and cached.expires > GetGameTimer() then return cached.phone end
    local phone = nil
    for _, col in ipairs(getPhoneColumns()) do
        local ok, row = pcall(function()
            return MySQL.single.await(
                ('SELECT %s AS phone FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(col), sqlName(Config.UsersTable or 'users'), sqlName(Config.UsersIdColumn or 'uid')),
                { uid }
            )
        end)
        if ok and row then
            phone = cleanNumber(row.phone)
            if phone ~= '' then break end
        end
    end
    if phone == '' then phone = nil end
    PhoneCache[uid] = { phone = phone, expires = GetGameTimer() + 7000 }
    return phone
end

local function getUidByPhone(phone)
    phone = cleanNumber(phone)
    if phone == '' then return nil end
    for _, col in ipairs(getPhoneColumns()) do
        local expr = normalizeSqlExpr(col)
        local ok, row = pcall(function()
            return MySQL.single.await(
                ('SELECT %s AS uid FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(Config.UsersIdColumn or 'uid'), sqlName(Config.UsersTable or 'users'), expr),
                { phone }
            )
        end)
        if ok and row and tonumber(row.uid) then return tonumber(row.uid) end
    end
    return nil
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)
    if not uid then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getUid(src) == uid then return src end
    end
    return nil
end

local function getPlayerByPhone(phone)
    local uid = getUidByPhone(phone)
    if not uid then return nil, nil end
    return getPlayerByUid(uid), uid
end

local function getContactName(ownerUid, number)
    ownerUid = tonumber(ownerUid)
    number = cleanNumber(number)
    if not ownerUid or ownerUid <= 0 or number == '' then return nil end
    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT contact_name FROM %s WHERE owner_uid = ? AND phone_number = ? LIMIT 1'):format(sqlName(Config.ContactsTable)), { ownerUid, number })
    end)
    if ok and row and trim(row.contact_name) ~= '' then return trim(row.contact_name) end
    return nil
end

local function isBlocked(ownerUid, number)
    ownerUid = tonumber(ownerUid)
    number = cleanNumber(number)
    if not ownerUid or ownerUid <= 0 or number == '' then return false end
    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT blocked FROM %s WHERE owner_uid = ? AND phone_number = ? LIMIT 1'):format(sqlName(Config.ContactsTable)), { ownerUid, number })
    end)
    return ok and row and tonumber(row.blocked or 0) == 1
end

local function getContacts(uid)
    uid = tonumber(uid)
    if not uid then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT id, contact_name, phone_number, blocked FROM %s WHERE owner_uid = ? ORDER BY contact_name ASC LIMIT ?'):format(sqlName(Config.ContactsTable)), { uid, tonumber(Config.ContactsLimit or 300) or 300 }) or {}
    end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            id = tonumber(row.id or 0) or 0,
            name = tostring(row.contact_name or ''),
            number = cleanNumber(row.phone_number),
            blocked = tonumber(row.blocked or 0) == 1
        }
    end
    return out
end

local function addCallHistory(ownerUid, otherNumber, otherName, direction, status, duration)
    ownerUid = tonumber(ownerUid)
    if not ownerUid then return end
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (owner_uid, other_number, other_name, direction, status, duration, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.CallHistoryTable)), {
            ownerUid, cleanNumber(otherNumber), tostring(otherName or ''), tostring(direction or ''), tostring(status or ''), tonumber(duration or 0) or 0
        })
    end)
end

local function getCallHistory(uid)
    uid = tonumber(uid)
    if not uid then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT id, other_number, other_name, direction, status, duration, created_at FROM %s WHERE owner_uid = ? ORDER BY id DESC LIMIT ?'):format(sqlName(Config.CallHistoryTable)), { uid, tonumber(Config.HistoryLimit or 80) or 80 }) or {}
    end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for _, row in ipairs(rows) do
        local num = cleanNumber(row.other_number)
        out[#out + 1] = {
            id = tonumber(row.id or 0) or 0,
            number = num,
            name = getContactName(uid, num) or tostring(row.other_name or '') or '',
            direction = tostring(row.direction or ''),
            status = tostring(row.status or ''),
            duration = tonumber(row.duration or 0) or 0,
            created_at = tostring(row.created_at or '')
        }
    end
    return out
end

local function getMessages(uid)
    uid = tonumber(uid)
    if not uid then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await(([=[
            SELECT id, sender_uid, receiver_uid, sender_number, receiver_number, message, message_type, location_json, created_at
            FROM %s
            WHERE sender_uid = ? OR receiver_uid = ?
            ORDER BY id DESC
            LIMIT ?
        ]=]):format(sqlName(Config.MessageHistoryTable)), { uid, uid, tonumber(Config.MessageLimit or 250) or 250 }) or {}
    end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for i = #rows, 1, -1 do
        local row = rows[i]
        local mine = tonumber(row.sender_uid or 0) == uid
        local otherNumber = mine and cleanNumber(row.receiver_number) or cleanNumber(row.sender_number)
        out[#out + 1] = {
            id = tonumber(row.id or 0) or 0,
            mine = mine,
            otherNumber = otherNumber,
            otherName = getContactName(uid, otherNumber) or otherNumber,
            from = cleanNumber(row.sender_number),
            to = cleanNumber(row.receiver_number),
            text = tostring(row.message or ''),
            type = tostring(row.message_type or 'text'),
            location = jsonDecode(row.location_json),
            created_at = tostring(row.created_at or '')
        }
    end
    return out
end

local function makeCallId()
    NextCallId = NextCallId + 1
    return ('dzcall_%s_%s'):format(os.time(), NextCallId)
end

local function getCallForPlayer(src)
    local callId = PlayerCall[tonumber(src)]
    if not callId then return nil, nil end
    local call = Calls[callId]
    if not call then PlayerCall[tonumber(src)] = nil return nil, nil end
    return callId, call
end

local function otherParticipant(call, src)
    src = tonumber(src)
    if call.a == src then return call.b end
    if call.b == src then return call.a end
    return nil
end

local function publicCallStateFor(src)
    local uid = getUid(src)
    local myPhone = uid and getPhoneByUid(uid, true) or nil
    local callId, call = getCallForPlayer(src)
    local state = {
        myNumber = myPhone or '',
        inCall = false,
        incoming = false,
        outgoing = false,
        active = false,
        otherNumber = '',
        otherName = '',
        callId = nil,
        startedAt = 0,
        contacts = uid and getContacts(uid) or {},
        callHistory = uid and getCallHistory(uid) or {},
        messages = uid and getMessages(uid) or {}
    }
    if call then
        local otherSrc = otherParticipant(call, src)
        local otherPhone = call.a == src and call.bPhone or call.aPhone
        state.inCall = true
        state.active = call.state == 'active'
        state.incoming = call.state == 'ringing' and call.to == src
        state.outgoing = call.state == 'ringing' and call.from == src
        state.otherNumber = tostring(otherPhone or '')
        state.otherName = uid and (getContactName(uid, otherPhone) or tostring(otherPhone or '')) or tostring(otherPhone or '')
        state.callId = callId
        state.startedAt = call.startedAt or 0
    end
    return state
end

local function sendState(src)
    src = tonumber(src)
    if src and src > 0 then
        TriggerClientEvent('driftzone_phone:client:state', src, publicCallStateFor(src))
    end
end

local function sendCallStates(call)
    if not call then return end
    sendState(call.a)
    sendState(call.b)
end

local function failCall(src, title, text)
    sendFeedback(src, { kind = 'call_fail', title = title or 'Apel esuat', text = text or '', sound = 'decline' })
    sendState(src)
end

local function endCall(callId, reason, endedBy)
    local call = Calls[callId]
    if not call then return end
    Calls[callId] = nil
    PlayerCall[call.a] = nil
    PlayerCall[call.b] = nil
    TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId)

    local aUid = getUid(call.a)
    local bUid = getUid(call.b)
    local duration = 0
    if call.startedAt and call.startedAt > 0 then duration = math.max(0, os.time() - call.startedAt) end

    if reason == 'missed' then
        if aUid then addCallHistory(aUid, call.bPhone, call.bName, 'outgoing', 'missed', 0) end
        if bUid then addCallHistory(bUid, call.aPhone, call.aName, 'missed', 'missed', 0) end
        sendFeedback(call.from, { kind = 'missed', sound = 'decline' })
    elseif reason == 'declined' then
        if aUid then addCallHistory(aUid, call.bPhone, call.bName, 'outgoing', 'declined', 0) end
        if bUid then addCallHistory(bUid, call.aPhone, call.aName, 'incoming', 'declined', 0) end
        sendFeedback(call.from, { kind = 'declined', sound = 'decline' })
    elseif reason == 'ended' then
        local status = call.state == 'active' and 'answered' or 'ended'
        if aUid then addCallHistory(aUid, call.bPhone, call.bName, call.from == call.a and 'outgoing' or 'incoming', status, duration) end
        if bUid then addCallHistory(bUid, call.aPhone, call.aName, call.from == call.b and 'outgoing' or 'incoming', status, duration) end
        local other = endedBy and otherParticipant(call, endedBy) or nil
        if other then sendFeedback(other, { kind = 'ended' }) end
    end

    sendState(call.a)
    sendState(call.b)
end

RegisterNetEvent('driftzone_phone:server:requestState', function()
    local src = source
    if isLogged(src) then sendState(src) end
end)

RegisterNetEvent('driftzone_phone:server:startCall', function(rawNumber)
    local src = source
    if not isLogged(src) then return failCall(src, 'Telefon blocat', 'Trebuie sa fii logat.') end
    if PlayerCall[src] then return failCall(src, 'Linie ocupata', 'Esti deja intr-un apel.') end

    local number = cleanNumber(rawNumber)
    if number == '' or #number < (Config.PhoneNumberMinLength or 1) or #number > (Config.PhoneNumberMaxLength or 32) then
        return failCall(src, 'Numar invalid', 'Numarul nu este valid.')
    end

    local uid = getUid(src)
    local myPhone = uid and getPhoneByUid(uid, true) or nil
    if not myPhone then return failCall(src, 'Numar lipsa', 'Nu ai users.phonenumber setat.') end
    if number == myPhone then return failCall(src, 'Numar invalid', 'Nu te poti suna singur.') end

    local target, targetUid = getPlayerByPhone(number)
    if not targetUid then return failCall(src, 'Numar inexistent', 'Numarul nu exista.') end
    if not target then return failCall(src, 'Telefon indisponibil', 'Persoana nu este pe server.') end
    if isBlocked(targetUid, myPhone) then return failCall(src, 'Apel blocat', 'Persoana nu poate fi apelata.') end
    if PlayerCall[target] then return failCall(src, 'Linie ocupata', 'Persoana este deja intr-un apel.') end

    local callId = makeCallId()
    local targetPhone = getPhoneByUid(targetUid, true) or number
    local call = {
        id = callId,
        a = src,
        b = target,
        from = src,
        to = target,
        aPhone = myPhone,
        bPhone = targetPhone,
        aName = getContactName(targetUid, myPhone) or myPhone,
        bName = getContactName(uid, targetPhone) or targetPhone,
        state = 'ringing',
        createdAt = os.time(),
        startedAt = 0
    }
    Calls[callId] = call
    PlayerCall[src] = callId
    PlayerCall[target] = callId

    sendFeedback(src, { kind = 'ringing', sound = 'ring' })
    TriggerClientEvent('driftzone_phone:client:incoming', target, publicCallStateFor(target))
    sendCallStates(call)

    SetTimeout(tonumber(Config.CallTimeoutMs or 30000) or 30000, function()
        local current = Calls[callId]
        if current and current.state == 'ringing' then endCall(callId, 'missed') end
    end)
end)

RegisterNetEvent('driftzone_phone:server:answerCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call or call.state ~= 'ringing' or call.to ~= src then return sendState(src) end
    call.state = 'active'
    call.startedAt = os.time()
    TriggerEvent('driftzone_voicechat:server:startPhoneCall', callId, call.a, call.b)
    sendCallStates(call)
end)

RegisterNetEvent('driftzone_phone:server:declineCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end
    if call.state == 'ringing' and call.to == src then endCall(callId, 'declined', src) else endCall(callId, 'ended', src) end
end)

RegisterNetEvent('driftzone_phone:server:hangupCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end
    endCall(callId, 'ended', src)
end)

RegisterNetEvent('driftzone_phone:server:saveContact', function(data)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    if not uid then return end
    data = type(data) == 'table' and data or {}
    local id = tonumber(data.id or 0) or 0
    local name = trim(data.name)
    local number = cleanNumber(data.number)
    if name == '' or number == '' then return sendState(src) end

    if id > 0 then
        pcall(function()
            MySQL.update.await(('UPDATE %s SET contact_name = ?, phone_number = ?, updated_at = NOW() WHERE id = ? AND owner_uid = ?'):format(sqlName(Config.ContactsTable)), { name, number, id, uid })
        end)
    else
        pcall(function()
            MySQL.update.await(('INSERT INTO %s (owner_uid, contact_name, phone_number, blocked, created_at, updated_at) VALUES (?, ?, ?, 0, NOW(), NOW()) ON DUPLICATE KEY UPDATE contact_name = VALUES(contact_name), updated_at = NOW()'):format(sqlName(Config.ContactsTable)), { uid, name, number })
        end)
    end
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:toggleBlock', function(contactId)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    contactId = tonumber(contactId or 0) or 0
    if not uid or contactId <= 0 then return end
    pcall(function()
        MySQL.update.await(('UPDATE %s SET blocked = IF(blocked = 1, 0, 1), updated_at = NOW() WHERE id = ? AND owner_uid = ?'):format(sqlName(Config.ContactsTable)), { contactId, uid })
    end)
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:deleteContact', function(contactId)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    contactId = tonumber(contactId or 0) or 0
    if not uid or contactId <= 0 then return end
    pcall(function()
        MySQL.update.await(('DELETE FROM %s WHERE id = ? AND owner_uid = ? LIMIT 1'):format(sqlName(Config.ContactsTable)), { contactId, uid })
    end)
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:sendMessage', function(data)
    local src = source
    if not isLogged(src) then return end
    local uid = getUid(src)
    if not uid then return end
    data = type(data) == 'table' and data or {}
    local toNumber = cleanNumber(data.number)
    local text = trim(data.text)
    local msgType = tostring(data.type or 'text')
    local location = type(data.location) == 'table' and data.location or {}
    if toNumber == '' then return sendState(src) end
    if msgType ~= 'location' and text == '' then return sendState(src) end
    if msgType == 'location' then text = 'Locatie partajata' end

    local myPhone = getPhoneByUid(uid, true)
    if not myPhone then return sendState(src) end
    local targetUid = getUidByPhone(toNumber)
    if not targetUid then return sendFeedback(src, { kind = 'message_failed', sound = 'decline' }) end
    if isBlocked(targetUid, myPhone) then return sendFeedback(src, { kind = 'message_blocked', sound = 'decline' }) end

    local insertedId = 0
    pcall(function()
        insertedId = MySQL.insert.await(('INSERT INTO %s (sender_uid, receiver_uid, sender_number, receiver_number, message, message_type, location_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.MessageHistoryTable)), {
            uid, targetUid, myPhone, toNumber, text, msgType, jsonEncode(location)
        }) or 0
    end)

    sendFeedback(src, { kind = 'message_sent', sound = 'message' })
    sendState(src)

    local target = getPlayerByUid(targetUid)
    if target then
        TriggerClientEvent('driftzone_phone:client:messageReceived', target, {
            id = insertedId,
            from = myPhone,
            name = getContactName(targetUid, myPhone) or myPhone,
            text = text,
            type = msgType,
            location = location,
            sound = 'message'
        })
        sendState(target)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    UidCache[src] = nil
    local callId = PlayerCall[src]
    if callId then endCall(callId, 'ended', src) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for callId in pairs(Calls) do TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId) end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_PHONE] Loaded. Command: /' .. tostring(Config.Command or 'phone'))
end)
