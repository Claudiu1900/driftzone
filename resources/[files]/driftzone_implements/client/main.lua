local lastVehicle = 0

local function cfg()
    return Config.Client or {}
end

local function safeCall(fn)
    local ok = pcall(fn)
    return ok
end

local function getPed()
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        return ped
    end
    return 0
end

local function disableControls(list)
    if type(list) ~= 'table' then return end

    for i = 1, #list do
        local control = tonumber(list[i])
        if control then
            DisableControlAction(0, control, true)
            DisableControlAction(1, control, true)
            DisableControlAction(2, control, true)
        end
    end
end

local function hideDefaultHud()
    if cfg().HideDefaultHud ~= true then return end

    DisplayRadar(true)

    safeCall(function()
        DisplayAreaName(false)
    end)

    for i = 1, #(Config.HiddenHudComponents or {}) do
        HideHudComponentThisFrame(Config.HiddenHudComponents[i])
    end
end

local function disableWeaponWheel()
    if cfg().DisableWeaponWheel ~= true then return end

    disableControls(Config.DisabledWeaponControls)

    safeCall(function()
        HideWeaponWheelThisFrame()
    end)
end

local function disableVehicleMusicWheel(ped)
    if cfg().DisableVehicleMusicWheel ~= true then return end
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then return end

    disableControls(Config.DisabledVehicleMusicControls)
    HideHudComponentThisFrame(16)
end

local function disableVehicleDriveBy(ped)
    if cfg().DisableVehicleDriveBy ~= true then return end

    SetPlayerCanDoDriveBy(PlayerId(), false)

    if ped ~= 0 and IsPedInAnyVehicle(ped, false) then
        disableControls(Config.DisabledVehicleShootingControls)
        DisablePlayerFiring(PlayerId(), true)
    end
end

local function forceRadioOff(ped)
    if cfg().ForceVehicleRadioOff ~= true then return end
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then
        lastVehicle = 0
        return
    end

    safeCall(function()
        SetUserRadioControlEnabled(false)
    end)

    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        if veh ~= lastVehicle then
            lastVehicle = veh
            SetVehRadioStation(veh, 'OFF')
            SetVehicleRadioEnabled(veh, false)
        else
            SetVehRadioStation(veh, 'OFF')
        end
    end
end

local function preventDriverPullout()
    if cfg().DisableCarjackDriverPullout ~= true then return end

    local ped = getPed()
    if ped == 0 then return end

    safeCall(function()
        SetPedCanBeDraggedOut(ped, false)
    end)

    local myCoords = GetEntityCoords(ped)
    local range = tonumber(cfg().AntiCarjackRange or 10.0) or 10.0
    local pool = GetGamePool('CVehicle')

    for i = 1, #pool do
        local veh = pool[i]
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local coords = GetEntityCoords(veh)
            if #(myCoords - coords) <= range then
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver and driver ~= 0 and DoesEntityExist(driver) then
                    safeCall(function()
                        SetPedCanBeDraggedOut(driver, false)
                    end)
                end
            end
        end
    end
end

local function applyFrameControls()
    local ped = getPed()

    hideDefaultHud()
    disableWeaponWheel()
    disableVehicleMusicWheel(ped)
    disableVehicleDriveBy(ped)
end

CreateThread(function()
    while true do
        applyFrameControls()
        Wait(tonumber(cfg().MainLoopWaitMs or 0) or 0)
    end
end)

CreateThread(function()
    while true do
        local ped = getPed()

        forceRadioOff(ped)
        preventDriverPullout()

        Wait(tonumber(cfg().VehicleCheckIntervalMs or 650) or 650)
    end
end)

AddEventHandler('playerSpawned', function()
    TriggerServerEvent('driftzone_implements:server:resetAdutyOnJoin')

    SetTimeout(700, function()
        local ped = getPed()
        forceRadioOff(ped)
        preventDriverPullout()
        SetPlayerCanDoDriveBy(PlayerId(), false)
    end)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    TriggerServerEvent('driftzone_implements:server:resetAdutyOnJoin')
    SetPlayerCanDoDriveBy(PlayerId(), false)
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    safeCall(function()
        SetUserRadioControlEnabled(true)
    end)

    safeCall(function()
        SetPlayerCanDoDriveBy(PlayerId(), true)
    end)
end)
