local garageOpened = false
local nuiReady = false
local pendingOpenPayload = nil
local ownedVehicleBlips = {}
local protectedVehicles = {}
local garageBlocked = false
local garageBlockedReason = 'Garaj indisponibil.'
local currentGarageId = 0
local cachedGarages = {}

local sendNui
local setGarageFocus

local function notify(type, message, duration)
    TriggerEvent('client:notify', type or 'info', duration or 5000, tostring(message or ''))
end

local function isGarageBlocked()
    return garageBlocked == true
end

local function blockMessage()
    return tostring(garageBlockedReason or 'Garaj indisponibil.')
end

local function denyGarageOpen()
    if garageOpened then
        sendNui({ action = 'close' })
        setGarageFocus(false)
    end
    pendingOpenPayload = nil
    notify('warning', blockMessage(), 3500)
    return false
end

local function canOpenGarage()
    if isGarageBlocked() then
        return denyGarageOpen()
    end
    return true
end

sendNui = function(data)
    if not nuiReady then
        if data.action == 'open' then pendingOpenPayload = data end
        return false
    end
    SendNUIMessage(data)
    return true
end

setGarageFocus = function(state)
    garageOpened = state == true
    SetNuiFocus(garageOpened, garageOpened)
    SetNuiFocusKeepInput(false)
    if garageOpened then TriggerEvent('driftzone_hud:visible', false) else TriggerEvent('driftzone_hud:visible', true) end
end

local function openGarageNui(vehicles, hasVip, garage)
    if not canOpenGarage() then return end
    garage = type(garage) == 'table' and garage or {}
    currentGarageId = tonumber(garage.id or 0) or 0
    local payload = { action = 'open', vehicles = vehicles or {}, hasVip = hasVip == true, garage = garage }
    if sendNui(payload) then setGarageFocus(true) else pendingOpenPayload = payload end
end

local function getLocalUid()
    local state = LocalPlayer.state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then return tonumber(state.dz_uid) end
    return nil
end

local function removeBlip(entity)
    local blip = ownedVehicleBlips[entity]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    ownedVehicleBlips[entity] = nil
end

local function createBlip(entity, name, isVip)
    if ownedVehicleBlips[entity] and DoesBlipExist(ownedVehicleBlips[entity]) then return end
    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, isVip and 5 or 2)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    SetBlipDisplay(blip, 4)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(name or 'Vehiculul tau')
    EndTextCommandSetBlipName(blip)
    ownedVehicleBlips[entity] = blip
end

local function isPlayerInsideVehicle(entity)
    local ped = PlayerPedId()
    if not DoesEntityExist(entity) then return false end
    return IsPedInVehicle(ped, entity, false)
end

local function isOwnedGarageVehicle(entity)
    if not DoesEntityExist(entity) then return false end
    local state = Entity(entity).state
    if state.dz_garage_vehicle ~= true then return false end
    local localUid = getLocalUid()
    if not localUid then return false end
    return tonumber(state.dz_garage_owner_uid or 0) == tonumber(localUid)
end

local function requestControl(entity, timeoutMs)
    if not DoesEntityExist(entity) then return false end
    local timeout = GetGameTimer() + (timeoutMs or 1500)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(25)
    end
    return NetworkHasControlOfEntity(entity)
end

local function setVehicleProtection(entity)
    -- Dezactivat intentionat: masinile din garaj NU mai primesc godmode.
    if not DoesEntityExist(entity) then return end
end

local function repairOnce(entity)
    if not DoesEntityExist(entity) then return end
    requestControl(entity, 1500)
    SetVehicleFixed(entity)
    SetVehicleDeformationFixed(entity)
    SetVehicleDirtLevel(entity, 0.0)
    SetVehicleEngineHealth(entity, 1000.0)
    SetVehicleBodyHealth(entity, 1000.0)
    SetVehiclePetrolTankHealth(entity, 1000.0)
    SetVehicleOnGroundProperly(entity)
    -- Fara engine forced ON.
end

local function softMaintain(entity)
    -- Dezactivat intentionat: fara godmode/protectie permanenta.
    if not DoesEntityExist(entity) then return end
