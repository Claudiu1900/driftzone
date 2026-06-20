local phoneVisible = false
local phoneOpen = false
local phoneFocus = false
local lastState = {}
local PhoneGarageWorld = {}
local PhoneGarageBlips = {}
local garageAdminOpen = false
local phoneAnimPlaying = false
local currentCallOptions = { muted = false, speaker = false }


-- =========================
-- GARAGE PHONE APP
-- =========================
local PendingGarageVehicles = {}
local ConfirmedGarageVehicles = {}

local function garageNotify(typ, msg, duration)
    TriggerEvent('client:notify', typ or 'info', duration or 4500, tostring(msg or ''))
end

local function requestVehicleControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local expires = GetGameTimer() + (tonumber(timeout or 1200) or 1200)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < expires do
        NetworkRequestControlOfEntity(entity)
        Wait(25)
    end
    return NetworkHasControlOfEntity(entity)
end

local function loadVehicleModel(hash, timeout)
    hash = tonumber(hash or 0) or 0
    if hash == 0 or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return false end

    RequestModel(hash)
    local expires = GetGameTimer() + (tonumber(timeout or 10000) or 10000)

    while not HasModelLoaded(hash) and GetGameTimer() < expires do
        Wait(25)
    end

    return HasModelLoaded(hash)
end

local function getGroundSpawnZ(x, y, z)
    x = tonumber(x or 0.0) or 0.0
    y = tonumber(y or 0.0) or 0.0
    z = tonumber(z or 0.0) or 0.0

    for _, height in ipairs({ z + 80.0, z + 50.0, z + 25.0, z + 10.0, z + 3.0 }) do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
        if found and groundZ then return groundZ + 0.05 end
        Wait(0)
    end

    return z
end


local MOD_KEY_TYPES = {
    spoiler = 0, frontBumper = 1, rearBumper = 2, sideSkirt = 3, exhaust = 4, frame = 5, grille = 6, hood = 7,
    fender = 8, rightFender = 9, roof = 10, engine = 11, brakes = 12, transmission = 13, horn = 14, horns = 14,
    suspension = 15, armor = 16, frontWheels = 23, wheels = 23, wheel = 23, backWheels = 24, plateHolder = 25,
    vanityPlate = 26, trimA = 27, ornaments = 28, dashboard = 29, dial = 30, doorSpeaker = 31, seats = 32,
    steeringWheel = 33, shiftLever = 34, plaques = 35, speakers = 36, trunk = 37, hydraulics = 38, engineBlock = 39,
    airFilter = 40, struts = 41, archCover = 42, aerials = 43, trimB = 44, tank = 45, windows = 46, livery = 48
}

local function decodeTuning(raw)
    if type(raw) == 'table' then return raw end

    local text = tostring(raw or '{}')
    if text == '' or text == 'null' or text == 'nil' then return {} end

    local ok, decoded = pcall(json.decode, text)
    if ok and type(decoded) == 'table' then return decoded end

    return {}
end

