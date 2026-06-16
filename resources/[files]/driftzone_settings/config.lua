Config = {}

Config.Command = 'settings'
Config.MainColor = '#04c7f7'
Config.KvpPrefix = 'driftzone_settings_'

-- Am lasat doar toggle-urile corecte cerute:
-- HUD, radar/minimap, overhead pentru ceilalti si overhead personal.
Config.Toggles = {
    {
        id = 'radar',
        title = 'Radar / Minimap',
        description = 'Ascunde sau afiseaza minimap-ul GTA. Cand este OFF ramane ascuns corect.',
        category = 'Interface',
        default = true
    },
    {
        id = 'turometru',
        title = 'Turometru',
        description = 'Ascunde sau afiseaza turometrul / speedometer-ul DriftZone.',
        category = 'Interface',
        default = true
    },
    {
        id = 'voice_volume_ui',
        title = 'Voice Volume UI',
        description = 'Ascunde sau afiseaza bara de volum pentru voice chat.',
        category = 'Voice Chat',
        default = true
    }
}

Config.Radar = {
    -- Cat timp radarul este OFF, il fortam ascuns constant.
    -- 0 = cel mai sigur; 250 = mai economic. Pentru FiveM, 0 este recomandat cand vrei sa nu reapara in masina.
    hideLoopWait = 0
}

Config.Notify = {
    enabled = false,
    event = 'client:notify'
}
