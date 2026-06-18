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


Config.Mutes = {
    UsersTable = 'users',
    UidColumn = 'uid',
    MuteColumn = 'mute',
    ReasonColumn = 'mute_reason',
    MutedByColumn = 'mute_by',
    MutedByNameColumn = 'mute_by_name',
    MutedAtColumn = 'mute_at'
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
    -- Comenzile se executa universal prin ExecuteCommand pe client,
    -- exact ca in F8/default chat. Nu mai trebuie listate aici.
}

-- Comenzi speciale care nu au RunCommand export.
Config.SpecialCommands = {
    character = 'driftzone_character:OpenCharacterCreator',
    fixcharacter = 'driftzone_character:FixCharacter'
}

Config.Debug = false
