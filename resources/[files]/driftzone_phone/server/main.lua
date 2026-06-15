local Calls = {}
local PlayerCall = {}
local PhoneCache = {}
local UidCache = {}
local UserColumns = nil
local NextCallId = 0

local function debugPrint(...)
    if Config.Debug then
        print('[DRIFTZONE_PHONE]', ...)
    end
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function cleanNumber(number)
    number = tostring(number or '')
    number = number:gsub('%s+', '')
    number = number:gsub('[^%d]', '')
    return number
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

local function sendFeedback(src, payload)
    src = tonumber(src)
    if not src or src <= 0 then return end
    TriggerClientEvent('driftzone_phone:client:feedback', src, payload or {})
end

local function getUserColumns()
    if UserColumns then return UserColumns end
    UserColumns = {}

    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM %s'):format(sqlName(Config.UsersTable or 'users')), {}) or {}
    end)

    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row and row.Field then
                UserColumns[tostring(row.Field)] = true
            end
        end
    end

    return UserColumns
end

local function getPhoneColumns()
    local cols = getUserColumns()
    local out = {}
    local added = {}

    local function add(name)
        name = tostring(name or '')
        if name ~= '' and not added[name] and (cols[name] == true or next(cols) == nil) then
            added[name] = true
            out[#out + 1] = name
        end
    end

    add(Config.PhoneColumn or 'phonenumber')
    for _, name in ipairs(Config.PhoneColumns or {}) do add(name) end

    if #out <= 0 then
        out[1] = Config.PhoneColumn or 'phonenumber'
    end

    return out
end

local function getUid(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end

    local state = Player(src).state
    local stateKeys = { 'dz_uid', 'uid', 'user_id', 'userId', 'driftzone_uid' }
    for _, key in ipairs(stateKeys) do
        local value = state and tonumber(state[key])
        if value and value > 0 then return value end
    end

    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then
        return cached.uid
    end

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
    if not force and cached and cached.expires > GetGameTimer() then
        return cached.phone
    end

    local phone = nil
    local phoneCols = getPhoneColumns()

    for _, col in ipairs(phoneCols) do
        local ok, row = pcall(function()
            return MySQL.single.await(
                ('SELECT %s AS phone FROM %s WHERE %s = ? LIMIT 1'):format(
                    sqlName(col),
                    sqlName(Config.UsersTable or 'users'),
                    sqlName(Config.UsersIdColumn or 'uid')
                ),
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

    local phoneCols = getPhoneColumns()
    for _, col in ipairs(phoneCols) do
        local expr = normalizeSqlExpr(col)
        local ok, row = pcall(function()
            return MySQL.single.await(
                ('SELECT %s AS uid FROM %s WHERE %s = ? LIMIT 1'):format(
                    sqlName(Config.UsersIdColumn or 'uid'),
                    sqlName(Config.UsersTable or 'users'),
                    expr
                ),
                { phone }
            )
        end)

        if ok and row and tonumber(row.uid) then
            return tonumber(row.uid)
        end
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
    phone = cleanNumber(phone)
    if phone == '' then return nil, nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local uid = src and getUid(src)
        local p = uid and getPhoneByUid(uid, false) or nil
        if p and cleanNumber(p) == phone then
            return src, uid
        end
    end

    return nil, nil
end

local function getCallForPlayer(src)
    local callId = PlayerCall[tonumber(src)]
    if not callId then return nil, nil end

    local call = Calls[callId]
    if not call then
        PlayerCall[tonumber(src)] = nil
        return nil, nil
    end

    return callId, call
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
        startedAt = 0
    }

    if call then
        local otherSrc = call.a == src and call.b or call.a
        local otherPhone = call.a == src and call.bPhone or call.aPhone

        state.inCall = true
        state.active = call.state == 'active'
        state.incoming = call.state == 'ringing' and call.to == src
        state.outgoing = call.state == 'ringing' and call.from == src
        state.otherNumber = tostring(otherPhone or '')
        state.otherName = GetPlayerName(otherSrc) or 'Unknown'
        state.callId = callId
        state.startedAt = call.startedAt or 0
    end

    return state
end

local function sendState(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    TriggerClientEvent('driftzone_phone:client:state', src, publicCallStateFor(src))
end

local function sendCallStates(call)
    if not call then return end
    sendState(call.a)
    sendState(call.b)
end

local function otherParticipant(call, src)
    if not call then return nil end
    src = tonumber(src)
    if call.a == src then return call.b end
    if call.b == src then return call.a end
    return nil
end

local function endCall(callId, reason, endedBy)
    local call = Calls[callId]
    if not call then return end

    Calls[callId] = nil
    PlayerCall[call.a] = nil
    PlayerCall[call.b] = nil

    TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId)

    if reason == 'missed' then
        sendFeedback(call.from, {
            kind = 'missed',
            title = 'Apel nepreluat',
            text = 'Nu a raspuns nimeni.',
            sound = 'decline'
        })
    elseif reason == 'declined' then
        sendFeedback(call.from, {
            kind = 'declined',
            title = 'Apel respins',
            text = 'Persoana a inchis apelul.',
            sound = 'decline'
        })
    elseif reason == 'busy' then
        sendFeedback(call.from, {
            kind = 'busy',
            title = 'Linie ocupata',
            text = 'Persoana este deja intr-un apel.',
            sound = 'decline'
        })
    elseif reason == 'ended' then
        local other = endedBy and otherParticipant(call, endedBy) or nil
        if other then
            sendFeedback(other, {
                kind = 'ended',
                title = 'Apel inchis',
                text = 'Persoana a inchis apelul.',
                sound = 'decline'
            })
        end
    end

    sendState(call.a)
    sendState(call.b)
end

local function makeCallId()
    NextCallId = NextCallId + 1
    return ('dzcall_%s_%s'):format(os.time(), NextCallId)
end

local function failCall(src, title, text)
    sendFeedback(src, {
        kind = 'error',
        title = title or 'Apel esuat',
        text = text or 'Nu se poate efectua apelul.',
        sound = 'decline'
    })
    sendState(src)
end

RegisterNetEvent('driftzone_phone:server:requestState', function()
    local src = source
    if not isLogged(src) then return end
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:startCall', function(rawNumber)
    local src = source
    if not isLogged(src) then
        return failCall(src, 'Telefon blocat', 'Trebuie sa fii logat.')
    end

    if PlayerCall[src] then
        return failCall(src, 'Linie ocupata', 'Esti deja intr-un apel.')
    end

    local number = cleanNumber(rawNumber)
    local minLen = tonumber(Config.PhoneNumberMinLength or 1) or 1
    local maxLen = tonumber(Config.PhoneNumberMaxLength or 32) or 32

    if number == '' or #number < minLen or #number > maxLen then
        return failCall(src, 'Numar invalid', 'Scrie un numar de telefon valid.')
    end

    local uid = getUid(src)
    local myPhone = uid and getPhoneByUid(uid, true) or nil
    if not myPhone then
        return failCall(src, 'Numar lipsa', 'Nu ai users.phonenumber setat.')
    end

    if number == myPhone then
        return failCall(src, 'Numar invalid', 'Nu te poti suna singur.')
    end

    local target, targetUid = getPlayerByPhone(number)
    if not target then
        targetUid = getUidByPhone(number)
        if targetUid then target = getPlayerByUid(targetUid) end
    end

    if not targetUid then
        return failCall(src, 'Numar inexistent', 'Numarul nu exista in baza de date.')
    end

    if not target then
        return failCall(src, 'Telefon indisponibil', 'Persoana nu este pe server.')
    end

    if PlayerCall[target] then
        local fake = { from = src }
        return failCall(src, 'Linie ocupata', 'Persoana este deja intr-un apel.')
    end

    local callId = makeCallId()
    local call = {
        id = callId,
        a = src,
        b = target,
        from = src,
        to = target,
        aPhone = myPhone,
        bPhone = number,
        state = 'ringing',
        createdAt = os.time(),
        startedAt = 0
    }

    Calls[callId] = call
    PlayerCall[src] = callId
    PlayerCall[target] = callId

    sendFeedback(src, {
        kind = 'ringing',
        title = 'Se apeleaza',
        text = 'Suni la ' .. number .. '.',
        sound = 'ring'
    })

    TriggerClientEvent('driftzone_phone:client:incoming', target, publicCallStateFor(target))
    sendCallStates(call)

    SetTimeout(tonumber(Config.CallTimeoutMs or 30000) or 30000, function()
        local current = Calls[callId]
        if current and current.state == 'ringing' then
            endCall(callId, 'missed')
        end
    end)
end)

RegisterNetEvent('driftzone_phone:server:answerCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call or call.state ~= 'ringing' or call.to ~= src then
        return sendState(src)
    end

    call.state = 'active'
    call.startedAt = os.time()

    TriggerEvent('driftzone_voicechat:server:startPhoneCall', callId, call.a, call.b)
    sendCallStates(call)
end)

RegisterNetEvent('driftzone_phone:server:declineCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end

    if call.state == 'ringing' and call.to == src then
        endCall(callId, 'declined', src)
    else
        endCall(callId, 'ended', src)
    end
end)

RegisterNetEvent('driftzone_phone:server:hangupCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end
    endCall(callId, 'ended', src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    UidCache[src] = nil

    local callId = PlayerCall[src]
    if callId then
        endCall(callId, 'ended', src)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for callId in pairs(Calls) do
        TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId)
    end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_PHONE] Loaded. Command: /' .. tostring(Config.Command or 'phone'))
end)
