Config = {}

Config.Debug = false
Config.NotifyEvent = 'client:notify'
Config.InteractKey = 38 -- E

Config.DrawDistance = {
    JobCenter = 30.0,
    Depot = 30.0,
    Intervention = 45.0
}

Config.Security = {
    RequireOneSync = true,
    JobCenterDistance = 7.0,
    DepotDistance = 7.0,
    InterventionDistance = 7.0,
    ActionCooldownMs = 700,
    RepairMaxExtraSeconds = 20,
    MaxClientMistakes = 10,
    MaxShiftSeconds = 3 * 60 * 60,
    VehicleRegisterDistance = 80.0,
    VehicleRespawnCooldownSeconds = 20
}

Config.JobCenter = {
    coords = vector4(736.83, 132.73, 80.72, 239.0),
    ped = 's_m_y_construct_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    blip = {
        enabled = true,
        sprite = 354,
        colour = 5,
        scale = 0.78,
        label = 'Compania Electrica DriftZone'
    }
}

Config.ToolDepot = {
    coords = vector3(741.06, 128.65, 80.72),
    marker = 1,
    radius = 1.35
}

Config.Vehicle = {
    enabled = true,
    model = 'speedo',
    platePrefix = 'DZEL',
    warpIntoVehicle = false,
    primaryColour = 111,
    secondaryColour = 111,
    dirtLevel = 0.0,
    fuelLevel = 100.0,
    clearanceRadius = 3.5,
    blip = {
        enabled = true,
        sprite = 67,
        colour = 5,
        scale = 0.82,
        label = 'Duba electricianului'
    },
    -- Locurile sunt verificate in aceasta ordine. Daca toate sunt ocupate, duba nu este creata.
    spawns = {
        vector4(744.303284, 136.219788, 80.267456, 249.45),
        vector4(742.575806, 132.962632, 80.233642, 257.95),
        vector4(751.635192, 110.518684, 79.071044, 136.06)
    }
}

Config.Uniform = {
    enabled = true,
    male = {
        components = {
            [3] = { drawable = 19, texture = 0 },
            [4] = { drawable = 36, texture = 0 },
            [6] = { drawable = 12, texture = 0 },
            [8] = { drawable = 59, texture = 1 },
            [11] = { drawable = 56, texture = 1 }
        },
        props = {
            [0] = { drawable = -1, texture = 0 }
        }
    },
    female = {
        components = {
            [3] = { drawable = 20, texture = 0 },
            [4] = { drawable = 35, texture = 0 },
            [6] = { drawable = 26, texture = 0 },
            [8] = { drawable = 36, texture = 1 },
            [11] = { drawable = 49, texture = 1 }
        },
        props = {
            [0] = { drawable = -1, texture = 0 }
        }
    }
}

Config.Shift = {
    minTasks = 4,
    maxTasks = 6,
    cleanBonus = 650,
    badWeatherExtraChance = 70,
    badWeatherMaxExtraTasks = 2,
    allowEarlyFinish = true,
    failedRepairBaseMistake = 1
}

Config.Levels = {
    [1] = { name = 'Electrician I', minXp = 0, multiplier = 1.00 },
    [2] = { name = 'Electrician II', minXp = 450, multiplier = 1.15 },
    [3] = { name = 'Electrician III', minXp = 1200, multiplier = 1.35 }
}

