local open = false
local cleanMode = false
local studioVehicle = 0
local studioCam = nil
local currentModel = nil
local savedPed = nil
local lastCleanToggle = 0

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
    else
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

local function safeTriggerEvent(name, ...)
    if name and name ~= '' then
        pcall(function(...)
            TriggerEvent(name, ...)
        end, ...)
    end
end

local function setDriftzoneHudVisible(state)
    if not Config.Hud or Config.Hud.enabled == false then return end

    if Config.Hud.callToggleEvent == true then
        safeTriggerEvent(Config.Hud.toggleEvent or 'driftzone_hud:client:toggle')
        return
    end

    if state then
        safeTriggerEvent(Config.Hud.showEvent or 'driftzone_hud:client:show')
        safeTriggerEvent(Config.Hud.visibleEvent or 'driftzone_hud:visible', true)
    else
        safeTriggerEvent(Config.Hud.hideEvent or 'driftzone_hud:client:hide')
        safeTriggerEvent(Config.Hud.visibleEvent or 'driftzone_hud:visible', false)
    end
end

local function applyGameHudVisible(state)
    DisplayRadar(state == true)
    DisplayHud(state == true)
    setDriftzoneHudVisible(state == true)
end

local function setCleanMode(state, silent)
    if not open then return end

    cleanMode = state == true

    if cleanMode then
        setFocus(false)
        sendNui({ action = 'cleanMode', enabled = true })
        applyGameHudVisible(false)
        if not silent then notify('info', 'UI/HUD ascunse. Apasa ` iar ca sa apara inapoi.', 3500) end
    else
        sendNui({ action = 'cleanMode', enabled = false })
        applyGameHudVisible(true)
        setFocus(true)
        if not silent then notify('info', 'UI/HUD afisate inapoi.', 2500) end
    end
end

local function toggleCleanMode(silent)
    local now = GetGameTimer()
    if now - lastCleanToggle < 350 then return end
    lastCleanToggle = now

    if not open then return end
    setCleanMode(not cleanMode, silent == true)
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
    if cleanMode then
        cleanMode = false
        applyGameHudVisible(true)
    end

    open = false
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
        return false, 'empty'
    end

    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        notify('warning', 'Model invalid: ' .. modelName)
        return false, 'invalid'
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + (Config.Studio.modelLoadTimeoutMs or 9000)
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then
            notify('warning', 'Nu am putut incarca modelul: ' .. modelName)
            return false, 'timeout'
        end
    end

    if not savedPed then
        saveAndMovePlayer()
    end

    deleteCurrentVehicle()
    if not keepView then resetSettings() end

    local c = Config.Studio.coords
    studioVehicle = CreateVehicle(hash, c.x, c.y, c.z, currentSettings.heading or Config.Studio.heading or 45.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then
        notify('warning', 'Nu am putut crea masina.')
        return false, 'create_failed'
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

    return true, nil
end

local function updateUi()
    sendNui({
        action = 'state',
        model = currentModel or '',
        hasVehicle = studioVehicle ~= 0 and DoesEntityExist(studioVehicle),
        heading = math.floor((currentSettings.heading or 0) * 10) / 10,
        fov = math.floor((currentSettings.fov or 0) * 10) / 10,
        distance = math.floor((currentSettings.distance or 0) * 10) / 10,
        height = math.floor((currentSettings.height or 0) * 10) / 10,
        autoRotate = currentSettings.autoRotate == true,
        lights = currentSettings.lights == true,
        doors = currentSettings.doors == true,
        cleanMode = cleanMode == true
    })
end

RegisterCommand(Config.Command or 'vehss', function(_, args)
    TriggerServerEvent('driftzone_vehicless:server:requestOpen', args and args[1] or '')
end, false)

RegisterCommand(Config.CloseCommand or 'vehssclose', function()
    destroyStudio()
end, false)

RegisterCommand(Config.CleanToggleCommand or 'vehssclean', function()
    toggleCleanMode(false)
end, false)

RegisterKeyMapping(Config.CleanToggleCommand or 'vehssclean', 'DriftZone Vehicless - hide/show UI + HUD', 'keyboard', Config.CleanToggleDefaultKey or 'OEM_3')

RegisterNetEvent('driftzone_vehicless:client:openStudio', function(data)
    data = data or {}
    local model = cleanModel(data.model or '')

    if open then destroyStudio() Wait(250) end

    open = true
    cleanMode = false
    currentModel = nil
    resetSettings()

    applyGameHudVisible(true)
    setFocus(true)
    sendNui({ action = 'open', model = model, mainColor = data.mainColor or Config.MainColor or '#04c7f7' })
    updateUi()

    if model ~= '' then
        local ok = spawnStudioVehicle(model, true)
        if ok then
            sendNui({ action = 'open', model = model, mainColor = Config.MainColor or '#04c7f7' })
            updateUi()
        else
            sendNui({ action = 'loadFailed', model = model })
            updateUi()
        end
    end
end)

RegisterNUICallback('close', function(_, cb)
    destroyStudio()
    cb({ ok = true })
end)

RegisterNUICallback('toggleClean', function(_, cb)
    toggleCleanMode(false)
    cb({ ok = true })
end)

RegisterNUICallback('loadModel', function(data, cb)
    data = data or {}
    if not open then cb({ ok = false, error = 'closed' }) return end

    local model = cleanModel(data.model)
    local ok, err = spawnStudioVehicle(model, data.keepView ~= false)
    if ok then
        sendNui({ action = 'open', model = model, mainColor = Config.MainColor or '#04c7f7' })
        updateUi()
        if cleanMode then sendNui({ action = 'cleanMode', enabled = true }) end
    else
        sendNui({ action = 'loadFailed', model = model, error = err })
        updateUi()
    end

    cb({ ok = ok == true, error = err })
end)

RegisterNUICallback('control', function(data, cb)
    data = data or {}
    local action = tostring(data.action or '')
    local s = Config.Studio

    if not open or not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle) then
        notify('warning', 'Incarca un model de masina mai intai.', 2500)
        cb({ ok = false, error = 'no_vehicle' })
        return
    end

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

CreateThread(function()
    while true do
        if open and studioVehicle ~= 0 and DoesEntityExist(studioVehicle) then
            if currentSettings.autoRotate then
                currentSettings.heading = ((currentSettings.heading or 0.0) + (Config.Studio.autoRotateSpeed or 0.18)) % 360.0
                SetEntityHeading(studioVehicle, currentSettings.heading)
                updateCamera()
                if GetGameTimer() % 350 < 20 and not cleanMode then updateUi() end
            end

            local ped = PlayerPedId()
            if Config.Studio.hidePlayer ~= false then SetEntityVisible(ped, false, false) end

            if cleanMode then
                DisplayRadar(false)
                DisplayHud(false)
                HideHudAndRadarThisFrame()
                for i = 0, 22 do
                    HideHudComponentThisFrame(i)
                end
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 322, true)
            else
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 322, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
            end

            Wait(0)
        else
            Wait(450)
        end
    end
end)

CreateThread(function()
    while true do
        if open and cleanMode and IsControlJustPressed(0, 243) then
            toggleCleanMode(false)
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        if open and currentModel and currentModel ~= '' and (not studioVehicle or studioVehicle == 0 or not DoesEntityExist(studioVehicle)) then
            destroyStudio()
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    destroyStudio()
end)
