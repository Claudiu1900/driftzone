local talking = false
local uiReady = false
local voiceVolume = Config.Volume.default or 100
local resourceStarted = false
local volumeFocus = false
local lastVolumeApply = 0

local function clamp(value, min, max)
    value = tonumber(value)

    if value == nil then
        value = min
    end

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

local function getVoiceDistance()
    return tonumber(Config.VoiceMode.distance or 15.0) or 15.0
end

local function setLocalTalkerRange()
    local range = talking and getVoiceDistance() or (Config.SilentDistance or 0.0)

    -- Native FiveM/Mumble proximity.
    MumbleSetTalkerProximity(range + 0.0)
    NetworkSetTalkerProximity(range + 0.0)

    LocalPlayer.state:set('proximity', {
        index = 1,
        distance = getVoiceDistance(),
        mode = Config.VoiceMode.label or 'Tipa'
    }, true)

    LocalPlayer.state:set('dz_voice_talking', talking, true)
    LocalPlayer.state:set('dz_voice_distance', getVoiceDistance(), true)
end

local function getPlayerCoordsSafe(player)
    local ped = GetPlayerPed(player)

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end

    return GetEntityCoords(ped)
end

local function shouldHearPlayer(player, myCoords)
    if player == PlayerId() then
        return true
    end

    local serverId = GetPlayerServerId(player)

    if not serverId or serverId == 0 then
        return false
    end

    local remotePlayer = Player(serverId)
    local state = remotePlayer and remotePlayer.state

    if not state or state.dz_voice_talking ~= true then
        return false
    end

    local distanceLimit = tonumber(state.dz_voice_distance or getVoiceDistance()) or getVoiceDistance()
    if distanceLimit <= 0.0 then
        return false
    end

    local coords = getPlayerCoordsSafe(player)
    if not coords then
        return false
    end

    local dx = myCoords.x - coords.x
    local dy = myCoords.y - coords.y
    local dz = myCoords.z - coords.z
    local distSq = dx * dx + dy * dy + dz * dz

    return distSq <= (distanceLimit * distanceLimit)
end

local function applyVolumeToPlayers()
    local volume = clamp(voiceVolume, Config.Volume.min or 0, Config.Volume.max or 100) / 100.0
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)

    for i = 1, #players do
        local ply = players[i]
        local serverId = GetPlayerServerId(ply)

        if serverId and serverId ~= 0 then
            if shouldHearPlayer(ply, myCoords) then
                MumbleSetVolumeOverrideByServerId(serverId, volume + 0.0)
            else
                -- Hard mute pe client pentru jucatorii care nu vorbesc sau sunt peste distanta.
                MumbleSetVolumeOverrideByServerId(serverId, 0.0)
            end
        end
    end
end

local function saveVolume(value)
    voiceVolume = math.floor(clamp(value, Config.Volume.min or 0, Config.Volume.max or 100) + 0.5)
    SetResourceKvpInt('driftzone_voice_volume', voiceVolume)
    applyVolumeToPlayers()

    sendUi({
        action = 'volume',
        volume = voiceVolume,
        focus = volumeFocus
    })
end

local function updateUi()
    sendUi({
        action = 'state',
        talking = talking,
        volume = voiceVolume,
        mainColor = Config.MainColor,
        mode = Config.VoiceMode.label or 'Tipa',
        distance = getVoiceDistance(),
        focus = volumeFocus
    })
end

local function setVolumeFocus(state)
    volumeFocus = state == true

    SetNuiFocus(volumeFocus, volumeFocus)
    SetNuiFocusKeepInput(false)

    sendUi({
        action = 'focus',
        focus = volumeFocus,
        volume = voiceVolume
    })
end

local function setTalking(state)
    state = state == true

    if talking == state then return end

    talking = state
    setLocalTalkerRange()

    TriggerServerEvent('driftzone_voicechat:server:setTalking', talking)
    applyVolumeToPlayers()
    updateUi()
end

local function initVoice()
    local savedVolume = GetResourceKvpInt('driftzone_voice_volume')

    if savedVolume ~= nil and savedVolume >= 0 then
        voiceVolume = math.floor(clamp(savedVolume, Config.Volume.min or 0, Config.Volume.max or 100) + 0.5)
    else
        voiceVolume = math.floor(clamp(Config.Volume.default or 100, Config.Volume.min or 0, Config.Volume.max or 100) + 0.5)
        SetResourceKvpInt('driftzone_voice_volume', voiceVolume)
    end

    MumbleSetActive(true)
    MumbleSetAudioInputIntent(`speech`)

    LocalPlayer.state:set('voiceIntent', 'speech', true)
    LocalPlayer.state:set('dz_voice_distance', getVoiceDistance(), true)

    setTalking(false)
    applyVolumeToPlayers()

    resourceStarted = true
    updateUi()

    debugPrint('initialized loud mode, distance=' .. tostring(getVoiceDistance()))
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
        mode = Config.VoiceMode.label or 'Tipa',
        distance = getVoiceDistance(),
        focus = volumeFocus
    })

    cb({ ok = true })
end)

RegisterNUICallback('setVolume', function(data, cb)
    local value = data and data.volume

    -- IMPORTANT: 0 este volum valid. Nu cade pe default 100.
    if value ~= nil then
        saveVolume(tonumber(value))
    end

    cb({ ok = true })
end)

RegisterNUICallback('closeFocus', function(_, cb)
    setVolumeFocus(false)
    cb({ ok = true })
end)

RegisterCommand('voicevol', function()
    setVolumeFocus(true)

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

            if now - lastVolumeApply >= (Config.Volume.refreshMs or 250) then
                lastVolumeApply = now
                applyVolumeToPlayers()
            end

            Wait(100)
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

            Wait(90)
        else
            Wait(450)
        end
    end
end)

CreateThread(function()
    while true do
        if volumeFocus then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 243, true)

            -- ESC sau ` inchide cursorul.
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 243) then
                setVolumeFocus(false)
            end

            Wait(0)
        else
            Wait(400)
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
