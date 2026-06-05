Config = {}

Config.Debug = false

-- Nu sunt comenzi. Sistemul se controleaza doar prin triggere/exporturi.
Config.EnableCommands = false

Config.Distance = {
    max = 22.0,
    fullOpacity = 7.0,
    minScale = 0.72,
    maxScale = 1.0,
    headOffsetZ = 1.18
}

Config.Performance = {
    -- 70-90ms este smooth fara sa spameze NUI inutil.
    updateMs = 80,

    -- Daca activezi, face line-of-sight checks. Mai realist, dar mai scump.
    useLineOfSight = false,

    -- Daca nu vezi niciodata propriul overhead, pune true.
    hideOwnByDefault = false
}

Config.Metadata = {
    refreshSeconds = 12
}

Config.Database = {
    usersTable = 'users',
    uidColumn = 'uid',
    nameColumn = 'username',
    rankColumn = 'rank',
    rankColorColumn = 'rankcolor',
    adminLevelColumn = 'admin_level',
    adutyColumn = 'aduty'
}

Config.AdminRanks = {
    [1] = 'TRIAL HELPER',
    [2] = 'HELPER',
    [3] = 'MODERATOR',
    [4] = 'ADMIN',
    [5] = 'MANAGER',
    [6] = 'CO-OWNER',
    [7] = 'OWNER',
    [8] = 'FOUNDER'
}

Config.DefaultRank = {
    label = 'STARTER',
    color = '#04c7f7'
}
