Config = {}

Config.Command = 'vehss'
Config.NotifyEvent = 'client:notify'
Config.AuthResource = 'driftzone_auth'
Config.MainColor = '#04c7f7'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = 'admin'
Config.AdutyColumn = 'aduty'

Config.AdminLevel = 6
Config.RequireAduty = true

Config.Studio = {
    coords = vector3(-75.243958, -818.716492, 326.173584),

    -- Rotatia initiala a masinii.
    heading = 45.0,

    -- Camera ramane fixa pe aceasta directie. Nu se mai roteste cand rotesti masina.
    cameraHeading = 45.0,

    -- Playerul este dus sus si ascuns ca sa nu intre in poza/camera.
    hidePlayer = true,
    playerOffset = { x = 0.0, y = 0.0, z = 24.0 },

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

    defaultLookHeight = 0.65,
    minLookHeight = -0.4,
    maxLookHeight = 2.8,

    rotationStep = 7.5,
    fovStep = 3.0,
    distanceStep = 0.35,
    heightStep = 0.12,
    lookHeightStep = 0.10,

    autoRotateSpeed = 0.18,
    modelLoadTimeoutMs = 9000,
    screenshotDelayMs = 350,
    screenshotFailTimeoutMs = 9000,
    screenshotEncoding = 'png',
    screenshotQuality = 0.95
}
