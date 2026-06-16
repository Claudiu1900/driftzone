local panelOpen = false
local focusEnabled = false
local nuiReady = false
local pendingOpen = nil
local tabletProp = nil
local tabletAnimActive = false

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 4500, tostring(msg or ''))
end

local function sendNui(payload)
    SendNUIMessage(payload)
end

local function setFocus(state)
    focusEnabled = state == true
    SetNuiFocus(focusEnabled, focusEnabled)
    SetNuiFocusKeepInput(false)
    sendNui({ action = 'focus', focus = focusEnabled })
end

local function loadAnimDict(dict, timeout)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local endTime = GetGameTimer() + (timeout or 1200)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < endTime do
        Wait(10)
    end

    return HasAnimDictLoaded(dict)
end

local function loadModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    if HasModelLoaded(hash) then return hash end

    RequestModel(hash)
    local endTime = GetGameTimer() + (timeout or 1200)
    while not HasModelLoaded(hash) and GetGameTimer() < endTime do
        Wait(10)
    end

    if HasModelLoaded(hash) then return hash end
    return nil
end

local function deleteTabletProp()
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
    end
    tabletProp = nil
end

local function attachTabletProp(ped)
    local cfg = Config.TabletAnimation or {}
    if not cfg.prop or cfg.prop == '' then return end
    if tabletProp and DoesEntityExist(tabletProp) then return end

    local hash = loadModel(cfg.prop, 1200)
    if not hash then return end

    local coords = GetEntityCoords(ped)
    tabletProp = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    local placement = cfg.placement or {}
    AttachEntityToEntity(
        tabletProp,
        ped,
        GetPedBoneIndex(ped, tonumber(cfg.bone or 28422) or 28422),
        tonumber(placement.x or 0.03) or 0.03,
        tonumber(placement.y or -0.05) or -0.05,
        tonumber(placement.z or 0.0) or 0.0,
        tonumber(placement.rx or 0.0) or 0.0,
        tonumber(placement.ry or 0.0) or 0.0,
        tonumber(placement.rz or 0.0) or 0.0,
        true,
        true,
        false,
        true,
        1,
        true
    )
end

local function startTabletEmote()
    local cfg = Config.TabletAnimation or {}
    if cfg.enabled == false then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end

    local dict = cfg.dict or 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
    local anim = cfg.anim or 'base'

    if loadAnimDict(dict, 1200) then
        TaskPlayAnim(ped, dict, anim, 4.0, 4.0, -1, tonumber(cfg.flag or 49) or 49, 0.0, false, false, false)
        RemoveAnimDict(dict)
    end

    attachTabletProp(ped)
    tabletAnimActive = true
end

local function stopTabletEmote()
    local cfg = Config.TabletAnimation or {}
    if cfg.enabled == false then return end

    local ped = PlayerPedId()
    local dict = cfg.dict or 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
    local anim = cfg.anim or 'base'

    if ped and ped ~= 0 then
        StopAnimTask(ped, dict, anim, 1.0)
        ClearPedSecondaryTask(ped)
    end

    tabletAnimActive = false
    deleteTabletProp()
end

local function openPanel(data)
    panelOpen = true
    pendingOpen = nil
    startTabletEmote()
    setFocus(true)
    sendNui({ action = 'open', data = data or {} })
end

local function closePanel(skipServer)
    if not panelOpen then
        setFocus(false)
        return
    end

    panelOpen = false
    setFocus(false)
    stopTabletEmote()
    sendNui({ action = 'close' })

    if skipServer ~= true then
        TriggerServerEvent('driftzone_gangpanel:server:closed')
    end
end

RegisterCommand(Config.Command or 'gang', function()
    TriggerServerEvent('driftzone_gangpanel:server:requestOpen')
end, false)

RegisterNetEvent('driftzone_gangpanel:client:open', function(data)
    if not nuiReady then
        pendingOpen = data or {}
        return
    end
    openPanel(data or {})
end)

RegisterNetEvent('driftzone_gangpanel:client:deny', function(message)
    notify('warning', message or 'Nu ai acces la gang panel.')
end)

RegisterNetEvent('driftzone_gangpanel:client:update', function(data)
    if not panelOpen then return end
    sendNui({ action = 'update', data = data or {} })
end)

RegisterNetEvent('driftzone_gangpanel:client:toast', function(typ, message)
    notify(typ or 'info', message or '')
end)

RegisterNetEvent('driftzone_gangpanel:client:forceClose', function()
    closePanel(true)
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })

    if pendingOpen then
        Wait(100)
        openPanel(pendingOpen)
    end
end)

RegisterNUICallback('close', function(_, cb)
    closePanel(false)
    cb({ ok = true })
end)

RegisterNUICallback('toggleFocus', function(_, cb)
    if panelOpen then
        setFocus(not focusEnabled)
    end
    cb({ ok = true, focus = focusEnabled })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('driftzone_gangpanel:server:refresh')
    cb({ ok = true })
end)

RegisterNUICallback('getGangDetails', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:getGangDetails', tonumber(data and data.gangId or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('createGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:createGang', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('updateGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:updateGang', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('deleteGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:deleteGang', tonumber(data and data.gangId or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('addMember', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:addMember', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('kickMember', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:kickMember', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('changeRole', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:changeRole', data or {})
    cb({ ok = true })
end)


RegisterNUICallback('getCoords', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({ ok = true, x = coords.x, y = coords.y, z = coords.z })
end)

CreateThread(function()
    while true do
        if panelOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 245, true)
            DisableControlAction(0, 243, true)

            if IsDisabledControlJustPressed(0, 200) then
                closePanel(false)
            elseif IsDisabledControlJustPressed(0, 243) then
                setFocus(not focusEnabled)
            end

            Wait(0)
        else
            Wait(450)
        end
    end
end)


CreateThread(function()
    while true do
        if panelOpen and tabletAnimActive then
            local cfg = Config.TabletAnimation or {}
            local ped = PlayerPedId()
            local dict = cfg.dict or 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
            local anim = cfg.anim or 'base'
            if ped and ped ~= 0 and not IsEntityPlayingAnim(ped, dict, anim, 3) then
                startTabletEmote()
            elseif ped and ped ~= 0 then
                attachTabletProp(ped)
            end
            Wait(1300)
        else
            Wait(700)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if panelOpen then
        stopTabletEmote()
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)