end

local function getVehicleFromNetId(netId)
    netId = tonumber(netId) or 0
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

    -- Compatibilitate daca tuning-ul este salvat direct pe mod type numeric/string numeric.
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

local function applyForcedGarageTuning(entity, tuningRaw)
    if not DoesEntityExist(entity) then return false end

    requestControl(entity, 2500)

    SetVehicleModKit(entity, 0)

    local tuning = decodeTuning(tuningRaw)

    if type(tuning) ~= 'table' then return false end

    applyColorData(entity, tuning)
    applyNumberMods(entity, tuning)
    applyToggleMods(entity, tuning)

    if tuning.plate ~= nil then
        SetVehicleNumberPlateText(entity, tostring(tuning.plate):sub(1, 8))
    end

    return true
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
    if not DoesEntityExist(entity) then return false end

    local gradient = decodeGradient(gradientRaw)
    if not gradient then return false end

    local colorId = tonumber(gradient.colorId or gradient.colourId or gradient.color or 0) or 0
    if colorId <= 0 then return false end

    local applyTo = tostring(gradient.applyTo or gradient.appliedTo or 'both'):lower()
    if applyTo ~= 'primary' and applyTo ~= 'secondary' and applyTo ~= 'both' then
        applyTo = 'both'
    end

    requestControl(entity, 1500)
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

local function forceGarageTuningByNetId(netId, data)
    data = data or {}

    local entity = getVehicleFromNetId(netId)

    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local state = Entity(entity).state
    local tuningRaw = data.tuning or state.dz_garage_tuning or state.vehicleTunning or '{}'
    local gradientRaw = data.gradient or state.dz_garage_gradient or state.vehicleGradient or state.gradient or nil

    -- Reaplica direct + trimite si catre driftzone_tunning, ca ambele sisteme sa fie sincronizate.
    applyForcedGarageTuning(entity, tuningRaw)
    TriggerEvent('client:tunning:applyVehicle', netId, tostring(tuningRaw))
    TriggerEvent('driftzone_tunning:client:applyVehicle', netId, tostring(tuningRaw))

    -- Gradientul se aplica dupa tuning, ca vopseaua salvata din tuning sa nu il suprascrie.
    applyGarageGradient(entity, gradientRaw)

    if data.plate then
        SetVehicleNumberPlateText(entity, tostring(data.plate):sub(1, 8))
    end

    return true
end



