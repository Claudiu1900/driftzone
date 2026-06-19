local status = {
    food = Config.DefaultFood,
    water = Config.DefaultWater,
    loaded = true,
    synced = false
}

local hudVisible = true
local staminaVisibleUntil = 0
local staminaValue = 100.0
local staminaRunning = false
local staminaExhausted = false
local lastSprintAt = 0
local lastPayload = nil
local lastResolutionX, lastResolutionY = 0, 0
local minimapScaleform = nil
local nuiReady = false

local vitalsApplied = false
local vitalsApplyToken = 0
local lastSentHealth = nil
local lastSentArmour = nil
local lastVitalsHeartbeat = 0

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
    if not DoesEntityExist(ped) then return 0 end

    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)

    if maxHealth > 100 then
        return clamp(round(((health - 100) / (maxHealth - 100)) * 100), 0, 100)
    end

    if maxHealth <= 0 then return 0 end
    return clamp(round((health / maxHealth) * 100), 0, 100)
end

local function setHealthPercent(ped, percent)
    percent = clamp(round(percent), 0, 100)
    local maxHealth = GetEntityMaxHealth(ped)

    if percent <= 0 then
        SetEntityHealth(ped, 0)
        return
    end

    if maxHealth > 100 then
        local health = 100 + round((maxHealth - 100) * (percent / 100))
        SetEntityHealth(ped, clamp(health, 101, maxHealth))
        return
    end

    SetEntityHealth(ped, clamp(round(maxHealth * (percent / 100)), 1, maxHealth))
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

local function getVitals()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return Config.DefaultHealth, Config.DefaultArmour
    end

    return getHealthPercent(ped), clamp(round(GetPedArmour(ped)), 0, 100)
end

local function reportVitals(force)
    if not status.synced or not vitalsApplied then return end

    local health, armour = getVitals()
    local now = GetGameTimer()
    local heartbeatDue = now - lastVitalsHeartbeat >= Config.VitalsHeartbeatInterval

    if force or heartbeatDue or health ~= lastSentHealth or armour ~= lastSentArmour then
        TriggerServerEvent('driftzone_minimap:updateVitals', health, armour)
        lastSentHealth = health
        lastSentArmour = armour
        lastVitalsHeartbeat = now
    end
end

local function applySavedVitals(health, armour)
    vitalsApplyToken = vitalsApplyToken + 1
    local token = vitalsApplyToken

    CreateThread(function()
        Wait(Config.VitalsApplyDelay)

        local timeoutAt = GetGameTimer() + 10000
        while token == vitalsApplyToken and GetGameTimer() < timeoutAt do
            local ped = PlayerPedId()

            if NetworkIsPlayerActive(PlayerId()) and DoesEntityExist(ped) then
                local safeHealth = clamp(round(health), Config.MinimumLoadedHealth, 100)
                local safeArmour = clamp(round(armour), 0, 100)

                setHealthPercent(ped, safeHealth)
                SetPedArmour(ped, safeArmour)

                vitalsApplied = true
                lastSentHealth = safeHealth
                lastSentArmour = safeArmour
                lastVitalsHeartbeat = GetGameTimer()
                lastPayload = nil
                return
            end

            Wait(250)
        end
    end)
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
    local armour = clamp(GetPedArmour(ped), 0, 100)
    local stamina = clamp(round(staminaValue), 0, 100)
    local now = GetGameTimer()

    local payload = {
        visible = true,
        health = getHealthPercent(ped),
        armour = armour,
        food = clamp(round(status.food), 0, 100),
        water = clamp(round(status.water), 0, 100),
        stamina = stamina,
        showArmour = armour > 0,
        showStamina = staminaRunning or stamina < 100 or now < staminaVisibleUntil
    }

    if force or payloadChanged(payload) then
        SendNUIMessage({ action = 'update', data = payload })
        lastPayload = payload
    end
end

local function resetStamina()
    staminaValue = 100.0
    staminaRunning = false
    staminaExhausted = false
    staminaVisibleUntil = 0
    lastSprintAt = 0
    lastPayload = nil
end

