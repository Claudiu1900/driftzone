local talking = false
local uiReady = false
local voiceVolume = Config.Volume.default or 100
local resourceStarted = false
local lastVolumeApply = 0

local function clamp(value, min, max)
    value = tonumber(value) or min

    if value < min then return min end
    if value > max then return max end

    return value
end

local function debugPrint(...)
    if Config.Debug then
        print('[DRIFTZONE_VOICECHAT]', ...)
    end
end

local function sendUi(payload)
    if not uiReady then return end

    SendNUIMessage(payload)
end

local function setTalkerRange()
    local range = talking and (Config.VoiceMode.distance or 18.0) or (Config.SilentDistance or 0.0)

    MumbleSetTalkerProximity((tonumber(range) or 0.0) + 0.0)
    NetworkSetTalkerProximity((tonumber(range) or 0.0) + 0.0)

    LocalPlayer.state:set('proximity', {
        index = 1,
        distance = Config.VoiceMode.distance or 18.0,
        mode = Config.VoiceMode.label or 'Tipa'
    }, true)
end

local function applyVolumeToPlayers()
    local volume = clamp(voiceVolume, Config.Volume.min or 0, Config.Volume.max or 100) / 100.0
    local players = GetActivePlayers()

    for i = 1, #players do
        local ply = players[i]
        local serverId = GetPlayerServerId(ply)

        if serverId and serverId ~= 0 then
            MumbleSetVolumeOverrideByServerId(serverId, volume + 0.0)
        end
    end
end

local function saveVolume(value)
    voiceVolume = clamp(value, Config.Volume.min or 0, Config.Volume.max or 100)
    SetResourceKvpInt('driftzone_voice_volume', voiceVolume)
    applyVolumeToPlayers()

    sendUi({
        action = 'volume',
        volume = voiceVolume
    })
end

local function updateUi()
    sendUi({
        action = 'state',
        talking = talking,
        volume = voiceVolume,
        mainColor = Config.MainColor,
        mode = Config.VoiceMode.label or 'Tipa'
    })
end

local function setTalking(state)
    state = state == true

    if talking == state then return end

    talking = state
    setTalkerRange()

    TriggerServerEvent('driftzone_voicechat:server:setTalking', talking)
    updateUi()
end

local function initVoice()
    local savedVolume = GetResourceKvpInt('driftzone_voice_volume')

    if savedVolume and savedVolume >= 0 then
        voiceVolume = clamp(savedVolume, Config.Volume.min or 0, Config.Volume.max or 100)
    else
        voiceVolume = clamp(Config.Volume.default or 100, Config.Volume.min or 0, Config.Volume.max or 100)
        SetResourceKvpInt('driftzone_voice_volume', voiceVolume)
    end

    MumbleSetActive(true)
    MumbleSetAudioInputIntent(`speech`)

    LocalPlayer.state:set('voiceIntent', 'speech', true)

    setTalking(false)
    applyVolumeToPlayers()

    resourceStarted = true
    updateUi()

    debugPrint('initialized loud mode')
end

RegisterCommand(Config.TalkCommand, function()
    setTalking(true)
end, false)

RegisterCommand('-driftzone_voice_talk', function()
    setTalking(false)
end, false)

RegisterKeyMapping(Config.TalkCommand, 'DriftZone Voice: Push To Talk', 'keyboard', Config.TalkKey or 'N')

RegisterNUICallback('ready', function(_, cb)
    uiReady = true

    sendUi({
        action = 'setup',
        talking = talking,
        volume = voiceVolume,
        mainColor = Config.MainColor,
        showVolume = Config.UI.showVolume,
        showMicIcon = Config.UI.showMicIcon,
        mode = Config.VoiceMode.label or 'Tipa'
    })

    cb({ ok = true })
end)

RegisterNUICallback('setVolume', function(data, cb)
    saveVolume(tonumber(data and data.volume or voiceVolume) or voiceVolume)
    cb({ ok = true })
end)

RegisterNUICallback('closeFocus', function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterCommand('voicevol', function()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    sendUi({
        action = 'volume',
        volume = voiceVolume,
        focus = true
    })
end, false)

CreateThread(function()
    Wait(900)
    initVoice()
end)

CreateThread(function()
    while true do
        if resourceStarted then
            local now = GetGameTimer()

            if now - lastVolumeApply >= (Config.Volume.refreshMs or 2000) then
                lastVolumeApply = now
                applyVolumeToPlayers()
            end

            Wait(900)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if talking then
            -- Safety fallback: daca key-up nu ajunge, opreste vorbitul cand N nu mai este apasat.
            if not IsControlPressed(0, 249) and not IsDisabledControlPressed(0, 249) then
                setTalking(false)
            end

            Wait(120)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    setTalking(false)
    MumbleSetTalkerProximity(0.0)
    NetworkSetTalkerProximity(0.0)
    SetNuiFocus(false, false)
end)

exports('SetVolume', saveVolume)

exports('GetVolume', function()
    return voiceVolume
end)

exports('SetTalking', setTalking)

exports('IsTalking', function()
    return talking
end)
