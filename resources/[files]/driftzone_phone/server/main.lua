local Calls = {}
local PlayerCall = {}
local PhoneCache = {}
local UidCache = {}
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

local function notify(src, typ, msg, duration)
    if src and tonumber(src) and tonumber(src) > 0 then
        TriggerClientEvent('driftzone_phone:client:notify', src, typ or 'info', tostring(msg or ''), duration or 4500)
    end
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
            function() return exports[res]:getUserId(src) end
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
        local ok, result = pcall(function()
            return exports[res]:IsLoggedIn(src)
        end)
        if ok and result == true then return true end
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

    local row = MySQL.single.await(
        ('SELECT %s AS phone FROM %s WHERE %s = ? LIMIT 1'):format(
            sqlName(Config.PhoneColumn or 'phonenumber'),
            sqlName(Config.UsersTable or 'users'),
            sqlName(Config.UsersIdColumn or 'uid')
        ),
        { uid }
    )

    local phone = row and cleanNumber(row.phone) or nil
    if phone == '' then phone = nil end

    PhoneCache[uid] = { phone = phone, expires = GetGameTimer() + 15000 }
    return phone
end

local function getUidByPhone(phone)
    phone = cleanNumber(phone)
    if phone == '' then return nil end

    local row = MySQL.single.await(
        ('SELECT %s AS uid FROM %s WHERE %s = ? LIMIT 1'):format(
            sqlName(Config.UsersIdColumn or 'uid'),
            sqlName(Config.UsersTable or 'users'),
            sqlName(Config.PhoneColumn or 'phonenumber')
        ),
        { phone }
    )

    return row and tonumber(row.uid) or nil
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)
    if not uid then return nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getUid(src) == uid then
            return src
        end
    end

    return nil
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
    local myPhone = uid and getPhoneByUid(uid) or nil
    local callId, call = getCallForPlayer(src)

    local state = {
        myNumber = myPhone or '',
        inCall = false,
        incoming = false,
        outgoing = false,
        active = false,
        otherNumber = '',
        otherName = '',
        callId = nil
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
    if not src or src <= 0 then return end
    TriggerClientEvent('driftzone_phone:client:state', src, publicCallStateFor(src))
end

local function sendCallStates(call)
    if not call then return end
    sendState(call.a)
    sendState(call.b)
end

local function endCall(callId, reason)
    local call = Calls[callId]
    if not call then return end

    Calls[callId] = nil
    PlayerCall[call.a] = nil
    PlayerCall[call.b] = nil

    TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId)

    if reason == 'missed' then
        notify(call.from, 'warning', 'Apel nepreluat.', 4500)
        notify(call.to, 'warning', 'Apel ratat.', 4500)
    elseif reason == 'declined' then
        notify(call.from, 'warning', 'Apel respins.', 4500)
    elseif reason == 'busy' then
        notify(call.from, 'warning', 'Linia este ocupata.', 4500)
    elseif reason == 'ended' then
        notify(call.a, 'info', 'Apel incheiat.', 3500)
        notify(call.b, 'info', 'Apel incheiat.', 3500)
    end

    sendState(call.a)
    sendState(call.b)
end

local function makeCallId()
    NextCallId = NextCallId + 1
    return ('dzcall_%s_%s'):format(os.time(), NextCallId)
end

RegisterNetEvent('driftzone_phone:server:requestState', function()
    local src = source
    if not isLogged(src) then return end
    sendState(src)
end)

RegisterNetEvent('driftzone_phone:server:startCall', function(rawNumber)
    local src = source
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.', 4000) end

    if PlayerCall[src] then
        return notify(src, 'warning', 'Esti deja intr-un apel.', 4000)
    end

    local number = cleanNumber(rawNumber)
    local minLen = tonumber(Config.PhoneNumberMinLength or 3) or 3
    local maxLen = tonumber(Config.PhoneNumberMaxLength or 16) or 16

    if #number < minLen or #number > maxLen then
        return notify(src, 'warning', 'Numar de telefon invalid.', 4000)
    end

    local uid = getUid(src)
    local myPhone = uid and getPhoneByUid(uid, true) or nil
    if not myPhone then
        return notify(src, 'warning', 'Nu ai numar de telefon setat.', 4500)
    end

    if number == myPhone then
        return notify(src, 'warning', 'Nu te poti suna singur.', 4000)
    end

    local targetUid = getUidByPhone(number)
    if not targetUid then
        return notify(src, 'warning', 'Numarul nu exista.', 4500)
    end

    local target = getPlayerByUid(targetUid)
    if not target then
        return notify(src, 'warning', 'Telefonul este inchis sau persoana nu este online.', 4500)
    end

    if PlayerCall[target] then
        return notify(src, 'warning', 'Linia este ocupata.', 4500)
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

    notify(src, 'info', 'Suni la ' .. number .. '...', 4500)
    TriggerClientEvent('driftzone_phone:client:incoming', target, publicCallStateFor(target))
    notify(target, 'info', 'Te suna ' .. myPhone .. '.', 6000)

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

    notify(call.a, 'success', 'Apel conectat.', 3500)
    notify(call.b, 'success', 'Apel conectat.', 3500)
    sendCallStates(call)
end)

RegisterNetEvent('driftzone_phone:server:declineCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end

    if call.state == 'ringing' and call.to == src then
        endCall(callId, 'declined')
    else
        endCall(callId, 'ended')
    end
end)

RegisterNetEvent('driftzone_phone:server:hangupCall', function()
    local src = source
    local callId, call = getCallForPlayer(src)
    if not call then return sendState(src) end
    endCall(callId, 'ended')
end)

AddEventHandler('playerDropped', function()
    local src = source
    UidCache[src] = nil

    local callId = PlayerCall[src]
    if callId then
        endCall(callId, 'ended')
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
    print('[DRIFTZONE_PHONE] Prototype loaded. Command: /' .. tostring(Config.Command or 'phone'))
end)
