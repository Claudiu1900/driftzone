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

local function notify(src, notifyType, message, duration)
    if src == 0 then
        print('[DRIFTZONE_CYCLE] ' .. tostring(message or ''))
        return
    end

    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function isDutyValue(value)
    if value == true then return true end

    local text = tostring(value or ''):lower()
    return tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getIdentifierMap(src)
    local ids = {}

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        local key, value = tostring(identifier):match('^([^:]+):(.+)$')

        if key and value then
            ids[key] = value
            ids[key .. '_full'] = tostring(identifier)
        end
    end

    return ids
end

local function getUidFromState(src)
    local state = Player(src).state
    if not state then return nil end

    local keys = (Config.Admin and Config.Admin.uidStateKeys) or { 'dz_uid', 'uid', 'user_id', 'userId' }

    for i = 1, #keys do
        local value = state[keys[i]]
        if tonumber(value) and tonumber(value) > 0 then
            return tonumber(value)
        end
    end

    return nil
end

local function getUidFromExports(src)
    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end,
        function() return exports.driftzone_auth:getUserId(src) end,
        function() return exports.driftzone_auth:GetPlayerUID(src) end,
        function() return exports.driftzone_auth:getPlayerUID(src) end
    }

    for i = 1, #attempts do
        local ok, uid = pcall(attempts[i])

        if ok and tonumber(uid) and tonumber(uid) > 0 then
            return tonumber(uid)
        end
    end

    return nil
end

local function getUidFromIdentifiers(src)
    local ids = getIdentifierMap(src)
    local playerName = GetPlayerName(src) or ''
    local conditions = {}
    local params = {}

    -- Aceste query-uri sunt facute individual cu pcall ca sa nu cada daca lipseste o coloana.
    local checks = {
        { column = 'license', values = { ids.license_full, ids.license } },
        { column = 'identifier', values = { ids.license_full, ids.license, ids.steam_full, ids.steam } },
        { column = 'steam', values = { ids.steam_full, ids.steam } },
        { column = 'discord', values = { ids.discord_full, ids.discord } },
        { column = 'fivem', values = { ids.fivem_full, ids.fivem } },
        { column = 'username', values = { playerName } }
    }

    for _, check in ipairs(checks) do
        for _, value in ipairs(check.values or {}) do
            if value and value ~= '' then
                local query = ('SELECT uid FROM users WHERE `%s` = ? LIMIT 1'):format(check.column)

                local ok, row = pcall(function()
                    return MySQL.single.await(query, { value })
                end)

                if ok and row and tonumber(row.uid) then
                    return tonumber(row.uid)
                end
            end
        end
    end

    return nil
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    return getUidFromState(src) or getUidFromExports(src) or getUidFromIdentifiers(src)
end

local function isLogged(src)
    local state = Player(src).state

    if state then
        if state.dz_logged == true or state.logged == true or state.isLoggedIn == true then
            return true
        end
    end

    local attempts = {
        function() return exports.driftzone_auth:IsLoggedIn(src) end,
        function() return exports.driftzone_auth:isLoggedIn(src) end,
        function() return exports.driftzone_auth:IsLogged(src) end
    }

    for i = 1, #attempts do
        local ok, result = pcall(attempts[i])
        if ok and result == true then
            return true
        end
    end

    -- Nu bloca adminul daca auth-ul nu expune logged, dar UID-ul exista.
    return getUid(src) ~= nil
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then
        return nil, 'uid_missing'
    end

    -- FIX FINAL: nu mai folosim SHOW COLUMNS.
    -- Query direct pe coloanele tale exacte: users.uid, users.admin_level, users.aduty.
    local ok, row = pcall(function()
        return MySQL.single.await([[
            SELECT uid, username, admin_level, aduty
            FROM users
            WHERE uid = ?
            LIMIT 1
        ]], { uid })
    end)

    if not ok then
        print('[DRIFTZONE_CYCLE] Admin query failed: ' .. tostring(row))
        return nil, 'query_failed'
    end

    if not row then
        return nil, 'row_missing'
    end

    return {
        uid = tonumber(row.uid or uid) or uid,
        username = tostring(row.username or GetPlayerName(src) or 'Admin'),
        level = tonumber(row.admin_level or 0) or 0,
        aduty = isDutyValue(row.aduty)
    }, nil
end

