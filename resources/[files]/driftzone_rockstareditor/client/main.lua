local recording = false
local processing = false
local lastUse = 0

local function notify(notifyType, message, duration)
    if Config.Notify and Config.Notify.enabled then
        TriggerEvent(Config.Notify.event or 'client:notify', notifyType or 'info', duration or 5000, tostring(message or ''))
    else
        print('[DRIFTZONE_EDITOR] ' .. tostring(message or ''))
    end
end

local function nativeIsRecording()
    local ok, result = pcall(function()
        return IsRecording()
    end)

    return ok and result == true
end

local function syncRecordingState()
    -- IsRecording poate raspunde cu delay, de asta il folosim doar ca backup.
    if nativeIsRecording() then
        recording = true
    end

    return recording
end

local function startRecording()
    if processing then return false end

    processing = true

    -- Daca Rockstar Editor deja inregistreaza, sincronizam state-ul si nu mai dam start inca o data.
    if nativeIsRecording() or recording then
        recording = true
        processing = false
        notify('info', 'Rockstar Editor recording este deja pornit.')
        return true
    end

    -- 1 = start Rockstar Editor recording.
    StartRecording(1)

    -- Nu asteptam confirmare stricta de la IsRecording, fiindca pe unele build-uri native-ul raspunde cu delay.
    SetTimeout(450, function()
        recording = true
        processing = false
        notify('success', Config.Messages.started)
    end)

    return true
end

local function stopRecording()
    if processing then return false end

    processing = true

    -- Daca state-ul nostru crede ca merge SAU native-ul zice ca merge, incercam stop.
    if recording or nativeIsRecording() then
        if Config.SaveClipOnStop then
            StopRecordingAndSaveClip()

            SetTimeout(250, function()
                recording = false
                processing = false
                notify('success', Config.Messages.stoppedSaved)
            end)
        else
            StopRecordingAndDiscardClip()

            SetTimeout(250, function()
                recording = false
                processing = false
                notify('info', Config.Messages.stoppedDiscarded)
            end)
        end

        return true
    end

    recording = false
    processing = false
    notify('warning', 'Rockstar Editor recording nu este pornit.')
    return false
end

local function toggleRecording()
    local now = GetGameTimer()

    if now - lastUse < (Config.CooldownMs or 1200) then
        notify('warning', Config.Messages.alreadyProcessing, 2500)
        return
    end

    lastUse = now

    if processing then
        notify('warning', Config.Messages.alreadyProcessing, 2500)
        return
    end

    if syncRecordingState() then
        stopRecording()
    else
        startRecording()
    end
end

-- IMPORTANT:
-- Nu inregistram RegisterCommand client-side ca sa nu se dubleze cu server command.
-- Comanda /editor este prinsa pe server si trimite eventul de toggle catre client.

RegisterNetEvent('driftzone_rockstareditor:client:toggle', function()
    toggleRecording()
end)

RegisterNetEvent('driftzone_rockstareditor:client:start', function()
    startRecording()
end)

RegisterNetEvent('driftzone_rockstareditor:client:stop', function()
    stopRecording()
end)

RegisterNetEvent('driftzone_rockstareditor:client:status', function()
    if syncRecordingState() then
        notify('info', 'Rockstar Editor recording: ON')
    else
        notify('info', 'Rockstar Editor recording: OFF')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if recording or nativeIsRecording() then
        StopRecordingAndSaveClip()
    end
end)

exports('Toggle', toggleRecording)
exports('Start', startRecording)
exports('Stop', stopRecording)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_EDITOR] Client-side loaded. Server command: /' .. tostring(Config.Command or 'editor'))
end)
