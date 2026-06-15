local talking = false
local uiReady = false
local voiceVolume = Config.Volume.default or 100
local resourceStarted = false
local volumeFocus = false
local volumeUiVisible = true
local lastVolumeApply = 0

local phoneCallId = false
local phoneParticipants = {}
local phoneVoiceTargetActive = false
local phoneMuted = false
local phoneSpeaker = false
local phoneSpeakerListeners = {}
local phoneSpeakerSources = {}
local lastSpeakerUpdate = 0
local getProximityDistance
local getPlayerCoordsSafe

local function phoneVoiceTargetId()
    return tonumber(Config.PhoneVoiceTarget or 31) or 31
end

local function safeNative(fn)
    local ok, err = pcall(fn)
    if not ok and Config.Debug then
        print('[DRIFTZONE_VOICECHAT] native error: ' .. tostring(err))
    end
end

local function rebuildPhoneVoiceTarget()
    local target = phoneVoiceTargetId()

    safeNative(function() MumbleClearVoiceTarget(target) end)

    if phoneCallId ~= false and phoneCallId ~= nil and tostring(phoneCallId) ~= '' and talking == true then
        local myServerId = GetPlayerServerId(PlayerId())
        local added = {}
        local hasTarget = false

        local function addTarget(serverId)
            serverId = tonumber(serverId)
            if serverId and serverId > 0 and serverId ~= myServerId and not added[serverId] then
                added[serverId] = true
                safeNative(function() MumbleAddVoiceTargetPlayerByServerId(target, serverId) end)
                hasTarget = true
            end
        end

        -- Persoana din apel aude vocea indiferent de distanta, daca nu ai mute pe apel.
        if phoneMuted ~= true then
            for serverId, enabled in pairs(phoneParticipants or {}) do
                if enabled == true then addTarget(serverId) end
            end
            -- Listenerii adaugati de speaker-ul celuilalt participant.
            for serverId, enabled in pairs(phoneSpeakerListeners or {}) do
                if enabled == true then addTarget(serverId) end
            end
        end

        -- Jucatorii din jur te aud normal cand vorbesti la telefon.
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local myCoords = GetEntityCoords(ped)
            local prox = getProximityDistance()
            for _, ply in ipairs(GetActivePlayers()) do
                if ply ~= PlayerId() then
                    local sid = GetPlayerServerId(ply)
                    local coords = getPlayerCoordsSafe(ply)
                    if sid and sid ~= 0 and coords then
                        local dx = myCoords.x - coords.x
                        local dy = myCoords.y - coords.y
                        local dz = myCoords.z - coords.z
                        local distSq = dx * dx + dy * dy + dz * dz
                        if distSq <= (prox * prox) then
                            addTarget(sid)
                        end
                    end
                end
            end
        end

        if hasTarget then
            safeNative(function() MumbleSetVoiceTarget(target) end)
            phoneVoiceTargetActive = true
            return
        end
    end

    if phoneVoiceTargetActive then
        safeNative(function() MumbleSetVoiceTarget(0) end)
    end

    phoneVoiceTargetActive = false
end

local function clamp(value, min, max)
    value = tonumber(value)
    if value == nil then value = min end
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

getProximityDistance = function()
    return tonumber(Config.VoiceMode.distance or 15.0) or 15.0
end

local function isInPhoneCall()
    return phoneCallId ~= false and phoneCallId ~= nil and tostring(phoneCallId) ~= ''
end

local function getVoiceDistance()
    return getProximityDistance()
end

local function setLocalTalkerRange()
    local range = talking and getVoiceDistance() or (Config.SilentDistance or 0.0)

    MumbleSetTalkerProximity(range + 0.0)
    NetworkSetTalkerProximity(range + 0.0)

    LocalPlayer.state:set('proximity', {
        index = 1,
        distance = getProximityDistance(),
        mode = Config.VoiceMode.label or 'Tipa'
    }, true)

    LocalPlayer.state:set('dz_voice_talking', talking, true)
    LocalPlayer.state:set('dz_voice_distance', getProximityDistance(), true)
end

getPlayerCoordsSafe = function(player)
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

local function isPhoneParticipant(serverId)
    serverId = tonumber(serverId)
    return serverId and phoneParticipants[serverId] == true
end