local function requireAdmin(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local data, reason = getAdminData(src)

    if not data then
        if reason == 'uid_missing' then
            notify(src, 'warning', 'Nu ti-am gasit UID-ul. Asteapta cateva secunde dupa login sau da relog.')
        elseif reason == 'row_missing' then
            notify(src, 'warning', 'Nu exista rand in users pentru UID-ul tau.')
        elseif reason == 'query_failed' then
            notify(src, 'warning', 'Query-ul de admin a esuat. Verifica server console.')
        else
            notify(src, 'warning', 'Nu ti-am gasit datele de admin in baza de date.')
        end

        return nil
    end

    if data.level < (Config.Admin.requiredLevel or 6) then
        notify(src, 'warning', ('Nu ai acces la aceasta comanda. Ai admin %s, trebuie %s+.'):format(data.level, Config.Admin.requiredLevel or 6))
        return nil
    end

    if Config.Admin.requireAduty and not data.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return data
end

local function parseTime(value)
    value = tostring(value or ''):gsub('%s+', '')
    local hour, minute = value:match('^(%d%d?):(%d%d)$')

    if not hour or not minute then
        hour, minute = value:match('^(%d%d?)[%.%-](%d%d)$')
    end

    hour = tonumber(hour)
    minute = tonumber(minute)

    if not hour or not minute then return nil end
    if hour < 0 or hour > 23 then return nil end
    if minute < 0 or minute > 59 then return nil end

    return {
        hour = hour,
        minute = minute,
        second = 0,
        frozen = true
    }
end

local function normalizeWeather(value)
    value = tostring(value or ''):upper():gsub('%s+', '')

    if value == 'FOG' then value = 'FOGGY' end
    if value == 'CLOUDY' then value = 'CLOUDS' end
    if value == 'STORM' then value = 'THUNDER' end

    if Config.AllowedWeather[value] then
        return value
    end

    return nil
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
        local wday = tonumber(os.date('!%w', t))

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

    if code == 95 or code == 96 or code == 99 then return 'THUNDER' end
    if code == 71 or code == 73 or code == 75 or code == 77 or code == 85 or code == 86 then return 'SNOW' end
    if code == 56 or code == 57 or code == 66 or code == 67 then return 'RAIN' end
    if code == 51 or code == 53 or code == 55 or code == 61 or code == 63 or code == 65 or code == 80 or code == 81 or code == 82 then return 'RAIN' end
    if precipitation > 0.2 then return 'RAIN' end
    if code == 45 or code == 48 then return 'FOGGY' end
    if code == 3 then return 'OVERCAST' end
    if code == 2 then return 'CLOUDS' end
    if code == 1 then return 'CLEAR' end
    if cloudCover >= 85 then return 'OVERCAST' end
    if cloudCover >= 45 then return 'CLOUDS' end

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

local function commandTime(src, args)
    local admin = requireAdmin(src)
    if not admin then return true end

    local parsed = parseTime(args and args[1])

    if not parsed then
        notify(src, 'info', 'Folosire: /time 20:23')
        return true
    end

    TriggerClientEvent('driftzone_cycle:client:setLocalTime', src, parsed)
    notify(src, 'success', ('Ti-ai setat timpul local la %02d:%02d.'):format(parsed.hour, parsed.minute))
    return true
end

local function commandWeather(src, args)
    local admin = requireAdmin(src)
    if not admin then return true end

    local weather = normalizeWeather(args and args[1])

    if not weather then
        notify(src, 'info', 'Folosire: /weather EXTRASUNNY/CLEAR/CLOUDS/RAIN/THUNDER/FOGGY/OVERCAST/SNOW')
        return true
    end

    TriggerClientEvent('driftzone_cycle:client:setLocalWeather', src, {
        weather = weather,
        frozen = true
    })

    notify(src, 'success', ('Ti-ai setat vremea locala la %s.'):format(weather))
    return true
end

local function commandResetCycle(src)
    local admin = requireAdmin(src)
    if not admin then return true end

    TriggerClientEvent('driftzone_cycle:client:resetLocalOverride', src, CurrentTime, CurrentWeather)
    notify(src, 'success', 'Ai revenit la cycle-ul normal al serverului.')
    return true
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

RegisterCommand('time', function(src, args)
    if src == 0 then return end
    commandTime(src, args or {})
end, false)

RegisterCommand('weather', function(src, args)
    if src == 0 then return end
    commandWeather(src, args or {})
end, false)

RegisterCommand('resetcycle', function(src)
    if src == 0 then return end
    commandResetCycle(src)
end, false)

RegisterCommand('resetcylce', function(src)
    if src == 0 then return end
    commandResetCycle(src)
end, false)

exports('RunCommand', function(src, command, args)
    command = tostring(command or ''):lower():gsub('^/', '')

    if command == 'time' then
        return commandTime(src, args or {})
    end

    if command == 'weather' then
        return commandWeather(src, args or {})
    end

    if command == 'resetcycle' or command == 'resetcylce' then
        return commandResetCycle(src)
    end

    if command == 'synctime' then
        CurrentTime = getRomaniaTime()
        fetchWeather()
        notify(src, 'info', 'Ora si vremea au fost sincronizate cu Mangalia.')
        return true
    end

    return false
end)

CreateThread(function()
    Wait(1000)

    CurrentTime = getRomaniaTime()
    fetchWeather()
    syncAll()

    print(('[DRIFTZONE_CYCLE] Loaded final admin fix. Timezone: Europe/Bucharest | Weather: %s'):format(Config.Location.name))

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
