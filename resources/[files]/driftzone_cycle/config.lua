Config = {}

Config.Debug = false

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

    -- FIX FINAL: foloseste direct aceste coloane, fara SHOW COLUMNS.
    uidColumn = 'uid',
    adminColumn = 'admin_level',
    adutyColumn = 'aduty',

    -- Daca auth-ul intarzie, incearca si aceste state keys.
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
