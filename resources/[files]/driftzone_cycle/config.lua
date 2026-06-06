Config = {}

Config.Debug = false

-- Mangalia, judetul Constanta
Config.Location = {
    name = 'Mangalia, Constanta',
    latitude = 43.8152,
    longitude = 28.5749,
    timezone = 'Europe/Bucharest'
}

Config.Time = {
    enabled = true,
    syncEverySeconds = 30,
    freezeTime = false,
    secondsInGame = true
}

Config.Weather = {
    enabled = true,
    syncEveryMinutes = 10,
    transitionSeconds = 18,
    fallback = 'EXTRASUNNY',
    useRainAmount = true
}

Config.Admin = {
    requiredLevel = 6,
    requireAduty = true,

    -- Coloanele tale exacte:
    adminColumn = 'admin_level',
    adutyColumn = 'aduty',

    -- Fallback-uri pentru UID in caz ca driftzone_auth nu a setat inca dz_uid.
    uidStateKeys = {
        'dz_uid',
        'uid',
        'user_id',
        'userId'
    }
}

Config.AllowedWeather = {
    EXTRASUNNY = true,
    CLEAR = true,
    CLOUDS = true,
    SMOG = true,
    FOGGY = true,
    OVERCAST = true,
    RAIN = true,
    THUNDER = true,
    CLEARING = true,
    NEUTRAL = true,
    SNOW = true,
    BLIZZARD = true,
    SNOWLIGHT = true,
    XMAS = true,
    HALLOWEEN = true
}

-- Daca ai alt resource de vreme/timp, opreste-l sau va suprascrie acest resource.