local function shouldHearPlayer(player, myCoords)
    if player == PlayerId() then return true end

    local serverId = GetPlayerServerId(player)
    if not serverId or serverId == 0 then return false end

    -- Persoana din apel se aude mereu pentru tine.
    if isPhoneParticipant(serverId) == true then
        return true
    end

    -- Daca esti langa cineva cu speaker-ul pe apel pornit, auzi sursa din telefon.
    if phoneSpeakerSources[serverId] == true then
        return true
    end

    local remotePlayer = Player(serverId)
    local state = remotePlayer and remotePlayer.state
    if not state or state.dz_voice_talking ~= true then return false end

    local distanceLimit = tonumber(state.dz_voice_distance or getProximityDistance()) or getProximityDistance()
    if distanceLimit <= 0.0 then return false end

    local coords = getPlayerCoordsSafe(player)
    if not coords then return false end

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
                MumbleSetVolumeOverrideByServerId(serverId, 0.0)
            end
        end
    end
end

local function setVolumeUiVisible(state)
    volumeUiVisible = state == true
    SetResourceKvp('driftzone_voice_volume_ui', volumeUiVisible and 'true' or 'false')

    if not volumeUiVisible and volumeFocus then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        volumeFocus = false
    end

    sendUi({
        action = 'visibility',
        showVolume = volumeUiVisible and (Config.UI.showVolume ~= false),
        showMicIcon = Config.UI.showMicIcon ~= false,
        focus = volumeFocus,
        volume = voiceVolume
    })
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
        mode = isInPhoneCall() and 'Telefon' or (Config.VoiceMode.label or 'Tipa'),
        distance = getVoiceDistance(),
        focus = volumeFocus,
        showVolume = volumeUiVisible and (Config.UI.showVolume ~= false),
        showMicIcon = Config.UI.showMicIcon ~= false
    })
end

local function setVolumeFocus(state)
    if state == true and not volumeUiVisible then
        setVolumeUiVisible(true)
    end

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
    rebuildPhoneVoiceTarget()

    TriggerServerEvent('driftzone_voicechat:server:setTalking', talking)
    applyVolumeToPlayers()
    updateUi()
end

local function initVoice()
    local savedUi = GetResourceKvpString('driftzone_voice_volume_ui')

    if savedUi == nil or savedUi == '' then
        volumeUiVisible = Config.UI.showVolume ~= false
    else
        savedUi = tostring(savedUi):lower()
        volumeUiVisible = savedUi == 'true' or savedUi == '1' or savedUi == 'yes' or savedUi == 'on'
    end

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
    LocalPlayer.state:set('dz_voice_distance', getProximityDistance(), true)
    LocalPlayer.state:set('dz_voice_phone_call', false, true)
    rebuildPhoneVoiceTarget()

    setTalking(false)
    applyVolumeToPlayers()

    resourceStarted = true
    updateUi()

    debugPrint('initialized voicechat, distance=' .. tostring(getProximityDistance()))
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
        showVolume = volumeUiVisible and (Config.UI.showVolume ~= false),
        showMicIcon = Config.UI.showMicIcon ~= false,
        mode = isInPhoneCall() and 'Telefon' or (Config.VoiceMode.label or 'Tipa'),
        distance = getVoiceDistance(),
        focus = volumeFocus
    })

    cb({ ok = true })
end)

RegisterNUICallback('setVolume', function(data, cb)
    local value = data and data.volume
    if value ~= nil then
        saveVolume(tonumber(value))
    end
    cb({ ok = true })
end)

RegisterNUICallback('closeFocus', function(_, cb)
    setVolumeFocus(false)
    cb({ ok = true })
end)

RegisterCommand(Config.UI.toggleCommand or 'voiceui', function()
    setVolumeUiVisible(not volumeUiVisible)
end, false)

RegisterNetEvent('driftzone_voicechat:client:showVolumeUi', function()
    setVolumeUiVisible(true)
end)

RegisterNetEvent('driftzone_voicechat:client:hideVolumeUi', function()
    setVolumeUiVisible(false)
end)

RegisterNetEvent('driftzone_voicechat:client:toggleVolumeUi', function()
    setVolumeUiVisible(not volumeUiVisible)
end)


