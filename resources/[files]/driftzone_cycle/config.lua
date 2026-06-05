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

-- Daca ai alt resource de vreme/timp, opreste-l sau va suprascrie acest resource.
