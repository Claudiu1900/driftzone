local PhoneCalls = {}

RegisterNetEvent('driftzone_voicechat:server:setTalking', function(state)
    local src = source

    Player(src).state:set('dz_voice_talking', state == true, true)
    Player(src).state:set('dz_voice_mode', 'Tipa', true)

    local phoneCall = Player(src).state.dz_voice_phone_call
    if phoneCall ~= nil and phoneCall ~= false and tostring(phoneCall) ~= '' then
        Player(src).state:set('dz_voice_distance', Config.PhoneCallDistance or 99999.0, true)
    else
        Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
    end
end)

local function clearPlayerPhoneState(src)
    if not src or src <= 0 then return end
    if not Player(src) or not Player(src).state then return end

    Player(src).state:set('dz_voice_phone_call', false, true)
    Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
    TriggerClientEvent('driftzone_voicechat:client:clearPhoneCall', src)
end

AddEventHandler('driftzone_voicechat:server:startPhoneCall', function(callId, a, b)
    callId = tostring(callId or '')
    a = tonumber(a)
    b = tonumber(b)

    if callId == '' or not a or not b then return end

    PhoneCalls[callId] = { a = a, b = b }

    if Player(a) and Player(a).state then
        Player(a).state:set('dz_voice_phone_call', callId, true)
        Player(a).state:set('dz_voice_distance', Config.PhoneCallDistance or 99999.0, true)
    end

    if Player(b) and Player(b).state then
        Player(b).state:set('dz_voice_phone_call', callId, true)
        Player(b).state:set('dz_voice_distance', Config.PhoneCallDistance or 99999.0, true)
    end

    TriggerClientEvent('driftzone_voicechat:client:setPhoneCall', a, callId, { a, b })
    TriggerClientEvent('driftzone_voicechat:client:setPhoneCall', b, callId, { a, b })
end)

AddEventHandler('driftzone_voicechat:server:endPhoneCall', function(callId)
    callId = tostring(callId or '')
    local call = PhoneCalls[callId]
    if not call then return end

    PhoneCalls[callId] = nil
    clearPlayerPhoneState(call.a)
    clearPlayerPhoneState(call.b)
end)

AddEventHandler('playerJoining', function()
    local src = source

    Player(src).state:set('dz_voice_talking', false, true)
    Player(src).state:set('dz_voice_mode', 'Tipa', true)
    Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
    Player(src).state:set('dz_voice_phone_call', false, true)
end)

AddEventHandler('playerDropped', function()
    local src = source

    for callId, call in pairs(PhoneCalls) do
        if call.a == src or call.b == src then
            TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId)
        end
    end

    if Player(src) and Player(src).state then
        Player(src).state:set('dz_voice_talking', false, true)
        Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
        Player(src).state:set('dz_voice_phone_call', false, true)
    end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_VOICECHAT] Server loaded. Range: ' .. tostring(Config.VoiceMode.distance or 15.0) .. ', phone calls enabled.')
end)