local function parseHexColor(value)
    local clean = tostring(value or ''):gsub('#', '')
    if not clean:match('^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return nil
    end

    return {
        r = tonumber(clean:sub(1, 2), 16) or 0,
        g = tonumber(clean:sub(3, 4), 16) or 0,
        b = tonumber(clean:sub(5, 6), 16) or 0
    }
end

local function normalizeColor(value)
    if type(value) == 'string' then
        return parseHexColor(value)
    end

    if type(value) == 'table' then
        return {
            r = tonumber(value.r or value[1] or 0) or 0,
            g = tonumber(value.g or value[2] or 0) or 0,
            b = tonumber(value.b or value[3] or 0) or 0
        }
    end

    return nil
end

local function boolValue(value)
    if value == true then return true end
    local text = tostring(value or ''):lower()
    return tonumber(value) == 1 or text == 'true' or text == 'yes' or text == 'on'
end

local function applyColorData(entity, tuning)
    local primary = normalizeColor(tuning.primaryColor or tuning.primary or tuning.customPrimaryColor)
    local secondary = normalizeColor(tuning.secondaryColor or tuning.secondary or tuning.customSecondaryColor)

    if primary then
        SetVehicleCustomPrimaryColour(entity, primary.r, primary.g, primary.b)
    end

    if secondary then
        SetVehicleCustomSecondaryColour(entity, secondary.r, secondary.g, secondary.b)
    end

    local pearl, wheel = GetVehicleExtraColours(entity)

    if tuning.pearlescentColor ~= nil or tuning.pearl ~= nil then
        pearl = tonumber(tuning.pearlescentColor or tuning.pearl) or pearl or 0
    end

    if tuning.wheelColor ~= nil then
        wheel = tonumber(tuning.wheelColor) or wheel or 0
    end

    SetVehicleExtraColours(entity, pearl or 0, wheel or 0)

    if tuning.windowTint ~= nil then
        SetVehicleWindowTint(entity, tonumber(tuning.windowTint) or 0)
    end

    if tuning.xenonColor ~= nil then
        ToggleVehicleMod(entity, 22, true)
        SetVehicleXenonLightsColor(entity, tonumber(tuning.xenonColor) or 0)
    end

    if tuning.neonColor ~= nil then
        local c = normalizeColor(tuning.neonColor)
        if c then
            SetVehicleNeonLightsColour(entity, c.r, c.g, c.b)
            for i = 0, 3 do SetVehicleNeonLightEnabled(entity, i, true) end
        end
    end

    if tuning.tyreSmokeColor ~= nil or tuning.tireSmokeColor ~= nil then
        local c = normalizeColor(tuning.tyreSmokeColor or tuning.tireSmokeColor)
        if c then
            ToggleVehicleMod(entity, 20, true)
            SetVehicleTyreSmokeColor(entity, c.r, c.g, c.b)
        end
    end
end

local function applyNumberMods(entity, tuning)
    for key, modType in pairs(MOD_KEY_TYPES) do
        if tuning[key] ~= nil then
            local value = tonumber(tuning[key])
            if value ~= nil then
                SetVehicleMod(entity, modType, value, false)
            end
        end
    end

    -- Compatibilitate cand tuning-ul este salvat direct pe mod type numeric/string numeric.
    for key, value in pairs(tuning) do
        local modType = tonumber(key)
        if modType and modType >= 0 and modType <= 60 then
            SetVehicleMod(entity, modType, tonumber(value) or -1, false)
        end
    end
end

local function applyToggleMods(entity, tuning)
    if tuning.turbo ~= nil then
        ToggleVehicleMod(entity, 18, boolValue(tuning.turbo))
    end

    if tuning.xenon ~= nil then
        ToggleVehicleMod(entity, 22, boolValue(tuning.xenon))
    end

    if tuning.tireSmoke ~= nil or tuning.tyreSmoke ~= nil then
        ToggleVehicleMod(entity, 20, boolValue(tuning.tireSmoke or tuning.tyreSmoke))
    end
end

local function decodeGradient(raw)
    if type(raw) == 'table' then return raw end
    local text = tostring(raw or '')
    if text == '' or text == 'null' or text == 'nil' or text == '{}' then return nil end
    local ok, decoded = pcall(json.decode, text)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

local function applyGarageGradient(entity, gradientRaw)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local gradient = decodeGradient(gradientRaw)
    if not gradient then return false end

    local colorId = tonumber(gradient.colorId or gradient.colourId or gradient.color or 0) or 0
    if colorId <= 0 then return false end

    local applyTo = tostring(gradient.applyTo or gradient.appliedTo or 'both'):lower()
    if applyTo ~= 'primary' and applyTo ~= 'secondary' and applyTo ~= 'both' then
        applyTo = 'both'
    end

    requestVehicleControl(entity, 1500)
    SetVehicleModKit(entity, 0)

    local primary, secondary = GetVehicleColours(entity)
    primary = tonumber(primary or 0) or 0
    secondary = tonumber(secondary or 0) or 0

    if applyTo == 'primary' then
        ClearVehicleCustomPrimaryColour(entity)
        SetVehicleColours(entity, colorId, secondary)
    elseif applyTo == 'secondary' then
        ClearVehicleCustomSecondaryColour(entity)
        SetVehicleColours(entity, primary, colorId)
    else
        ClearVehicleCustomPrimaryColour(entity)
        ClearVehicleCustomSecondaryColour(entity)
        SetVehicleColours(entity, colorId, colorId)
    end

    SetVehicleDirtLevel(entity, 0.0)
    return true
end

local function applyGarageVehicleTuning(entity, tuningRaw, gradientRaw)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    requestVehicleControl(entity, 2500)
    SetVehicleModKit(entity, 0)

    local tuning = decodeTuning(tuningRaw)
    if type(tuning) == 'table' then
        applyColorData(entity, tuning)
        applyNumberMods(entity, tuning)
        applyToggleMods(entity, tuning)

        if tuning.plate ~= nil then
            SetVehicleNumberPlateText(entity, tostring(tuning.plate):sub(1, 8))
        end
    end

    -- Gradientul se aplica dupa tuning, ca vopseaua salvata din tuning sa nu il suprascrie.
    applyGarageGradient(entity, gradientRaw)

    local netId = VehToNet(entity)
    if netId and netId > 0 and tuningRaw and tostring(tuningRaw) ~= '' and tostring(tuningRaw) ~= '{}' then
        TriggerEvent('client:tunning:applyVehicle', netId, tostring(tuningRaw))
        TriggerEvent('driftzone_tunning:client:applyVehicle', netId, tostring(tuningRaw))
    end

    return true
end

local function getVehicleFromNetId(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return 0 end

    local timeout = GetGameTimer() + 15000
    while GetGameTimer() < timeout do
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetToVeh(netId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
        end
        Wait(100)
    end

    return 0
end

local function forcePhoneGarageVehicleByNetId(netId, data)
    data = type(data) == 'table' and data or {}

    local entity = getVehicleFromNetId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    requestVehicleControl(entity, 5000)

    if data.plate then
        SetVehicleNumberPlateText(entity, tostring(data.plate or 'DRIFT'):sub(1, 8))
    end

    SetVehicleModKit(entity, 0)
    SetVehicleDirtLevel(entity, 0.0)
    SetVehicleEngineOn(entity, false, true, true)
    SetVehicleDoorsLocked(entity, 2)

    applyGarageVehicleTuning(entity, data.tuning, data.gradient)

    -- Integrare driftzone_vehicleconfig / VS:
    -- seteaza SQL ID, lock default real si motor oprit.
    pcall(function()
        TriggerEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', entity, tonumber(data.id or data.vehicleId or 0))
    end)

    return true
end

local function schedulePhoneGarageTuning(netId, data)
    CreateThread(function()
        forcePhoneGarageVehicleByNetId(netId, data)

        local retries = (Config.Garage and Config.Garage.ApplyTuningRetries) or { 150, 450, 900, 1600, 2800 }
        for i = 1, #retries do
            Wait(tonumber(retries[i] or 0) or 0)

            local entity = getVehicleFromNetId(netId)
            if not entity or entity == 0 or not DoesEntityExist(entity) then break end

            forcePhoneGarageVehicleByNetId(netId, data)
        end
    end)
end

local function applyStateBagGarageData(bagName)
    CreateThread(function()
        local entity = GetEntityFromStateBagName(bagName)
        local timeout = GetGameTimer() + 6000

        while (not entity or entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() < timeout do
            Wait(100)
            entity = GetEntityFromStateBagName(bagName)
        end

        if not entity or entity == 0 or not DoesEntityExist(entity) then return end

        local state = Entity(entity).state
        local tuning = state.dz_garage_tuning or state.vehicleTunning or state.dz_vehicle_tunning or '{}'
        local gradient = state.dz_garage_gradient or state.vehicleGradient or state.dz_vehicle_gradient or ''

        Wait(250)
        applyGarageVehicleTuning(entity, tuning, gradient)
    end)
end

AddStateBagChangeHandler('dz_garage_tuning', nil, function(bagName)
    applyStateBagGarageData(bagName)
end)

AddStateBagChangeHandler('vehicleTunning', nil, function(bagName)
    applyStateBagGarageData(bagName)
end)

AddStateBagChangeHandler('dz_garage_gradient', nil, function(bagName)
    applyStateBagGarageData(bagName)
end)


local function deleteGarageVehicle(vehicle)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        requestVehicleControl(vehicle, 1000)
        DeleteVehicle(vehicle)
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end
end

local function cleanupPendingGarageVehicle(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if ConfirmedGarageVehicles[vehicleId] then
        PendingGarageVehicles[vehicleId] = nil
        return
    end
    deleteGarageVehicle(PendingGarageVehicles[vehicleId])
    PendingGarageVehicles[vehicleId] = nil
end

RegisterNetEvent('driftzone_phone:client:garageCreateVehicle', function(data)
    data = data or {}

    local vehicleId = tonumber(data.id or 0) or 0
    local model = tostring(data.model or '')
    local hash = GetHashKey(model)
    local spawn = type(data.spawn) == 'table' and data.spawn or {}

    local x = tonumber(spawn.x)
    local y = tonumber(spawn.y)
    local z = tonumber(spawn.z)
    local h = tonumber(spawn.h or spawn.heading or 0.0) or 0.0

    if vehicleId <= 0 or not x or not y or not z then
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Date spawn invalide.')
        return
    end

    cleanupPendingGarageVehicle(vehicleId)

    if not loadVehicleModel(hash, 10000) then
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Modelul masinii nu este streamat.')
        return
    end

    z = getGroundSpawnZ(x, y, z)
    local vehicle = CreateVehicle(hash, x, y, z, h, true, true)

    local expires = GetGameTimer() + 7000
    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and GetGameTimer() < expires do
        Wait(25)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Nu am putut crea masina.')
        return
    end

    PendingGarageVehicles[vehicleId] = vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityCoordsNoOffset(vehicle, x, y, z, false, false, false)
    Wait(0)
    SetVehicleOnGroundProperly(vehicle)
    Wait(0)
    SetEntityHeading(vehicle, h)
    SetVehicleNumberPlateText(vehicle, tostring(data.plate or 'DRIFT'):sub(1, 8))
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleDirtLevel(vehicle, 0.0)

    local state = Entity(vehicle).state
    state:set('dz_phone_garage_vehicle', true, true)
    state:set('dz_phone_garage_vehicle_id', vehicleId, true)
    state:set('dz_phone_garage_plate', tostring(data.plate or ''), true)
    state:set('dz_phone_garage_model', tostring(data.model or model or ''), true)
    state:set('dz_garage_vehicle', true, true)
    state:set('dz_garage_db_id', vehicleId, true)
    state:set('ownedVehicleId', vehicleId, true)
    state:set('vehicle_id', vehicleId, true)
    state:set('vehicle_plate', tostring(data.plate or ''), true)
    state:set('dz_garage_tuning', tostring(data.tuning or '{}'), true)
    state:set('vehicleTunning', tostring(data.tuning or '{}'), true)
    state:set('dz_vehicle_tunning', tostring(data.tuning or '{}'), true)
    state:set('dz_garage_gradient', tostring(data.gradient or ''), true)
    state:set('vehicleGradient', tostring(data.gradient or ''), true)
    state:set('dz_vehicle_gradient', tostring(data.gradient or ''), true)

    applyGarageVehicleTuning(vehicle, data.tuning, data.gradient)

    local netId = VehToNet(vehicle)
    NetworkRegisterEntityAsNetworked(vehicle)
    netId = VehToNet(vehicle)

    if netId and netId > 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
    end

    expires = GetGameTimer() + 5000
    while (not netId or netId <= 0) and GetGameTimer() < expires do
        Wait(50)
        netId = VehToNet(vehicle)
    end

    if not netId or netId <= 0 then
        cleanupPendingGarageVehicle(vehicleId)
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent('driftzone_phone:server:garageSpawnFailed', vehicleId, 'Masina nu a primit Network ID.')
        return
    end

    schedulePhoneGarageTuning(netId, {
        id = vehicleId,
        vehicleId = vehicleId,
        model = model,
        plate = data.plate,
        tuning = data.tuning,
        gradient = data.gradient
    })

    ConfirmedGarageVehicles[vehicleId] = true
    SetModelAsNoLongerNeeded(hash)
    TriggerServerEvent('driftzone_phone:server:garageConfirmSpawn', vehicleId, netId)
end)

RegisterNetEvent('driftzone_phone:client:garageApplyVehicle', function(netId, data)
    schedulePhoneGarageTuning(netId, data or {})
end)

RegisterNetEvent('driftzone_phone:client:garageSpawnSuccess', function(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId > 0 then
        PendingGarageVehicles[vehicleId] = nil
        ConfirmedGarageVehicles[vehicleId] = true
    end

    SetTimeout(250, function()
        TriggerServerEvent('driftzone_phone:server:requestState')
    end)

    SetTimeout(1000, function()
        TriggerServerEvent('driftzone_phone:server:requestState')
    end)
end)

RegisterNetEvent('driftzone_phone:client:garageDeletePending', function(vehicleId)
    vehicleId = tonumber(vehicleId or 0) or 0
    ConfirmedGarageVehicles[vehicleId] = nil
    cleanupPendingGarageVehicle(vehicleId)
end)

RegisterNetEvent('driftzone_phone:client:garageDeleteNet', function(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    CreateThread(function()
        if NetworkDoesNetworkIdExist(netId) then
            deleteGarageVehicle(NetToVeh(netId))
        end
    end)
end)

RegisterNetEvent('driftzone_phone:client:garageWaypoint', function(coords)
    coords = coords or {}
    local x = tonumber(coords.x)
    local y = tonumber(coords.y)

    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
    else
        garageNotify('warning', 'Locatia masinii nu este valida.')
    end
end)




-- =========================
-- PHONE VOICE CALL
-- =========================
local currentPhoneVoiceTarget = nil

RegisterNetEvent('driftzone_phone:client:voiceStart', function(targetServerId)
    targetServerId = tonumber(targetServerId or 0) or 0
    currentPhoneVoiceTarget = targetServerId

    if targetServerId <= 0 then return end

    -- pma-voice normal call channel export.
    pcall(function()
        exports['pma-voice']:addPlayerToCall(targetServerId)
    end)

    -- fallback pentru sisteme custom care asculta eventuri.
    TriggerEvent('driftzone_phone:voice:start', targetServerId)
end)

RegisterNetEvent('driftzone_phone:client:voiceEnd', function()
    local target = currentPhoneVoiceTarget
    currentPhoneVoiceTarget = nil

    pcall(function()
        exports['pma-voice']:removePlayerFromCall()
    end)

    TriggerEvent('driftzone_phone:voice:end', target)
end)


local function requestAnimDictPhone(dict)
    dict = tostring(dict or '')
    if dict == '' then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function startPhoneAnim()
    if phoneAnimPlaying then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 or IsPedDeadOrDying(ped, true) then return end

    local dict = 'cellphone@'
    local anim = 'cellphone_text_read_base'
    if not requestAnimDictPhone(dict) then return end

    -- Flag 49 = upper body/secondary task, nu blocheaza mersul si nu ingheata ped-ul.
    TaskPlayAnim(ped, dict, anim, 2.0, -2.0, -1, 49, 0.0, false, false, false)
    phoneAnimPlaying = true
end

local function stopPhoneAnim()
    if not phoneAnimPlaying then return end
    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        StopAnimTask(ped, 'cellphone@', 'cellphone_text_read_base', 1.0)
        ClearPedSecondaryTask(ped)
    end
    phoneAnimPlaying = false
end

CreateThread(function()
    while true do
        if phoneVisible or phoneOpen then
            startPhoneAnim()
            local ped = PlayerPedId()
            if ped and ped ~= 0 and not IsEntityPlayingAnim(ped, 'cellphone@', 'cellphone_text_read_base', 3) then
                phoneAnimPlaying = false
                startPhoneAnim()
            end
            Wait(1200)
        else
            stopPhoneAnim()
            Wait(500)
        end
    end
end)


local function sendNui(data)
    SendNUIMessage(data)
end

local function setFocus(state)
    phoneFocus = state == true
    SetNuiFocus(phoneFocus, phoneFocus)
    SetNuiFocusKeepInput(false)
    sendNui({ action = 'focus', focus = phoneFocus })
end

local function resetCallOptions()
    currentCallOptions = { muted = false, speaker = false }
    TriggerEvent('driftzone_voicechat:client:setPhoneOptions', currentCallOptions)
end

local function refreshState()
    TriggerServerEvent('driftzone_phone:server:requestState')
end

local function openPhone(screen)
    phoneVisible = true
    phoneOpen = true
    setFocus(true)
    sendNui({
        action = 'open',
        screen = screen or 'home',
        mainColor = Config.MainColor or '#04c7f7',
        state = lastState or {}
    })
    refreshState()
end

local function showIncomingPeek(state)
    phoneVisible = true
    phoneOpen = false
    setFocus(false)
    sendNui({ action = 'incomingPeek', mainColor = Config.MainColor or '#04c7f7', state = state or lastState or {} })
end

local function showMessagePeek(payload)
    if phoneOpen then return end
    phoneVisible = true
    phoneOpen = false
    setFocus(false)
    sendNui({ action = 'messagePeek', mainColor = Config.MainColor or '#04c7f7', message = payload or {}, state = lastState or {} })

    SetTimeout(3000, function()
        if phoneVisible and not phoneOpen then
            closePhone()
        end
    end)
end

local function closePhone()
    phoneVisible = false
    phoneOpen = false
    resetCallOptions()
    setFocus(false)
    sendNui({ action = 'close' })
end

local function toggleCursor()
    if not phoneVisible then return end
    setFocus(not phoneFocus)
end

RegisterCommand(Config.Command or 'phone', function()
    if phoneOpen then
        closePhone()
    else
        openPhone('home')
    end
end, false)

RegisterKeyMapping(Config.Command or 'phone', 'Deschide telefonul', 'keyboard', 'L')

RegisterCommand('garage', function()
    openPhone('garage')
end, false)

RegisterCommand('garaj', function()
    openPhone('garage')
end, false)

RegisterCommand('park', function()
    local ped = PlayerPedId()
    if not ped or ped == 0 or not IsPedInAnyVehicle(ped, false) then
        TriggerEvent('client:notify', 'warning', 4500, 'Trebuie sa fii intr-o masina.')
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return end
    TriggerServerEvent('driftzone_phone:server:garageParkCurrent', VehToNet(veh))
end, false)

RegisterNUICallback('ready', function(_, cb)
    sendNui({ action = 'setup', mainColor = Config.MainColor or '#04c7f7' })
    refreshState()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb({ ok = true })
end)

RegisterNUICallback('openFull', function(data, cb)
    openPhone(data and data.screen or 'home')
    cb({ ok = true })
end)

RegisterNUICallback('toggleCursor', function(_, cb)
    toggleCursor()
    cb({ ok = true })
end)

RegisterNUICallback('requestState', function(_, cb)
    refreshState()
    cb({ ok = true })
end)

RegisterNUICallback('dial', function(data, cb)
    phoneVisible = true
    phoneOpen = true
    TriggerServerEvent('driftzone_phone:server:startCall', data and data.number or '')
    cb({ ok = true })
end)

RegisterNUICallback('answer', function(_, cb)
    phoneVisible = true
    phoneOpen = true
    setFocus(true)
    sendNui({ action = 'open', screen = 'call', state = lastState or {} })
    TriggerServerEvent('driftzone_phone:server:answerCall')
    cb({ ok = true })
end)

RegisterNUICallback('decline', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:declineCall')
    if not phoneOpen then
        closePhone()
    else
        setFocus(true)
    end
    cb({ ok = true })
end)

RegisterNUICallback('hangup', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:hangupCall')
    resetCallOptions()
    if phoneOpen then setFocus(true) end
    cb({ ok = true })
end)

RegisterNUICallback('setCallOptions', function(data, cb)
    currentCallOptions = {
        muted = data and data.muted == true,
        speaker = data and data.speaker == true
    }
    TriggerEvent('driftzone_voicechat:client:setPhoneOptions', currentCallOptions)
    cb({ ok = true })
end)

RegisterNUICallback('saveContact', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:saveContact', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('toggleBlock', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:toggleBlock', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('deleteContact', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:deleteContact', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('sendMessage', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:sendMessage', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('shareLocation', function(data, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    TriggerServerEvent('driftzone_phone:server:sendMessage', {
        number = data and data.number or '',
        type = 'location',
        text = 'Locatie partajata',
        location = { x = c.x, y = c.y, z = c.z },
        clientToken = data and data.clientToken or ''
    })
    cb({ ok = true })
end)



RegisterNetEvent('driftzone_phone:client:garageAdminOpen', function(data)
    garageAdminOpen = true
    phoneVisible = false
    phoneOpen = false
    setFocus(true)
    sendNui({ action = 'garageAdminOpen', data = data or {} })
end)

RegisterNetEvent('driftzone_phone:client:garageAdminResult', function(ok, message, garages)
    if type(garages) == 'table' then PhoneGarageWorld = garages end
    sendNui({ action = 'garageAdminResult', ok = ok == true, message = tostring(message or ''), garages = garages or {} })
end)

RegisterNUICallback('garageAdminClose', function(_, cb)
    garageAdminOpen = false
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('garageAdminGetPlayerPosition', function(_, cb)
    local ped = PlayerPedId()
    local entity = ped

    if ped and ped ~= 0 and IsPedInAnyVehicle(ped, false) then
        entity = GetVehiclePedIsIn(ped, false)
    end

    if not entity or entity == 0 then
        cb({ ok = false })
        return
    end

    local c = GetEntityCoords(entity)
    local h = GetEntityHeading(entity)
    cb({ ok = true, x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, h = h + 0.0 })
end)

RegisterNUICallback('garageAdminSave', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageAdminSave', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('garageAdminDelete', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageAdminDelete', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('garageAdminReload', function(_, cb)
    TriggerServerEvent('driftzone_phone:server:garageAdminReload')
    cb({ ok = true })
end)


RegisterNUICallback('garageSpawn', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageSpawn', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('garagePark', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garagePark', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('garageTow', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageTow', data and data.id or 0)
    cb({ ok = true })
end)

RegisterNUICallback('garageLocate', function(data, cb)
    TriggerServerEvent('driftzone_phone:server:garageLocate', data and data.id or 0)
    cb({ ok = true })
end)




local function clearPhoneGarageBlips()
    for _, blip in pairs(PhoneGarageBlips or {}) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    PhoneGarageBlips = {}
end

local function refreshPhoneGarageBlips()
    clearPhoneGarageBlips()

    local cfg = Config.Garage or {}
    if cfg.GarageBlipEnabled == false then return end

    for _, garage in ipairs(PhoneGarageWorld or {}) do
        local id = tonumber(garage.id or 0) or 0
        local x = tonumber(garage.x or (garage.coords and garage.coords.x))
        local y = tonumber(garage.y or (garage.coords and garage.coords.y))
        local z = tonumber(garage.z or (garage.coords and garage.coords.z))

        if id > 0 and x and y and z then
            local blip = AddBlipForCoord(x + 0.0, y + 0.0, z + 0.0)

            SetBlipSprite(blip, tonumber(cfg.GarageBlipSprite or 357) or 357)
            SetBlipColour(blip, tonumber(cfg.GarageBlipColor or 38) or 38)
            SetBlipScale(blip, tonumber(cfg.GarageBlipScale or 0.78) or 0.78)
            SetBlipAsShortRange(blip, cfg.GarageBlipShortRange ~= false)
            SetBlipDisplay(blip, 4)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(tostring(garage.name or cfg.GarageBlipName or 'Garaj'))
            EndTextCommandSetBlipName(blip)

            PhoneGarageBlips[id] = blip
        end
    end
end

RegisterNetEvent('driftzone_phone:client:garageWorld', function(garages)
    PhoneGarageWorld = type(garages) == 'table' and garages or {}
    refreshPhoneGarageBlips()
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('driftzone_phone:server:requestGarageWorld')
end)

CreateThread(function()
    while true do
        local waitTime = 900
        local ped = PlayerPedId()

        if ped and ped ~= 0 and #PhoneGarageWorld > 0 then
            local pcoords = GetEntityCoords(ped)

            for _, garage in ipairs(PhoneGarageWorld) do
                local x = tonumber(garage.x or (garage.coords and garage.coords.x))
                local y = tonumber(garage.y or (garage.coords and garage.coords.y))
                local z = tonumber(garage.z or (garage.coords and garage.coords.z))

                if x and y and z then
                    local dist = #(pcoords - vector3(x, y, z))
                    if dist <= 45.0 then
                        waitTime = 0

                        -- Sign albastru de masina, ca in driftzone_garage.
                        DrawMarker(
                            36,
                            x, y, z + 0.55,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.82, 0.82, 0.82,
                            4, 199, 247, 210,
                            false, true, 2, false, nil, nil, false
                        )

                        if garage.visible_radius ~= false then
                            local radius = tonumber(garage.radius or 4.0) or 4.0
                            DrawMarker(
                                1,
                                x, y, z - 1.02,
                                0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0,
                                radius * 2.0, radius * 2.0, 0.22,
                                4, 199, 247, 50,
                                false, false, 2, false, nil, nil, false
                            )
                        end
                    end
                end
            end
        end

        Wait(waitTime)
    end
end)


RegisterNUICallback('setWaypoint', function(data, cb)
    local loc = data and data.location or {}
    local x = tonumber(loc.x)
    local y = tonumber(loc.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
    end
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_phone:client:state', function(state)
    local wasInCall = lastState and lastState.inCall == true
    local wasActive = lastState and lastState.active == true
    lastState = state or {}

    if lastState.garage and type(lastState.garage.garages) == 'table' then
        PhoneGarageWorld = lastState.garage.garages
    end

    sendNui({ action = 'state', state = lastState })

    if wasInCall and not lastState.inCall then
        resetCallOptions()
        if phoneOpen then
            setFocus(true)
        elseif phoneVisible then
            closePhone()
        end
    end

    if wasActive and not lastState.active and phoneOpen then
        setFocus(true)
    end
end)

RegisterNetEvent('driftzone_phone:client:incoming', function(state)
    lastState = state or lastState or {}
    showIncomingPeek(lastState)
end)

RegisterNetEvent('driftzone_phone:client:messageSync', function(payload)
    sendNui({ action = 'messageSync', message = payload or {} })
end)

RegisterNetEvent('driftzone_phone:client:messageReceived', function(payload)
    sendNui({ action = 'messageReceived', message = payload or {} })
    showMessagePeek(payload or {})
end)

RegisterNetEvent('driftzone_phone:client:feedback', function(payload)
    sendNui({ action = 'feedback', payload = payload or {} })
end)

CreateThread(function()
    while true do
        if phoneVisible then
            if IsControlJustPressed(0, 243) or IsDisabledControlJustPressed(0, 243) then
                toggleCursor()
                Wait(250)
            end

            if phoneFocus then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 200, true)
            end

            Wait(0)
        else
            Wait(350)
        end
    end
end)

CreateThread(function()
    while true do
        if phoneVisible or (lastState and lastState.inCall) then
            refreshState()
            if lastState and lastState.inCall then
                Wait(2500)
            else
                Wait(Config.StateRefreshMs or 8000)
            end
        else
            Wait(6000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    resetCallOptions()
end)