CreateThread(function()
    local previousTick = GetGameTimer()

    while true do
        local now = GetGameTimer()
        local deltaSeconds = math.min((now - previousTick) / 1000.0, 0.25)
        previousTick = now

        local ped = PlayerPedId()
        local player = PlayerId()
        local validPed = DoesEntityExist(ped)
            and not IsEntityDead(ped)
            and not IsPedInAnyVehicle(ped, false)

        local sprintPressed = validPed and IsControlPressed(0, 21)
        local moving = validPed and GetEntitySpeed(ped) >= Config.Stamina.MinimumMoveSpeed
        local isSprinting = sprintPressed and moving and not staminaExhausted

        if isSprinting then
            -- Stamina proprie: 100 -> 0 cât timp jucătorul aleargă.
            staminaRunning = true
            lastSprintAt = now
            staminaVisibleUntil = now + Config.Stamina.HideDelay
            staminaValue = clamp(
                staminaValue - (Config.Stamina.DrainPerSecond * deltaSeconds),
                0.0,
                100.0
            )

            -- Stamina nativă este menținută plină; sprintul este controlat de sistemul nostru.
            RestorePlayerStamina(player, 1.0)

            if staminaValue <= 0.0 then
                staminaValue = 0.0
                staminaRunning = false
                staminaExhausted = true
            end
        else
            staminaRunning = false

            if staminaValue < 100.0 and now - lastSprintAt >= Config.Stamina.RegenDelay then
                staminaValue = clamp(
                    staminaValue + (Config.Stamina.RegenPerSecond * deltaSeconds),
                    0.0,
                    100.0
                )

                if staminaValue >= 100.0 then
                    staminaValue = 100.0
                    staminaVisibleUntil = now + Config.Stamina.HideDelay
                end
            end
        end

        if staminaExhausted then
            -- DisableControlAction trebuie apelat în fiecare frame cât timp sprintul este blocat.
            DisableControlAction(0, 21, true)
            RestorePlayerStamina(player, 1.0)

            if staminaValue >= Config.Stamina.ResumeSprintAt then
                staminaExhausted = false
            end
        end

        local active = isSprinting or staminaValue < 100.0 or staminaExhausted

        if staminaExhausted then
            Wait(0)
        elseif active then
            Wait(Config.Stamina.ActiveTick)
        else
            Wait(Config.Stamina.IdleTick)
        end
    end
end)

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

local function requestStatus(applyVitals)
    TriggerServerEvent('driftzone_minimap:requestStatus', applyVitals == true)
end

RegisterNUICallback('ready', function(_, callback)
    nuiReady = true
    lastPayload = nil
    sendHudUpdate(true)
    callback({ ok = true })
end)

RegisterNetEvent('driftzone_minimap:client:syncStatus', function(data)
    if type(data) ~= 'table' then return end

    status.food = clamp(data.food, 0, 100)
    status.water = clamp(data.water, 0, 100)
    status.loaded = true
    status.synced = true

    if data.applyVitals == true then
        applySavedVitals(data.health or Config.DefaultHealth, data.armour or Config.DefaultArmour)
    end

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
    requestStatus(true)

    local nextStatusRetry = GetGameTimer() + 5000

    while true do
        sendHudUpdate(false)

        if (not status.synced or not vitalsApplied) and GetGameTimer() >= nextStatusRetry then
            requestStatus(true)
            nextStatusRetry = GetGameTimer() + 5000
        end

        local ped = PlayerPedId()
        local active = DoesEntityExist(ped)
            and (staminaRunning or staminaValue < 100.0 or GetPedArmour(ped) > 0)

        Wait(active and Config.ClientHudUpdateInterval or 250)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.VitalsReportInterval)
        reportVitals(false)
    end
end)

CreateThread(function()
    local nextHealthArmourRefresh = 0

    while true do
        local shouldDisplayRadar = Config.Minimap.Enabled
            and (not Config.Minimap.HideWithHud or hudVisible)

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
    resetStamina()
    Wait(1000)

    if not status.synced or not vitalsApplied then
        requestStatus(true)
    else
        requestStatus(false)
    end

    applyMinimapPosition()
    hideDefaultHealthArmour()
    lastPayload = nil
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Wait(750)
    resetStamina()
    vitalsApplied = false
    applyMinimapPosition()
    hideDefaultHealthArmour()
    requestStatus(true)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    reportVitals(true)
    DisplayRadar(true)

    if Config.Minimap.HideDefaultHealthArmour then
        setDefaultHealthArmourMode(0)
    end
end)
