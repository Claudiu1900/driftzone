local currentWeather = 'EXTRASUNNY'
local lastHour = -1
local lastMinute = -1
local lastSecond = -1
local lastWeatherUpdate = 0

local function applyTime(timeData)
    if not Config.Time.enabled then return end
    if type(timeData) ~= 'table' then return end

    local hour = tonumber(timeData.hour or 12) or 12
    local minute = tonumber(timeData.minute or 0) or 0
    local second = tonumber(timeData.second or 0) or 0

    if hour ~= lastHour or minute ~= lastMinute or second ~= lastSecond then
        NetworkOverrideClockTime(hour, minute, second)
        lastHour = hour
        lastMinute = minute
        lastSecond = second
    end
end

local function applyWeather(weatherData, instant)
    if not Config.Weather.enabled then return end
    if type(weatherData) ~= 'table' then return end

    local weather = tostring(weatherData.weather or Config.Weather.fallback or 'EXTRASUNNY'):upper()
    if weather == '' then weather = Config.Weather.fallback or 'EXTRASUNNY' end

    if weather ~= currentWeather or instant then
        currentWeather = weather

        ClearOverrideWeather()
        ClearWeatherTypePersist()

        if instant then
            SetWeatherTypeNowPersist(currentWeather)
            SetWeatherTypeNow(currentWeather)
            SetWeatherTypePersist(currentWeather)
        else
            SetWeatherTypeOvertimePersist(currentWeather, tonumber(Config.Weather.transitionSeconds or 18) + 0.0)
            Wait((tonumber(Config.Weather.transitionSeconds or 18) + 1) * 1000)
            SetWeatherTypeNowPersist(currentWeather)
            SetWeatherTypePersist(currentWeather)
        end
    else
        SetWeatherTypePersist(currentWeather)
        SetWeatherTypeNowPersist(currentWeather)
    end

    if currentWeather == 'RAIN' or currentWeather == 'THUNDER' then
        SetRainLevel(0.55)
    else
        SetRainLevel(0.0)
    end

    if currentWeather == 'SNOW' then
        SetForceVehicleTrails(true)
        SetForcePedFootstepsTracks(true)
    else
        SetForceVehicleTrails(false)
        SetForcePedFootstepsTracks(false)
    end

    lastWeatherUpdate = GetGameTimer()
end

RegisterNetEvent('driftzone_cycle:client:sync', function(timeData, weatherData)
    applyTime(timeData)
    applyWeather(weatherData, lastWeatherUpdate == 0)
end)

RegisterNetEvent('driftzone_cycle:client:forceSync', function()
    TriggerServerEvent('driftzone_cycle:server:requestSync')
end)

CreateThread(function()
    Wait(3000)
    TriggerServerEvent('driftzone_cycle:server:requestSync')
end)

CreateThread(function()
    while true do
        if Config.Time.enabled and Config.Time.freezeTime then
            if lastHour >= 0 and lastMinute >= 0 then
                NetworkOverrideClockTime(lastHour, lastMinute, lastSecond >= 0 and lastSecond or 0)
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if Config.Weather.enabled and currentWeather then
            SetWeatherTypePersist(currentWeather)

            if currentWeather == 'RAIN' or currentWeather == 'THUNDER' then
                SetRainLevel(0.55)
            else
                SetRainLevel(0.0)
            end
        end

        Wait(10000)
    end
end)
