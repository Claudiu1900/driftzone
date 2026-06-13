local open = false
local studioVehicle = 0
local studioCam = nil
local currentModel = nil
local takingShot = false
local shotToken = 0

local savedPed = nil

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

local function chat(msg)
    if Config.ChatFallback ~= false then
        TriggerEvent('chat:addMessage', {
            color = { 4, 199, 247 },
            args = { 'DriftZone', tostring(msg or '') }
        })
    end
end

local function notify(typ, msg, duration)
    msg = tostring(msg or '')
    if Config.NotifyEvent and Config.NotifyEvent ~= '' then
        TriggerEvent(Config.NotifyEvent, typ or 'info', duration or 5000, msg)
    end
    if not Config.NotifyEvent or Config.NotifyEvent == '' then
        chat(msg)
    end
end

RegisterNetEvent('driftzone_vehicless:client:notify', function(typ, msg, duration)
    notify(typ, msg, duration)
end)

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

local function cleanModel(value)
    return tostring(value or ''):lower():gsub('%s+', ''):gsub('[^%w_%-]', '')
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

local function saveAndMovePlayer()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    savedPed = {
        coords = coords,
        heading = GetEntityHeading(ped),
        visible = IsEntityVisible(ped),
        inVehicle = IsPedInAnyVehicle(ped, false)
    }

    if savedPed.inVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 then
            savedPed.vehicle = veh
            savedPed.seat = -1
            for i = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                if GetPedInVehicleSeat(veh, i) == ped then
                    savedPed.seat = i
                    break
                end
            end
            TaskLeaveVehicle(ped, veh, 16)
            Wait(250)
        end
    end

    local c = Config.Studio.coords
    local offset = Config.Studio.playerOffset or { x = 0.0, y = 0.0, z = 24.0 }
    SetEntityCoords(ped, c.x + (offset.x or 0.0), c.y + (offset.y or 0.0), c.z + (offset.z or 24.0), false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)

    if Config.Studio.hidePlayer ~= false then
        SetEntityVisible(ped, false, false)
    end
end

local function restorePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)

    if savedPed and savedPed.coords then
        SetEntityCoords(ped, savedPed.coords.x, savedPed.coords.y, savedPed.coords.z, false, false, false, false)
        SetEntityHeading(ped, savedPed.heading or GetEntityHeading(ped))

        if savedPed.inVehicle and savedPed.vehicle and DoesEntityExist(savedPed.vehicle) then
            SetPedIntoVehicle(ped, savedPed.vehicle, savedPed.seat or -1)
        end
    end

    savedPed = nil
end

local function deleteCurrentVehicle()
    if studioVehicle and studioVehicle ~= 0 and DoesEntityExist(studioVehicle) then
        SetEntityAsMissionEntity(studioVehicle, true, true)
        DeleteEntity(studioVehicle)
    end
    studioVehicle = 0
end

local function destroyStudio()
    open = false
    takingShot = false
    currentModel = nil

    if studioCam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(studioCam, false)
        studioCam = nil
    end

    deleteCurrentVehicle()
    restorePlayer()
    setFocus(false)
    sendNui({ action = 'close' })
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

    local camX = coords.x + -math.sin(rad) * dist
    local camY = coords.y + math.cos(rad) * dist
    local camZ = coords.z + height

    SetCamCoord(studioCam, camX, camY, camZ)
    PointCamAtCoord(studioCam, coords.x, coords.y, coords.z + lookHeight)
    SetCamFov(studioCam, currentSettings.fov or Config.Studio.defaultFov or 47.0)
end

local function makeVehicleWhite(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local color = Config.Studio.whiteColorIndex or 111
    SetVehicleColours(vehicle, color, color)
    SetVehicleExtraColours(vehicle, color, color)

    local p = Config.Studio.primaryRGB or { r = 255, g = 255, b = 255 }
    local s = Config.Studio.secondaryRGB or { r = 255, g = 255, b = 255 }
    SetVehicleCustomPrimaryColour(vehicle, p.r or 255, p.g or 255, p.b or 255)
    SetVehicleCustomSecondaryColour(vehicle, s.r or 255, s.g or 255, s.b or 255)

    if SetVehicleInteriorColour then SetVehicleInteriorColour(vehicle, color) end
    if SetVehicleDashboardColour then SetVehicleDashboardColour(vehicle, color) end
end

local function applyVehicleLook()
    if not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then return end

    SetVehicleModKit(studioVehicle, 0)
    SetEntityHeading(studioVehicle, currentSettings.heading or Config.Studio.heading or 45.0)
    SetVehicleDirtLevel(studioVehicle, 0.0)
    SetVehicleEngineOn(studioVehicle, false, true, true)
    SetVehicleRadioEnabled(studioVehicle, false)
    SetVehRadioStation(studioVehicle, 'OFF')
    SetVehicleNumberPlateText(studioVehicle, Config.Studio.plate or 'DRIFTZ')
    makeVehicleWhite(studioVehicle)

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
        for i = 0, 7 do
            SetVehicleDoorShut(studioVehicle, i, false)
        end
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
    RenderScriptCams(true, true, 300, true, true)
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
        doors = currentSettings.doors == true
    })