AddStateBagChangeHandler('dz_garage_gradient', nil, function(bagName, key, value, reserved, replicated)
    if not value or value == '' or value == '{}' then return end

    CreateThread(function()
        local entity = GetEntityFromStateBagName(bagName)
        local timeout = GetGameTimer() + 5000

        while (not entity or entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() < timeout do
            Wait(100)
            entity = GetEntityFromStateBagName(bagName)
        end

        if entity and entity ~= 0 and DoesEntityExist(entity) then
            -- Delay mic ca tuning-ul de spawn sa fie aplicat primul.
            Wait(250)
            applyGarageGradient(entity, value)
        end
    end)
end)


local function forceVehicleTransform(entity, spawn)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    spawn = type(spawn) == 'table' and spawn or {}

    local x = tonumber(spawn.x)
    local y = tonumber(spawn.y)
    local z = tonumber(spawn.z)
    local h = tonumber(spawn.h or spawn.heading)

    requestControl(entity, 700)

    if x and y and z then
        SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
        Wait(0)
        SetVehicleOnGroundProperly(entity)
        Wait(0)
    end

    if h then
        SetEntityHeading(entity, h)
        SetVehicleForwardSpeed(entity, 0.0)
    end
end

local function prepareVehicleByNetId(netId, data)
    data = data or {}

    local entity = getVehicleFromNetId(netId)

    if not entity or entity == 0 or not DoesEntityExist(entity) then
        TriggerServerEvent('driftzone_garage:server:spawnPrepareFailed', tonumber(data.id or 0))
        return
    end

    requestControl(entity, 5000)
    SetVehicleNumberPlateText(entity, tostring(data.plate or 'DRIFT'):sub(1, 8))

    local heading = tonumber(data.heading or data.h or (data.spawn and data.spawn.h) or 0.0) or 0.0
    local spawnTransform = type(data.spawn) == 'table' and data.spawn or { h = heading }

    forceVehicleTransform(entity, spawnTransform)

    -- Fara godmode si fara teleport in masina.
    repairOnce(entity)

    -- Prima aplicare se face fara sa bage playerul in masina.
    forceGarageTuningByNetId(netId, data)

    -- Integrare driftzone_vehicleconfig: seteaza SQL ID, lock default real si motor oprit.
    pcall(function()
        TriggerEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', entity, tonumber(data.id or 0))
    end)

    -- Aplicari repetate pentru bug-ul unde uneori masina apare fara tuning din cauza streaming/control.
    local delays = { 150, 450, 900, 1600, 2800 }

    for i = 1, #delays do
        Wait(delays[i])
        if not DoesEntityExist(entity) then break end
        forceVehicleTransform(entity, spawnTransform)
        forceGarageTuningByNetId(netId, data)
        forceVehicleTransform(entity, spawnTransform)
    end

    TriggerServerEvent('driftzone_garage:server:spawnPrepared', tonumber(data.id or 0))
end


RegisterNetEvent('driftzone_garage:client:forceSpawnTransform', function(netId, spawn)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    CreateThread(function()
        local entity = getVehicleFromNetId(netId)
        if not entity or entity == 0 or not DoesEntityExist(entity) then return end

        local delays = { 0, 120, 300, 650, 1100, 1800 }

        for i = 1, #delays do
            if delays[i] > 0 then Wait(delays[i]) end
            if not DoesEntityExist(entity) then return end
            forceVehicleTransform(entity, spawn or {})
        end
    end)
end)


RegisterNetEvent('driftzone_garage:client:open', function(vehicles, hasVip, garage)
    if not canOpenGarage() then return end
    openGarageNui(vehicles or {}, hasVip == true, garage or {})
end)

RegisterNetEvent('driftzone_garage:client:update', function(vehicles, hasVip, garage)
    if garage then currentGarageId = tonumber(garage.id or currentGarageId or 0) or 0 end
    sendNui({ action = 'update', vehicles = vehicles or {}, hasVip = hasVip == true, garage = garage })
end)

RegisterNetEvent('driftzone_garage:client:spawnedSuccess', function()
    sendNui({ action = 'close' })
    setGarageFocus(false)
end)

RegisterNetEvent('driftzone_garage:client:prepareVehicle', function(netId, data)
    CreateThread(function() prepareVehicleByNetId(netId, data or {}) end)
end)

RegisterNetEvent('driftzone_garage:client:forceTuning', function(netId, data)
    CreateThread(function()
        forceGarageTuningByNetId(netId, data or {})
    end)
end)

RegisterNetEvent('driftzone_garage:client:parkCurrent', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then notify('warning', 'Nu esti intr-o masina.') return end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not isOwnedGarageVehicle(vehicle) then notify('warning', 'Aceasta masina nu iti apartine.') return end
    TriggerServerEvent('driftzone_garage:server:parkCurrent', VehToNet(vehicle))
end)

RegisterNetEvent('driftzone_garage:client:openCommand', function()
    if not canOpenGarage() then return end
    TriggerServerEvent('driftzone_garage:server:open')
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if pendingOpenPayload then
        if canOpenGarage() then
            SendNUIMessage(pendingOpenPayload)
            setGarageFocus(true)
        end
        pendingOpenPayload = nil
    end
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    setGarageFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('spawn', function(data, cb)
    local vehicleId = tonumber(data.id or data.vehicleId or 0)
    if vehicleId and vehicleId > 0 then
        TriggerServerEvent('driftzone_garage:server:spawn', vehicleId, tonumber(data.garageId or currentGarageId or 0) or 0)
    end
    cb({ ok = true })
end)

RegisterNUICallback('despawn', function(data, cb)
    local vehicleId = tonumber(data.id or data.vehicleId or 0)
    if vehicleId and vehicleId > 0 then TriggerServerEvent('driftzone_garage:server:despawn', vehicleId) end
    cb({ ok = true })
end)

RegisterCommand('garage', function() if canOpenGarage() then TriggerServerEvent('driftzone_garage:server:open') end end, false)
RegisterCommand('garaj', function() if canOpenGarage() then TriggerServerEvent('driftzone_garage:server:open') end end, false)
RegisterCommand('park', function() TriggerEvent('driftzone_garage:client:parkCurrent') end, false)

RegisterCommand('addgarage', function()
    TriggerServerEvent('driftzone_garage:server:adminOpen', 'add')
end, false)

RegisterCommand('editgarages', function()
    TriggerServerEvent('driftzone_garage:server:adminOpen', 'edit')
end, false)

RegisterCommand('resetgarages', function()
    TriggerServerEvent('driftzone_garage:server:resetGarages')
end, false)

-- Garajul se deschide doar daca esti in radiusul unui garaj DB.

RegisterNetEvent('driftzone_garage:client:openFromInteraction', function()
    if not canOpenGarage() then return end
    TriggerServerEvent('driftzone_garage:server:open')
end)

RegisterNetEvent('driftzone_garage:client:setBlocked', function(state, reason)
    garageBlocked = state == true
    garageBlockedReason = tostring(reason or 'Garaj indisponibil.')

    if garageBlocked then
        TriggerServerEvent('driftzone_garage:server:setBlocked', true, garageBlockedReason)
        if garageOpened then
            sendNui({ action = 'close' })
            setGarageFocus(false)
        end
        pendingOpenPayload = nil
    else
        TriggerServerEvent('driftzone_garage:server:setBlocked', false, garageBlockedReason)
    end
end)

RegisterNetEvent('driftzone_garage:client:block', function(reason)
    TriggerEvent('driftzone_garage:client:setBlocked', true, reason or 'Garaj indisponibil.')
end)

RegisterNetEvent('driftzone_garage:client:unblock', function()
    TriggerEvent('driftzone_garage:client:setBlocked', false)
end)

exports('SetBlocked', function(state, reason)
    TriggerEvent('driftzone_garage:client:setBlocked', state == true, reason or 'Garaj indisponibil.')
end)

exports('Block', function(reason)
    TriggerEvent('driftzone_garage:client:setBlocked', true, reason or 'Garaj indisponibil.')
end)

exports('Unblock', function()
    TriggerEvent('driftzone_garage:client:setBlocked', false)
end)

exports('IsBlocked', function()
    return isGarageBlocked()
end)


-- Interactiuni hardcodate scoase. Garajele sunt incarcate din tabela `garages`.

CreateThread(function()
    while true do
        if garageOpened then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                sendNui({ action = 'close' })
                setGarageFocus(false)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        -- Cand meniul este deschis, nu scanam agresiv toate vehiculele din lume.
        -- UI-ul ramane fluid, iar blip/protectie se actualizeaza imediat dupa inchidere.
        if garageOpened then
            Wait(1500)
        else
            local localUid = getLocalUid()
            if localUid then
                local valid = {}
                for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(vehicle) then
                    local state = Entity(vehicle).state
                    if state.dz_garage_vehicle == true and tonumber(state.dz_garage_owner_uid or 0) == tonumber(localUid) then
                        valid[vehicle] = true
                        -- Fara godmode / protection loop pe masini spawnate.
                        if isPlayerInsideVehicle(vehicle) then removeBlip(vehicle) else createBlip(vehicle, tostring(state.dz_garage_name or 'Vehiculul tau'), state.dz_garage_is_vip == true) end
                    end
                end
            end
            for entity, _ in pairs(ownedVehicleBlips) do if not DoesEntityExist(entity) or not valid[entity] then removeBlip(entity) end end
            else
                for entity, _ in pairs(ownedVehicleBlips) do removeBlip(entity) end
            end
            Wait(2200)
        end
    end
end)

-- Protection loop scos: fara godmode pe masini spawnate.


RegisterNetEvent('driftzone_garage:client:syncGarages', function(garages)
    cachedGarages = type(garages) == 'table' and garages or {}
    sendNui({ action = 'garagesData', garages = cachedGarages })
end)

RegisterNetEvent('driftzone_garage:client:openAdmin', function(payload)
    payload = type(payload) == 'table' and payload or {}
    cachedGarages = type(payload.garages) == 'table' and payload.garages or cachedGarages
    sendNui({ action = 'admin', mode = payload.mode or 'edit', garages = cachedGarages })
    setGarageFocus(true)
end)

RegisterNUICallback('adminSaveGarage', function(data, cb)
    TriggerServerEvent('driftzone_garage:server:adminSaveGarage', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteGarage', function(data, cb)
    TriggerServerEvent('driftzone_garage:server:adminDeleteGarage', tonumber(data and data.id or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('adminReloadGarages', function(_, cb)
    TriggerServerEvent('driftzone_garage:server:resetGarages')
    cb({ ok = true })
end)

RegisterNUICallback('getPlayerPosition', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({
        ok = true,
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        h = GetEntityHeading(ped) + 0.0
    })
end)

local function drawText3D(x, y, z, text, scale)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(scale or 0.34, scale or 0.34)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(4, 199, 247, 255)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(tostring(text or 'Garage'))
    DrawText(sx, sy)
end

local function drawGarageSign(garage, playerCoords)
    if type(garage) ~= 'table' then return false end

    local coords = garage.coords or {}
    local gx, gy, gz = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not gx or not gy or not gz then return false end

    local dist = #(playerCoords - vector3(gx, gy, gz))
    local signDistance = tonumber((Config.Draw and Config.Draw.signDistance) or 45.0) or 45.0

    if dist > signDistance then return false end

    local scale = (Config.Draw and Config.Draw.markerScale) or vector3(0.82, 0.82, 0.82)

    -- Doar simbolul de garaj, fara nume/text 3D.
    DrawMarker(
        (Config.Draw and Config.Draw.markerType) or 36,
        gx, gy, gz + 1.05,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale.x or 0.82, scale.y or 0.82, scale.z or 0.82,
        4, 199, 247, 230,
        false, true, 2, false, nil, nil, false
    )

    if garage.visible_radius == true then
        local radius = tonumber(garage.radius or 4.0) or 4.0
        DrawMarker(
            (Config.Draw and Config.Draw.radiusMarkerType) or 1,
            gx, gy, gz - 1.02,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            radius * 2.0, radius * 2.0, 0.28,
            4, 199, 247, (Config.Draw and Config.Draw.radiusAlpha) or 58,
            false, false, 2, false, nil, nil, false
        )
    end

    return true
end

CreateThread(function()
    Wait(1800)
    TriggerServerEvent('driftzone_garage:server:requestGarages')
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local waitTime = 900

        if ped and ped ~= 0 and #cachedGarages > 0 then
            local coords = GetEntityCoords(ped)

            for _, garage in ipairs(cachedGarages) do
                local drawn = drawGarageSign(garage, coords)
                local g = garage.coords or {}
                local gx, gy, gz = tonumber(g.x), tonumber(g.y), tonumber(g.z)

                if gx and gy and gz then
                    local radius = tonumber(garage.radius or 4.0) or 4.0
                    local dist = #(coords - vector3(gx, gy, gz))

                    -- Daca markerul/radiusul e vizibil, desenam in fiecare frame ca sa nu flickereze.
                    if drawn or dist <= math.max(radius, 4.0) then
                        waitTime = 0
                    end

                    if dist <= math.max(radius, 4.0) then
                        if IsControlJustPressed(0, 38) then -- E
                            if canOpenGarage() then
                                TriggerServerEvent('driftzone_garage:server:open')
                            end
                            Wait(350)
                        end
                    end
                end
            end
        end

        Wait(waitTime)
    end
end)


AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for entity, _ in pairs(ownedVehicleBlips) do removeBlip(entity) end
    SetNuiFocus(false, false)
end)
