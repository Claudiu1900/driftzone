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
    else
        TriggerEvent('driftzone_hud:visible', true)
    end
end

local function openUser()
    if not sendNui({ action = 'openUser' }) then
        pendingUserOpen = true
        return
    end

    setFocus(true)
end

local function openAdmin(tickets)
    tickets = tickets or {}

    if not sendNui({ action = 'openAdmin', tickets = tickets }) then
        pendingAdminList = tickets
        return
    end

    setFocus(true)
end

local function setCount(count)
    pendingCount = tonumber(count or 0) or 0

    sendNui({
        action = 'setCount',
        count = pendingCount
    })
end

local function closeMenu(sendServer)
    sendNui({ action = 'close' })
    setFocus(false)

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

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb({ ok = true })
end)

RegisterNUICallback('create', function(data, cb)
    TriggerServerEvent('driftzone_tickets:server:create', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('accept', function(data, cb)
    local id = tonumber(data.id or 0) or 0
    local now = GetGameTimer()

    -- Anti double-click / NUI duplicate callback.
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
    TriggerServerEvent('driftzone_tickets:server:delete', tonumber(data.id or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('teleport', function(data, cb)
    TriggerServerEvent('driftzone_tickets:server:teleport', tonumber(data.id or 0) or 0)
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
    closeMenu(false)
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
    closeMenu(false)
end)

RegisterCommand('ticket', function()
    TriggerServerEvent('driftzone_tickets:server:refreshState')
    TriggerServerEvent('driftzone_tickets:server:open')
end, false)

RegisterCommand('tickets', function()
    TriggerServerEvent('driftzone_tickets:server:refreshState')
    TriggerServerEvent('driftzone_tickets:server:open')
end, false)

RegisterCommand('tikcet', function()
    TriggerServerEvent('driftzone_tickets:server:refreshState')
    TriggerServerEvent('driftzone_tickets:server:open')
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
                closeMenu(true)
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
        Wait(5000)
    end
end)
