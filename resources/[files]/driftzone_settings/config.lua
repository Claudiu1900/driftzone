Config = {}

Config.Command = 'settings'
Config.MainColor = '#04c7f7'
Config.KvpPrefix = 'driftzone_settings_'

-- Toggle-urile sunt salvate local pe fiecare client cu KVP.
-- default = valoarea initiala cand jucatorul nu a salvat nimic.
Config.Toggles = {
    {
        id = 'hud',
        title = 'HUD',
        description = 'Afiseaza sau ascunde HUD-ul principal DriftZone.',
        category = 'Interface',
        default = true
    },
    {
        id = 'minimap',
        title = 'Minimap',
        description = 'Afiseaza sau ascunde minimap-ul GTA.',
        category = 'Interface',
        default = true
    },
    {
        id = 'tickets_counter',
        title = 'Tickets Counter',
        description = 'Afiseaza sau ascunde counter-ul de tickete pentru staff.',
        category = 'Interface',
        default = true
    },
    {
        id = 'speedometer',
        title = 'Turometru / Speedometer',
        description = 'Afiseaza sau ascunde turometrul masinii.',
        category = 'Vehicle',
        default = true
    },
    {
        id = 'vehicle_stats',
        title = 'Vehicle Stats',
        description = 'Afiseaza sau ascunde informatiile sistemului driftzone_vs.',
        category = 'Vehicle',
        default = true
    },
    {
        id = 'voice_ui',
        title = 'Voice UI',
        description = 'Afiseaza sau ascunde icon-ul/status-ul de voice chat.',
        category = 'Voice',
        default = true
    },
    {
        id = 'overhead',
        title = 'Overhead Stats',
        description = 'Afiseaza sau ascunde overhead stats complet.',
        category = 'Overhead',
        default = true
    },
    {
        id = 'overhead_names',
        title = 'Overhead Names',
        description = 'Afiseaza sau ascunde numele deasupra jucatorilor.',
        category = 'Overhead',
        default = true
    },
    {
        id = 'overhead_ids',
        title = 'Overhead IDs',
        description = 'Afiseaza sau ascunde ID-ul deasupra jucatorilor.',
        category = 'Overhead',
        default = true
    },
    {
        id = 'overhead_admin',
        title = 'Overhead Admin Badge',
        description = 'Afiseaza sau ascunde badge-ul/rank-ul de admin in overhead.',
        category = 'Overhead',
        default = true
    },
    {
        id = 'overhead_health',
        title = 'Overhead Health / Armor',
        description = 'Afiseaza sau ascunde viata si armura in overhead stats.',
        category = 'Overhead',
        default = true
    },
    {
        id = 'notifications',
        title = 'Notifications',
        description = 'Afiseaza sau ascunde notificarile DriftZone.',
        category = 'Interface',
        default = true
    }
}
