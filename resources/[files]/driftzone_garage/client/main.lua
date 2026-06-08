local garageOpened = false
local nuiReady = false
local pendingOpenPayload = nil
local ownedVehicleBlips = {}
local protectedVehicles = {}
local garageBlocked = false
local garageBlockedReason = 'Garaj indisponibil.'

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

local function openGarageNui(vehicles, hasVip)
    if not canOpenGarage() then return end
    local payload = { action = 'open', vehicles = vehicles or {}, hasVip = hasVip == true }
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
    if not DoesEntityExist(entity) then return end
    requestControl(entity, 750)
    SetEntityInvincible(entity, true)
    SetEntityCanBeDamaged(entity, false)
    SetVehicleCanBreak(entity, false)
    SetVehicleEngineCanDegrade(entity, false)
    SetVehicleStrong(entity, true)
    SetVehicleTyresCanBurst(entity, false)
    SetVehicleWheelsCanBreak(entity, false)
    SetVehicleHasBeenOwnedByPlayer(entity, true)
    SetVehicleEngineHealth(entity, 1000.0)
    SetVehicleBodyHealth(entity, 1000.0)
    SetVehiclePetrolTankHealth(entity, 1000.0)
    SetVehicleDirtLevel(entity, 0.0)
    SetVehicleEngineOn(entity, true, true, false)
    protectedVehicles[entity] = true
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
    SetVehicleEngineOn(entity, true, true, false)
end

local function softMaintain(entity)
    if not DoesEntityExist(entity) then return end
    SetEntityInvincible(entity, true)
    SetEntityCanBeDamaged(entity, false)
    SetVehicleCanBreak(entity, false)
    SetVehicleEngineCanDegrade(entity, false)
    SetVehicleStrong(entity, true)
    SetVehicleTyresCanBurst(entity, false)
    SetVehicleWheelsCanBreak(entity, false)
    if GetVehicleEngineHealth(entity) < 950.0 then SetVehicleEngineHealth(entity, 1000.0) end
    if GetVehicleBodyHealth(entity) < 950.0 then SetVehicleBodyHealth(entity, 1000.0) end
    if GetVehiclePetrolTankHealth(entity) < 950.0 then SetVehiclePetrolTankHealth(entity, 1000.0) end
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

local function forceGarageTuningByNetId(netId, data)
    data = data or {}

    local entity = getVehicleFromNetId(netId)

    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local tuningRaw = data.tuning or Entity(entity).state.dz_garage_tuning or Entity(entity).state.vehicleTunning or '{}'

    -- Reaplica direct + trimite si catre driftzone_tunning, ca ambele sisteme sa fie sincronizate.
    applyForcedGarageTuning(entity, tuningRaw)
    TriggerEvent('client:tunning:applyVehicle', netId, tostring(tuningRaw))
    TriggerEvent('driftzone_tunning:client:applyVehicle', netId, tostring(tuningRaw))

    if data.plate then
        SetVehicleNumberPlateText(entity, tostring(data.plate):sub(1, 8))
    end

    return true
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

    repairOnce(entity)
    setVehicleProtection(entity)

    -- Prima aplicare se face inainte de a pune playerul in masina.
    forceGarageTuningByNetId(netId, data)

    SetPedIntoVehicle(PlayerPedId(), entity, -1)

    -- Aplicari repetate pentru bug-ul unde uneori masina apare fara tuning din cauza streaming/control.
    local delays = { 150, 450, 900, 1600, 2800 }

    for i = 1, #delays do
        Wait(delays[i])
        if not DoesEntityExist(entity) then break end
        setVehicleProtection(entity)
        forceGarageTuningByNetId(netId, data)
    end

    TriggerServerEvent('driftzone_garage:server:spawnPrepared', tonumber(data.id or 0))
end

RegisterNetEvent('driftzone_garage:client:open', function(vehicles, hasVip)
    if not canOpenGarage() then return end
    openGarageNui(vehicles or {}, hasVip == true)
end)

RegisterNetEvent('driftzone_garage:client:update', function(vehicles, hasVip)
    sendNui({ action = 'update', vehicles = vehicles or {}, hasVip = hasVip == true })
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
    if vehicleId and vehicleId > 0 then TriggerServerEvent('driftzone_garage:server:spawn', vehicleId) end
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

-- Fara RegisterKeyMapping pe M. Garajul se deschide doar din comanda/interactiune.

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


CreateThread(function()
    Wait(1500)
    pcall(function()
        exports.driftzone_interactions:AddInteraction({
            id = 'driftzone_garage_main', coords = vector3(215.8, -810.2, 30.7), range = 3.0,
            key = 'E', text = 'Apasa tasta E pentru a deschide garajul', subText = 'DriftZone Garage', marker = true,
            event = 'driftzone_garage:client:openFromInteraction'
        })
    end)
end)

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
                        if state.dz_garage_godmode == true then protectedVehicles[vehicle] = true softMaintain(vehicle) end
                        if isPlayerInsideVehicle(vehicle) then removeBlip(vehicle) else createBlip(vehicle, tostring(state.dz_garage_name or 'Vehiculul tau'), state.dz_garage_is_vip == true) end
                    end
                end
            end
            for entity, _ in pairs(ownedVehicleBlips) do if not DoesEntityExist(entity) or not valid[entity] then removeBlip(entity) end end
            else
                for entity, _ in pairs(ownedVehicleBlips) do removeBlip(entity) end
            end
            Wait(1250)
        end
    end
end)

CreateThread(function()
    while true do
        for entity, _ in pairs(protectedVehicles) do
            if DoesEntityExist(entity) then softMaintain(entity) else protectedVehicles[entity] = nil end
        end
        Wait(garageOpened and 3500 or 2200)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for entity, _ in pairs(ownedVehicleBlips) do removeBlip(entity) end
    SetNuiFocus(false, false)
end)
