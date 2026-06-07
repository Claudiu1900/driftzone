local menuOpen = false
local nuiReady = false
local pendingOpen = false
local currentProps = {}
local lastEmoteAt = 0
local favoriteKey = 'driftzone_emotes_favorites'
local favorites = {}

local function notify(msg, nType)
    TriggerEvent(Config.NotifyEvent or 'client:notify', nType or 'info', 3500, tostring(msg or ''))
end

local function debugPrint(...)
    if Config.Debug then print('[DRIFTZONE_EMOTES]', ...) end
end

local function sendNui(data)
    if not nuiReady then return false end
    SendNUIMessage(data)
    return true
end

local function loadFavorites()
    local raw = GetResourceKvpString(favoriteKey)
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then favorites = decoded return end
    end
    favorites = {}
end

local function saveFavorites()
    SetResourceKvp(favoriteKey, json.encode(favorites or {}))
end

local function toArrayEmotes()
    local list = {}
    for name, data in pairs(DriftZoneEmotes.List or {}) do
        list[#list + 1] = {
            name = name,
            label = data.label or name,
            category = data.category or 'general',
            description = data.description or '',
            favorite = favorites[name] == true
        }
    end
    table.sort(list, function(a, b)
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)
    return list
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)

    if Config.HideHudWhileOpen then
        TriggerEvent('driftzone_hud:visible', not menuOpen)
    end
end

local function openMenu()
    loadFavorites()

    local payload = {
        action = 'open',
        mainColor = Config.MainColor or '#04c7f7',
        title = Config.UI and Config.UI.title or 'DriftZone Emotes',
        subtitle = Config.UI and Config.UI.subtitle or '',
        searchPlaceholder = Config.UI and Config.UI.searchPlaceholder or 'Cauta emote...',
        categories = Config.Categories or {},
        emotes = toArrayEmotes()
    }

    if not sendNui(payload) then
        pendingOpen = true
        return
    end

    setFocus(true)
end

local function closeMenu()
    sendNui({ action = 'close' })
    setFocus(false)
end

local function loadAnimDict(dict)
    dict = tostring(dict or '')
    if dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(tostring(model or ''))
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function clearProps()
    for i = 1, #currentProps do
        local obj = currentProps[i]
        if obj and DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    currentProps = {}
end

local function attachProp(ped, propData)
    if type(propData) ~= 'table' then return end
    local hash = loadModel(propData.model)
    if not hash then return end

    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    if not obj or obj == 0 then return end

    local placement = propData.placement or {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
    local bone = GetPedBoneIndex(ped, tonumber(propData.bone or 28422) or 28422)

    AttachEntityToEntity(
        obj,
        ped,
        bone,
        tonumber(placement[1] or 0.0) or 0.0,
        tonumber(placement[2] or 0.0) or 0.0,
        tonumber(placement[3] or 0.0) or 0.0,
        tonumber(placement[4] or 0.0) or 0.0,
        tonumber(placement[5] or 0.0) or 0.0,
        tonumber(placement[6] or 0.0) or 0.0,
        true, true, false, true, 1, true
    )

    currentProps[#currentProps + 1] = obj
    SetModelAsNoLongerNeeded(hash)
end

local function cancelEmote()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    clearProps()
end

local function playWalk(data)
    local ped = PlayerPedId()
    local walk = tostring(data.walk or '')

    if walk == '' or walk == 'reset' then
        ResetPedMovementClipset(ped, 0.25)
        notify('Mers resetat.', 'info')
        return true
    end

    RequestAnimSet(walk)
    local timeout = GetGameTimer() + 5000
    while not HasAnimSetLoaded(walk) and GetGameTimer() < timeout do Wait(10) end
    if not HasAnimSetLoaded(walk) then
        notify('Walk style invalid.', 'warning')
        return false
    end

    SetPedMovementClipset(ped, walk, 0.25)
    notify('Walk style aplicat.', 'success')
    return true
end

local function canPlay()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return false, 'Nu poti folosi emotes mort.' end
    if IsPedInAnyVehicle(ped, false) and Config.AllowInVehicle == false then return false, 'Nu poti folosi emotes in masina.' end
    return true
end

local function playEmote(name)
    name = tostring(name or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return false end

    if name == 'c' or name == 'cancel' or name == 'stop' then
        cancelEmote()
        return true
    end

    local now = GetGameTimer()
    if now - lastEmoteAt < 120 then return false end
    lastEmoteAt = now

    local data = DriftZoneEmotes.List[name]
    if not data then
        notify('Emote inexistent: ' .. name, 'warning')
        return false
    end

    local ok, reason = canPlay()
    if not ok then
        notify(reason, 'warning')
        return false
    end

    local ped = PlayerPedId()

    if data.type == 'walk' then
        return playWalk(data)
    end

    cancelEmote()
    Wait(40)

    if data.type == 'scenario' then
        TaskStartScenarioInPlace(ped, tostring(data.scenario), 0, true)
        return true
    end

    if data.type == 'anim' then
        if not loadAnimDict(data.dict) then
            notify('Animatia nu s-a putut incarca.', 'warning')
            return false
        end

        if data.prop then
            attachProp(ped, data.prop)
        end

        local flag = tonumber(data.flag or 1) or 1
        local duration = tonumber(data.duration or -1) or -1
        TaskPlayAnim(ped, tostring(data.dict), tostring(data.anim), 8.0, -8.0, duration, flag, 0.0, false, false, false)
        return true
    end

    return false
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if pendingOpen then
        pendingOpen = false
        openMenu()
    end
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('play', function(data, cb)
    local name = data and data.name or ''
    local played = playEmote(name)
    cb({ ok = played == true })
end)

RegisterNUICallback('toggleFavorite', function(data, cb)
    local name = tostring(data and data.name or '')
    if name ~= '' and DriftZoneEmotes.List[name] then
        favorites[name] = favorites[name] ~= true
        saveFavorites()
        sendNui({ action = 'favorites', emotes = toArrayEmotes() })
    end
    cb({ ok = true })
end)

RegisterCommand(Config.Command or 'emotes', function()
    openMenu()
end, false)

RegisterCommand(Config.PlayCommand or 'e', function(_, args)
    local name = table.concat(args or {}, ' ')
    playEmote(name)
end, false)

RegisterCommand(Config.CancelCommand or 'ecancel', function()
    cancelEmote()
end, false)

RegisterKeyMapping(Config.CancelCommand or 'ecancel', 'DriftZone Emotes: Cancel Emote', 'keyboard', Config.CancelKey or 'X')

if Config.OpenKeyEnabled then
    RegisterKeyMapping(Config.Command or 'emotes', 'DriftZone Emotes: Open Menu', 'keyboard', Config.OpenKey or 'F9')
end

CreateThread(function()
    loadFavorites()
    Wait(1000)
    print('[DRIFTZONE_EMOTES] Client loaded. Commands: /' .. tostring(Config.Command or 'emotes') .. ' and /' .. tostring(Config.PlayCommand or 'e'))
end)

CreateThread(function()
    while true do
        if menuOpen and Config.DisableCombatWhileOpen then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
                closeMenu()
            end
            Wait(0)
        else
            Wait(350)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cancelEmote()
    SetNuiFocus(false, false)
end)

exports('Play', playEmote)
exports('Cancel', cancelEmote)
exports('Open', openMenu)
exports('Close', closeMenu)
