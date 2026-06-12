local loaded = false

local Config = {}

Config.GodMode = true
Config.NoRagdoll = true
Config.InfiniteStamina = true
Config.HideDefaultHud = true
Config.DisableWeaponWheel = true
Config.DisableVehicleMusicWheel = true
Config.HideHealthArmorUnderMinimap = true
Config.KeepHatOnHead = true

Config.HatCheckInterval = 150
Config.MainCheckInterval = 0
Config.PlayerApplyInterval = 750

-- Weapon wheel + radio slots.
local DisabledWeaponControls = {
    12, 13, 14, 15, 16, 17, 37, 99, 100,
    157, 158, 159, 160, 161, 162, 163, 164, 165
}

-- Meniu muzica/radio in masina.
-- 85 = radio wheel, 81/82 = next/previous radio, 83/84 = next/previous radio track.
local DisabledVehicleMusicControls = {
    81, 82, 83, 84, 85
}

local HiddenHudComponents = {
    1,  -- wanted stars
    2,  -- weapon icon
    3,  -- cash
    4,  -- mp cash
    5,  -- mp message
    6,  -- vehicle name
    7,  -- area name
    8,  -- vehicle class
    9,  -- street name
    10, -- help text
    11, -- floating help text 1
    12, -- floating help text 2
    13, -- cash change
    14, -- reticle
    16, -- radio stations
    17, -- saving
    19, -- weapon wheel
    20, -- weapon wheel stats
    22  -- hud weapons
}

-- Incercam sa ascundem doar barele default de health/armor, fara sa ascundem minimap-ul.
-- Diferite build-uri au comportament usor diferit, de asta le tinem separat.
local HealthArmorHudComponents = {
    3,
    4,
    21,
    22
}

local lastHat = {
    drawable = -1,
    texture = 0,
    hadHat = false,
    updatedAt = 0
}

local lastPed = 0
local lockHat = true
local lastPlayerApply = 0

local function safeCall(fn)
    return pcall(fn)
end


local function resetAdutyServer()
    TriggerServerEvent('driftzone_implements:server:resetAdutyOnJoin')
end


local function getPed()
    local ped = PlayerPedId()

    if ped and ped ~= 0 and DoesEntityExist(ped) then
        return ped
    end

    return 0
end

local function isPedInVehicle(ped)
    return ped ~= 0 and IsPedInAnyVehicle(ped, false)
end

local function hideZoneAndHud()
    if not Config.HideDefaultHud then return end

    DisplayRadar(true)

    safeCall(function()
        DisplayAreaName(false)
    end)

    for i = 1, #HiddenHudComponents do
        local componentId = HiddenHudComponents[i]
        HideHudComponentThisFrame(componentId)
    end

    if Config.HideHealthArmorUnderMinimap then
        for i = 1, #HealthArmorHudComponents do
            HideHudComponentThisFrame(HealthArmorHudComponents[i])
        end
    end
end

local function disableControlsList(list)
    for i = 1, #list do
        local controlId = list[i]

        DisableControlAction(0, controlId, true)
        DisableControlAction(1, controlId, true)
        DisableControlAction(2, controlId, true)
    end
end

local function disableWeaponWheel()
    if not Config.DisableWeaponWheel then return end

    disableControlsList(DisabledWeaponControls)

    safeCall(function()
        HideWeaponWheelThisFrame()
    end)
end

local function disableVehicleMusicWheel(ped)
    if not Config.DisableVehicleMusicWheel then return end
    if not isPedInVehicle(ped) then return end

    disableControlsList(DisabledVehicleMusicControls)

    -- Forteaza radio off si previne roata de radio/muzica cand apesi TAB/Q in masina.
    safeCall(function()
        SetUserRadioControlEnabled(false)
    end)

    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle and vehicle ~= 0 then
        safeCall(function()
            SetVehRadioStation(vehicle, 'OFF')
        end)
    end

    HideHudComponentThisFrame(16)
end

