local disableNpc = true

local function applyNoNpcFrame()
    SetPedDensityMultiplierThisFrame(0.0)
    SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)

    SetVehicleDensityMultiplierThisFrame(0.0)
    SetRandomVehicleDensityMultiplierThisFrame(0.0)
    SetParkedVehicleDensityMultiplierThisFrame(0.0)

    SetGarbageTrucks(false)
    SetRandomBoats(false)
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
end

CreateThread(function()
    while true do
        if disableNpc then
            applyNoNpcFrame()
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if disableNpc then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            ClearAreaOfPeds(coords.x, coords.y, coords.z, 650.0, 1)
            ClearAreaOfVehicles(coords.x, coords.y, coords.z, 650.0, false, false, false, false, false)
        end

        Wait(3500)
    end
end)

CreateThread(function()
    for i = 1, 15 do
        EnableDispatchService(i, false)
    end

    while true do
        if disableNpc then
            for i = 1, 15 do
                EnableDispatchService(i, false)
            end
        end

        Wait(10000)
    end
end)

exports('EnableNoNpc', function()
    disableNpc = true
end)

exports('DisableNoNpc', function()
    disableNpc = false
end)

exports('IsNoNpcEnabled', function()
    return disableNpc
end)

RegisterNetEvent('driftzone_nonopc:client:enable', function()
    disableNpc = true
end)

RegisterNetEvent('driftzone_nonopc:client:disable', function()
    disableNpc = false
end)

RegisterNetEvent('driftzone_nonopc:client:toggle', function()
    disableNpc = not disableNpc
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_NONOPC] Loaded. Default GTA NPCs disabled.')
end)