local function collectNearbyServerIds()
    local out = {}
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return out end
    local myCoords = GetEntityCoords(ped)
    local prox = getProximityDistance()
    for _, ply in ipairs(GetActivePlayers()) do
        if ply ~= PlayerId() then
            local sid = GetPlayerServerId(ply)
            local coords = getPlayerCoordsSafe(ply)
            if sid and sid ~= 0 and coords then
                local dx = myCoords.x - coords.x
                local dy = myCoords.y - coords.y
                local dz = myCoords.z - coords.z
                local distSq = dx * dx + dy * dy + dz * dz
                if distSq <= (prox * prox) then out[#out + 1] = sid end
            end
        end
    end
    return out
end

local function sendPhoneOptionsUpdate(force)
    if not isInPhoneCall() then return end
    local now = GetGameTimer()
    if force ~= true and now - lastSpeakerUpdate < 900 then return end
    lastSpeakerUpdate = now
    TriggerServerEvent('driftzone_voicechat:server:updatePhoneOptions', phoneCallId, phoneMuted == true, phoneSpeaker == true, phoneSpeaker == true and collectNearbyServerIds() or {})
end

RegisterNetEvent('driftzone_voicechat:client:setPhoneCall', function(callId, participants)
    phoneCallId = tostring(callId or '')
    phoneParticipants = {}

    if type(participants) == 'table' then
        for _, serverId in ipairs(participants) do
            serverId = tonumber(serverId)
            if serverId then phoneParticipants[serverId] = true end
        end
    end

    LocalPlayer.state:set('dz_voice_phone_call', phoneCallId, true)
    phoneMuted = false
    phoneSpeaker = false
    phoneSpeakerListeners = {}
    phoneSpeakerSources = {}
    setLocalTalkerRange()
    rebuildPhoneVoiceTarget()
    applyVolumeToPlayers()
    updateUi()
end)

RegisterNetEvent('driftzone_voicechat:client:clearPhoneCall', function()
    phoneCallId = false
    phoneParticipants = {}
    phoneMuted = false
    phoneSpeaker = false
    phoneSpeakerListeners = {}
    phoneSpeakerSources = {}

    LocalPlayer.state:set('dz_voice_phone_call', false, true)
    rebuildPhoneVoiceTarget()
    setLocalTalkerRange()
    applyVolumeToPlayers()
    updateUi()
end)


RegisterNetEvent('driftzone_voicechat:client:setPhoneOptions', function(options)
    options = type(options) == 'table' and options or {}
    phoneMuted = options.muted == true
    phoneSpeaker = options.speaker == true
    rebuildPhoneVoiceTarget()
    sendPhoneOptionsUpdate(true)
end)

RegisterNetEvent('driftzone_voicechat:client:setPhoneSpeakerListeners', function(callId, listeners)
    if tostring(callId or '') ~= tostring(phoneCallId or '') then return end
    phoneSpeakerListeners = {}
    if type(listeners) == 'table' then
        for _, serverId in ipairs(listeners) do
            serverId = tonumber(serverId)
            if serverId and serverId > 0 then phoneSpeakerListeners[serverId] = true end
        end
    end
    rebuildPhoneVoiceTarget()
end)

RegisterNetEvent('driftzone_voicechat:client:addPhoneSpeakerSource', function(callId, sourceServerId)
    if tostring(callId or '') == '' then return end
    sourceServerId = tonumber(sourceServerId)
    if sourceServerId and sourceServerId > 0 then
        phoneSpeakerSources[sourceServerId] = true
        applyVolumeToPlayers()
    end
end)

RegisterNetEvent('driftzone_voicechat:client:removePhoneSpeakerSource', function(_, sourceServerId)
    sourceServerId = tonumber(sourceServerId)
    if sourceServerId and sourceServerId > 0 then
        phoneSpeakerSources[sourceServerId] = nil
        applyVolumeToPlayers()
    end
end)

RegisterCommand('voicevol', function()
    if not volumeUiVisible then
        setVolumeUiVisible(true)
    end

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
                if isInPhoneCall() then
                    if talking then rebuildPhoneVoiceTarget() end
                    if phoneSpeaker then sendPhoneOptionsUpdate(false) end
                end
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
    LocalPlayer.state:set('dz_voice_phone_call', false, true)
    phoneCallId = false
    phoneParticipants = {}
    phoneMuted = false
    phoneSpeaker = false
    phoneSpeakerListeners = {}
    phoneSpeakerSources = {}
    rebuildPhoneVoiceTarget()
    MumbleSetTalkerProximity(0.0)
    NetworkSetTalkerProximity(0.0)
    SetNuiFocus(false, false)
end)

exports('SetVolume', saveVolume)

exports('ShowVolumeUi', function()
    setVolumeUiVisible(true)
end)

exports('HideVolumeUi', function()
    setVolumeUiVisible(false)
end)

exports('ToggleVolumeUi', function()
    setVolumeUiVisible(not volumeUiVisible)
end)

exports('IsVolumeUiVisible', function()
    return volumeUiVisible
end)

exports('GetVolume', function()
    return voiceVolume
end)

exports('SetTalking', setTalking)

exports('IsTalking', function()
    return talking
end)

exports('SetPhoneCall', function(callId, participants)
    TriggerEvent('driftzone_voicechat:client:setPhoneCall', callId, participants)
end)

exports('ClearPhoneCall', function()
    TriggerEvent('driftzone_voicechat:client:clearPhoneCall')
end)

exports('SetPhoneOptions', function(options)
    TriggerEvent('driftzone_voicechat:client:setPhoneOptions', options or {})
end)
