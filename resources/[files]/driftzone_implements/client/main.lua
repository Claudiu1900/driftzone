local lastVehicle = 0
local crouched = false
local lastCrouchToggle = 0

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


local function enablePlayerDamage()
    if cfg().EnablePlayerDamage ~= true then return end

    local player = PlayerId()
    local ped = getPed()

    safeCall(function()
        NetworkSetFriendlyFireOption(true)
    end)

    if ped ~= 0 then
        safeCall(function()
            SetCanAttackFriendly(ped, true, false)
        end)

        safeCall(function()
            SetEntityCanBeDamaged(ped, true)
        end)

        safeCall(function()
            SetPedCanBeTargetted(ped, true)
        end)

        safeCall(function()
            SetPedSuffersCriticalHits(ped, true)
        end)

        -- Doar daca vrei sa fortezi complet off la invincible.
        -- Default false ca sa nu strice admin/godmode din alte scripturi.
        if cfg().ForceDisableInvincible == true then
            safeCall(function()
                SetPlayerInvincible(player, false)
            end)

            safeCall(function()
                SetEntityInvincible(ped, false)
            end)
        end
    end
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

local function toggleCrouch()
    local now = GetGameTimer()
    if now - lastCrouchToggle < 250 then return end
    lastCrouchToggle = now
    setCrouch(not crouched)
end

local function forceStealthOff(ped)
    if ped == 0 then return end

    safeCall(function()
        SetPedStealthMovement(ped, false, 0)
    end)

    safeCall(function()
        SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
    end)

    safeCall(function()
        SetPedUsingActionMode(ped, false, -1, 'DEFAULT_ACTION')
    end)

    -- Uneori jocul schimba movement clipset-ul pe stealth inainte sa il prindem.
    -- Daca nu suntem in crouch-ul nostru, resetam clipset-ul.
    if not crouched then
        safeCall(function()
            ResetPedMovementClipset(ped, 0.15)
        end)

        safeCall(function()
            ResetPedStrafeClipset(ped)
        end)
    end
end

local function handleStealthAndCrouch(ped)
    if cfg().DisableStealthMode ~= true then return end

    -- Control 36 = INPUT_DUCK / stealth. Il blocam direct, fara disableControls(),
    -- ca functia sa mearga indiferent de ordinea din fisier.
    DisableControlAction(0, 36, true)
    DisableControlAction(1, 36, true)
    DisableControlAction(2, 36, true)

    forceStealthOff(ped)

    if cfg().EnableCrouchReplacement ~= true then
        if crouched then setCrouch(false) end
        return
    end

    if ped == 0 or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then
        if crouched then setCrouch(false) end
        return
    end

    local control = tonumber(cfg().CrouchControl or 36) or 36

    -- Pentru CTRL folosim controlul dezactivat, nu keybind-ul GTA.
    if IsDisabledControlJustPressed(0, control) or IsDisabledControlJustPressed(1, control) or IsDisabledControlJustPressed(2, control) then
        toggleCrouch()
    end

    -- Daca GTA/alt script incearca sa intre in stealth, il scoatem imediat.
    forceStealthOff(ped)

    if crouched then
        local moveClipset = tostring(cfg().CrouchMoveClipset or 'move_ped_crouched')
        local strafeClipset = tostring(cfg().CrouchStrafeClipset or 'move_ped_crouched_strafing')

        if loadAnimSet(moveClipset) then
            SetPedMovementClipset(ped, moveClipset, 0.25)
        end

        safeCall(function()
            SetPedStrafeClipset(ped, strafeClipset)
        end)
    end
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


local function forceCrosshair(ped)
    if cfg().ForceCrosshair ~= true then return end
    if ped == 0 then return end
    if IsPedInAnyVehicle(ped, false) then return end

    local weapon = GetSelectedPedWeapon(ped)
    if not weapon or weapon == 0 or weapon == `WEAPON_UNARMED` then return end

    -- HUD component 14 = reticle/crosshair.
    -- Unele UI-uri il ascund cu HideHudComponentThisFrame(14), deci il fortam inapoi.
    ShowHudComponentThisFrame(14)

    if IsPlayerFreeAiming(PlayerId()) or IsControlPressed(0, 25) or IsPedShooting(ped) then
        ShowHudComponentThisFrame(14)
    end
end


local function hideDefaultHud()
    if cfg().HideDefaultHud ~= true then return end

    DisplayRadar(true)

    safeCall(function()
        DisplayAreaName(false)
    end)

    for i = 1, #(Config.HiddenHudComponents or {}) do
        local component = Config.HiddenHudComponents[i]
        if not (cfg().ForceCrosshair == true and component == 14) then
            HideHudComponentThisFrame(component)
        end
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
    forceCrosshair(ped)
    disableIdleCamera()
    forceStealthOff(ped)
    disableWeaponWheel()
    disableVehicleMusicWheel(ped)
    disableVehicleDriveBy(ped)
end


-- HIGH PRIORITY STEALTH BLOCK
-- Ruleaza separat la 0ms ca CTRL sa nu mai intre deloc in stealth.
CreateThread(function()
    while true do
        local ped = getPed()

        if cfg().DisableStealthMode == true then
            DisableControlAction(0, 36, true)
            DisableControlAction(1, 36, true)
            DisableControlAction(2, 36, true)

            forceStealthOff(ped)

            if cfg().EnableCrouchReplacement == true and ped ~= 0 and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) and not IsPedRagdoll(ped) then
                if IsDisabledControlJustPressed(0, 36) or IsDisabledControlJustPressed(1, 36) or IsDisabledControlJustPressed(2, 36) then
                    toggleCrouch()
                end

                if crouched then
                    local moveClipset = tostring(cfg().CrouchMoveClipset or 'move_ped_crouched')
                    if loadAnimSet(moveClipset) then
                        SetPedMovementClipset(ped, moveClipset, 0.25)
                    end
                end
            elseif crouched then
                setCrouch(false)
            end
        end

        Wait(0)
    end
end)



-- HIGH PRIORITY CROSSHAIR FIX
-- Reticle/crosshair este forțat când ai armă în mână.
CreateThread(function()
    while true do
        local ped = getPed()
        forceCrosshair(ped)
        Wait(0)
    end
end)

-- PLAYER DAMAGE / PVP ENABLE
-- Activeaza damage intre playeri: arme, pumni, melee.
CreateThread(function()
    while true do
        enablePlayerDamage()
        Wait(tonumber(cfg().PlayerDamageLoopWaitMs or 750) or 750)
    end
end)

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
        enablePlayerDamage()
    end)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    TriggerServerEvent('driftzone_implements:server:resetAdutyOnJoin')
SetPlayerCanDoDriveBy(PlayerId(), false)
    enablePlayerDamage()
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


