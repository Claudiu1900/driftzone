Config = {}

-- Comenzi
Config.Command = 'vehss'
Config.CloseCommand = 'vehssclose'

-- Notificari. Daca nu ai event-ul client:notify, seteaza nil si va folosi chat-ul.
Config.NotifyEvent = 'client:notify'
Config.ChatFallback = true
Config.MainColor = '#04c7f7'

-- Lasat pe false ca sa mearga comanda direct. Daca vrei restrictie, pune true si seteaza ACE.
Config.RequirePermission = false
Config.PermissionAce = 'driftzone.vehss'

-- Optional: integrare cu driftzone_auth, doar daca vrei acces dupa admin/aduty.
Config.UseDriftzoneAuth = false
Config.AuthResource = 'driftzone_auth'
Config.RequiredAdminLevel = 6
Config.RequireAduty = true

Config.Screenshot = {
    resource = 'screenshot-basic',
    directory = 'screenshots',

    -- true = mereu model_name.jpg. false = model_name.jpg, model_name_2.jpg, model_name_3.jpg
    overwriteSameModel = true,

    -- JPG e pus intentionat ca sa nu mai umple Reliable Network Queue.
    -- Daca pui png, poza devine mult mai mare si upload-ul dureaza mai mult.
    encoding = 'jpg',
    quality = 0.58,

    -- timp pentru ascunderea UI-ului inainte de poza
    prepareDelayMs = 550,

    -- upload client -> server pe bucati mici, fara crash/overflow
    chunkSize = 4000,
    chunkDelayMs = 75,
    maxChunks = 2200,
    maxDataLength = 9000000,

    -- timeout mare pentru masini/rezolutii mai grele
    timeoutMs = 180000
}

Config.Studio = {
    coords = vector3(-75.243958, -818.716492, 326.173584),
    heading = 45.0,

    -- Camera fixa. Masina se roteste, camera nu.
    cameraHeading = 45.0,

    hidePlayer = true,
    playerOffset = { x = 0.0, y = 0.0, z = 24.0 },

    plate = 'DRIFTZ',
    freezeVehicle = true,
    invincibleVehicle = true,

    -- Masina spawnata pe alb/alb.
    whiteColorIndex = 111,
    primaryRGB = { r = 255, g = 255, b = 255 },
    secondaryRGB = { r = 255, g = 255, b = 255 },

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
    modelLoadTimeoutMs = 9000
}
