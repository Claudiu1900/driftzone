local open = false
local studioVehicle = 0
local studioCam = nil
local currentModel = nil
local playerState = nil
local takingShot = false
local shotToken = 0

local currentSettings = {
    heading = 45.0,
    cameraHeading = 45.0,
    fov = 47.0,
    distance = 7.2,
    height = 1.15,
    lookHeight = 0.65,
    autoRotate = false,
    lights = true,
    doors = false
}

local function notify(typ, msg, duration)
    typ = typ or 'info'
    msg = tostring(msg or '')
    duration = duration or 5000

    if Config.NotifyEvent and Config.NotifyEvent ~= '' then
        TriggerEvent(Config.NotifyEvent, typ, duration, msg)
    end

    if Config.ChatFallback == true then
        TriggerEvent('chat:addMessage', {
            color = { 4, 199, 247 },
            args = { 'DRIFTZONE', msg }
        })
    end
end

RegisterNetEvent('driftzone_vehicless:client:notify', function(typ, duration, msg)
    notify(typ, msg, duration)
end)

local function sendNui(data)
    SendNUIMessage(data or {})
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

local function cleanModel(value)
    return tostring(value or ''):lower():gsub('%s+', ''):gsub('[^%w_%-]', '')
end

local function getPedSeat(vehicle, ped)
    if not vehicle or vehicle == 0 then return -1 end
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) do
        if GetPedInVehicleSeat(vehicle, seat) == ped then return seat end
    end
    return -1
end

local function saveAndMovePlayer()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)

    playerState = {
        coords = coords,
        heading = GetEntityHeading(ped),
        visible = IsEntityVisible(ped),
        vehicle = veh,
        vehicleSeat = veh ~= 0 and getPedSeat(veh, ped) or -1
    }

    if veh and veh ~= 0 then
        TaskLeaveVehicle(ped, veh, 16)
        local timeout = GetGameTimer() + 1600
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < timeout do
            Wait(0)
        end
        ClearPedTasksImmediately(ped)
    end

    local c = Config.Studio.coords
    local offset = Config.Studio.playerOffset or { x = 0.0, y = 0.0, z = 24.0 }

    SetEntityCoordsNoOffset(ped, c.x + (offset.x or 0.0), c.y + (offset.y or 0.0), c.z + (offset.z or 24.0), false, false, false)
    SetEntityHeading(ped, Config.Studio.heading or 45.0)
    SetEntityCollision(ped, false, false)

    if Config.Studio.freezePlayer ~= false then
        FreezeEntityPosition(ped, true)
    end

    if Config.Studio.hidePlayer ~= false then
        SetEntityVisible(ped, false, false)
        SetEntityAlpha(ped, 0, false)
    end
end

local function restorePlayer()
    local ped = PlayerPedId()

    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)

    if playerState then
        if Config.Studio.restorePlayerPosition ~= false and playerState.coords then
            SetEntityCoordsNoOffset(ped, playerState.coords.x, playerState.coords.y, playerState.coords.z, false, false, false)
            SetEntityHeading(ped, playerState.heading or GetEntityHeading(ped))
        end

        if playerState.visible == false then
            SetEntityVisible(ped, false, false)
        end

        if playerState.vehicle and playerState.vehicle ~= 0 and DoesEntityExist(playerState.vehicle) and playerState.vehicleSeat then
            SetPedIntoVehicle(ped, playerState.vehicle, playerState.vehicleSeat)
        end
    end

    playerState = nil
end

local function deleteCurrentVehicle()
    if studioVehicle and studioVehicle ~= 0 and DoesEntityExist(studioVehicle) then
        SetEntityAsMissionEntity(studioVehicle, true, true)
        DeleteVehicle(studioVehicle)
        DeleteEntity(studioVehicle)
    end

    studioVehicle = 0
end

local function resetSettings()
    local s = Config.Studio
    currentSettings.heading = s.heading or 45.0
    currentSettings.cameraHeading = s.cameraHeading or s.heading or 45.0
    currentSettings.fov = s.defaultFov or 47.0
    currentSettings.distance = s.defaultDistance or 7.2
    currentSettings.height = s.defaultHeight or 1.15
    currentSettings.lookHeight = s.defaultLookHeight or 0.65
    currentSettings.autoRotate = false
    currentSettings.lights = true
    currentSettings.doors = false
