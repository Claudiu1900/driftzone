Config = {}

Config.Chat = {
    MaxMessageLength = 160,
    MaxNameLength = 32,
    HideAfterMs = 6000,
    MetaCacheMs = 0,
    UidCacheMs = 30000,
    PendingLimit = 80,
    MaxMessages = 90
}

Config.AdminRanks = {
    [1] = { label = 'Trial Helper', color = '#0AF52A' },
    [2] = { label = 'Helper', color = '#37B048' },
    [3] = { label = 'Moderator', color = '#ED880C' },
    [4] = { label = 'Admin', color = '#ED0C0C' },
    [5] = { label = 'Manager', color = '#992DBD' },
    [6] = { label = 'Co-Owner', color = '#04c7f7' },
    [7] = { label = 'Owner', color = '#04c7f7' }
}

-- NU mai bagi comenzi in server/main.lua.
-- Pentru scripturi care au RegisterCommand pe client: merge automat prin ExecuteCommand pe client.
-- Pentru scripturi care au export RunCommand server-side: le pui aici, in config.
Config.CommandRoutes = {
    driftzone_admin = {
        'aduty', 'staff', 'kick', 'slap', 'coords', 'gotocoords', 'tptow', 'nc',
        'veh', 'fix', 'ban', 'tempban', 'unban',
        'givecar', 'takecar', 'transfercar', 'changeplate',
        'addoutfit',
        'goto', 'bring', 'warn', 'rwarn', 'warns', 'resetwarns'
    },

    driftzone_garage = { 'garage', 'garaj', 'park' },
    driftzone_stats = { 'stats', 'statistici' },
    driftzone_outfits = { 'outfit', 'outfits', 'addoutfit' },
    driftzone_keybinds = { 'keybind', 'keybinds' },
    driftzone_tickets = { 'ticket', 'tickets', 'cancelticket' },
    driftzone_codes = { 'code', 'codes', 'createcode', 'creatercode', 'delcode', 'codeslist' },
    driftzone_clothes = { 'haine', 'clothes', 'fixskin', 'setcl', 'bancl' },
    driftzone_vs = { 'vs', 'dv', 'gotoveh', 'bringveh', 'fixveh' }
}

-- Comenzi speciale care nu au RunCommand export.
Config.SpecialCommands = {
    character = 'driftzone_character:OpenCharacterCreator',
    fixcharacter = 'driftzone_character:FixCharacter'
}

Config.Debug = false
