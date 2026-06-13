Config = {}

-- Commanda: /vehss model
Config.Command = 'vehss'
Config.CloseCommand = 'vehssclose'

-- Daca ai notify custom, lasa asa. Semnatura folosita: TriggerEvent(event, type, duration, text)
Config.NotifyEvent = 'client:notify'
Config.ChatFallback = true
Config.MainColor = '#04c7f7'

-- Auth/admin. Resource-ul NU are dependency hard pe oxmysql/driftzone_auth,
-- deci comanda nu mai moare daca lipseste un resource. Doar iti da mesaj in joc.
Config.AuthResource = 'driftzone_auth'
Config.RequireLogin = true
Config.UseDatabase = true
Config.OxmysqlResource = 'oxmysql'
Config.AllowAceFallback = true -- ace: driftzone.vehicless sau command.vehss

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = 'admin'
Config.AdutyColumn = 'aduty'
Config.UsernameColumn = 'username'

Config.AdminLevel = 6
Config.RequireAduty = true

-- Screenshot.
-- Daca ai screenshot-basic pornit, il foloseste pentru captura reala si salveaza direct pe server.
-- Daca nu exista, incearca fallback intern NUI.
Config.UseScreenshotBasic = true
Config.ScreenshotBasicResource = 'screenshot-basic'
Config.InternalFallbackOnScreenshotBasicError = true
Config.ScreenshotServerFolder = 'screenshots'

-- true = salveaza fix model_name.png si suprascrie poza veche cu acelasi model.
-- false = daca exista deja model_name.png, salveaza model_name_2.png, model_name_3.png etc.
Config.ScreenshotOverwriteSameModel = true

-- Limite doar pentru fallback-ul intern, nu pentru screenshot-basic.
Config.ScreenshotMaxBase64Chars = 25000000
Config.ScreenshotMaxChunks = 2500

Config.Studio = {
    coords = vector3(-75.243958, -818.716492, 326.173584),

    -- Rotatia initiala a masinii.
    heading = 45.0,

    -- Camera ramane fixa pe aceasta directie. Nu se roteste cu masina.
    cameraHeading = 45.0,

    -- Playerul este dus langa studio doar ca sa se incarce zona, apoi revine exact unde era.
    hidePlayer = true,
    freezePlayer = true,
    playerOffset = { x = 0.0, y = 0.0, z = 24.0 },
    restorePlayerPosition = true,

    -- Forteaza masina alba pe primary + secondary.
    forceWhiteColor = true,

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

    screenshotDelayMs = 650,
    screenshotFailTimeoutMs = 30000,
    screenshotEncoding = 'png',
    screenshotQuality = 0.95
}
