local nuiReady = false
local visible = false
local wasInVehicle = false

local lastSpeed = -1
local lastGear = ''
local lastRpm = -1
local lastSent = 0

-- Nu spamam NUI. Update-ul ramane foarte usor.
local UPDATE_MS = 80
local MIN_SPEED_DELTA = 1
local MIN_RPM_DELTA = 0.025

local function sendNui(data)
    if not nuiReady then return end
    SendNUIMessage(data)
end

local function showSpeedo()
    if visible then return end

    visible = true
    sendNui({ action = 'show' })
end

local function hideSpeedo()
    if not visible then return end

    visible = false
    wasInVehicle = false
    lastSpeed = -1
    lastGear = ''
    lastRpm = -1

    sendNui({ action = 'hide' })
end

local function getSpeedKmh(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end

    return math.floor(GetEntitySpeed(vehicle) * 3.6 + 0.5)
end

local function getRpm(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0.0 end

    local rpm = GetVehicleCurrentRpm(vehicle) or 0.0

    if rpm < 0.0 then rpm = 0.0 end
    if rpm > 1.0 then rpm = 1.0 end

    return rpm
end

local function getGear(vehicle, speed)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 'N' end

    speed = tonumber(speed or 0) or 0

    if speed <= 1 then
        return 'N'
    end

    local velocity = GetEntityVelocity(vehicle)
    local forward = GetEntityForwardVector(vehicle)
    local dot = velocity.x * forward.x + velocity.y * forward.y + velocity.z * forward.z

    if dot < -0.35 then
        return 'R'
    end

    local gear = GetVehicleCurrentGear(vehicle)

    if not gear or gear <= 0 then
        return '1'
    end

    return tostring(gear)
end

local function shouldShowForVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local ped = PlayerPedId()

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return false
    end

    local class = GetVehicleClass(vehicle)

    -- Hide pentru biciclete, barci, elicoptere, avioane, trenuri.
    if class == 13 or class == 14 or class == 15 or class == 16 or class == 21 then
        return false
    end

    return true
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendNui({ action = 'hide' })
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_turometru:client:show', function()
    showSpeedo()
end)

RegisterNetEvent('driftzone_turometru:client:hide', function()
    hideSpeedo()
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if shouldShowForVehicle(vehicle) then
            if not wasInVehicle then
                wasInVehicle = true
                lastSpeed = -1
                lastGear = ''
                lastRpm = -1
                lastSent = 0
                showSpeedo()
            end

            local now = GetGameTimer()

            if now - lastSent >= UPDATE_MS then
                local speed = getSpeedKmh(vehicle)
                local gear = getGear(vehicle, speed)
                local rpm = getRpm(vehicle)

                if math.abs(speed - lastSpeed) >= MIN_SPEED_DELTA
                    or gear ~= lastGear
                    or math.abs(rpm - lastRpm) >= MIN_RPM_DELTA
                then
                    lastSpeed = speed
                    lastGear = gear
                    lastRpm = rpm
                    lastSent = now

                    sendNui({
                        action = 'update',
                        speed = speed,
                        gear = gear,
                        rpm = rpm
                    })
                end
            end

            Wait(0)
        else
            if wasInVehicle or visible then
                hideSpeedo()
            end

            Wait(350)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    hideSpeedo()
end)
