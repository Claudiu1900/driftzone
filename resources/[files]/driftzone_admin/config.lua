Config = {}

Config.MainColor = '#2aaeff'
Config.NotifyEvent = 'client:notify'
Config.ChatEvent = 'driftzone_chat:client:addMessage'

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
    ah = 1,
    ap = 6,

    aduty = 1,
    staff = 0,

    ['goto'] = 1,
    bring = 1,
    mark = 1,
    gotomark = 1,

    kick = 1,
    slap = 2,
    freeze = 3,
    unfreeze = 3,

    warn = 3,
    rwarn = 5,
    warns = 0,
    resetwarns = 6,

    coords = 6,
    gotocoords = 2,
    tptow = 0,
    nc = 3,
    spectate = 5,

    veh = 3,
    fix = 2,

    ban = 5,
    tempban = 4,
    unban = 5,

    giveveh = 6,
    takeveh = 6,
    transferveh = 6,
    changeplate = 6,

    lockveh = 4,
    unlockveh = 4,
    giveadm = 6,
    wipe = 6,
    givecash = 7,
    givedzcoins = 7,
    givevip = 7,
    removevip = 6,
    resettickets = 6,

    addoutfit = 6,

    cleanup = 3,
    cancelcleanup = 3,
    addveh = 6,
    removeveh = 6,
    configveh = 6,
    vehs = 6
}

-- Comenzi care pot fi folosite fara aduty. Restul cer aduty yes/1.
Config.NoDutyCommands = {
    aduty = true,
    staff = true
}

Config.Cooldowns = {
    kick = 10000,
    veh = 5000,
    tptow = 30000,
    warn = 4000,
    rwarn = 3000,
    cleanup = 3000,
    cancelcleanup = 3000,
    removeveh = 3000,
    lockveh = 1500,
    unlockveh = 1500,
    giveadm = 3000,
    wipe = 5000,
    givecash = 3000,
    givedzcoins = 3000,
    givevip = 3000,
    removevip = 3000,
    resettickets = 5000,
    configveh = 2000,
    vehs = 2000,
    freeze = 1500,
    unfreeze = 1500,
    spectate = 1500,
    mark = 700,
    gotomark = 700,
    ap = 1500,
    ah = 1000
}

Config.Database = {
    usersTable = 'users',
    uidColumn = 'uid',
    usernameColumn = 'username',
    adminColumn = 'admin_level',
    adminColumnFallback = 'admin',
    adutyColumn = 'aduty',
    cashColumn = 'cash',
    bankColumn = 'bank',
    dzcoinsColumn = 'dzcoins',
    warnsColumn = 'warns',
    banColumn = 'ban',
    banReasonColumn = 'banreason',
    tempBanColumn = 'tempban',
    tempBanReasonColumn = 'tempbanreason',
    vipColumn = 'vip',
    vipDaysColumn = 'vip_days',
    ticketsColumn = 'tickets'
}

Config.Warns = {
    tempBanDays = 4,
    maxWarns = 3
}

Config.Optimization = {
    adminDataCacheMs = 2500,
    playerLookupCacheMs = 2000,
    tableColumnsCacheMs = 60000
}

Config.Logs = {
    enabled = true,
    table = 'admin_command_logs',
    vehicleTable = 'admin_vehicle_logs',
    logFailed = true
}

Config.AdminExtra = {
    lockVehicleResource = 'driftzone_vehicleconfig',
    defaultGarageSlots = 8,
    defaultOutsideVehicles = 2
}

