local menuOpen = false
local nuiReady = false
local pendingOpen = false
local cachedData = nil
local lastOpen = 0

local handoffPause = false
local ignoreEscUntil = 0

local function sendNui(payload)
    if not nuiReady then return false end
    SendNUIMessage(payload)
    return true
end

local function setGameHud(state)
    local visible = state == true
    DisplayRadar(visible)
    DisplayHud(visible)
    TriggerEvent('driftzone_hud:visible', visible)
    TriggerEvent('client:hud:visible', visible)
end

local function setFocus(state)
    menuOpen = state == true

    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)

    setGameHud(not menuOpen)
end

local function closeEscUi()
    pendingOpen = false

    if menuOpen then
        menuOpen = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        sendNui({ action = 'close' })
        setGameHud(true)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        setGameHud(true)
    end
end

local function openEscUi()
    if handoffPause then return end
    if IsPauseMenuActive() then return end
    if GetGameTimer() < ignoreEscUntil then return end

    local now = GetGameTimer()
    if now - lastOpen < 300 then return end
    lastOpen = now

    if menuOpen then return end

    pendingOpen = true
    TriggerServerEvent('driftzone_escmenu:server:requestData')
end

local function forceDefaultPauseMenu()
    -- Sterge focus-ul NUI inainte. Daca focus-ul ramane activ, GTA nu deschide pause menu corect.
    closeEscUi()

    handoffPause = true
    ignoreEscUntil = GetGameTimer() + 1500

    CreateThread(function()
        local openDelay = tonumber(Config.Pause.openDelayMs or 260) or 260
        local attempts = tonumber(Config.Pause.openAttempts or 25) or 25
        local delay = tonumber(Config.Pause.attemptDelayMs or 60) or 60
        local cooldown = tonumber(Config.Pause.cooldownAfterCloseMs or 550) or 550
        local frontendHash = GetHashKey(Config.Pause.frontendHash or 'FE_MENU_VERSION_MP_PAUSE')

        Wait(openDelay)

        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        setGameHud(true)

        -- Deschide MENIUL DEFAULT GTA direct, fara PauseMenuceptionGoDeeper.
        -- ActivateFrontendMenu este mai stabil decat doar SetPauseMenuActive.
        for _ = 1, attempts do
            if IsPauseMenuActive() then
                break
            end

            ActivateFrontendMenu(frontendHash, false, -1)
            SetPauseMenuActive(true)

            Wait(delay)
        end

        -- Daca tot nu s-a deschis, nu lasa scriptul blocat.
        if not IsPauseMenuActive() then
            handoffPause = false
            ignoreEscUntil = GetGameTimer() + cooldown
            setGameHud(true)
            return
        end

        -- Cat timp meniul default GTA este deschis, NU blocam ESC.
        while IsPauseMenuActive() do
            Wait(0)
        end

        -- Asteapta sa fie eliberata tasta ESC/P, altfel poate redeschide UI instant.
        local releaseStart = GetGameTimer()
        while IsControlPressed(0, 200) or IsDisabledControlPressed(0, 200)
            or IsControlPressed(0, 199) or IsDisabledControlPressed(0, 199)
            or IsControlPressed(0, 322) or IsDisabledControlPressed(0, 322) do
            Wait(0)
            if GetGameTimer() - releaseStart > 1200 then
                break
            end
        end

        handoffPause = false
        ignoreEscUntil = GetGameTimer() + cooldown
        setGameHud(true)
    end)
end

local function handleAction(action)
    if type(action) ~= 'table' then return end

    local actionType = tostring(action.type or '')

    if actionType == 'default_pause' or actionType == 'normal_pause' then
        forceDefaultPauseMenu()
        return
    end

    if actionType == 'client_event' then
    local eventName = tostring(action.value or '')

    if eventName ~= '' then
        closeEscUi()

        CreateThread(function()
            Wait(90)
            TriggerEvent(eventName)
        end)
    end

    return
end

    if actionType == 'command' then
        local command = tostring(action.value or '')
        if command ~= '' then
            closeEscUi()
            CreateThread(function()
                Wait(90)
                ExecuteCommand(command)
            end)
        end
        return
    end

    if actionType == 'copy_discord' then
        sendNui({
            action = 'copyDiscord',
            value = Config.DiscordInvite or ''
        })
        return
    end

    if actionType == 'soon' then
        sendNui({ action = 'soon' })
        return
    end
end

RegisterNetEvent('driftzone_escmenu:client:data', function(data)
    cachedData = data or {}

    if not pendingOpen then return end
    if not nuiReady then return end
    if handoffPause or IsPauseMenuActive() then return end

    pendingOpen = false
    setFocus(true)

    sendNui({
        action = 'open',
        payload = cachedData
    })
end)

RegisterNetEvent('driftzone_escmenu:client:openCommand', function()
    openEscUi()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true

    if pendingOpen and cachedData and not handoffPause and not IsPauseMenuActive() then
        pendingOpen = false
        setFocus(true)
        sendNui({
            action = 'open',
            payload = cachedData
        })
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeEscUi()
    cb({ ok = true })
end)

RegisterNUICallback('runAction', function(data, cb)
    handleAction(data and data.action or nil)
    cb({ ok = true })
end)

RegisterNUICallback('copied', function(_, cb)
    cb({ ok = true })
end)

RegisterCommand(Config.OpenCommand or 'escmenu', function()
    openEscUi()
end, false)

CreateThread(function()
    while true do
        if not Config.DisableDefaultPause then
            Wait(500)
        else
            if handoffPause or IsPauseMenuActive() or GetGameTimer() < ignoreEscUntil then
                -- Nu interceptam ESC deloc cand e default pause menu activ.
                Wait(0)
            else
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 199, true)

                if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 199) then
                    if menuOpen then
                        closeEscUi()
                    else
                        openEscUi()
                    end
                end

                if menuOpen then
                    DisableControlAction(0, 322, true)
                    DisableControlAction(0, 177, true)
                end

                Wait(0)
            end
        end
    end
end)

CreateThread(function()
    while true do
        -- Protectie: daca ESC UI e deschis, nu lasa si pause menu default peste el.
        if menuOpen and IsPauseMenuActive() then
            SetPauseMenuActive(false)
        end

        Wait(menuOpen and 250 or 1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    setGameHud(true)
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_ESCMENU] Client-side loaded.')
end)
