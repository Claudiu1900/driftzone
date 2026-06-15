local PhoneCalls = {}
local PhoneOptions = {}

RegisterNetEvent('driftzone_voicechat:server:setTalking', function(state)
    local src = source

    Player(src).state:set('dz_voice_talking', state == true, true)
    Player(src).state:set('dz_voice_mode', 'Tipa', true)
    Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
end)

local function clearPlayerPhoneState(src)
    if not src or src <= 0 then return end
    if not Player(src) or not Player(src).state then return end

    Player(src).state:set('dz_voice_phone_call', false, true)
    Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
    TriggerClientEvent('driftzone_voicechat:client:clearPhoneCall', src)
end

local function clearSpeakerState(callId)
    local opts = PhoneOptions[callId]
    if not opts then return end
    local call = PhoneCalls[callId]
    for src, data in pairs(opts) do
        local other = nil
        if call then other = call.a == src and call.b or call.a end
        if type(data.listeners) == 'table' and other then
            for listener in pairs(data.listeners) do
                TriggerClientEvent('driftzone_voicechat:client:removePhoneSpeakerSource', listener, callId, other)
            end
        end
    end
    PhoneOptions[callId] = nil
end

AddEventHandler('driftzone_voicechat:server:startPhoneCall', function(callId, a, b)
    callId = tostring(callId or '')
    a = tonumber(a)
    b = tonumber(b)

    if callId == '' or not a or not b then return end

    PhoneCalls[callId] = { a = a, b = b }
    PhoneOptions[callId] = {}

    if Player(a) and Player(a).state then
        Player(a).state:set('dz_voice_phone_call', callId, true)
        Player(a).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
    end

    if Player(b) and Player(b).state then
        Player(b).state:set('dz_voice_phone_call', callId, true)
        Player(b).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
    end

    TriggerClientEvent('driftzone_voicechat:client:setPhoneCall', a, callId, { a, b })
    TriggerClientEvent('driftzone_voicechat:client:setPhoneCall', b, callId, { a, b })
end)

AddEventHandler('driftzone_voicechat:server:endPhoneCall', function(callId)
    callId = tostring(callId or '')
    local call = PhoneCalls[callId]
    if not call then return end

    clearSpeakerState(callId)
    PhoneCalls[callId] = nil
    clearPlayerPhoneState(call.a)
    clearPlayerPhoneState(call.b)
end)


RegisterNetEvent('driftzone_voicechat:server:updatePhoneOptions', function(callId, muted, speaker, listeners)
    local src = source
    callId = tostring(callId or '')
    local call = PhoneCalls[callId]
    if not call or (call.a ~= src and call.b ~= src) then return end

    local other = call.a == src and call.b or call.a
    PhoneOptions[callId] = PhoneOptions[callId] or {}
    local old = PhoneOptions[callId][src] or { listeners = {} }
    local oldListeners = old.listeners or {}
    local newListeners = {}

    if speaker == true and type(listeners) == 'table' then
        for _, sid in ipairs(listeners) do
            sid = tonumber(sid)
            if sid and sid > 0 and sid ~= src and sid ~= other then
                newListeners[sid] = true
            end
        end
    end

    for sid in pairs(oldListeners) do
        if not newListeners[sid] then
            TriggerClientEvent('driftzone_voicechat:client:removePhoneSpeakerSource', sid, callId, other)
        end
    end

    for sid in pairs(newListeners) do
        TriggerClientEvent('driftzone_voicechat:client:addPhoneSpeakerSource', sid, callId, other)
    end

    PhoneOptions[callId][src] = {
        muted = muted == true,
        speaker = speaker == true,
        listeners = newListeners
    }

    local list = {}
    for sid in pairs(newListeners) do list[#list + 1] = sid end
    TriggerClientEvent('driftzone_voicechat:client:setPhoneSpeakerListeners', other, callId, list)
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
