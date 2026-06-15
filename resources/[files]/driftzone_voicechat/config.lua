Config = {}

Config.MainColor = '#04c7f7'

Config.TalkCommand = '+driftzone_voice_talk'
Config.TalkKey = 'N'

Config.VoiceMode = {
    label = 'Tipa',
    distance = 15.0
}

Config.SilentDistance = 0.0

Config.Volume = {
    default = 100,
    min = 0,
    max = 100,
    refreshMs = 250
}

Config.UI = {
    showVolume = true,
    showMicIcon = true,
    toggleCommand = 'voiceui'
}

-- Target dedicat pentru apeluri. Nu schimba decat daca ai conflict cu alt voice script.
Config.PhoneVoiceTarget = 31

Config.Debug = false
