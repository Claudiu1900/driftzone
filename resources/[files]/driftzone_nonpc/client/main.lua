local enabled = Config.EnabledByDefault ~= false
local started = false
local lastVehicleGeneratorState = nil

local function safeCall(fn)
    return pcall(fn)
end

local function getPed()
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        return ped
    end
    return 0
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

    safeCall(function()
        SetDistantCarsEnabled(false)
    end)
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

local function clearExistingOnce()
    if Config.ClearExistingOnStart ~= true then return end

    local ped = getPed()
    if ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local radius = tonumber(Config.ClearExistingRadius or 450.0) or 450.0

    ClearAreaOfPeds(coords.x, coords.y, coords.z, radius, 1)
    ClearAreaOfVehicles(coords.x, coords.y, coords.z, radius, false, false, false, false, false)
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

        Wait(tonumber(Config.GeneratorLoopMs or 15000) or 15000)
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

    print('[DRIFTZONE_NONPC] Loaded. Ambient NPCs/cops/traffic disabled without delete loops.')
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

-- Aliases pentru resource-ul vechi scris driftzone_nonopc.
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
