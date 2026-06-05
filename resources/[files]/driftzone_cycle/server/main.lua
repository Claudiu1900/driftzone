local CurrentTime = {
    hour = 12,
    minute = 0,
    second = 0,
    offset = 2,
    timestamp = os.time()
}

local CurrentWeather = {
    weather = Config.Weather.fallback or 'EXTRASUNNY',
    code = -1,
    temperature = 0.0,
    cloudCover = 0,
    precipitation = 0,
    updatedAt = 0
}

local function debugPrint(...)
    if Config.Debug then
        print('[DRIFTZONE_CYCLE]', ...)
    end
end

local function isLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

local function daysInMonth(year, month)
    local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    if month == 2 and isLeapYear(year) then return 29 end
    return days[month]
end

local function lastSunday(year, month)
    local day = daysInMonth(year, month)

    while day > 0 do
        local t = os.time({ year = year, month = month, day = day, hour = 12, min = 0, sec = 0, isdst = false })
        local wday = tonumber(os.date('!%w', t)) -- 0 Sunday

        if wday == 0 then return day end
        day = day - 1
    end

    return daysInMonth(year, month)
end

local function getRomaniaUtcOffset(timestamp)
    timestamp = timestamp or os.time()

    local utc = os.date('!*t', timestamp)
    local year = utc.year

    local marchLastSunday = lastSunday(year, 3)
    local octoberLastSunday = lastSunday(year, 10)

    -- EU DST: from last Sunday in March 01:00 UTC to last Sunday in October 01:00 UTC.
    local dstStart = os.time({ year = year, month = 3, day = marchLastSunday, hour = 1, min = 0, sec = 0, isdst = false })
    local dstEnd = os.time({ year = year, month = 10, day = octoberLastSunday, hour = 1, min = 0, sec = 0, isdst = false })

    if timestamp >= dstStart and timestamp < dstEnd then
        return 3
    end

    return 2
end

local function getRomaniaTime()
    local now = os.time()
    local offset = getRomaniaUtcOffset(now)
    local romania = os.date('!*t', now + offset * 3600)

    return {
        hour = tonumber(romania.hour) or 12,
        minute = tonumber(romania.min) or 0,
        second = tonumber(romania.sec) or 0,
        offset = offset,
        timestamp = now
    }
end

local function weatherCodeToFiveM(code, cloudCover, precipitation)
    code = tonumber(code) or 0
    cloudCover = tonumber(cloudCover) or 0
    precipitation = tonumber(precipitation) or 0

    if code == 95 or code == 96 or code == 99 then
        return 'THUNDER'
    end

    if code == 71 or code == 73 or code == 75 or code == 77 or code == 85 or code == 86 then
        return 'SNOW'
    end

    if code == 56 or code == 57 or code == 66 or code == 67 then
        return 'RAIN'
    end

    if code == 51 or code == 53 or code == 55 or code == 61 or code == 63 or code == 65 or code == 80 or code == 81 or code == 82 then
        return 'RAIN'
    end

    if precipitation > 0.2 then
        return 'RAIN'
    end

    if code == 45 or code == 48 then
        return 'FOGGY'
    end

    if code == 3 then
        return 'OVERCAST'
    end

    if code == 2 then
        return 'CLOUDS'
    end

    if code == 1 then
        return 'CLEAR'
    end

    if cloudCover >= 85 then
        return 'OVERCAST'
    end

    if cloudCover >= 45 then
        return 'CLOUDS'
    end

    return 'EXTRASUNNY'
end

local function buildWeatherUrl()
    local lat = tostring(Config.Location.latitude)
    local lon = tostring(Config.Location.longitude)

    return ('https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=weather_code,temperature_2m,precipitation,rain,showers,snowfall,cloud_cover&timezone=Europe%%2FBucharest')
        :format(lat, lon)
end

local function syncAll()
    TriggerClientEvent('driftzone_cycle:client:sync', -1, CurrentTime, CurrentWeather)
end

local function fetchWeather()
    if not Config.Weather.enabled then
        CurrentWeather.weather = Config.Weather.fallback or 'EXTRASUNNY'
        CurrentWeather.updatedAt = os.time()
        syncAll()
        return
    end

    local url = buildWeatherUrl()

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or not body or body == '' then
            print(('[DRIFTZONE_CYCLE] Weather API failed. Status: %s. Using fallback: %s'):format(tostring(status), Config.Weather.fallback or 'EXTRASUNNY'))
            CurrentWeather.weather = CurrentWeather.weather or Config.Weather.fallback or 'EXTRASUNNY'
            CurrentWeather.updatedAt = os.time()
            syncAll()
            return
        end

        local ok, data = pcall(json.decode, body)

        if not ok or type(data) ~= 'table' or type(data.current) ~= 'table' then
            print('[DRIFTZONE_CYCLE] Weather API invalid response. Using fallback.')
            CurrentWeather.weather = CurrentWeather.weather or Config.Weather.fallback or 'EXTRASUNNY'
            CurrentWeather.updatedAt = os.time()
            syncAll()
            return
        end

        local current = data.current
        local code = tonumber(current.weather_code or 0) or 0
        local cloudCover = tonumber(current.cloud_cover or 0) or 0
        local precipitation = tonumber(current.precipitation or 0) or 0
        local rain = tonumber(current.rain or 0) or 0
        local showers = tonumber(current.showers or 0) or 0
        local snowfall = tonumber(current.snowfall or 0) or 0
        local totalPrecip = precipitation + rain + showers + snowfall

        local mapped = weatherCodeToFiveM(code, cloudCover, totalPrecip)

        CurrentWeather = {
            weather = mapped,
            code = code,
            temperature = tonumber(current.temperature_2m or 0) or 0,
            cloudCover = cloudCover,
            precipitation = totalPrecip,
            updatedAt = os.time()
        }

        debugPrint(('Weather %s | code %s | temp %s | cloud %s | precip %s'):format(mapped, code, CurrentWeather.temperature, cloudCover, totalPrecip))
        syncAll()
    end, 'GET', '', {
        ['Content-Type'] = 'application/json'
    })
end

RegisterNetEvent('driftzone_cycle:server:requestSync', function()
    local src = source
    TriggerClientEvent('driftzone_cycle:client:sync', src, CurrentTime, CurrentWeather)
end)

RegisterCommand('synctime', function(src)
    CurrentTime = getRomaniaTime()
    fetchWeather()

    if src and src > 0 then
        TriggerClientEvent('client:notify', src, 'info', 5000, 'Ora si vremea au fost sincronizate cu Mangalia.')
    else
        print('[DRIFTZONE_CYCLE] Manual sync executed.')
    end
end, false)

CreateThread(function()
    Wait(1000)

    CurrentTime = getRomaniaTime()
    fetchWeather()
    syncAll()

    print(('[DRIFTZONE_CYCLE] Loaded. Timezone: Europe/Bucharest | Weather: %s'):format(Config.Location.name))

    while true do
        if Config.Time.enabled then
            CurrentTime = getRomaniaTime()
            syncAll()
        end

        Wait((Config.Time.syncEverySeconds or 30) * 1000)
    end
end)

CreateThread(function()
    Wait(5000)

    while true do
        fetchWeather()
        Wait((Config.Weather.syncEveryMinutes or 10) * 60 * 1000)
    end
end)

AddEventHandler('playerJoining', function()
    local src = source

    SetTimeout(5000, function()
        if GetPlayerPing(src) > 0 then
            TriggerClientEvent('driftzone_cycle:client:sync', src, CurrentTime, CurrentWeather)
        end
    end)
end)
