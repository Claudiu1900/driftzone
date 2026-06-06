local recording = false
local lastUse = 0

local function notify(notifyType, message, duration)
    if Config.Notify and Config.Notify.enabled then
        TriggerEvent(Config.Notify.event or 'client:notify', notifyType or 'info', duration or 5000, tostring(message or ''))
    else
        print('[DRIFTZONE_EDITOR] ' .. tostring(message or ''))
    end
end

local function isRecordingNow()
    local ok, result = pcall(function()
        return IsRecording()
    end)

    return ok and result == true
end

local function startEditorRecording()
    if recording or isRecordingNow() then
        recording = true
        return false
    end

    -- 1 = start Rockstar Editor recording.
    StartRecording(1)

    Wait(250)

    recording = isRecordingNow()

    if recording then
        notify('success', Config.Messages.started)
        return true
    end

    notify('error', Config.Messages.failedStart)
    return false
end

local function stopEditorRecording()
    if not recording and not isRecordingNow() then
        recording = false
        notify('warning', 'Rockstar Editor recording nu este pornit.')
        return false
    end

    if Config.SaveClipOnStop then
        StopRecordingAndSaveClip()
        notify('success', Config.Messages.stoppedSaved)
    else
        StopRecordingAndDiscardClip()
        notify('info', Config.Messages.stoppedDiscarded)
    end

    recording = false
    return true
end

local function toggleEditorRecording()
    local now = GetGameTimer()

    -- mic anti-spam ca sa nu buguiasca recording-ul
    if now - lastUse < 1000 then
        return
    end

    lastUse = now

    if recording or isRecordingNow() then
        stopEditorRecording()
    else
        startEditorRecording()
    end
end

RegisterCommand(Config.Command or 'editor', function()
    toggleEditorRecording()
end, false)

RegisterNetEvent('driftzone_rockstareditor:client:toggle', function()
    toggleEditorRecording()
end)

RegisterNetEvent('driftzone_rockstareditor:client:start', function()
    startEditorRecording()
end)

RegisterNetEvent('driftzone_rockstareditor:client:stop', function()
    stopEditorRecording()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Daca resource-ul se opreste in timp ce inregistrezi, salveaza clipul ca sa nu-l pierzi.
    if recording or isRecordingNow() then
        StopRecordingAndSaveClip()
    end
end)

exports('Toggle', toggleEditorRecording)
exports('Start', startEditorRecording)
exports('Stop', stopEditorRecording)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_EDITOR] Client-side loaded. Command: /' .. tostring(Config.Command or 'editor'))
end)
