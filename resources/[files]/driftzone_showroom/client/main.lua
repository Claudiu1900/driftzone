local nuiReady = false
local showroomOpen = false
local cameraFree = false
local showroomCam = nil

local previewVehicle = 0
local previewVehicles = {}
local previewBaseHeading = 0.0
local previewRequestId = 0
local previewCreating = false

local currentPayload = nil
local currentSelectedModel = ''
local inTestDrive = false
local testVehicle = 0
local testTimers = {}

local function notify(notifyType, message, duration)
    TriggerEvent('client:notify', notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function sendNui(data)
    if not nuiReady then return end
    SendNUIMessage(data)
end

local function setHudVisible(state)
    local visible = state == true

    DisplayHud(visible)
    DisplayRadar(visible)

    TriggerEvent('driftzone_hud:visible', visible)
    TriggerEvent('client:hud:visible', visible)
end

local function setNui(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function loadModel(model)
    local hash = joaat(tostring(model or ''):lower():gsub('%s+', ''))

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return nil
    end

    if HasModelLoaded(hash) then
        return hash
    end

    RequestModel(hash)

    local timeout = GetGameTimer() + 6500

    while not HasModelLoaded(hash) do
        Wait(0)

        if GetGameTimer() > timeout then
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
    end

    return hash
end

local function setVehicleWhite(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    SetVehicleCustomPrimaryColour(vehicle, 255, 255, 255)
    SetVehicleCustomSecondaryColour(vehicle, 255, 255, 255)
    SetVehicleColours(vehicle, 111, 111)
    SetVehicleExtraColours(vehicle, 111, 111)
end

local function deleteEntitySafe(entity)
    if not entity or entity == 0 then return end

    if not DoesEntityExist(entity) then return end

    SetEntityAsMissionEntity(entity, true, true)

    if IsEntityAVehicle(entity) then
        DeleteVehicle(entity)
    else
        DeleteEntity(entity)
    end

    local timeout = GetGameTimer() + 850

    while DoesEntityExist(entity) and GetGameTimer() < timeout do
        SetEntityAsMissionEntity(entity, true, true)

        if IsEntityAVehicle(entity) then
            DeleteVehicle(entity)
        else
            DeleteEntity(entity)
        end

        Wait(0)
    end
end

local function deletePreviewVehicle()
    previewRequestId = previewRequestId + 1

    if previewVehicle and previewVehicle ~= 0 then
        deleteEntitySafe(previewVehicle)
    end

    for _, entity in ipairs(previewVehicles) do
        if entity and entity ~= 0 and entity ~= previewVehicle then
            deleteEntitySafe(entity)
        end
    end

    previewVehicles = {}
    previewVehicle = 0
    currentSelectedModel = ''

    if currentPayload and currentPayload.preview then
        local p = currentPayload.preview
        local x = tonumber(p.x or -42.85)
        local y = tonumber(p.y or -1096.65)
        local z = tonumber(p.z or 25.95)

        ClearAreaOfVehicles(x, y, z, 7.0, false, false, false, false, false)
    end
end

local function deleteTestVehicle()
    if testVehicle and testVehicle ~= 0 then
        deleteEntitySafe(testVehicle)
    end

    testVehicle = 0
end

local function hidePlayerForPreview(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state == true)
    SetEntityVisible(ped, state ~= true, false)
    SetPlayerInvincible(PlayerId(), state == true)
end

local function createShowroomCamera(cameraData)
    if showroomCam then
        DestroyCam(showroomCam, false)
        showroomCam = nil
    end

    if cameraFree then
        RenderScriptCams(false, false, 0, true, false)
        return
    end

    local c = cameraData or {}

    showroomCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    SetCamCoord(showroomCam, tonumber(c.x or -38.85), tonumber(c.y or -1100.65), tonumber(c.z or 28.35))
    PointCamAtCoord(showroomCam, tonumber(c.lookX or -42.85), tonumber(c.lookY or -1096.65), tonumber(c.lookZ or 26.55))
    SetCamFov(showroomCam, tonumber(c.fov or 55.0))
    SetCamActive(showroomCam, true)
    RenderScriptCams(true, false, 0, true, false)
end

local function destroyShowroomCamera()
    if showroomCam then
        SetCamActive(showroomCam, false)
        DestroyCam(showroomCam, false)
        showroomCam = nil
    end

    RenderScriptCams(false, false, 0, true, false)
end

local function setupPreviewVehicle(vehicle, heading)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleNumberPlateText(vehicle, 'SHOWROOM')
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleDirtLevel(vehicle, 0.0)
    setVehicleWhite(vehicle)
    FreezeEntityPosition(vehicle, true)
    SetEntityInvincible(vehicle, true)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityHeading(vehicle, heading)
end

local function createPreviewVehicle(model)
    if not showroomOpen or not currentPayload then return end

    model = tostring(model or ''):lower():gsub('%s+', '')
    if model == '' then return end

    if currentSelectedModel == model and previewVehicle ~= 0 and DoesEntityExist(previewVehicle) then
        return
    end

    previewRequestId = previewRequestId + 1
    local requestId = previewRequestId

    currentSelectedModel = model
    previewCreating = true

    if previewVehicle ~= 0 then
        deleteEntitySafe(previewVehicle)
        previewVehicle = 0
    end

    local hash = loadModel(model)
    if requestId ~= previewRequestId or not showroomOpen or currentSelectedModel ~= model then
        if hash then SetModelAsNoLongerNeeded(hash) end
        previewCreating = false
        return
    end

    if not hash then
        notify('warning', 'Model invalid sau nu este streamat: ' .. tostring(model))
        previewCreating = false
        return
    end

    local p = currentPayload.preview or {}
    local x = tonumber(p.x or -42.85)
    local y = tonumber(p.y or -1096.65)
    local z = tonumber(p.z or 25.95)
    local h = tonumber(p.heading or 165.0)

    RequestCollisionAtCoord(x, y, z)

    -- Curata zona preview ca sa nu ramana masini locale vechi in showroom.
    ClearAreaOfVehicles(x, y, z, 6.0, false, false, false, false, false)

    local vehicle = CreateVehicle(hash, x, y, z, h, false, false)

    SetModelAsNoLongerNeeded(hash)

    if requestId ~= previewRequestId or not showroomOpen or currentSelectedModel ~= model then
        deleteEntitySafe(vehicle)
        previewCreating = false
        return
    end

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        previewBaseHeading = h
        setupPreviewVehicle(vehicle, h)
        previewVehicle = vehicle
        previewVehicles[#previewVehicles + 1] = vehicle
    end

    previewCreating = false
end

local function rotatePreview(delta)
    if previewCreating then return end
    if not previewVehicle or previewVehicle == 0 or not DoesEntityExist(previewVehicle) then return end

    local nextHeading = GetEntityHeading(previewVehicle) + ((tonumber(delta or 0) or 0) * 0.25)
    SetEntityHeading(previewVehicle, nextHeading)
end

local function closeShowroom(sendServer)
    if not showroomOpen and not currentPayload then
        setNui(false)
        return
    end

    showroomOpen = false
    cameraFree = false
    currentPayload = nil

    setNui(false)
    setHudVisible(true)
    destroyShowroomCamera()
    deletePreviewVehicle()
    hidePlayerForPreview(false)

    sendNui({ action = 'close' })

    if sendServer then
        TriggerServerEvent('driftzone_showroom:server:close')
    end
end

local function openShowroom(payload)
    -- Safety: daca intri de doua ori sau ai ramas cu ceva local, curata inainte.
    closeShowroom(false)

    currentPayload = payload or {}
    showroomOpen = true
    cameraFree = false
    inTestDrive = false

    hidePlayerForPreview(true)
    setHudVisible(false)
    setNui(true)
    createShowroomCamera(currentPayload.camera or {})

    sendNui({
        action = 'open',
        data = currentPayload
    })
    -- Nu cream preview aici. UI-ul trimite un singur callback `preview` dupa ce selecteaza cardul.
    -- Asta rezolva bugul in care prima masina aparea de doua ori la deschiderea showroom-ului.
end

local function setCameraFree(state)
    if not showroomOpen then return end

    cameraFree = state == true

    if cameraFree then
        setNui(false)
        destroyShowroomCamera()
    else
        setNui(true)
        createShowroomCamera(currentPayload and currentPayload.camera or {})
    end
end

local function clearTestTimers()
    for _, timer in ipairs(testTimers) do
        if timer then
            ClearTimeout(timer)
        end
    end
    testTimers = {}
end

local function endTestDrive(reason)
    if not inTestDrive then return end

    inTestDrive = false
    clearTestTimers()
    deleteTestVehicle()
    hidePlayerForPreview(false)
    setHudVisible(false)

    TriggerServerEvent('driftzone_showroom:server:endTestDrive', reason or 'time')
end

local function startTestDrive(data)
    data = data or {}
    local vehicleData = data.vehicle or {}
    local model = tostring(vehicleData.model or ''):lower():gsub('%s+', '')
    local spawn = data.spawn or {}

    closeShowroom(false)
    deleteTestVehicle()
    clearTestTimers()

    local hash = loadModel(model)
    if not hash then
        notify('warning', 'Model invalid pentru test drive.')
        TriggerServerEvent('driftzone_showroom:server:endTestDrive', 'invalid')
        return
    end

    local ped = PlayerPedId()
    local x = tonumber(spawn.x or -50.35)
    local y = tonumber(spawn.y or -1113.42)
    local z = tonumber(spawn.z or 26.43)
    local h = tonumber(spawn.heading or 70.0)

    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, h)
    hidePlayerForPreview(false)
    setHudVisible(true)

    testVehicle = CreateVehicle(hash, x, y, z, h, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not testVehicle or testVehicle == 0 or not DoesEntityExist(testVehicle) then
        notify('warning', 'Nu am putut crea masina de test drive.')
        TriggerServerEvent('driftzone_showroom:server:endTestDrive', 'invalid')
        return
    end

    SetEntityAsMissionEntity(testVehicle, true, true)
    SetVehicleNumberPlateText(testVehicle, 'TEST')
    SetVehicleFixed(testVehicle)
    SetVehicleDeformationFixed(testVehicle)
    SetVehicleDirtLevel(testVehicle, 0.0)
    setVehicleWhite(testVehicle)
    SetVehicleEngineHealth(testVehicle, 1000.0)
    SetVehicleBodyHealth(testVehicle, 1000.0)
    SetVehiclePetrolTankHealth(testVehicle, 1000.0)
    SetVehicleEngineOn(testVehicle, true, true, false)
    SetPedIntoVehicle(ped, testVehicle, -1)

    inTestDrive = true
    local seconds = tonumber(data.seconds or Config.TestDriveSeconds or 120) or 120

    for _, warning in ipairs(data.warnings or {}) do
        local secondsLeft = tonumber(warning.secondsLeft or 0) or 0
        local ms = (seconds - secondsLeft) * 1000
        if ms > 0 then
            testTimers[#testTimers + 1] = SetTimeout(ms, function()
                if inTestDrive then
                    notify(warning.type or 'info', ('Test Drive: mai ai %s secunde.'):format(secondsLeft), 4000)
                end
            end)
        end
    end

    testTimers[#testTimers + 1] = SetTimeout(seconds * 1000, function()
        endTestDrive('time')
    end)

    notify('info', ('Ai inceput test drive cu %s pentru %s secunde.'):format(vehicleData.name or model, seconds))
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeShowroom(true)
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    local model = tostring((data or {}).model or ''):lower():gsub('%s+', '')
    if model ~= '' then
        createPreviewVehicle(model)
    end
    cb({ ok = true })
end)

RegisterNUICallback('buy', function(data, cb)
    local model = tostring((data or {}).model or ''):lower():gsub('%s+', '')
    if model ~= '' then
        TriggerServerEvent('driftzone_showroom:server:buy', model)
    end
    cb({ ok = true })
end)

RegisterNUICallback('testDrive', function(data, cb)
    local model = tostring((data or {}).model or ''):lower():gsub('%s+', '')
    if model ~= '' then
        TriggerServerEvent('driftzone_showroom:server:testDrive', model)
    end
    cb({ ok = true })
end)

RegisterNUICallback('rotatePreview', function(data, cb)
    rotatePreview(tonumber((data or {}).delta or 0) or 0)
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_showroom:client:open', function(payload)
    openShowroom(payload or {})
end)

RegisterNetEvent('driftzone_showroom:client:forceClose', function()
    closeShowroom(false)
end)

RegisterNetEvent('driftzone_showroom:client:startTestDrive', function(data)
    startTestDrive(data or {})
end)

RegisterNetEvent('driftzone_showroom:client:openFromInteraction', function()
    TriggerServerEvent('driftzone_showroom:server:open')
end)

RegisterCommand('showroom', function()
    TriggerServerEvent('driftzone_showroom:server:open')
end, false)

RegisterCommand('sr', function()
    TriggerServerEvent('driftzone_showroom:server:open')
end, false)

CreateThread(function()
    Wait(1200)

    if Config.Blip and Config.Blip.enabled then
        local coords = Config.Showroom.Interaction.coords
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, Config.Blip.sprite or 225)
        SetBlipColour(blip, Config.Blip.color or 3)
        SetBlipScale(blip, Config.Blip.scale or 0.85)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Blip.name or 'DriftZone Showroom')
        EndTextCommandSetBlipName(blip)
    end

    pcall(function()
        exports.driftzone_interactions:AddInteraction({
            id = 'driftzone_showroom_main',
            coords = Config.Showroom.Interaction.coords,
            range = Config.Showroom.Interaction.range,
            key = 'E',
            text = 'Apasa tasta E pentru a intra in showroom',
            subText = 'DriftZone Vehicle Showroom',
            marker = true,
            event = 'driftzone_showroom:client:openFromInteraction'
        })
    end)
end)

CreateThread(function()
    while true do
        if showroomOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
                closeShowroom(true)
            end

            if IsControlJustPressed(0, 243) then -- backtick
                setCameraFree(not cameraFree)
            end

            Wait(0)
        elseif inTestDrive then
            local ped = PlayerPedId()
            if testVehicle and testVehicle ~= 0 and DoesEntityExist(testVehicle) then
                if not IsPedInVehicle(ped, testVehicle, false) then
                    endTestDrive('left')
                end
            end
            Wait(500)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    showroomOpen = false
    inTestDrive = false
    previewRequestId = previewRequestId + 1

    deletePreviewVehicle()
    deleteTestVehicle()
    clearTestTimers()
    destroyShowroomCamera()
    hidePlayerForPreview(false)
    setNui(false)
    setHudVisible(true)
end)
