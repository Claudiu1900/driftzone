Config = {}

Config.Debug = false
Config.Framework = 'auto' -- auto / qb / esx / internal
Config.PaymentAccount = 'cash'
Config.InternalMoneyLabel = 'Sold mecanic'
Config.DatabaseTable = 'driftzone_mechanic_players'

Config.NotificationResource = 'driftzone_notifications'
Config.NotificationEvent = 'driftzone_notifications:client:notify'

Config.InteractionKey = 38 -- E
Config.InteractionDistance = 2.2
Config.DrawDistance = 22.0
Config.TaskInteractDistance = 3.0
Config.VehicleSpawnClearRadius = 3.2
Config.ServiceVehicleMaxDistance = 90.0

Config.BossBlip = { enabled = true, sprite = 446, colour = 47, scale = 0.85, label = 'Job mecanic' }

Config.BossNPC = {
    model = 's_m_m_autoshop_01',
    coords = vector4(-205.73, -1310.53, 31.29, 271.50),
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

Config.ToolDepot = vector3(-197.62, -1317.91, 31.09)

Config.ServiceVehicle = {
    model = 'speedo',
    platePrefix = 'MECH',
    primaryColor = 12,
    secondaryColor = 0,
    spawnPoints = {
        vector4(-201.20, -1309.23, 31.29, 89.50),
        vector4(-201.14, -1305.57, 31.29, 89.50),
        vector4(-201.11, -1301.93, 31.29, 89.50)
    }
}

Config.Uniforms = {
    male = {
        [3] = { drawable = 41, texture = 0 },
        [4] = { drawable = 36, texture = 0 },
        [6] = { drawable = 12, texture = 0 },
        [8] = { drawable = 15, texture = 0 },
        [11] = { drawable = 65, texture = 0 }
    },
    female = {
        [3] = { drawable = 44, texture = 0 },
        [4] = { drawable = 35, texture = 0 },
        [6] = { drawable = 26, texture = 0 },
        [8] = { drawable = 14, texture = 0 },
        [11] = { drawable = 59, texture = 0 }
    }
}

Config.Ranks = {
    [1] = { name = 'Mecanic I', minXP = 0, multiplier = 1.00 },
    [2] = { name = 'Mecanic II', minXP = 500, multiplier = 1.12 },
    [3] = { name = 'Mecanic III', minXP = 1500, multiplier = 1.25 }
}

Config.TaskTypes = {
    diagnostics = {
        label = 'Diagnoză electronică',
        description = 'Identifică erorile în ordinea corectă.',
        minRank = 1,
        pay = { 260, 340 },
        xp = { 30, 42 },
        difficulty = 1
    },
    battery = {
        label = 'Înlocuire baterie',
        description = 'Stabilizează tensiunea în zona sigură.',
        minRank = 1,
        pay = { 300, 390 },
        xp = { 34, 46 },
        difficulty = 1
    },
    tire = {
        label = 'Schimbare anvelopă',
        description = 'Strânge prezoanele în ordinea indicată.',
        minRank = 1,
        pay = { 320, 420 },
        xp = { 36, 50 },
        difficulty = 1
    },
    oil = {
        label = 'Schimb de ulei',
        description = 'Umple exact până la nivelul recomandat.',
        minRank = 1,
        pay = { 340, 450 },
        xp = { 38, 52 },
        difficulty = 2
    },
    brakes = {
        label = 'Reparație sistem frânare',
        description = 'Calibrează presiunea frânelor.',
        minRank = 2,
        pay = { 430, 560 },
        xp = { 48, 66 },
        difficulty = 2
    },
    engine = {
        label = 'Reparație motor',
        description = 'Reconectează circuitele motorului.',
        minRank = 2,
        pay = { 500, 680 },
        xp = { 55, 78 },
        difficulty = 3
    }
}

Config.TaskVehicleModels = {
    'asea', 'blista', 'buffalo', 'dilettante', 'futo', 'ingot',
    'oracle', 'premier', 'primo', 'schafter2', 'sultan', 'tailgater'
}

Config.TaskLocations = {
    vector4(215.47, -810.12, 30.73, 249.0),
    vector4(1154.49, -326.76, 69.20, 99.0),
    vector4(1207.24, -1387.03, 35.23, 177.0),
    vector4(818.26, -1028.17, 26.30, 89.0),
    vector4(-708.66, -1139.15, 10.61, 214.0),
    vector4(-1218.20, -1430.51, 4.34, 126.0),
    vector4(-1538.64, -575.22, 25.71, 35.0),
    vector4(-1040.42, -265.87, 37.84, 206.0),
    vector4(-352.61, -96.17, 45.66, 70.0),
    vector4(260.77, 2590.88, 44.90, 10.0),
    vector4(1178.50, 2640.14, 37.75, 180.0),
    vector4(1692.62, 3759.38, 34.71, 214.0),
    vector4(-91.14, 6424.64, 31.49, 46.0),
    vector4(-2547.60, 2334.13, 33.06, 93.0),
    vector4(-3165.72, 1087.72, 20.84, 245.0),
    vector4(-1419.90, 56.44, 52.42, 222.0)
}

Config.UrgentCallChance = 0.22
Config.UrgentPayMultiplier = 1.35
Config.UrgentXPBonus = 12

Config.FlawlessBonus = {
    minimumJobs = 4,
    money = 750,
    xp = 120
}

Config.Security = {
    minimumGameTimeMs = 2500,
    maximumTaskDistance = 28.0,
    taskRequestCooldownMs = 2500,
    resultCooldownMs = 1500
}

Config.Text = {
    interactBoss = '[E] Vorbește cu șeful atelierului',
    collectTools = '[E] Ridică trusa de scule',
    repairVehicle = '[E] Începe intervenția',
    returnToBoss = 'Întoarce-te la atelier pentru a încheia tura.',
    spawnOccupied = 'Toate locurile pentru vehiculul de serviciu sunt ocupate. Eliberează unul dintre ele.',
    noServiceVehicle = 'Vehiculul de serviciu este prea departe.',
    stayOnFoot = 'Coboară din vehicul pentru a începe reparația.'
}
