Config = {}

Config.MainColor = '#04c7f7'

-- Push-to-talk default: N
Config.TalkCommand = '+driftzone_voice_talk'
Config.TalkKey = 'N'

-- Un singur mod: Tipa/Loud
Config.VoiceMode = {
    label = 'Tipa',
    distance = 18.0
}

-- Cand nu tii apasat pe N, proximitatea devine 0.
Config.SilentDistance = 0.0

Config.Volume = {
    default = 100,
    min = 0,
    max = 100,

    -- Reaplica volumul pe playerii activi. Nu e loop greu.
    refreshMs = 2000
}

Config.UI = {
    showVolume = true,
    showMicIcon = true
}

Config.Debug = false
