
local nuiReady = false
local menuOpen = false
local currentEmote = nil
local pendingOpen = false
local emotesById = {}
local emotesByName = {}

local function notify(type, msg)
    if Config.NotifyEvent and Config.NotifyEvent ~= '' then
        TriggerEvent(Config.NotifyEvent, type or 'info', 3500, tostring(msg or ''))
    else
        print('[DRIFTZONE_EMOTES] ' .. tostring(msg or ''))
    end
end

local function sendNui(data)
    if not nuiReady then return false end
    SendNUIMessage(data)
    return true
end

local function normalize(value)
    value = tostring(value or ''):lower()
    value = value:gsub('%s+', '')
    value = value:gsub('[^%w_%-]', '')
    return value
end

local function buildIndexes()
    emotesById = {}
    emotesByName = {}

    for _, emote in ipairs(DriftzoneEmotes or {}) do
        if emote.id then
            emotesById[emote.id] = emote
            emotesByName[normalize(emote.id)] = emote
        end

        if emote.label then
            emotesByName[normalize(emote.label)] = emote
        end
    end
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)
end

local function openMenu()
    local payload = {
        action = 'open',
        mainColor = Config.MainColor or '#04c7f7',
        title = Config.MenuTitle or 'DriftZone Emotes',
        subtitle = Config.MenuSubtitle or '',
        emotes = DriftzoneEmotes or {}
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
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)

    local timeout = GetGameTimer() + (Config.MaxLoadTimeMs or 3500)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    return HasAnimDictLoaded(dict)
end

local function clearCurrent()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    currentEmote = nil
end

local function playEmote(emote)
    if not emote then
        notify('warning', 'Emote-ul nu exista.')
        return
    end

    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) and Config.AllowInVehicle ~= true then
        notify('warning', 'Nu poti folosi emote in masina.')
        return
    end

    local dict = tostring(emote.dict or '')
    if dict == '' then
        notify('warning', 'Emote invalid.')
        return
    end

    if not loadAnimDict(dict) then
        notify('warning', 'Animatia nu s-a incarcat: ' .. dict)
        return
    end

    clearCurrent()

    local flag = 0
    if emote.loop ~= false then flag = flag + 1 end
    if emote.moving == true then flag = flag + 48 end

    local anims = emote.anims or {}
    if type(anims) ~= 'table' then anims = { tostring(anims) } end

    local anim = tostring(anims[1] or '')
    if anim == '' then
        notify('warning', 'Anim name lipsa.')
        return
    end

    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag, 0.0, false, false, false)
    currentEmote = emote

    if Config.CloseOnPlay then closeMenu() end
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendNui({
        action = 'setup',
        mainColor = Config.MainColor or '#04c7f7',
        title = Config.MenuTitle or 'DriftZone Emotes',
        subtitle = Config.MenuSubtitle or '',
        emotes = DriftzoneEmotes or {}
    })

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
    playEmote(emotesById[data and data.id])
    cb({ ok = true })
end)

RegisterCommand(Config.OpenCommand or 'emotes', function()
    openMenu()
end, false)

RegisterCommand(Config.PlayCommand or 'e', function(_, args)
    local name = table.concat(args or {}, ' ')

    if name == '' then
        openMenu()
        return
    end

    local normalized = normalize(name)
    if normalized == 'c' or normalized == 'cancel' or normalized == 'stop' then
        clearCurrent()
        return
    end

    local emote = emotesByName[normalized]
    if not emote then
        notify('warning', 'Emote invalid: ' .. name)
        return
    end

    playEmote(emote)
end, false)

for _, command in ipairs(Config.CancelCommands or {}) do
    RegisterCommand(command, function()
        clearCurrent()
    end, false)
end

RegisterNetEvent('driftzone_emotes:client:open', openMenu)
RegisterNetEvent('driftzone_emotes:client:close', closeMenu)
RegisterNetEvent('driftzone_emotes:client:cancel', clearCurrent)
RegisterNetEvent('driftzone_emotes:client:play', function(name)
    playEmote(emotesByName[normalize(name)])
end)

exports('Open', openMenu)
exports('Close', closeMenu)
exports('Cancel', clearCurrent)
exports('Play', function(name)
    playEmote(emotesByName[normalize(name)])
end)

CreateThread(function()
    buildIndexes()
    Wait(500)
    print(('[DRIFTZONE_EMOTES] Loaded %s emotes.'):format(#(DriftzoneEmotes or {})))
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
                closeMenu()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearCurrent()
    SetNuiFocus(false, false)
end)