Config.TaskTypes = {
    pole = {
        label = 'Reparatie la stalp',
        description = 'Verifica izolatorii si restabileste alimentarea.',
        voltage = 'Joasa tensiune',
        minLevel = 1,
        duration = 22,
        minimumDuration = 5,
        minigames = { 'sequence', 'voltage' },
        difficulty = 1,
        allowedMistakes = 2,
        pay = { min = 320, max = 430 },
        xp = { min = 35, max = 50 },
        scenario = 'WORLD_HUMAN_WELDING',
        markerColour = { 255, 196, 0, 150 }
    },
    fuse = {
        label = 'Cutie de sigurante',
        description = 'Inlocuieste sigurantele arse si testeaza circuitul.',
        voltage = 'Joasa tensiune',
        minLevel = 1,
        duration = 24,
        minimumDuration = 6,
        minigames = { 'fuses', 'sequence' },
        difficulty = 1,
        allowedMistakes = 2,
        pay = { min = 280, max = 390 },
        xp = { min = 30, max = 45 },
        scenario = 'WORLD_HUMAN_HAMMERING',
        markerColour = { 0, 174, 255, 150 }
    },
    panel_low = {
        label = 'Panou de distributie',
        description = 'Reconfigureaza circuitele panoului de joasa tensiune.',
        voltage = 'Joasa tensiune',
        minLevel = 1,
        duration = 28,
        minimumDuration = 7,
        minigames = { 'wires', 'switches' },
        difficulty = 2,
        allowedMistakes = 2,
        pay = { min = 390, max = 520 },
        xp = { min = 45, max = 60 },
        scenario = 'WORLD_HUMAN_CONST_DRILL',
        markerColour = { 60, 210, 120, 150 }
    },
    panel_high = {
        label = 'Panou industrial',
        description = 'Izoleaza si repara panoul de inalta tensiune.',
        voltage = 'Inalta tensiune',
        minLevel = 2,
        duration = 32,
        minimumDuration = 8,
        minigames = { 'switches', 'wires', 'voltage' },
        difficulty = 3,
        allowedMistakes = 1,
        pay = { min = 620, max = 790 },
        xp = { min = 70, max = 95 },
        scenario = 'WORLD_HUMAN_WELDING',
        markerColour = { 255, 70, 70, 165 }
    }
}

Config.Interventions = {
    { id = 'pole_01', type = 'pole', coords = vector3(716.84, 164.78, 80.75), area = 'Vinewood Boulevard' },
    { id = 'pole_02', type = 'pole', coords = vector3(512.19, 168.61, 99.37), area = 'Alta Street' },
    { id = 'pole_03', type = 'pole', coords = vector3(292.45, -286.13, 53.98), area = 'Power Street' },
    { id = 'pole_04', type = 'pole', coords = vector3(-308.64, -887.45, 31.07), area = 'San Andreas Avenue' },
    { id = 'pole_05', type = 'pole', coords = vector3(-1044.28, -222.33, 37.93), area = 'West Eclipse Boulevard' },
    { id = 'pole_06', type = 'pole', coords = vector3(1221.41, -470.34, 66.20), area = 'Mirror Park Boulevard' },

    { id = 'fuse_01', type = 'fuse', coords = vector3(454.41, -1580.72, 29.28), area = 'Davis Avenue' },
    { id = 'fuse_02', type = 'fuse', coords = vector3(115.83, -1299.21, 29.27), area = 'Strawberry Avenue' },
    { id = 'fuse_03', type = 'fuse', coords = vector3(-579.98, -1006.58, 22.33), area = 'Vespucci Boulevard' },
    { id = 'fuse_04', type = 'fuse', coords = vector3(-1268.17, -812.43, 17.11), area = 'Boulevard Del Perro' },
    { id = 'fuse_05', type = 'fuse', coords = vector3(824.08, -2147.16, 29.62), area = 'Popular Street' },
    { id = 'fuse_06', type = 'fuse', coords = vector3(1209.73, -1389.20, 35.23), area = 'El Rancho Boulevard' },

    { id = 'panel_low_01', type = 'panel_low', coords = vector3(724.46, 133.48, 80.96), area = 'Statia Downtown' },
    { id = 'panel_low_02', type = 'panel_low', coords = vector3(274.29, -831.41, 29.30), area = 'Legion Square' },
    { id = 'panel_low_03', type = 'panel_low', coords = vector3(-529.57, -1215.20, 18.18), area = 'Little Seoul' },
    { id = 'panel_low_04', type = 'panel_low', coords = vector3(964.82, -1856.06, 31.20), area = 'Cypress Flats' },
    { id = 'panel_low_05', type = 'panel_low', coords = vector3(-1517.83, -442.02, 35.44), area = 'Morningwood' },

    { id = 'panel_high_01', type = 'panel_high', coords = vector3(2824.14, 1505.14, 24.72), area = 'Palmer-Taylor Power Station' },
    { id = 'panel_high_02', type = 'panel_high', coords = vector3(2736.58, 1533.88, 24.50), area = 'Palmer-Taylor Substation' },
    { id = 'panel_high_03', type = 'panel_high', coords = vector3(718.95, 156.29, 80.75), area = 'Downtown Substation' },
    { id = 'panel_high_04', type = 'panel_high', coords = vector3(2054.68, 3688.91, 34.59), area = 'Sandy Shores Substation' }
}

