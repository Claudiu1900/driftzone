local nuiReady = false
local pendingCount = 0
local pendingUserOpen = false
local pendingAdminList = nil
local menuOpen = false
local lastAcceptAt = 0
local lastAcceptId = 0

local function sendNui(data)
    if not nuiReady then return false end
    SendNUIMessage(data)
    return true
end

local function setFocus(state)
    menuOpen = state == true

    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)

    if menuOpen then
        TriggerEvent('driftzone_hud:visible', false)
        TriggerEvent('driftzone_hud:client:hide')
    else
        TriggerEvent('driftzone_hud:visible', true)
        TriggerEvent('driftzone_hud:client:show')
    end
end

local function closeLocal(sendUi)
    pendingUserOpen = false
    pendingAdminList = nil

    if sendUi ~= false then
        sendNui({ action = 'close' })
    end

    setFocus(false)
end

local function openUser()
    pendingAdminList = nil

    if not sendNui({ action = 'openUser' }) then
        pendingUserOpen = true
        return
    end

    pendingUserOpen = false
    setFocus(true)
end

local function openAdmin(tickets)
    tickets = tickets or {}
    pendingUserOpen = false

    if not sendNui({ action = 'openAdmin', tickets = tickets }) then
        pendingAdminList = tickets
        return
    end

    pendingAdminList = nil
    setFocus(true)
end

local function setCount(count)
    pendingCount = tonumber(count or 0) or 0

    sendNui({
        action = 'setCount',
        count = pendingCount
    })
end

local function closeMenu(sendServer, sendUi)
    closeLocal(sendUi)

    if sendServer == true then
        TriggerServerEvent('driftzone_tickets:server:closed')
    end
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true

    sendNui({
        action = 'setCount',
        count = pendingCount
    })

    if pendingUserOpen then
        pendingUserOpen = false
        openUser()
    end

    if pendingAdminList ~= nil then
        local data = pendingAdminList
        pendingAdminList = nil
        openAdmin(data)
    end

    cb({ ok = true })
end)

-- IMPORTANT: cand NUI cere close, nu mai trimitem inapoi action='close', ca intra in loop.
RegisterNUICallback('close', function(_, cb)
    closeMenu(true, false)
    cb({ ok = true })
end)

RegisterNUICallback('create', function(data, cb)
    TriggerServerEvent('driftzone_tickets:server:create', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('accept', function(data, cb)
    local id = tonumber(data and data.id or 0) or 0
    local now = GetGameTimer()

    if id > 0 and lastAcceptId == id and now - lastAcceptAt < 1500 then
        cb({ ok = true, blocked = true })
        return
    end

    lastAcceptId = id
    lastAcceptAt = now

    TriggerServerEvent('driftzone_tickets:server:accept', id)
    cb({ ok = true })
end)

RegisterNUICallback('delete', function(data, cb)
    TriggerServerEvent('driftzone_tickets:server:delete', tonumber(data and data.id or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('teleport', function(data, cb)
    TriggerServerEvent('driftzone_tickets:server:teleport', tonumber(data and data.id or 0) or 0)
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_tickets:client:openUser', function()
    openUser()
end)

RegisterNetEvent('driftzone_tickets:client:openAdmin', function(tickets)
    openAdmin(tickets or {})
end)

RegisterNetEvent('driftzone_tickets:client:count', function(count)
    setCount(count)
end)

RegisterNetEvent('driftzone_tickets:client:close', function()
    closeMenu(false, true)
end)

RegisterNetEvent('client:tickets:openUser', function()
    openUser()
end)

RegisterNetEvent('client:tickets:openAdmin', function(ticketsJson)
    local parsed = {}

    if type(ticketsJson) == 'string' then
        local ok, decoded = pcall(json.decode, ticketsJson)
        if ok and type(decoded) == 'table' then
            parsed = decoded
        end
    elseif type(ticketsJson) == 'table' then
        parsed = ticketsJson
    end

    openAdmin(parsed)
end)

RegisterNetEvent('client:tickets:count', function(count)
    setCount(count)
end)

RegisterNetEvent('client:tickets:close', function()
    closeMenu(false, true)
end)

local function requestOpen()
    -- Nu inchidem UI-ul cu callback aici; lasam serverul sa decida panelul si NUI schimba direct panelul.
    TriggerServerEvent('driftzone_tickets:server:open')
end

RegisterCommand('ticket', function()
    requestOpen()
end, false)

RegisterCommand('tickets', function()
    requestOpen()
end, false)

RegisterCommand('tikcet', function()
    requestOpen()
end, false)

RegisterCommand('cancelticket', function()
    TriggerServerEvent('driftzone_tickets:server:cancel')
end, false)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('driftzone_tickets:server:requestCount')
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                closeMenu(true, true)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        TriggerServerEvent('driftzone_tickets:server:requestCount')
        Wait(Config.CounterRefreshMs or 5000)
    end
end)
