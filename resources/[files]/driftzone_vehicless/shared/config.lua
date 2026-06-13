Config = {}

-- Comenzi
Config.Command = 'vehss'
Config.CloseCommand = 'vehssclose'
Config.CleanToggleCommand = 'vehssclean'
Config.CleanToggleDefaultKey = 'OEM_3' -- tasta ` / ~. Daca nu merge pe tastatura ta, foloseste /vehssclean.

-- Notificari. Daca nu ai event-ul client:notify, seteaza nil si va folosi chat-ul.
Config.NotifyEvent = 'client:notify'
Config.ChatFallback = true
Config.MainColor = '#04c7f7'

-- Acces. Lasat pe false ca sa mearga direct.
Config.RequirePermission = false
Config.PermissionAce = 'driftzone.vehss'

-- Optional: integrare cu driftzone_auth, doar daca vrei acces dupa admin/aduty.
Config.UseDriftzoneAuth = false
Config.AuthResource = 'driftzone_auth'
Config.RequiredAdminLevel = 6
Config.RequireAduty = true

-- HUD extern DriftZone.
Config.Hud = {
    enabled = true,
    showEvent = 'driftzone_hud:client:show',
    hideEvent = 'driftzone_hud:client:hide',
    visibleEvent = 'driftzone_hud:visible',

    -- Nu e recomandat sa folosesti toggle, pentru ca poate inversa gresit starea.
    -- Lasa false. Daca HUD-ul tau merge DOAR cu toggle, pune true.
    callToggleEvent = false,
    toggleEvent = 'driftzone_hud:client:toggle'
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
