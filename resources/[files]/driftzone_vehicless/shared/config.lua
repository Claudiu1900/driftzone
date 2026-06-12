Config = {}

Config.Command = 'vehss'
Config.NotifyEvent = 'client:notify'
Config.AuthResource = 'driftzone_auth'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = 'admin'
Config.AdutyColumn = 'aduty'

Config.AdminLevel = 6
Config.RequireAduty = true

Config.Studio = {
    coords = vector3(-75.243958, -818.716492, 326.173584),
    heading = 45.0,
    plate = 'DRIFTZ',
    freezeVehicle = true,
    cleanVehicle = true,
    invincibleVehicle = true,
    defaultFov = 47.0,
    minFov = 18.0,
    maxFov = 85.0,
    defaultDistance = 7.2,
    minDistance = 2.5,
    maxDistance = 14.0,
    defaultHeight = 1.15,
    minHeight = -0.2,
    maxHeight = 4.5,
    rotationStep = 7.5,
    fovStep = 3.0,
    distanceStep = 0.35,
    heightStep = 0.12,
    autoRotateSpeed = 0.18,
    screenshotDelayMs = 180,
    screenshotResource = 'screenshot-basic'
}