end

RegisterCommand(Config.Command or 'vehss', function(_, args)
    TriggerServerEvent('driftzone_vehicless:server:requestOpen', args and args[1] or '')
end, false)

RegisterCommand(Config.CloseCommand or 'vehssclose', function()
    destroyStudio()
end, false)

RegisterNetEvent('driftzone_vehicless:client:openStudio', function(data)
    data = data or {}
    local model = cleanModel(data.model or '')

    if open then destroyStudio() Wait(250) end

    open = true
    resetSettings()
    saveAndMovePlayer()

    local ok = spawnStudioVehicle(model, true)
    if not ok then
        destroyStudio()
        return
    end

    setFocus(true)
    sendNui({ action = 'open', model = model, mainColor = data.mainColor or Config.MainColor or '#04c7f7' })
    updateUi()
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

    currentSettings.heading = currentSettings.heading % 360.0
    applyVehicleLook()
    updateCamera()
    updateUi()
    cb({ ok = true })
end)

RegisterNUICallback('screenshot', function(_, cb)
    if not open or not currentModel or currentModel == '' then
        cb({ ok = false })
        return
    end

    if takingShot then
        cb({ ok = false })
        return
    end

    takingShot = true
    shotToken = shotToken + 1
    local myToken = shotToken

    sendNui({ action = 'prepareShot' })
    setFocus(false)

    SetTimeout(Config.Screenshot.prepareDelayMs or 550, function()
        if not open or not takingShot or shotToken ~= myToken then return end

        local resourceName = Config.Screenshot.resource or 'screenshot-basic'
        if GetResourceState(resourceName) ~= 'started' then
            takingShot = false
            sendNui({ action = 'shotDone' })
            if open then setFocus(true) end
            notify('warning', 'screenshot-basic nu este pornit. Pune ensure screenshot-basic inainte de driftzone_vehicless.', 7500)
            return
        end

        local options = {
            encoding = Config.Screenshot.encoding or 'jpg',
            quality = Config.Screenshot.quality or 0.82
        }

        local okCall, errCall = pcall(function()
            exports[resourceName]:requestScreenshot(options, function(data)
                if not open or not takingShot or shotToken ~= myToken then return end

                if type(data) ~= 'string' or data == '' or not data:find('base64,', 1, true) then
                    takingShot = false
                    sendNui({ action = 'shotDone' })
                    if open then setFocus(true) end
                    notify('warning', 'Screenshot-basic a returnat date invalide.', 7500)
                    return
                end

                local maxLen = Config.Screenshot.maxDataLength or 12000000
                if #data > maxLen then
                    takingShot = false
                    sendNui({ action = 'shotDone' })
                    if open then setFocus(true) end
                    notify('warning', 'Poza este prea mare. Lasa encoding jpg si quality mai mic in config.', 8500)
                    return
                end

                local chunkSize = Config.Screenshot.chunkSize or 12000
                local delay = Config.Screenshot.chunkDelayMs or 45
                local total = math.ceil(#data / chunkSize)

                TriggerServerEvent('driftzone_vehicless:server:beginScreenshotUpload', currentModel, myToken, total, options.encoding)

                CreateThread(function()
                    for i = 1, total do
                        if not takingShot or shotToken ~= myToken then return end
                        local from = ((i - 1) * chunkSize) + 1
                        local to = i * chunkSize
                        local chunk = data:sub(from, to)
                        TriggerServerEvent('driftzone_vehicless:server:screenshotChunk', myToken, i, chunk)
                        Wait(delay)
                    end
                end)
            end)
        end)

        if not okCall then
            takingShot = false
            sendNui({ action = 'shotDone' })
            if open then setFocus(true) end
            notify('warning', 'Nu pot apela export-ul screenshot-basic: ' .. tostring(errCall) .. '. Sterge folderul screenshot-basic vechi si pune folderul din zip-ul v10.', 12000)
        end
    end)

    SetTimeout((Config.Screenshot.timeoutMs or 90000) + 2500, function()
        if takingShot and shotToken == myToken then
            takingShot = false
            sendNui({ action = 'shotDone' })
            if open then setFocus(true) end
            notify('warning', 'Screenshot timeout. Verifica screenshot-basic si consola F8.', 7500)
        end
    end)

    cb({ ok = true })
end)

RegisterNetEvent('driftzone_vehicless:client:screenshotDone', function(ok, message, token)
    if token and token ~= shotToken then return end

    takingShot = false
    sendNui({ action = 'shotDone' })
    if open then setFocus(true) end

    if ok then
        notify('success', message or 'Screenshot salvat.', 5500)
    else
        notify('warning', message or 'Nu am putut salva screenshot-ul.', 8000)
    end
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

            local ped = PlayerPedId()
            if Config.Studio.hidePlayer ~= false then SetEntityVisible(ped, false, false) end
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
