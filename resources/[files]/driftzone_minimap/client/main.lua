local status = {
    food = Config.DefaultFood,
    water = Config.DefaultWater,
    loaded = true,
    synced = false
}

local hudVisible = true
local staminaVisibleUntil = 0
local lastPayload = nil
local lastResolutionX, lastResolutionY = 0, 0
local minimapScaleform = nil
local nuiReady = false

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function round(value)
    return math.floor(value + 0.5)
end

local function getHealthPercent(ped)
    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)

    -- Ped-urile GTA folosesc de regulă 100 ca prag de moarte și 200 ca viață maximă.
    if maxHealth > 100 then
        return clamp(round(((health - 100) / (maxHealth - 100)) * 100), 0, 100)
    end

    if maxHealth <= 0 then return 0 end
    return clamp(round((health / maxHealth) * 100), 0, 100)
end

local function payloadChanged(payload)
    if not lastPayload then return true end

    return payload.visible ~= lastPayload.visible
        or payload.health ~= lastPayload.health
        or payload.armour ~= lastPayload.armour
        or payload.food ~= lastPayload.food
        or payload.water ~= lastPayload.water
        or payload.stamina ~= lastPayload.stamina
        or payload.showArmour ~= lastPayload.showArmour
        or payload.showStamina ~= lastPayload.showStamina
end

local function sendHudUpdate(force)
    local pauseActive = IsPauseMenuActive()
    local shouldShow = hudVisible and not pauseActive

    if not shouldShow then
        local hiddenPayload = { visible = false }
        if force or not lastPayload or lastPayload.visible ~= false then
            SendNUIMessage({ action = 'update', data = hiddenPayload })
            lastPayload = hiddenPayload
        end
        return
    end

    local ped = PlayerPedId()
    local player = PlayerId()
    local armour = clamp(GetPedArmour(ped), 0, 100)
    local stamina = clamp(round(GetPlayerSprintStaminaRemaining(player)), 0, 100)
    local movingFast = (IsPedRunning(ped) or IsPedSprinting(ped)) and not IsPedInAnyVehicle(ped, false)
    local now = GetGameTimer()

    if movingFast or stamina < 100 then
        staminaVisibleUntil = now + 1200
    end

    local payload = {
        visible = true,
        health = getHealthPercent(ped),
        armour = armour,
        food = clamp(round(status.food), 0, 100),
        water = clamp(round(status.water), 0, 100),
        stamina = stamina,
        showArmour = armour > 0,
        showStamina = movingFast or stamina < 100 or now < staminaVisibleUntil
    }

    if force or payloadChanged(payload) then
        SendNUIMessage({ action = 'update', data = payload })
        lastPayload = payload
    end
end

local function applyMinimapPosition()
    if not Config.Minimap.Enabled then
        DisplayRadar(false)
        return
    end

    local offset = tonumber(Config.Minimap.VerticalOffset) or 0.0

    for componentName, component in pairs(Config.Minimap.Components) do
        SetMinimapComponentPosition(
            componentName,
            component.alignX,
            component.alignY,
            component.x,
            component.y + offset,
            component.width,
            component.height
        )
    end

    SetMinimapClipType(0)

    -- Forțează minimap-ul să-și recalculeze poziția după modificare.
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
end

local function setDefaultHealthArmourMode(mode)
    minimapScaleform = minimapScaleform or RequestScaleformMovie('minimap')
    local timeoutAt = GetGameTimer() + 5000

    while not HasScaleformMovieLoaded(minimapScaleform) and GetGameTimer() < timeoutAt do
        Wait(0)
    end

    if HasScaleformMovieLoaded(minimapScaleform) then
        BeginScaleformMovieMethod(minimapScaleform, 'SETUP_HEALTH_ARMOUR')
        ScaleformMovieMethodAddParamInt(mode)
        EndScaleformMovieMethod()
    end
end

local function hideDefaultHealthArmour()
    if Config.Minimap.HideDefaultHealthArmour then
        setDefaultHealthArmourMode(3)
    end
end

local function requestStatus()
    TriggerServerEvent('driftzone_minimap:requestStatus')
end

RegisterNUICallback('ready', function(_, callback)
    nuiReady = true
    lastPayload = nil
    sendHudUpdate(true)
    callback({ ok = true })
end)

RegisterNetEvent('driftzone_minimap:client:syncStatus', function(food, water)
    status.food = clamp(food, 0, 100)
    status.water = clamp(water, 0, 100)
    status.loaded = true
    status.synced = true
    sendHudUpdate(true)
end)

RegisterNetEvent('driftzone_minimap:client:applyStatusDamage', function(percent)
    percent = clamp(percent, 1, 100)

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    local effectiveMaximum = math.max(1, maxHealth - 100)
    local damage = math.max(1, round(effectiveMaximum * (percent / 100)))

    SetEntityHealth(ped, health - damage)
end)

RegisterNetEvent('driftzone_minimap:client:setVisible', function(visible)
    hudVisible = visible == true
    lastPayload = nil
    sendHudUpdate(true)
end)

exports('SetHudVisible', function(visible)
    hudVisible = visible == true
    lastPayload = nil
    sendHudUpdate(true)
end)

exports('IsHudVisible', function()
    return hudVisible
end)

CreateThread(function()
    Wait(500)
    applyMinimapPosition()
    hideDefaultHealthArmour()
    sendHudUpdate(true)
    requestStatus()

    local nextStatusRetry = GetGameTimer() + 5000

    while true do
        sendHudUpdate(false)

        -- Dacă serverul nu a răspuns încă, cerem din nou statusul fără spam.
        if not status.synced and GetGameTimer() >= nextStatusRetry then
            requestStatus()
            nextStatusRetry = GetGameTimer() + 5000
        end

        local ped = PlayerPedId()
        local active = DoesEntityExist(ped)
            and ((IsPedRunning(ped) or IsPedSprinting(ped)) or GetPedArmour(ped) > 0)

        Wait(active and Config.ClientHudUpdateInterval or 250)
    end
end)

CreateThread(function()
    local nextHealthArmourRefresh = 0

    while true do
        local shouldDisplayRadar = Config.Minimap.Enabled
            and (not Config.Minimap.HideWithHud or hudVisible)

        -- Reaplicăm periodic deoarece alte resurse pot modifica radarul sau scaleform-ul.
        DisplayRadar(shouldDisplayRadar)

        if GetGameTimer() >= nextHealthArmourRefresh then
            hideDefaultHealthArmour()
            nextHealthArmourRefresh = GetGameTimer() + 3000
        end

        local resolutionX, resolutionY = GetActiveScreenResolution()
        if resolutionX ~= lastResolutionX or resolutionY ~= lastResolutionY then
            lastResolutionX, lastResolutionY = resolutionX, resolutionY
            applyMinimapPosition()
            hideDefaultHealthArmour()
            lastPayload = nil
        end

        Wait(1000)
    end
end)

AddEventHandler('playerSpawned', function()
    Wait(1000)
    requestStatus()
    applyMinimapPosition()
    hideDefaultHealthArmour()
    lastPayload = nil
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Wait(750)
    applyMinimapPosition()
    hideDefaultHealthArmour()
    requestStatus()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    DisplayRadar(true)

    if Config.Minimap.HideDefaultHealthArmour then
        setDefaultHealthArmourMode(0)
    end
end)