-- Modul auto cauta automat coloana de bani din tabelele de mai jos.
-- Pentru serverul DriftZone obisnuit va detecta de regula users.id + users.wallet/cash/money.
Config.Economy = {
    mode = 'auto', -- auto | database | export | event | disabled
    payAccount = 'cash',
    databaseProfiles = {
        { table = 'users', uidColumns = { 'id', 'uid', 'user_id' }, cashColumns = { 'wallet', 'cash', 'money' }, bankColumns = { 'bank', 'bank_money' } },
        { table = 'vrp_user_moneys', uidColumns = { 'user_id' }, cashColumns = { 'wallet' }, bankColumns = { 'bank' } }
    },
    export = {
        resource = '',
        name = '',
        argumentOrder = 'source_uid_amount_reason'
    },
    event = 'driftzone_electrician:server:addMoney'
}

Config.Text = {
    interactNpc = 'Apasa ~INPUT_CONTEXT~ pentru a vorbi cu dispecerul',
    interactDepot = 'Apasa ~INPUT_CONTEXT~ pentru depozitul de unelte',
    interactRepair = 'Apasa ~INPUT_CONTEXT~ pentru a incepe interventia',
    noTools = 'Trebuie sa iei trusa de electrician de la depozit.',
    routeSet = 'Ruta a fost setata pe GPS.',
    tooFar = 'Esti prea departe de locatia necesara.',
    hired = 'Ai fost angajat ca electrician.',
    resigned = 'Ai demisionat din companie.',
    shiftStarted = 'Tura a inceput. Ia trusa si verifica tableta.',
    shiftEnded = 'Tura a fost incheiata.',
    shiftExpired = 'Tura a expirat si a fost inchisa automat.',
    toolsTaken = 'Ai luat trusa de electrician.',
    toolsReturned = 'Ai returnat trusa de electrician.',
    alreadyTools = 'Ai deja trusa de electrician.',
    notTools = 'Nu ai nicio trusa de returnat.',
    taskComplete = 'Interventie finalizata: +$%s si +%s XP.',
    taskFailed = 'Interventia a esuat. Verifica circuitul si incearca din nou.',
    cleanBonus = 'Tura perfecta! Bonus fara greseli: +$%s.',
    promoted = 'Felicitari! Ai fost promovat la %s.',
    allComplete = 'Toate interventiile sunt finalizate. Returneaza trusa si incheie tura.',
    returnToolsFirst = 'Returneaza trusa la depozit inainte sa inchei tura.',
    activeShift = 'Nu poti demisiona in timpul unei ture.',
    noShift = 'Nu ai nicio tura activa.',
    notEmployed = 'Nu esti angajat la compania electrica.',
    repairTooFast = 'Interventia a fost anulata de sistemul de securitate.',
    repairExpired = 'Interventia a expirat. Incearca din nou.',
    badWeather = 'Vreme severa: au fost adaugate interventii suplimentare.',
    uidMissing = 'UID-ul tau nu a putut fi identificat. Reconecteaza-te.',
    vehicleSpawned = 'Duba de serviciu a fost pregatita si marcata pe harta.',
    vehicleBlocked = 'Toate locurile pentru duba sunt ocupate. Roaga jucatorii sa elibereze locurile si incearca din nou.',
    vehicleRespawnCooldown = 'Asteapta inainte sa ceri alta duba.',
    vehicleOnlyAtCenter = 'Duba poate fi recuperata doar de la dispecerat.',
    paymentPending = 'Plata nu a putut fi trimisa acum si a fost salvata ca plata restanta.',
    pendingPaid = 'Ai primit plata restanta: $%s.'
}
