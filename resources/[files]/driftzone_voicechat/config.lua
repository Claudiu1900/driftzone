Config = {}

Config.MainColor = '#04c7f7'

-- Push-to-talk default: N
Config.TalkCommand = '+driftzone_voice_talk'
Config.TalkKey = 'N'

-- Un singur mod: Loud/Tipa
Config.VoiceMode = {
    label = 'Tipa',
    distance = 15.0
}

-- Cand nu tii apasat pe N, server/client state ramane muted.
Config.SilentDistance = 0.0

Config.Volume = {
    default = 100,
    min = 0,
    max = 100,

    -- Cat de des aplica volumul/mute pe jucatori.
    -- 250ms = suficient de rapid fara lag.
    refreshMs = 250
}

Config.UI = {
    showVolume = true,
    showMicIcon = true
}

Config.Debug = false
