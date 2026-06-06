local currentWeather = 'EXTRASUNNY'
local lastHour = -1
local lastMinute = -1
local lastSecond = -1
local lastWeatherUpdate = 0

local localOverride = {
    time = nil,
    weather = nil
}

local function applyTime(timeData, force)
    if not Config.Time.enabled then return end
    if type(timeData) ~= 'table' then return end

    local hour = tonumber(timeData.hour or 12) or 12
    local minute = tonumber(timeData.minute or 0) or 0
    local second = tonumber(timeData.second or 0) or 0

    if force or hour ~= lastHour or minute ~= lastMinute or second ~= lastSecond then
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
    if not localOverride.time then
        applyTime(timeData)
    end

    if not localOverride.weather then
        applyWeather(weatherData, lastWeatherUpdate == 0)
    end
end)

RegisterNetEvent('driftzone_cycle:client:setLocalTime', function(timeData)
    if type(timeData) ~= 'table' then return end

    localOverride.time = {
        hour = tonumber(timeData.hour or 12) or 12,
        minute = tonumber(timeData.minute or 0) or 0,
        second = tonumber(timeData.second or 0) or 0
    }

    applyTime(localOverride.time, true)
end)

RegisterNetEvent('driftzone_cycle:client:setLocalWeather', function(weatherData)
    if type(weatherData) ~= 'table' then return end

    local weather = tostring(weatherData.weather or ''):upper()
    if weather == '' then return end

    localOverride.weather = {
        weather = weather
    }

    applyWeather(localOverride.weather, true)
end)

RegisterNetEvent('driftzone_cycle:client:resetLocalOverride', function(timeData, weatherData)
    localOverride.time = nil
    localOverride.weather = nil

    ClearOverrideWeather()
    ClearWeatherTypePersist()

    applyTime(timeData, true)
    applyWeather(weatherData, true)
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
        if Config.Time.enabled then
            if localOverride.time then
                applyTime(localOverride.time, true)
                Wait(0)
            elseif Config.Time.freezeTime then
                if lastHour >= 0 and lastMinute >= 0 then
                    NetworkOverrideClockTime(lastHour, lastMinute, lastSecond >= 0 and lastSecond or 0)
                end
                Wait(0)
            else
                Wait(1000)
            end
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if Config.Weather.enabled and currentWeather then
            if localOverride.weather then
                applyWeather(localOverride.weather, true)
            else
                SetWeatherTypePersist(currentWeather)
                SetWeatherTypeNowPersist(currentWeather)

                if currentWeather == 'RAIN' or currentWeather == 'THUNDER' then
                    SetRainLevel(0.55)
                else
                    SetRainLevel(0.0)
                end
            end
        end

        Wait(localOverride.weather and 1000 or 10000)
    end
end)
