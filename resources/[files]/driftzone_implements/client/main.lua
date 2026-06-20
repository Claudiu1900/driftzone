local lastVehicle = 0
local crouched = false

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


local function loadAnimSet(animSet)
    animSet = tostring(animSet or '')
    if animSet == '' then return false end

    if HasAnimSetLoaded(animSet) then return true end

    RequestAnimSet(animSet)
    local timeout = GetGameTimer() + 1500

    while not HasAnimSetLoaded(animSet) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasAnimSetLoaded(animSet)
end

local function setCrouch(enabled)
    local ped = getPed()
    if ped == 0 then return end

    if enabled == true then
        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then
            return
        end

        local moveClipset = tostring(cfg().CrouchMoveClipset or 'move_ped_crouched')
        local strafeClipset = tostring(cfg().CrouchStrafeClipset or 'move_ped_crouched_strafing')

        if loadAnimSet(moveClipset) then
            SetPedMovementClipset(ped, moveClipset, 0.25)
        end

        safeCall(function()
            SetPedStrafeClipset(ped, strafeClipset)
        end)

        crouched = true
    else
        safeCall(function()
            ResetPedMovementClipset(ped, 0.25)
        end)

        safeCall(function()
            ResetPedStrafeClipset(ped)
        end)

        crouched = false
    end
end

local function disableIdleCamera()
    if cfg().DisableIdleCamera ~= true then return end

    safeCall(function()
        InvalidateIdleCam()
    end)

    safeCall(function()
        InvalidateVehicleIdleCam()
    end)

    safeCall(function()
        if IsCinematicCamRendering() then
            SetCinematicModeActive(false)
        end
    end)
end

local function handleStealthAndCrouch(ped)
    if cfg().DisableStealthMode ~= true then return end

    disableControls(Config.DisabledStealthControls)

    if ped ~= 0 then
        safeCall(function()
            SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
        end)
    end

    if cfg().EnableCrouchReplacement ~= true then
        if crouched then setCrouch(false) end
        return
    end

    local control = tonumber(cfg().CrouchControl or 36) or 36

    if ped == 0 or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then
        if crouched then setCrouch(false) end
        return
    end

    if IsDisabledControlJustPressed(0, control) then
        setCrouch(not crouched)
    end
end

local function gtaHealthFromStatsHealth(value)
    local health = tonumber(value)
    if not health then return nil end

    if health <= 0 then return 0 end

    health = math.floor(health)

    if health <= 100 then
        return math.max(101, math.min(200, health + 100))
    end

    return math.max(101, math.min(200, health))
end

local function applyStatsPayload(payload)
    if type(payload) ~= 'table' then return end

    local health = gtaHealthFromStatsHealth(payload.health)
    local armour = tonumber(payload.armour)

    CreateThread(function()
        local delay = tonumber((Config.PlayerStats or {}).ClientApplyDelayMs or 1200) or 1200
        Wait(delay)

        for _ = 1, 20 do
            local ped = getPed()

            if ped ~= 0 and not IsEntityDead(ped) then
                if health then
                    safeCall(function()
                        SetEntityMaxHealth(ped, 200)
                    end)

                    SetEntityHealth(ped, health)
                end

                if armour then
                    armour = math.max(0, math.min(100, math.floor(armour)))

                    safeCall(function()
                        SetPlayerMaxArmour(PlayerId(), 100)
                    end)

                    SetPedArmour(ped, armour)
                end

                return
            end

            Wait(500)
        end
    end)
end

RegisterNetEvent('driftzone_implements:client:applyStats', function(payload)
    applyStatsPayload(payload)
end)


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
    disableIdleCamera()
    handleStealthAndCrouch(ped)
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
    TriggerServerEvent('driftzone_implements:server:loadStatsOnJoin')

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
    TriggerServerEvent('driftzone_implements:server:loadStatsOnJoin')
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

    if crouched then
        setCrouch(false)
    end
end)
