local nuiReady = false
local menuOpen = false
local pendingOpen = false
local binds = {}
local lastPressed = {}

local function notify(type, message, duration)
    TriggerEvent('client:notify', type or 'info', duration or 5000, tostring(message or ''))
end

local function normalizeKey(key)
    return tostring(key or ''):upper():gsub('%s+', '')
end

local function getDefaultBind(id)
    for _, item in ipairs(Config.Keybinds or {}) do
        if item.id == id then
            return item
        end
    end
    return nil
end

local function keyToControl(key)
    key = normalizeKey(key)
    return Config.KeyMap[key]
end

local function isBlockedKey(key)
    key = normalizeKey(key)
    return Config.BlockedKeys and Config.BlockedKeys[key] == true
end

local function isValidKey(key)
    key = normalizeKey(key)
    if key == '' then return false end
    if isBlockedKey(key) then return false end
    return keyToControl(key) ~= nil
end

local function buildBind(item, key)
    local bindKey = normalizeKey(key or item.key)
    local control = keyToControl(bindKey)

    return {
        id = item.id,
        name = item.name or item.id,
        description = item.description or '',
        key = bindKey,
        defaultKey = normalizeKey(item.key),
        control = control,
        eventType = item.eventType or 'command',
        eventName = item.eventName or '',
        enabled = item.enabled ~= false,
        supported = control ~= nil
    }
end

local function getKvpName(id)
    return tostring(Config.KvpPrefix or 'driftzone_keybind_') .. tostring(id)
end

local function saveKey(id, key)
    key = normalizeKey(key)
    SetResourceKvp(getKvpName(id), key)
end

local function deleteKey(id)
    DeleteResourceKvp(getKvpName(id))
end

local function loadBinds()
    binds = {}

    for _, item in ipairs(Config.Keybinds or {}) do
        local saved = GetResourceKvpString(getKvpName(item.id))
        local key = saved and saved ~= '' and saved or item.key

        local bind = buildBind(item, key)

        -- Daca tasta salvata nu mai este suportata, revenim la default.
        if not bind.supported then
            bind = buildBind(item, item.key)
            deleteKey(item.id)
        end

        binds[#binds + 1] = bind
    end
end

local function getBindById(id)
    for _, bind in ipairs(binds) do
        if bind.id == id then return bind end
    end
    return nil
end

local function sendNui(payload)
    if not nuiReady then return end
    SendNUIMessage(payload)
end

local function getPayload()
    local payload = {}

    for _, bind in ipairs(binds) do
        payload[#payload + 1] = {
            id = bind.id,
            name = bind.name,
            description = bind.description,
            key = bind.key,
            defaultKey = bind.defaultKey,
            eventType = bind.eventType,
            eventName = bind.eventName,
            enabled = bind.enabled,
            supported = bind.supported
        }
    end

    return {
        mainColor = Config.MainColor or '#04c7f7',
        keybinds = payload
    }
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)

    if menuOpen then
        TriggerEvent('driftzone_hud:visible', false)
        TriggerEvent('client:hud:visible', false)
        TriggerEvent('hud:visible', false)
    else
        TriggerEvent('driftzone_hud:visible', true)
        TriggerEvent('client:hud:visible', true)
        TriggerEvent('hud:visible', true)
    end
end

local function openMenu()
    loadBinds()

    if not nuiReady then
        pendingOpen = true
        return
    end

    setFocus(true)
    sendNui({ action = 'open', payload = getPayload() })
end

local function closeMenu()
    setFocus(false)
    sendNui({ action = 'close' })
end

local function runBind(bind)
    if not bind or not bind.enabled then return end
    if not bind.eventName or bind.eventName == '' then return end

    if bind.eventType == 'client' then
        TriggerEvent(bind.eventName)
        return
    end

    if bind.eventType == 'server' then
        TriggerServerEvent(bind.eventName)
        return
    end

    ExecuteCommand(bind.eventName)
end

RegisterNetEvent('driftzone_keybinds:client:open', function()
    openMenu()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    loadBinds()

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

RegisterNUICallback('setKey', function(data, cb)
    local id = tostring(data.id or '')
    local key = normalizeKey(data.key)
    local default = getDefaultBind(id)

    if not default then
        cb({ ok = false, error = 'Keybind invalid.' })
        return
    end

    if isBlockedKey(key) then
        cb({ ok = false, error = 'Tasta este blocata.' })
        return
    end

    if not isValidKey(key) then
        cb({ ok = false, error = 'Tasta nu este suportata de FiveM fara RegisterKeyMapping.' })
        return
    end

    saveKey(id, key)
    loadBinds()

    sendNui({ action = 'refresh', payload = getPayload() })

    cb({ ok = true })
end)

RegisterNUICallback('resetKey', function(data, cb)
    local id = tostring(data.id or '')
    deleteKey(id)
    loadBinds()
    sendNui({ action = 'refresh', payload = getPayload() })
    cb({ ok = true })
end)

RegisterNUICallback('resetAll', function(_, cb)
    for _, item in ipairs(Config.Keybinds or {}) do
        deleteKey(item.id)
    end

    loadBinds()
    sendNui({ action = 'refresh', payload = getPayload() })
    cb({ ok = true })
end)

RegisterCommand('keybind', function()
    openMenu()
end, false)

RegisterCommand('keybinds', function()
    openMenu()
end, false)

CreateThread(function()
    loadBinds()

    while true do
        if menuOpen then
            Wait(250)
        else
            local active = false
            local now = GetGameTimer()

            for _, bind in ipairs(binds) do
                if bind.enabled and bind.supported and bind.control then
                    active = true

                    if IsDisabledControlJustPressed(0, bind.control) or IsControlJustPressed(0, bind.control) then
                        local last = lastPressed[bind.id] or 0

                        if now - last > 450 then
                            lastPressed[bind.id] = now
                            runBind(bind)
                        end
                    end
                end
            end

            if active then
                Wait(Config.CheckInterval or 0)
            else
                Wait(Config.IdleInterval or 180)
            end
        end
    end
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_KEYBINDS] Client-side loaded.')
end)