local function applyPlayerFlags(ped)
    if ped == 0 then return end

    if Config.GodMode then
        SetPlayerInvincible(PlayerId(), true)
        SetEntityInvincible(ped, true)
        SetEntityProofs(ped, true, true, true, true, true, true, true, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedSuffersCriticalHits(ped, false)
    end

    if Config.NoRagdoll then
        SetPedCanRagdoll(ped, false)
        SetPedCanRagdollFromPlayerImpact(ped, false)
        SetPedCanBeKnockedOffVehicle(ped, 1)
    end

    if Config.InfiniteStamina then
        RestorePlayerStamina(PlayerId(), 1.0)
        ResetPlayerStamina(PlayerId())
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        SetSwimMultiplierForPlayer(PlayerId(), 1.0)
        SetPlayerHealthRechargeMultiplier(PlayerId(), 1.0)
    end
end

local function applyPlayerFlagsThrottled(ped)
    local now = GetGameTimer()

    if now - lastPlayerApply < Config.PlayerApplyInterval then
        if Config.InfiniteStamina then
            RestorePlayerStamina(PlayerId(), 1.0)
        end

        return
    end

    lastPlayerApply = now
    applyPlayerFlags(ped)
end

local function getHat(ped)
    local drawable = GetPedPropIndex(ped, 0)
    local texture = GetPedPropTextureIndex(ped, 0)

    drawable = tonumber(drawable or -1) or -1
    texture = tonumber(texture or 0) or 0

    return drawable, texture
end

local function cacheCurrentHat(ped)
    local drawable, texture = getHat(ped)

    if drawable and drawable >= 0 then
        lastHat.drawable = drawable
        lastHat.texture = texture or 0
        lastHat.hadHat = true
        lastHat.updatedAt = GetGameTimer()
    end
end

local function applyHat(ped)
    if not lastHat.hadHat then return end
    if lastHat.drawable < 0 then return end

    safeCall(function()
        SetPedPropIndex(ped, 0, lastHat.drawable, lastHat.texture or 0, true)
    end)
end

local function preventHelmetSystems(ped)
    -- Opreste GTA/FiveM din a pune/scoate casti automat pe motoare sau in vehicule.
    SetPedHelmet(ped, false)
    RemovePedHelmet(ped, true)

    -- Native-ul exista pe multe build-uri FiveM. pcall-ul evita orice crash daca lipseste.
    safeCall(function()
        SetPedCanLosePropsOnDamage(ped, false, 0)
    end)
end

local function maintainHat()
    if not Config.KeepHatOnHead or not lockHat then return end

    local ped = getPed()

    if ped == 0 then return end

    if ped ~= lastPed then
        lastPed = ped
        lastHat.drawable = -1
        lastHat.texture = 0
        lastHat.hadHat = false

        SetTimeout(700, function()
            local freshPed = getPed()

            if freshPed ~= 0 then
                cacheCurrentHat(freshPed)
            end
        end)
    end

    preventHelmetSystems(ped)

    local drawable, texture = getHat(ped)

    if drawable >= 0 then
        if drawable ~= lastHat.drawable or texture ~= lastHat.texture then
            lastHat.drawable = drawable
            lastHat.texture = texture or 0
            lastHat.hadHat = true
            lastHat.updatedAt = GetGameTimer()
        end

        return
    end

    -- Daca GTA a scos palaria/casca in vehicul, pe impact sau la animatii, o punem inapoi.
    if lastHat.hadHat and lastHat.drawable >= 0 then
        applyHat(ped)
    end
end

local function applyImplements()
    local ped = getPed()

    hideZoneAndHud()
    disableWeaponWheel()
    disableVehicleMusicWheel(ped)
    applyPlayerFlagsThrottled(ped)
end

RegisterNetEvent('driftzone_implements:client:refreshHat', function()
    local ped = getPed()

    if ped == 0 then return end

    cacheCurrentHat(ped)
end)

RegisterNetEvent('driftzone_implements:client:setHatLock', function(state)
    lockHat = state ~= false

    if lockHat then
        local ped = getPed()

        if ped ~= 0 then
            cacheCurrentHat(ped)
        end
    end
end)

RegisterNetEvent('driftzone_implements:client:setGodMode', function(state)
    Config.GodMode = state == true
end)

RegisterNetEvent('driftzone_implements:client:setHudClean', function(state)
    Config.HideDefaultHud = state == true
end)

RegisterNetEvent('driftzone_implements:client:setWeaponWheelDisabled', function(state)
    Config.DisableWeaponWheel = state == true
end)

RegisterNetEvent('driftzone_implements:client:setVehicleMusicWheelDisabled', function(state)
    Config.DisableVehicleMusicWheel = state == true

    if not Config.DisableVehicleMusicWheel then
        safeCall(function()
            SetUserRadioControlEnabled(true)
        end)
    end
end)

RegisterNetEvent('driftzone_implements:client:setHealthArmorHudHidden', function(state)
    Config.HideHealthArmorUnderMinimap = state == true
end)

exports('RefreshHat', function()
    local ped = getPed()

    if ped ~= 0 then
        cacheCurrentHat(ped)
    end
end)

exports('SetHatLock', function(state)
    lockHat = state ~= false
end)

exports('SetGodMode', function(state)
    Config.GodMode = state == true
end)

exports('SetHudClean', function(state)
    Config.HideDefaultHud = state == true
end)

exports('SetWeaponWheelDisabled', function(state)
    Config.DisableWeaponWheel = state == true
end)

exports('SetVehicleMusicWheelDisabled', function(state)
    Config.DisableVehicleMusicWheel = state == true

    if not Config.DisableVehicleMusicWheel then
        safeCall(function()
            SetUserRadioControlEnabled(true)
        end)
    end
end)

exports('SetHealthArmorHudHidden', function(state)
    Config.HideHealthArmorUnderMinimap = state == true
end)

AddEventHandler('playerSpawned', function()
    loaded = true
    resetAdutyServer()

    SetTimeout(500, function()
        local ped = getPed()

        if ped ~= 0 then
            cacheCurrentHat(ped)
            maintainHat()
            applyPlayerFlags(ped)
        end
    end)

    SetTimeout(1500, function()
        local ped = getPed()

        if ped ~= 0 then
            cacheCurrentHat(ped)
            maintainHat()
            applyPlayerFlags(ped)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    safeCall(function()
        SetUserRadioControlEnabled(true)
    end)
end)

CreateThread(function()
    Wait(1000)
    loaded = true
    resetAdutyServer()

    local ped = getPed()

    if ped ~= 0 then
        cacheCurrentHat(ped)
        maintainHat()
        applyPlayerFlags(ped)
    end

    print('[DRIFTZONE_IMPLEMENTS] Client-side loaded.')
end)

CreateThread(function()
    while true do
        if loaded then
            applyImplements()
            Wait(Config.MainCheckInterval or 0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if loaded and Config.KeepHatOnHead then
            maintainHat()
            Wait(Config.HatCheckInterval or 150)
        else
            Wait(500)
        end
    end
end)