end

local function updateCamera()
    if not open or not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then return end
    if not studioCam then return end

    local coords = GetEntityCoords(studioVehicle)
    local cameraHeading = tonumber(currentSettings.cameraHeading or Config.Studio.cameraHeading or Config.Studio.heading or 45.0) or 45.0
    local rad = math.rad(cameraHeading)
    local dist = currentSettings.distance or Config.Studio.defaultDistance or 7.2
    local height = currentSettings.height or Config.Studio.defaultHeight or 1.15
    local lookHeight = currentSettings.lookHeight or Config.Studio.defaultLookHeight or 0.65

    -- Camera sta pe pozitie fixa. Doar masina se roteste.
    local camX = coords.x + (-math.sin(rad) * dist)
    local camY = coords.y + (math.cos(rad) * dist)
    local camZ = coords.z + height

    SetCamCoord(studioCam, camX, camY, camZ)
    PointCamAtCoord(studioCam, coords.x, coords.y, coords.z + lookHeight)
    SetCamFov(studioCam, currentSettings.fov or Config.Studio.defaultFov or 47.0)
end

local function applyVehicleLook()
    if not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then return end

    SetVehicleModKit(studioVehicle, 0)
    SetEntityHeading(studioVehicle, currentSettings.heading or Config.Studio.heading or 45.0)
    SetEntityLodDist(studioVehicle, 1000)
    SetVehicleDirtLevel(studioVehicle, 0.0)
    SetVehicleEngineOn(studioVehicle, false, true, true)
    SetVehicleRadioEnabled(studioVehicle, false)
    SetVehRadioStation(studioVehicle, 'OFF')
    SetVehicleNumberPlateText(studioVehicle, Config.Studio.plate or 'DRIFTZ')

    if Config.Studio.invincibleVehicle ~= false then
        SetEntityInvincible(studioVehicle, true)
        SetVehicleCanBreak(studioVehicle, false)
        SetVehicleEngineCanDegrade(studioVehicle, false)
    end

    if Config.Studio.freezeVehicle ~= false then
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
        for i = 0, 7 do
            SetVehicleDoorShut(studioVehicle, i, false)
        end
    end
end

local function destroyStudio(skipNuiClose)
    open = false
    currentModel = nil
    takingShot = false
    shotToken = shotToken + 1

    if studioCam then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(studioCam, false)
        studioCam = nil
    end

    deleteCurrentVehicle()
    restorePlayer()
    setFocus(false)

    if not skipNuiClose then
        sendNui({ action = 'close' })
    end
end

