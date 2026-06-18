local enabled = Config.EnabledByDefault ~= false
local started = false
local lastVehicleGeneratorState = nil

local function dbg(msg)
    if Config.Debug then
        print('[DRIFTZONE_NONOPC] ' .. tostring(msg))
    end
end

local function safeCall(fn)
    local ok, result = pcall(fn)
    return ok, result
end

local function getPed()
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        return ped
    end
    return 0
end

local function distanceBetween(a, b)
    if not a or not b then return 999999.0 end
    return #(a - b)
end

local function applyDensityFrame()
    local d = Config.Disable or {}

    if d.Peds ~= false then
        SetPedDensityMultiplierThisFrame(0.0)
    end

    if d.ScenarioPeds ~= false then
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
    end

    if d.Vehicles ~= false then
        SetVehicleDensityMultiplierThisFrame(0.0)
    end

    if d.RandomVehicles ~= false then
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
    end

    if d.ParkedVehicles ~= false then
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
    end

    if d.GarbageTrucks ~= false then
        SetGarbageTrucks(false)
    end

    if d.RandomBoats ~= false then
        SetRandomBoats(false)
    end

    if d.RandomCops ~= false then
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
    end
end

local function applyWantedAndDispatch()
    local d = Config.Disable or {}
    local player = PlayerId()

    if d.WantedLevel ~= false then
        SetMaxWantedLevel(0)
        SetPoliceIgnorePlayer(player, true)
        SetDispatchCopsForPlayer(player, false)
        ClearPlayerWantedLevel(player)
        SetPlayerWantedLevel(player, 0, false)
        SetPlayerWantedLevelNow(player, false)
    end

    if d.Dispatch ~= false then
        for _, service in ipairs(Config.DispatchServices or {}) do
            EnableDispatchService(tonumber(service) or service, false)
        end
    end

    if d.DistantCars ~= false then
        safeCall(function()
            SetDistantCarsEnabled(false)
        end)
    end
end

local function setScenarioTypes(state)
    if (Config.Disable or {}).EmergencyScenarios == false then return end

    for _, name in ipairs(Config.DisabledScenarioTypes or {}) do
        safeCall(function()
            SetScenarioTypeEnabled(name, state == true)
        end)
    end
end

local function applyVehicleGenerators()
    if (Config.Disable or {}).VehicleGenerators == false then return end
    if lastVehicleGeneratorState == false then return end

    lastVehicleGeneratorState = false

    safeCall(function()
        SetAllVehicleGeneratorsActive(false)
    end)
end

local function restoreVehicleGenerators()
    if lastVehicleGeneratorState == true then return end
    lastVehicleGeneratorState = true

    safeCall(function()
        SetAllVehicleGeneratorsActive(true)
    end)
end

