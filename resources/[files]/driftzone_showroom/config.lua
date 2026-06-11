Config = {}

Config.CashColumn = 'cash'
Config.DzCoinsColumn = 'dzcoins'
Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsersVipColumn = 'vip'
Config.VehicleCacheSeconds = 30

-- Legacy category names raman pentru compatibilitate.
Config.CategoryNames = {
    [1] = 'STARTER',
    [2] = 'STREET CLASS',
    [3] = 'JDM LEGENDS',
    [4] = 'PRO DRIFT',
    [5] = 'ELITE CLASS',
    vip = 'VIP',
    [6] = 'CUSTOM'
}

-- Butoanele mari + subcategoriile din showroom.
-- vehiclenames.showroom_section: DRIFT / HS / PREMIUM / CUSTOM
-- vehiclenames.showroom_subcategory:
-- DRIFT: starter / drifter / jdm_legends
-- HS: starter / racer / legend
-- PREMIUM: drift / hs
-- CUSTOM: all
Config.ShowroomGroups = {
    DRIFT = {
        { id = 'all', label = 'ALL' },
        { id = 'starter', label = 'Starter' },
        { id = 'drifter', label = 'Drifter' },
        { id = 'jdm_legends', label = 'JDM Legends' }
    },
    HS = {
        { id = 'all', label = 'ALL' },
        { id = 'starter', label = 'Starter' },
        { id = 'racer', label = 'Racer' },
        { id = 'legend', label = 'Legend' }
    },
    PREMIUM = {
        { id = 'all', label = 'ALL' },
        { id = 'drift', label = 'Drift' },
        { id = 'hs', label = 'HS' }
    },
    CUSTOM = {
        { id = 'all', label = 'ALL' }
    }
}

Config.Showroom = {
    Interaction = { coords = vector3(-36.083958, -1102.284546, 26.422356), range = 2.5 },
    PlayerPosition = { coords = vector3(-36.083958, -1102.284546, 26.422356), heading = 70.0 },
    BuyExit = { coords = vector3(-39.139870, -1110.605835, 26.438608), heading = 93.0 },
    PreviewVehicle = { coords = vector3(-42.85, -1096.65, 25.95), heading = 165.0 },
    TestDriveSpawn = { coords = vector3(-50.35, -1113.42, 26.43), heading = 70.0 },
    Camera = { coords = vector3(-38.85, -1100.65, 28.35), lookAt = vector3(-42.85, -1096.65, 26.55), fov = 55.0 }
}

Config.TestDriveSeconds = 120
Config.TestDriveWarnings = {
    { secondsLeft = 90, type = 'info' },
    { secondsLeft = 60, type = 'info' },
    { secondsLeft = 30, type = 'warning' },
    { secondsLeft = 5, type = 'warning' }
}

Config.PrivateBucketBase = 80000
Config.Blip = { enabled = true, sprite = 225, color = 3, scale = 0.85, name = 'DriftZone Showroom' }
Config.FallbackImage = 'https://i.imgur.com/8QfQZQp.png'
