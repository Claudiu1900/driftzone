RegisterNetEvent('driftzone_voicechat:server:setTalking', function(state)
    local src = source

    Player(src).state:set('dz_voice_talking', state == true, true)
    Player(src).state:set('dz_voice_mode', 'Tipa', true)
    Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
end)

AddEventHandler('playerJoining', function()
    local src = source

    Player(src).state:set('dz_voice_talking', false, true)
    Player(src).state:set('dz_voice_mode', 'Tipa', true)
    Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
end)

AddEventHandler('playerDropped', function()
    local src = source

    if Player(src) and Player(src).state then
        Player(src).state:set('dz_voice_talking', false, true)
        Player(src).state:set('dz_voice_distance', Config.VoiceMode.distance or 15.0, true)
    end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_VOICECHAT] Server loaded. Range: ' .. tostring(Config.VoiceMode.distance or 15.0))
end)