local function requestControl(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not NetworkGetEntityIsNetworked(entity) then return true end
    if NetworkHasControlOfEntity(entity) then return true end

    local timeout = GetGameTimer() + (timeoutMs or 350)

    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end

    return NetworkHasControlOfEntity(entity)
end

local function hasStateBagVehicleData(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local state = Entity(vehicle).state
    if not state then return false end

    for _, key in ipairs(Config.SafeVehicleStateKeys or {}) do
        local value = state[key]
        if value ~= nil and tostring(value) ~= '' and tostring(value) ~= '0' and tostring(value) ~= 'false' then
            return true
        end
    end

    return false
end

local function vehicleHasPlayer(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    seats = tonumber(seats or 0) or 0

    for seat = -1, seats - 2 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 and DoesEntityExist(ped) and IsPedAPlayer(ped) then
            return true
        end
    end

    return false
end

local function shouldDeletePed(ped, playerCoords)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPedAPlayer(ped) then return false end
    if ped == PlayerPedId() then return false end

    local coords = GetEntityCoords(ped)
    local radius = tonumber((Config.Cleanup or {}).Radius or 420.0) or 420.0

    if distanceBetween(playerCoords, coords) > radius then return false end

    return true
end

local function shouldDeleteVehicle(vehicle, playerCoords)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if not IsEntityAVehicle(vehicle) then return false end

    local cleanup = Config.Cleanup or {}
    local coords = GetEntityCoords(vehicle)
    local radius = tonumber(cleanup.Radius or 420.0) or 420.0

    if distanceBetween(playerCoords, coords) > radius then return false end

    if cleanup.SkipVehiclesWithPlayers ~= false and vehicleHasPlayer(vehicle) then
        return false
    end

    if cleanup.SkipStateBagVehicles ~= false and hasStateBagVehicleData(vehicle) then
        return false
    end

    local popType = GetEntityPopulationType(vehicle)

    -- 7 = mission/script entity. De obicei masini spawnate de resurse.
    if cleanup.SkipMissionVehicles ~= false and tonumber(popType) == 7 then
        return false
    end

    local protection = tonumber(cleanup.VehicleNearPlayerProtection or 0.0) or 0.0
    if protection > 0.0 and distanceBetween(playerCoords, coords) <= protection then
        return false
    end

    return true
end

local function deleteEntitySafe(entity, isVehicle)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    requestControl(entity, 400)

    if not DoesEntityExist(entity) then return true end

    safeCall(function()
        SetEntityAsMissionEntity(entity, true, true)
    end)

    if isVehicle then
        safeCall(function()
            SetVehicleHasBeenOwnedByPlayer(entity, false)
        end)

        safeCall(function()
            SetVehicleAsNoLongerNeeded(entity)
        end)

        DeleteVehicle(entity)
    end

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    return not DoesEntityExist(entity)
end

local function cleanupAmbientEntities()
    local cleanup = Config.Cleanup or {}
    if cleanup.Enabled ~= true then return end

    local ped = getPed()
    if ped == 0 then return end

    local playerCoords = GetEntityCoords(ped)
    local deletedPeds = 0
    local deletedVehicles = 0

    if cleanup.DeletePeds ~= false then
        local maxPeds = tonumber(cleanup.MaxPedsPerTick or 45) or 45
        local peds = GetGamePool('CPed') or {}

        for i = 1, #peds do
            if deletedPeds >= maxPeds then break end

            local targetPed = peds[i]
            if shouldDeletePed(targetPed, playerCoords) then
                if deleteEntitySafe(targetPed, false) then
                    deletedPeds = deletedPeds + 1
                end
            end
        end
    end

    if cleanup.DeleteVehicles ~= false then
        local maxVehicles = tonumber(cleanup.MaxVehiclesPerTick or 35) or 35
        local vehicles = GetGamePool('CVehicle') or {}

        for i = 1, #vehicles do
            if deletedVehicles >= maxVehicles then break end

            local vehicle = vehicles[i]
            if shouldDeleteVehicle(vehicle, playerCoords) then
                if deleteEntitySafe(vehicle, true) then
                    deletedVehicles = deletedVehicles + 1
                end
            end
        end
    end

    if deletedPeds > 0 or deletedVehicles > 0 then
        dbg(('cleanup deleted peds=%s vehicles=%s'):format(deletedPeds, deletedVehicles))
    end
end

local function clearExistingOnce()
    if Config.ClearExistingOnStart ~= true then return end

    local ped = getPed()
    if ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local radius = tonumber(Config.ClearExistingRadius or 450.0) or 450.0

    ClearAreaOfPeds(coords.x, coords.y, coords.z, radius, 1)
    -- Nu folosim ClearAreaOfVehicles aici ca poate sterge masini custom/owned.
    cleanupAmbientEntities()
end

local function enableNoNpc()
    enabled = true
    applyWantedAndDispatch()
    setScenarioTypes(false)
    applyVehicleGenerators()
end

local function disableNoNpc()
    enabled = false

    local player = PlayerId()
    SetMaxWantedLevel(5)
    SetPoliceIgnorePlayer(player, false)
    SetDispatchCopsForPlayer(player, true)

    for _, service in ipairs(Config.DispatchServices or {}) do
        EnableDispatchService(tonumber(service) or service, true)
    end

    setScenarioTypes(true)
    restoreVehicleGenerators()

    safeCall(function()
        SetDistantCarsEnabled(true)
    end)
end

CreateThread(function()
    while true do
        if enabled then
            applyDensityFrame()
            Wait(tonumber(Config.FrameWaitMs or 0) or 0)
        else
            Wait(750)
        end
    end
end)

CreateThread(function()
    while true do
        if enabled then
            applyWantedAndDispatch()
        end

        Wait(tonumber(Config.ServiceLoopMs or 1000) or 1000)
    end
end)

CreateThread(function()
    while true do
        if enabled then
            setScenarioTypes(false)
            applyVehicleGenerators()
        end

        Wait(tonumber(Config.GeneratorLoopMs or 10000) or 10000)
    end
end)

CreateThread(function()
    while true do
        if enabled and Config.Cleanup and Config.Cleanup.Enabled == true then
            cleanupAmbientEntities()
            Wait(tonumber(Config.Cleanup.IntervalMs or 1200) or 1200)
        else
            Wait(1500)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if started then return end
    started = true

    Wait(500)

    if enabled then
        enableNoNpc()
        clearExistingOnce()
    end

    print('[DRIFTZONE_NONOPC] Loaded. Ambient NPCs/traffic disabled + safe cleanup enabled.')
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    disableNoNpc()
end)

exports('EnableNoNpc', function()
    enableNoNpc()
end)

exports('DisableNoNpc', function()
    disableNoNpc()
end)

exports('IsNoNpcEnabled', function()
    return enabled
end)

RegisterNetEvent('driftzone_nonpc:client:enable', function()
    enableNoNpc()
end)

RegisterNetEvent('driftzone_nonpc:client:disable', function()
    disableNoNpc()
end)

RegisterNetEvent('driftzone_nonpc:client:toggle', function()
    if enabled then
        disableNoNpc()
    else
        enableNoNpc()
    end
end)

-- Aliases pentru resource-ul scris driftzone_nonopc.
RegisterNetEvent('driftzone_nonopc:client:enable', function()
    enableNoNpc()
end)

RegisterNetEvent('driftzone_nonopc:client:disable', function()
    disableNoNpc()
end)

RegisterNetEvent('driftzone_nonopc:client:toggle', function()
    if enabled then
        disableNoNpc()
    else
        enableNoNpc()
    end
end)
