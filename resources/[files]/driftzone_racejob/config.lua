Config = {}

Config.MainColor = '#04c7f7'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.CashColumn = 'cash'
Config.RacesColumn = 'races'
Config.XpColumn = 'xp'

Config.OwnedVehiclesTable = 'ownedvehicles'
Config.OwnedVehicleIdColumn = 'id'
Config.OwnedVehicleOwnerColumn = 'owner_id'
Config.OwnedVehicleModelColumn = 'vehicle_model'
Config.OwnedVehiclePlateColumn = 'vehicle_plate'
Config.OwnedVehicleTuningColumn = 'vehicle_tunning'

Config.ResetCooldownCommand = 'rracecd'
Config.ResetCooldownMinAdminLevel = 6
Config.AdminColumns = {'admin_level'}

Config.Interaction = {
    id = 'driftzone_racejob_main',
    coords = vector3(-116.835160, -604.720886, 36.272584),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Job',
    subText = 'DriftZone Race Job',
    marker = true,
    event = 'driftzone_racejob:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Race Job' }
}

Config.ReturnPosition = vector4(-100.826370, -612.079102, 36.255738, 65.20)
Config.ReturnBucket = 0
Config.RaceBucketBase = 62000
Config.FinishRadius = 9.0
Config.CountdownSeconds = 3

Config.Vehicle = {
    deleteExistingOwnedVehicle = true,
    freezeDuringCountdown = true,
    protectVehicle = true,
    cleanupOnFinish = true,
    cleanupOnFail = true,
    spawnZOffset = 0.45,
    clientSpawnTimeoutMs = 15000,
    tuningApplyDelays = { 100, 350, 750, 1400, 2400, 3600 }
}

Config.Races = {
    short = {
        id = 'short',
        label = 'Short Delivery',
        description = 'Livrare scurta, rapida si buna pentru cash rapid.',
        reward = { min = 2500, max = 5000 },
        xp = { min = 100, max = 300 },
        cooldown = 15 * 60, -- cooldown dupa castig
        failCooldown = 5 * 60, -- cooldown daca pierde
        timeLimit = 180,
        start = vector4(-490.958252, -751.094482, 31.144288, 170.08),
        finish = vector3(-853.806580, -1257.784668, 3.999268)
    },
    medium = {
        id = 'medium',
        label = 'Medium Delivery',
        description = 'Livrare medie, distanta mai mare si recompensa mai buna.',
        reward = { min = 7500, max = 15000 },
        xp = { min = 300, max = 700 },
        cooldown = 30 * 60, -- cooldown dupa castig
        failCooldown = 10 * 60, -- cooldown daca pierde
        timeLimit = 360,
        start = vector4(1364.373658, -2023.503296, 50.858642, 28.35),
        finish = vector3(2539.938476, -279.837372, 91.989014)
    },
    long = {
        id = 'long',
        label = 'Long Delivery',
        description = 'Livrare lunga pe harta, risc mare si reward mare.',
        reward = { min = 15000, max = 30000 },
        xp = { min = 700, max = 1500 },
        cooldown = 60 * 60, -- cooldown dupa castig
        failCooldown = 15 * 60, -- cooldown daca pierde
        timeLimit = 700,
        start = vector4(164.202194, -3290.650634, 4.909180, 269.29),
        finish = vector3(162.764832, 6448.338378, 30.301880)
    },
    special = {
        id = 'special',
        label = 'SPECIAL',
        subLabel = 'Duo Delivery',
        description = 'Fa o livrare impreuna cu prietenul tau si impartiti recompensa finala.',
        special = true,
        reward = { min = 25000, max = 50000 },
        xp = { min = 1000, max = 5000 },
        cooldown = 24 * 60 * 60, -- cooldown dupa castig
        failCooldown = 60 * 60, -- cooldown daca pierde
        timeLimit = 3 * 60,
        start1 = vector4(52.391208, -600.843934, 31.621948, 161.57),
        start2 = vector4(48.857144, -599.723084, 31.638794, 161.57),
        finish = vector3(-1820.439576, -1245.956054, 13.002930)
    }
}

Config.Notify = {
    event = 'client:notify'
}

Config.Debug = false

-- Fallback daca nu ai rulat sql.sql si cash este INT normal.
-- Scriptul nu mai crapa la reward; daca atingi limita, ruleaza sql.sql.
Config.SafeCashMax = 2147483647
