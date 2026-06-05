Config = {}

Config.MainColor = '#2aaeff'

Config.Ranks = {
    [1] = 'Trial Helper',
    [2] = 'Helper',
    [3] = 'Moderator',
    [4] = 'Admin',
    [5] = 'Manager',
    [6] = 'Co-Owner',
    [7] = 'Owner'
}

Config.Commands = {
    aduty = 1,
    staff = 0,

    ['goto'] = 1,
    bring = 1,

    kick = 1,
    slap = 2,

    warn = 3,
    rwarn = 5,
    warns = 0,
    resetwarns = 6,

    coords = 6,
    gotocoords = 2,
    tptow = 0,
    nc = 3,

    veh = 3,
    fix = 2,

    ban = 5,
    tempban = 4,
    unban = 5,

    givecar = 6,
    takecar = 6,
    transfercar = 6,
    changeplate = 6,

    addoutfit = 6
}

Config.Cooldowns = {
    kick = 10000,
    veh = 5000,
    tptow = 30000,
    warn = 4000,
    rwarn = 3000
}

Config.Tptow = {
    maxAttempts = 5,
    safeHeight = 950.0,
    verifyDistance = 12.0,
    landingOffset = 1.7
}

Config.Warns = {
    tempBanDays = 4,
    maxWarns = 3
}

Config.Database = {
    usersTable = 'users',
    uidColumn = 'uid',
    warnsColumn = 'warns',
    tempBanColumn = 'tempban',
    tempBanReasonColumn = 'tempbanreason'
}


Config.Optimization = {
    adminDataCacheMs = 2500,
    playerLookupCacheMs = 2000
}

Config.Logs = {
    enabled = true,
    table = 'admin_command_logs',

    -- Logheaza si incercarile esuate / lipsa acces / erori.
    logFailed = true,

    -- Trimite in acelasi timp si catre sistemele externe de logs, daca exista.
    triggerExternalLogs = true
}