Config.CommandMeta = {
    ah = { label = 'Admin Help', category = 'system', syntax = '/ah', description = 'Deschide lista comenzilor disponibile.' },
    ap = { label = 'Admin Panel', category = 'system', syntax = '/ap', description = 'Deschide panoul admin cu comenzi directe.' },

    aduty = { label = 'Admin Duty', category = 'system', syntax = '/aduty', description = 'Porneste/opreste aduty.' },
    staff = { label = 'Staff Online', category = 'system', syntax = '/staff', description = 'Arata staff-ul online.' },

    ['goto'] = { label = 'Goto player', category = 'teleport', syntax = '/goto uid', description = 'Te teleporteaza la un player.' },
    bring = { label = 'Bring player', category = 'teleport', syntax = '/bring uid', description = 'Aduce playerul la tine.' },
    mark = { label = 'Mark', category = 'teleport', syntax = '/mark', description = 'Salveaza pozitia ta actuala local.' },
    gotomark = { label = 'Goto Mark', category = 'teleport', syntax = '/gotomark', description = 'Te teleporteaza la pozitia salvata.' },
    gotocoords = { label = 'Goto Coords', category = 'teleport', syntax = '/gotocoords x y z heading_optional', description = 'Teleport pe coordonate.' },
    tptow = { label = 'TP to Waypoint', category = 'teleport', syntax = '/tptow', description = 'Teleport la waypoint.' },
    coords = { label = 'Coords', category = 'teleport', syntax = '/coords', description = 'Deschide panoul cu coordonate.' },

    kick = { label = 'Kick', category = 'punish', syntax = '/kick uid motiv', description = 'Da kick unui player.' },
    slap = { label = 'Slap', category = 'punish', syntax = '/slap uid', description = 'Arunca playerul in aer.' },
    freeze = { label = 'Freeze', category = 'punish', syntax = '/freeze uid', description = 'Blocheaza miscarea playerului.' },
    unfreeze = { label = 'Unfreeze', category = 'punish', syntax = '/unfreeze uid', description = 'Deblocheaza miscarea playerului.' },
    warn = { label = 'Warn', category = 'punish', syntax = '/warn uid motiv', description = 'Adauga un warn.' },
    rwarn = { label = 'Remove Warn', category = 'punish', syntax = '/rwarn uid', description = 'Scoate un warn.' },
    warns = { label = 'Warns', category = 'punish', syntax = '/warns uid', description = 'Verifica warn-urile.' },
    resetwarns = { label = 'Reset Warns', category = 'punish', syntax = '/resetwarns uid', description = 'Reseteaza warn-urile.' },
    ban = { label = 'Ban', category = 'punish', syntax = '/ban uid motiv', description = 'Baneaza permanent.' },
    tempban = { label = 'Temp Ban', category = 'punish', syntax = '/tempban uid zile motiv', description = 'Baneaza temporar.' },
    unban = { label = 'Unban', category = 'punish', syntax = '/unban uid', description = 'Scoate banul.' },

    nc = { label = 'Noclip', category = 'tools', syntax = '/nc', description = 'Porneste/opreste noclip.' },
    spectate = { label = 'Spectate', category = 'tools', syntax = '/spectate uid', description = 'Spectate toggle pe player.' },
    fix = { label = 'Fix Vehicle', category = 'tools', syntax = '/fix', description = 'Repara masina.' },
    cleanup = { label = 'Cleanup', category = 'tools', syntax = '/cleanup 10 s', description = 'Sterge vehiculele fara sofer dupa timp.' },
    cancelcleanup = { label = 'Cancel Cleanup', category = 'tools', syntax = '/cancelcleanup', description = 'Anuleaza cleanup-ul activ.' },

    veh = { label = 'Spawn Vehicle', category = 'vehicles', syntax = '/veh model', description = 'Spawneaza o masina.' },
    addveh = { label = 'Add Vehicle Config', category = 'vehicles', syntax = '/addveh', description = 'Adauga o masina in vehiclenames.' },
    removeveh = { label = 'Remove Vehicle Config', category = 'vehicles', syntax = '/removeveh id', description = 'Sterge o masina din vehiclenames.' },
    configveh = { label = 'Config Vehicles', category = 'vehicles', syntax = '/configveh', description = 'Editeaza vehiclenames.' },
    vehs = { label = 'Owned Vehicles', category = 'vehicles', syntax = '/vehs uid', description = 'Vezi masinile unui UID.' },
    giveveh = { label = 'Give Vehicle', category = 'vehicles', syntax = '/giveveh uid model plate_optional', description = 'Da masina unui UID.' },
    takeveh = { label = 'Take Vehicle', category = 'vehicles', syntax = '/takeveh uid sql_id', description = 'Sterge masina unui UID.' },
    transferveh = { label = 'Transfer Vehicle', category = 'vehicles', syntax = '/transferveh uid_nou sql_id', description = 'Transfera masina.' },
    changeplate = { label = 'Change Plate', category = 'vehicles', syntax = '/changeplate sql_id plate', description = 'Schimba numarul masinii.' },
    lockveh = { label = 'Lock Vehicle', category = 'vehicles', syntax = '/lockveh sql_id', description = 'Incuie masina live prin driftzone_vehicleconfig + salveaza locked in DB.' },
    unlockveh = { label = 'Unlock Vehicle', category = 'vehicles', syntax = '/unlockveh sql_id', description = 'Descuie masina live prin driftzone_vehicleconfig + salveaza locked in DB.' },

    giveadm = { label = 'Give Admin', category = 'give', syntax = '/giveadm uid level', description = 'Seteaza admin_level.' },
    givecash = { label = 'Give Cash', category = 'give', syntax = '/givecash uid suma', description = 'Adauga cash.' },
    givedzcoins = { label = 'Give DZ Coins', category = 'give', syntax = '/givedzcoins uid suma', description = 'Adauga dzcoins.' },
    givevip = { label = 'Give VIP', category = 'give', syntax = '/givevip uid zile', description = 'Da VIP.' },
    removevip = { label = 'Remove VIP', category = 'give', syntax = '/removevip uid', description = 'Scoate VIP.' },
    resettickets = { label = 'Reset Tickets', category = 'give', syntax = '/resettickets uid_optional', description = 'Reseteaza tickets.' },
    wipe = { label = 'Wipe', category = 'give', syntax = '/wipe uid', description = 'Wipe bani/inventory/vehicule.' },
    addoutfit = { label = 'Add Outfit', category = 'give', syntax = '/addoutfit', description = 'Comanda outfit externa.' }
}

Config.Categories = {
    { id = 'system', label = 'System' },
    { id = 'teleport', label = 'Teleport' },
    { id = 'punish', label = 'Punish' },
    { id = 'tools', label = 'Tools' },
    { id = 'vehicles', label = 'Vehicles' },
    { id = 'give', label = 'Give / Economy' }
}
