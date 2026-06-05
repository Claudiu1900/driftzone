local droneActive = false
local droneCam = nil
local dronePoint = nil
local currentRot = vector3(0.0, 0.0, 0.0)

local function notify(notifyType, message, duration)
    if Config.Notify and Config.Notify.enabled then
        TriggerEvent(Config.Notify.event or 'client:notify', notifyType or 'info', duration or 5000, tostring(message or ''))
    end
end

local function lerp(a, b, t) return a + (b - a) * t end

local function normalizeAngle(angle)
    angle = angle % 360.0
    if angle > 180.0 then angle = angle - 360.0 end
    return angle
end

local function lerpAngle(a, b, t)
    local diff = normalizeAngle(b - a)
    return a + diff * t
end

local function rotFromDirection(direction)
    local dx, dy, dz = direction.x, direction.y, direction.z
    local heading = math.deg(math.atan2(dy, dx)) - 90.0
    local horizontal = math.sqrt(dx * dx + dy * dy)
    local pitch = -math.deg(math.atan2(dz, horizontal))
    return vector3(pitch, 0.0, heading)
end

local function getHeadCoords()
    local ped = PlayerPedId()
    local coords = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local offset = Config.HeadOffset or vector3(0.0, 0.0, 0.08)
    return vector3(coords.x + offset.x, coords.y + offset.y, coords.z + offset.z)
end

local function destroyDrone()
    droneActive = false
    dronePoint = nil

    if droneCam and DoesCamExist(droneCam) then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(droneCam, false)
    else
        RenderScriptCams(false, true, 350, true, true)
    end

    droneCam = nil
    SetFocusEntity(PlayerPedId())
    ClearFocus()
    notify('info', 'Drone camera dezactivata.')
end

local function createDrone(point)
    local x = type(point) == 'table' and tonumber(point.x) or nil
    local y = type(point) == 'table' and tonumber(point.y) or nil
    local z = type(point) == 'table' and tonumber(point.z) or nil

    if not x or not y or not z then
        notify('error', 'Punct drone invalid.')
        return
    end

    if droneActive then
        destroyDrone()
        return
    end

    dronePoint = vector3(x + 0.0, y + 0.0, z + 0.0)
    droneCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(droneCam, dronePoint.x, dronePoint.y, dronePoint.z)

    local pedCoords = GetEntityCoords(PlayerPedId())
    local rot = rotFromDirection(pedCoords - dronePoint)

    currentRot = rot
    SetCamRot(droneCam, rot.x, rot.y, rot.z, 2)
    SetCamActive(droneCam, true)
    RenderScriptCams(true, true, 350, true, true)
    SetFocusPosAndVel(dronePoint.x, dronePoint.y, dronePoint.z, 0.0, 0.0, 0.0)

    droneActive = true
    notify('success', 'Drone camera activata. Foloseste /drone pentru dezactivare.')
end

RegisterNetEvent('driftzone_drone:client:capturePoint', function()
    local started = GetGameTimer()

    CreateThread(function()
        while GetGameTimer() - started < (Config.CaptureTimeoutMs or 2500) do
            if not IsPedDeadOrDying(PlayerPedId(), true) then
                local coords = getHeadCoords()
                TriggerServerEvent('driftzone_drone:server:savePoint', { x = coords.x, y = coords.y, z = coords.z })
                return
            end
            Wait(50)
        end
        notify('error', 'Nu am putut captura coordonatele capului.')
    end)
end)

RegisterNetEvent('driftzone_drone:client:toggleDrone', function(point)
    createDrone(point)
end)

CreateThread(function()
    while true do
        if droneActive and droneCam and DoesCamExist(droneCam) and dronePoint then
            local target = GetEntityCoords(PlayerPedId())
            local targetRot = rotFromDirection(target - dronePoint)
            local t = tonumber(Config.CameraLerp or 0.08) or 0.08

            currentRot = vector3(
                lerp(currentRot.x, targetRot.x, t),
                0.0,
                lerpAngle(currentRot.z, targetRot.z, t)
            )

            SetCamCoord(droneCam, dronePoint.x, dronePoint.y, dronePoint.z)
            SetCamRot(droneCam, currentRot.x, currentRot.y, currentRot.z, 2)
            SetFocusPosAndVel(dronePoint.x, dronePoint.y, dronePoint.z, 0.0, 0.0, 0.0)

            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 3, true)
            DisableControlAction(0, 4, true)
            DisableControlAction(0, 5, true)
            DisableControlAction(0, 6, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 44, true)

            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if droneActive then destroyDrone() end
end)

exports('IsDroneActive', function() return droneActive end)
exports('DisableDrone', function() if droneActive then destroyDrone() end end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_DRONE] Client-side loaded.')
end)
