Config = {}

Config.UsersTable = 'users'
Config.UsersUidColumn = 'uid'
Config.AdutyColumn = 'aduty'

Config.ResetAduty = {
    ResetAllOnResourceStart = true,
    ResourceStartDelayMs = 2500,

    ResetOnlinePlayersOnResourceStart = true,

    JoinReset = {
        enabled = true,
        attempts = 18,
        intervalMs = 1200
    }
}

Config.Client = {
    HideDefaultHud = true,
    DisableWeaponWheel = true,
    DisableVehicleMusicWheel = true,
    ForceVehicleRadioOff = true,
    DisableVehicleDriveBy = true,
    DisableCarjackDriverPullout = true,

    -- Dezactiveaza stealth mode-ul GTA. Pe CTRL pune crouch custom.
    DisableStealthMode = true,
    EnableCrouchReplacement = true,
    CrouchControl = 36,
    CrouchKey = 'LCONTROL',
    CrouchMoveClipset = 'move_ped_crouched',
    CrouchStrafeClipset = 'move_ped_crouched_strafing',

    -- Dezactiveaza camera idle / AFK cinematic camera.
    DisableIdleCamera = true,

    -- Activeaza damage intre playeri: gloante, pumni, melee.
    -- Nu activeaza drive-by; drive-by ramane blocat separat.
    EnablePlayerDamage = true,
    PlayerDamageLoopWaitMs = 750,
    ForceDisableInvincible = false,

    -- Crosshair / reticle.
    -- Daca alte UI-uri/HUD-uri il ascund, il fortam cand tii arma/aim.
    ForceCrosshair = true,
    CrosshairOnlyWhileAiming = true,

    -- Cu 0 trebuie sa ruleze in fiecare frame pentru controale/HUD.
    MainLoopWaitMs = 0,

    -- Thread separat, optimizat, pentru radio OFF si anti-carjack.
    VehicleCheckIntervalMs = 650,
    AntiCarjackRange = 10.0
}

Config.HiddenHudComponents = {
    1,  -- wanted stars
    2,  -- weapon icon
    3,  -- cash
    4,  -- mp cash
    5,  -- mp message
    6,  -- vehicle name
    7,  -- area name
    8,  -- vehicle class
    9,  -- street name
    10, -- help text
    11, -- floating help text 1
    12, -- floating help text 2
    13, -- cash change
    16, -- radio stations
    17, -- saving
    19, -- weapon wheel
    20, -- weapon wheel stats
    22  -- hud weapons
}

Config.DisabledWeaponControls = {
    12, 13, 14, 15, 16, 17, 37, 99, 100,
    157, 158, 159, 160, 161, 162, 163, 164, 165
}

Config.DisabledVehicleMusicControls = {
    81, 82, 83, 84, 85
}

Config.DisabledVehicleShootingControls = {
    24, 25, 68, 69, 70, 91, 92, 114, 257, 263, 264
}


Config.DisabledStealthControls = {
    36 -- INPUT_DUCK / stealth
}


