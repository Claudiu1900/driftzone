Config = {}

Config.MainColor = '#04c7f7'

-- Push-to-talk default: N
Config.TalkCommand = '+driftzone_voice_talk'
Config.TalkKey = 'N'

-- Proximity voice default.
Config.VoiceMode = {
    label = 'Tipa',
    distance = 15.0
}

-- Distanta folosita in apel telefonic.
-- Non-participantii sunt mutati client-side, deci nu aud apelul.
Config.PhoneCallDistance = 99999.0

-- Voice target folosit pentru apeluri telefonice.
-- Nu schimba daca nu folosesti deja voice targets in alt script.
Config.PhoneVoiceTarget = 31

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

Config.Debug = false