local function spawnStudioVehicle(modelName, keepView)
    modelName = cleanModel(modelName)

    if modelName == '' then
        notify('warning', 'Scrie modelul masinii.')
        return false
    end

    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        notify('warning', 'Model invalid: ' .. modelName)
        return false
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + (Config.Studio.modelLoadTimeoutMs or 9000)
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then
            notify('warning', 'Nu am putut incarca modelul: ' .. modelName)
            return false
        end
    end

    deleteCurrentVehicle()
    if not keepView then resetSettings() end

    local c = Config.Studio.coords
    studioVehicle = CreateVehicle(hash, c.x, c.y, c.z, currentSettings.heading or Config.Studio.heading or 45.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then
        notify('warning', 'Nu am putut crea masina.')
        return false
    end

    currentModel = modelName
    SetEntityAsMissionEntity(studioVehicle, true, true)
    SetVehicleOnGroundProperly(studioVehicle)
    applyVehicleLook()

    if not studioCam then
        studioCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end

    SetCamActive(studioCam, true)
    RenderScriptCams(true, true, 250, true, true)
    updateCamera()

    return true
end

local function updateUi()
    sendNui({
        action = 'state',
        model = currentModel or '',
        heading = math.floor((currentSettings.heading or 0.0) * 10.0) / 10.0,
        fov = math.floor((currentSettings.fov or 0.0) * 10.0) / 10.0,
        distance = math.floor((currentSettings.distance or 0.0) * 10.0) / 10.0,
        height = math.floor((currentSettings.height or 0.0) * 10.0) / 10.0,
        lookHeight = math.floor((currentSettings.lookHeight or 0.0) * 10.0) / 10.0,
        autoRotate = currentSettings.autoRotate == true,
        lights = currentSettings.lights == true,
        doors = currentSettings.doors == true,
        screenshotReady = true
    })
end

local function openStudio(model, mainColor)
    model = cleanModel(model)

    if open then
        local ok = spawnStudioVehicle(model, true)
        if ok then
            sendNui({ action = 'open', model = model, mainColor = mainColor or Config.MainColor or '#04c7f7' })
            updateUi()
        end
        return
    end

    resetSettings()
    open = true
    saveAndMovePlayer()

    local ok = spawnStudioVehicle(model, false)
    if not ok then
        destroyStudio()
        return
    end

    setFocus(true)
    sendNui({ action = 'open', model = model, mainColor = mainColor or Config.MainColor or '#04c7f7' })
    updateUi()
end

RegisterCommand(Config.Command or 'vehss', function(_, args)
    TriggerServerEvent('driftzone_vehicless:server:requestOpen', args and args[1] or '')
end, false)

RegisterCommand(Config.CloseCommand or 'vehssclose', function()
    if open then destroyStudio() end
end, false)

RegisterNetEvent('driftzone_vehicless:client:openStudio', function(data)
    data = data or {}
    openStudio(data.model or '', data.mainColor)
end)

RegisterNUICallback('close', function(_, cb)
    destroyStudio()
    cb({ ok = true })
end)

RegisterNUICallback('loadModel', function(data, cb)
    data = data or {}
    if not open then cb({ ok = false }) return end

    local model = cleanModel(data.model)
    local ok = spawnStudioVehicle(model, data.keepView ~= false)

    if ok then
        sendNui({ action = 'open', model = model, mainColor = Config.MainColor or '#04c7f7' })
        updateUi()
    end

    cb({ ok = ok })
end)

RegisterNUICallback('control', function(data, cb)
    data = data or {}
    local action = tostring(data.action or '')
    local s = Config.Studio

    if not open or not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then
        cb({ ok = false })
        return
    end

    if action == 'rotate_left' then
        currentSettings.heading = (currentSettings.heading or 0.0) - (s.rotationStep or 7.5)
    elseif action == 'rotate_right' then
        currentSettings.heading = (currentSettings.heading or 0.0) + (s.rotationStep or 7.5)
    elseif action == 'fov_down' then
        currentSettings.fov = clamp((currentSettings.fov or s.defaultFov or 47.0) - (s.fovStep or 3.0), s.minFov or 18.0, s.maxFov or 85.0)
    elseif action == 'fov_up' then
        currentSettings.fov = clamp((currentSettings.fov or s.defaultFov or 47.0) + (s.fovStep or 3.0), s.minFov or 18.0, s.maxFov or 85.0)
    elseif action == 'distance_down' then
        currentSettings.distance = clamp((currentSettings.distance or s.defaultDistance or 7.2) - (s.distanceStep or 0.35), s.minDistance or 2.5, s.maxDistance or 14.0)
    elseif action == 'distance_up' then
        currentSettings.distance = clamp((currentSettings.distance or s.defaultDistance or 7.2) + (s.distanceStep or 0.35), s.minDistance or 2.5, s.maxDistance or 14.0)
    elseif action == 'height_down' then
        currentSettings.height = clamp((currentSettings.height or s.defaultHeight or 1.15) - (s.heightStep or 0.12), s.minHeight or -0.2, s.maxHeight or 4.5)
    elseif action == 'height_up' then
        currentSettings.height = clamp((currentSettings.height or s.defaultHeight or 1.15) + (s.heightStep or 0.12), s.minHeight or -0.2, s.maxHeight or 4.5)
    elseif action == 'look_down' then
        currentSettings.lookHeight = clamp((currentSettings.lookHeight or s.defaultLookHeight or 0.65) - (s.lookHeightStep or 0.10), s.minLookHeight or -0.4, s.maxLookHeight or 2.8)
    elseif action == 'look_up' then
        currentSettings.lookHeight = clamp((currentSettings.lookHeight or s.defaultLookHeight or 0.65) + (s.lookHeightStep or 0.10), s.minLookHeight or -0.4, s.maxLookHeight or 2.8)
    elseif action == 'auto_rotate' then
        currentSettings.autoRotate = not currentSettings.autoRotate
    elseif action == 'lights' then
        currentSettings.lights = not currentSettings.lights
    elseif action == 'doors' then
        currentSettings.doors = not currentSettings.doors
    elseif action == 'reset' then
        resetSettings()
    end

    currentSettings.heading = (currentSettings.heading or 0.0) % 360.0
    applyVehicleLook()
    updateCamera()
    updateUi()
    cb({ ok = true })
end)

local function finishScreenshot(ok, message)
    takingShot = false
    setFocus(open == true)
    sendNui({ action = 'shotDone' })

    if ok then
        notify('success', message or 'Screenshot facut. Verifica Downloads.', 5000)
    else
        notify('warning', message or 'Nu am putut face screenshot. Verifica F8.', 6500)
    end
end

RegisterNUICallback('screenshot', function(_, cb)
    if not open then cb({ ok = false }) return end
    if takingShot then cb({ ok = false }) return end

    takingShot = true
    shotToken = shotToken + 1
    local myToken = shotToken
    local safeModel = cleanModel(currentModel or 'vehicle')
    local fileName = ('driftzone_%s_%s.png'):format(safeModel ~= '' and safeModel or 'vehicle', tostring(GetCloudTimeAsInt()))

    sendNui({ action = 'prepareShot' })
    setFocus(false)

    SetTimeout(Config.Studio.screenshotFailTimeoutMs or 10000, function()
        if takingShot and shotToken == myToken then
            finishScreenshot(false, 'Screenshot-ul nu a raspuns. Verifica consola F8 pentru erori NUI.')
        end
    end)

    SetTimeout(Config.Studio.screenshotDelayMs or 450, function()
        if not open or not takingShot or shotToken ~= myToken then return end

        sendNui({
            action = 'captureInternal',
            filename = fileName,
            encoding = Config.Studio.screenshotEncoding or 'png',
            quality = Config.Studio.screenshotQuality or 0.95,
            token = myToken
        })
    end)

    cb({ ok = true })
end)

RegisterNUICallback('shotResult', function(data, cb)
    data = data or {}
    if not takingShot then cb({ ok = false }) return end

    finishScreenshot(data.ok == true, data.error or nil)
    cb({ ok = true })
end)

CreateThread(function()
    Wait(800)
    TriggerEvent('chat:addSuggestion', '/' .. (Config.Command or 'vehss'), 'Deschide studio-ul pentru poza la masina', {
        { name = 'model', help = 'ex: s15, rmodm4, supra' }
    })
    TriggerEvent('chat:addSuggestion', '/' .. (Config.CloseCommand or 'vehssclose'), 'Inchide studio-ul daca UI-ul s-a blocat')
end)

CreateThread(function()
    while true do
        if open and studioVehicle ~= 0 and DoesEntityExist(studioVehicle) then
            if currentSettings.autoRotate then
                currentSettings.heading = ((currentSettings.heading or 0.0) + (Config.Studio.autoRotateSpeed or 0.18)) % 360.0
                SetEntityHeading(studioVehicle, currentSettings.heading)
                updateCamera()

                if GetGameTimer() % 350 < 20 then
                    updateUi()
                end
            end

            local ped = PlayerPedId()
            if Config.Studio.hidePlayer ~= false then
                SetEntityVisible(ped, false, false)
                SetEntityAlpha(ped, 0, false)
            end

            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
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
    TriggerEvent('chat:removeSuggestion', '/' .. (Config.Command or 'vehss'))
    TriggerEvent('chat:removeSuggestion', '/' .. (Config.CloseCommand or 'vehssclose'))
    destroyStudio(true)
end)
