Config = {}

Config.MainColor = '#04c7f7'

Config.OpenKey = 'M'
Config.OpenKeyControl = 244 -- M
Config.UseKeybind = false
Config.UseCommand = true
Config.Command = 'garage'
Config.ParkCommand = 'park'

Config.SpawnCooldownMs = 3000
Config.ParkingSpotClearRadius = 3.2
Config.DefaultGarageRadius = 4.0
Config.DefaultParkRadius = 12.0
Config.DefaultVisibleRadius = true

Config.SpawnDistance = 5.5
Config.DeleteDistance = 8.0
Config.BlipSprite = 225
Config.BlipColor = 2
Config.BlipScale = 0.82

Config.DefaultFuel = 100.0
Config.DefaultEngineHealth = 1000.0
Config.DefaultBodyHealth = 1000.0

Config.NotifyEvent = 'client:notify'

Config.Admin = {
    minLevelAddGarage = 6,
    minLevelEditGarages = 6,
    minLevelResetGarages = 6
}

Config.Database = {
    garagesTable = 'garages',
    usersTable = 'users',
    uidColumn = 'uid',
    adminColumn = 'admin_level',
    adutyColumn = 'aduty'
}

-- Folosite doar ca fallback/migrare daca tabela garages este goala.
Config.Garages = {
    {
        name = 'Pillbox Garage',
        coords = vector3(215.15, -809.95, 30.73),
        radius = 4.0,
        visible_radius = true,
        parking_spots = {
            vector4(229.70, -800.12, 30.57, 158.0),
            vector4(232.60, -801.20, 30.56, 158.0),
            vector4(235.40, -802.25, 30.55, 158.0)
        }
    },
    {
        name = 'Showroom Garage',
        coords = vector3(-39.139870, -1110.605835, 26.438608),
        radius = 4.0,
        visible_radius = true,
        parking_spots = {
            vector4(-43.50, -1102.72, 26.42, 70.0),
            vector4(-47.35, -1100.95, 26.42, 70.0)
        }
    }
}

Config.Block = {
    defaultReason = 'Garaj indisponibil.'
}

Config.Draw = {
    markerType = 36,
    markerScale = vector3(0.82, 0.82, 0.82),
    radiusMarkerType = 1,
    radiusAlpha = 58,
    signDistance = 45.0,
    interactDistance = 4.0
}
