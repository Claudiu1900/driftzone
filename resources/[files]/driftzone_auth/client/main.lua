local authOpen = false
local authCam = nil
local loadedOnce = false

local function setHudVisible(state)
    DisplayHud(state)
    DisplayRadar(state)

    TriggerEvent('drift_hud:visible', state)
    TriggerEvent('driftzone_hud:visible', state)
    TriggerEvent('client:hud:visible', state)
end

local function destroyAuthCam()
    if authCam then
        SetCamActive(authCam, false)
        DestroyCam(authCam, false)
        authCam = nil
    end

    RenderScriptCams(false, true, 500, true, true)
end

local function createAuthCam()
    destroyAuthCam()

    authCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    SetCamCoord(
        authCam,
        Config.AuthCamera.coords.x,
        Config.AuthCamera.coords.y,
        Config.AuthCamera.coords.z
    )

    PointCamAtCoord(
        authCam,
        Config.AuthCamera.point.x,
        Config.AuthCamera.point.y,
        Config.AuthCamera.point.z
    )

    SetCamFov(authCam, Config.AuthCamera.fov or 45.0)
    SetCamActive(authCam, true)

    RenderScriptCams(true, false, 0, true, true)
end

local function openAuth(data)
    authOpen = true

    local ped = PlayerPedId()

    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    setHudVisible(false)
    createAuthCam()

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    SendNUIMessage({
        action = 'open',
        name = data.name or GetPlayerName(PlayerId()),
        hasAccount = data.hasAccount == true,
        mainColor = Config.MainColor
    })
end

local function closeAuth(spawnData)
    authOpen = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'close'
    })

    destroyAuthCam()

    local spawn = spawnData or Config.DefaultSpawn
    local ped = PlayerPedId()

    DoScreenFadeOut(300)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)

    NetworkResurrectLocalPlayer(
        spawn.x + 0.0,
        spawn.y + 0.0,
        spawn.z + 0.0,
        spawn.h + 0.0,
        true,
        true,
        false
    )

    ped = PlayerPedId()

    SetEntityCoordsNoOffset(ped, spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, false, false, false)
    SetEntityHeading(ped, spawn.h + 0.0)

    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)

    setHudVisible(true)

    Wait(500)

    DoScreenFadeIn(500)
end

CreateThread(function()
    while true do
        if authOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            SetNuiFocus(true, true)
            setHudVisible(false)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    Wait(1000)

    if not loadedOnce then
        loadedOnce = true
        TriggerServerEvent('driftzone_auth:server:requestInit')
    end
end)

RegisterNetEvent('driftzone_auth:client:init', function(data)
    openAuth(data or {})
end)

RegisterNetEvent('driftzone_auth:client:status', function(message)
    SendNUIMessage({
        action = 'status',
        message = tostring(message or 'Eroare')
    })
end)

RegisterNetEvent('driftzone_auth:client:success', function(data)
    local spawn = Config.DefaultSpawn

    if data and data.spawn then
        spawn = data.spawn
    end

    closeAuth(spawn)

    TriggerEvent('chat:addMessage', {
        color = { 4, 199, 247 },
        multiline = true,
        args = {
            'DRIFTZONE',
            ('Bine ai venit! ID: %s | Nick: %s'):format(
                data and data.uid or '?',
                data and data.username or GetPlayerName(PlayerId())
            )
        }
    })
end)

RegisterNUICallback('submit', function(data, cb)
    TriggerServerEvent('driftzone_auth:server:submit', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)