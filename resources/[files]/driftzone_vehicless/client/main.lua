local open = false
local studioVehicle = 0
local studioCam = nil
local currentModel = nil
local currentSettings = {
    heading = 45.0,
    fov = 47.0,
    distance = 7.2,
    height = 1.15,
    autoRotate = false,
    lights = true,
    doors = false
}

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 5000, tostring(msg or ''))
end

local function sendNui(data)
    SendNUIMessage(data)
end

local function setFocus(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function clamp(value, min, max)
    value = tonumber(value or 0) or 0
    if value < min then return min end
    if value > max then return max end
    return value
end

local function destroyStudio()
    open = false
    currentModel = nil

    if studioCam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(studioCam, false)
        studioCam = nil
    end

    if studioVehicle and studioVehicle ~= 0 and DoesEntityExist(studioVehicle) then
        SetEntityAsMissionEntity(studioVehicle, true, true)
        DeleteEntity(studioVehicle)
        studioVehicle = 0
    end

    FreezeEntityPosition(PlayerPedId(), false)
    setFocus(false)
    sendNui({ action = 'close' })
end

local function updateCamera()
    if not open or not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then return end
    if not studioCam then return end

    local coords = GetEntityCoords(studioVehicle)
    local heading = GetEntityHeading(studioVehicle)
    local rad = math.rad(heading)
    local dist = currentSettings.distance or Config.Studio.defaultDistance
    local height = currentSettings.height or Config.Studio.defaultHeight

    -- Camera in fata masinii.
    local camX = coords.x + -math.sin(rad) * dist
    local camY = coords.y + math.cos(rad) * dist
    local camZ = coords.z + height

    SetCamCoord(studioCam, camX, camY, camZ)
    PointCamAtCoord(studioCam, coords.x, coords.y, coords.z + 0.65)
    SetCamFov(studioCam, currentSettings.fov or Config.Studio.defaultFov)
end

local function applyVehicleLook()
    if not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then return end

    SetVehicleModKit(studioVehicle, 0)
    SetEntityHeading(studioVehicle, currentSettings.heading or Config.Studio.heading)
    SetVehicleDirtLevel(studioVehicle, 0.0)
    SetVehicleEngineOn(studioVehicle, false, true, true)
    SetVehicleRadioEnabled(studioVehicle, false)
    SetVehRadioStation(studioVehicle, 'OFF')
    SetVehicleNumberPlateText(studioVehicle, Config.Studio.plate or 'DRIFTZ')

    if Config.Studio.invincibleVehicle then
        SetEntityInvincible(studioVehicle, true)
        SetVehicleCanBreak(studioVehicle, false)
        SetVehicleEngineCanDegrade(studioVehicle, false)
    end

    if Config.Studio.freezeVehicle then
        FreezeEntityPosition(studioVehicle, true)
    end

    if currentSettings.lights then
        SetVehicleLights(studioVehicle, 2)
        SetVehicleFullbeam(studioVehicle, true)
    else
        SetVehicleLights(studioVehicle, 0)
        SetVehicleFullbeam(studioVehicle, false)
    end

    if currentSettings.doors then
        SetVehicleDoorOpen(studioVehicle, 0, false, false)
        SetVehicleDoorOpen(studioVehicle, 1, false, false)
        SetVehicleDoorOpen(studioVehicle, 4, false, false)
        SetVehicleDoorOpen(studioVehicle, 5, false, false)
    else
        for i = 0, 7 do SetVehicleDoorShut(studioVehicle, i, false) end
    end
end

local function spawnStudioVehicle(modelName)
    modelName = tostring(modelName or ''):lower()
    local hash = joaat(modelName)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        notify('warning', 'Model invalid: ' .. modelName)
        return false
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 9000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then
            notify('warning', 'Nu am putut incarca modelul: ' .. modelName)
            return false
        end
    end

    if studioVehicle ~= 0 and DoesEntityExist(studioVehicle) then
        SetEntityAsMissionEntity(studioVehicle, true, true)
        DeleteEntity(studioVehicle)
        studioVehicle = 0
    end

    local c = Config.Studio.coords
    studioVehicle = CreateVehicle(hash, c.x, c.y, c.z, Config.Studio.heading or 45.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then
        notify('warning', 'Nu am putut crea masina.')
        return false
    end

    currentModel = modelName
    currentSettings.heading = Config.Studio.heading or 45.0
    currentSettings.fov = Config.Studio.defaultFov or 47.0
    currentSettings.distance = Config.Studio.defaultDistance or 7.2
    currentSettings.height = Config.Studio.defaultHeight or 1.15
    currentSettings.autoRotate = false
    currentSettings.lights = true
    currentSettings.doors = false

    SetEntityAsMissionEntity(studioVehicle, true, true)
    SetVehicleOnGroundProperly(studioVehicle)
    applyVehicleLook()

    if not studioCam then
        studioCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end

    SetCamActive(studioCam, true)
    RenderScriptCams(true, true, 400, true, true)
    updateCamera()

    return true
end

local function updateUi()
    sendNui({
        action = 'state',
        model = currentModel or '',
        heading = math.floor((currentSettings.heading or 0) * 10) / 10,
        fov = math.floor((currentSettings.fov or 0) * 10) / 10,
        distance = math.floor((currentSettings.distance or 0) * 10) / 10,
        height = math.floor((currentSettings.height or 0) * 10) / 10,
        autoRotate = currentSettings.autoRotate == true,
        lights = currentSettings.lights == true,
        doors = currentSettings.doors == true,
        screenshotReady = GetResourceState(Config.Studio.screenshotResource or 'screenshot-basic') == 'started'
    })
end

RegisterCommand(Config.Command or 'vehss', function(_, args)
    TriggerServerEvent('driftzone_vehicless:server:requestOpen', args and args[1] or '')
end, false)

RegisterNetEvent('driftzone_vehicless:client:openStudio', function(data)
    data = data or {}
    local model = data.model or ''

    local ok = spawnStudioVehicle(model)
    if not ok then return end

    local ped = PlayerPedId()
    local c = Config.Studio.coords
    SetEntityCoords(ped, c.x + 0.0, c.y - 3.0, c.z + 1.0, false, false, false, false)
    FreezeEntityPosition(ped, true)

    open = true
    setFocus(true)
    sendNui({ action = 'open', model = model, mainColor = data.mainColor or '#04c7f7' })
    updateUi()
end)

RegisterNUICallback('close', function(_, cb)
    destroyStudio()
    cb({ ok = true })
end)

RegisterNUICallback('control', function(data, cb)
    data = data or {}
    local action = tostring(data.action or '')
    local s = Config.Studio

    if not open or not DoesEntityExist(studioVehicle) then cb({ ok = false }) return end

    if action == 'rotate_left' then
        currentSettings.heading = (currentSettings.heading or 0.0) - (s.rotationStep or 7.5)
    elseif action == 'rotate_right' then
        currentSettings.heading = (currentSettings.heading or 0.0) + (s.rotationStep or 7.5)
    elseif action == 'fov_down' then
        currentSettings.fov = clamp((currentSettings.fov or s.defaultFov) - (s.fovStep or 3.0), s.minFov or 18.0, s.maxFov or 85.0)
    elseif action == 'fov_up' then
        currentSettings.fov = clamp((currentSettings.fov or s.defaultFov) + (s.fovStep or 3.0), s.minFov or 18.0, s.maxFov or 85.0)
    elseif action == 'distance_down' then
        currentSettings.distance = clamp((currentSettings.distance or s.defaultDistance) - (s.distanceStep or 0.35), s.minDistance or 2.5, s.maxDistance or 14.0)
    elseif action == 'distance_up' then
        currentSettings.distance = clamp((currentSettings.distance or s.defaultDistance) + (s.distanceStep or 0.35), s.minDistance or 2.5, s.maxDistance or 14.0)
    elseif action == 'height_down' then
        currentSettings.height = clamp((currentSettings.height or s.defaultHeight) - (s.heightStep or 0.12), s.minHeight or -0.2, s.maxHeight or 4.5)
    elseif action == 'height_up' then
        currentSettings.height = clamp((currentSettings.height or s.defaultHeight) + (s.heightStep or 0.12), s.minHeight or -0.2, s.maxHeight or 4.5)
    elseif action == 'auto_rotate' then
        currentSettings.autoRotate = not currentSettings.autoRotate
    elseif action == 'lights' then
        currentSettings.lights = not currentSettings.lights
    elseif action == 'doors' then
        currentSettings.doors = not currentSettings.doors
    elseif action == 'reset' then
        currentSettings.heading = s.heading or 45.0
        currentSettings.fov = s.defaultFov or 47.0
        currentSettings.distance = s.defaultDistance or 7.2
        currentSettings.height = s.defaultHeight or 1.15
        currentSettings.autoRotate = false
        currentSettings.lights = true
        currentSettings.doors = false
    end

    currentSettings.heading = currentSettings.heading % 360.0
    applyVehicleLook()
    updateCamera()
    updateUi()
    cb({ ok = true })
end)

RegisterNUICallback('screenshot', function(_, cb)
    if not open then cb({ ok = false }) return end

    local res = Config.Studio.screenshotResource or 'screenshot-basic'
    if GetResourceState(res) ~= 'started' then
        notify('warning', 'Lipseste resource-ul screenshot-basic. Pune ensure screenshot-basic in server.cfg.')
        cb({ ok = false, error = 'screenshot-basic not started' })
        return
    end

    setFocus(false)
    sendNui({ action = 'prepareShot' })

    SetTimeout(Config.Studio.screenshotDelayMs or 180, function()
        exports[res]:requestScreenshot(function(data)
            setFocus(true)
            sendNui({
                action = 'downloadScreenshot',
                image = data,
                filename = ('driftzone_%s_%s.png'):format(tostring(currentModel or 'vehicle'), tostring(os.time()))
            })
            sendNui({ action = 'shotDone' })
            notify('success', 'Screenshot salvat in Downloads / folderul ales de browser.', 4500)
        end)
    end)

    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if open and studioVehicle ~= 0 and DoesEntityExist(studioVehicle) then
            if currentSettings.autoRotate then
                currentSettings.heading = ((currentSettings.heading or 0.0) + (Config.Studio.autoRotateSpeed or 0.18)) % 360.0
                SetEntityHeading(studioVehicle, currentSettings.heading)
                updateCamera()
                if GetGameTimer() % 350 < 20 then updateUi() end
            end
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            Wait(0)
        else
            Wait(450)
        end
    end
end)

CreateThread(function()
    while true do
        if open and (not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle)) then
            destroyStudio()
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    destroyStudio()
end)
