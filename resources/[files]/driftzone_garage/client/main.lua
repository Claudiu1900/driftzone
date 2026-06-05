local garageOpened = false
local nuiReady = false
local pendingOpenPayload = nil
local ownedVehicleBlips = {}
local protectedVehicles = {}

local function notify(type, message, duration)
    TriggerEvent('client:notify', type or 'info', duration or 5000, tostring(message or ''))
end

local function sendNui(data)
    if not nuiReady then
        if data.action == 'open' then pendingOpenPayload = data end
        return false
    end
    SendNUIMessage(data)
    return true
end

local function setGarageFocus(state)
    garageOpened = state == true
    SetNuiFocus(garageOpened, garageOpened)
    SetNuiFocusKeepInput(false)
    if garageOpened then TriggerEvent('driftzone_hud:visible', false) else TriggerEvent('driftzone_hud:visible', true) end
end

local function openGarageNui(vehicles, hasVip)
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
    SetPedIntoVehicle(PlayerPedId(), entity, -1)
    Wait(350)
    setVehicleProtection(entity)
    TriggerEvent('client:tunning:applyVehicle', netId, tostring(data.tuning or '{}'))
    TriggerEvent('driftzone_tunning:client:applyVehicle', netId, tostring(data.tuning or '{}'))
    TriggerServerEvent('driftzone_garage:server:spawnPrepared', tonumber(data.id or 0))
end

RegisterNetEvent('driftzone_garage:client:open', function(vehicles, hasVip)
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

RegisterNetEvent('driftzone_garage:client:parkCurrent', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then notify('warning', 'Nu esti intr-o masina.') return end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not isOwnedGarageVehicle(vehicle) then notify('warning', 'Aceasta masina nu iti apartine.') return end
    TriggerServerEvent('driftzone_garage:server:parkCurrent', VehToNet(vehicle))
end)

RegisterNetEvent('driftzone_garage:client:openCommand', function()
    TriggerServerEvent('driftzone_garage:server:open')
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if pendingOpenPayload then
        SendNUIMessage(pendingOpenPayload)
        pendingOpenPayload = nil
        setGarageFocus(true)
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

RegisterCommand('garage', function() TriggerServerEvent('driftzone_garage:server:open') end, false)
RegisterCommand('garaj', function() TriggerServerEvent('driftzone_garage:server:open') end, false)
RegisterCommand('park', function() TriggerEvent('driftzone_garage:client:parkCurrent') end, false)

-- Fara RegisterKeyMapping pe M. Garajul se deschide doar din comanda/interactiune.

RegisterNetEvent('driftzone_garage:client:openFromInteraction', function()
    TriggerServerEvent('driftzone_garage:server:open')
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
