local Tickets = {}
local NextTicketId = 1

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function cleanText(value, maxLength)
    value = tostring(value or '')
        :gsub('[\r\n\t]', ' ')
        :gsub('%c', '')
        :gsub('%s+', ' ')

    value = trim(value)

    return value:sub(1, maxLength or 160)
end

local function isDutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true'
end

local function getUid(src)
    local state = Player(src).state

    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local ok, uid = pcall(function()
        return exports.driftzone_auth:GetUID(src)
    end)

    if ok and tonumber(uid) and tonumber(uid) > 0 then
        return tonumber(uid)
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state

    if state and state.dz_logged == true then
        return true
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:IsLoggedIn(src)
    end)

    return ok and result == true
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then return nil end

    local row = MySQL.single.await(
        ('SELECT `%s` AS uid, username, `%s` AS admin_level, `%s` AS aduty FROM `%s` WHERE `%s` = ? LIMIT 1'):format(
            Config.UsersIdColumn,
            Config.AdminLevelColumn,
            Config.AdminDutyColumn,
            Config.UsersTable,
            Config.UsersIdColumn
        ),
        { uid }
    )

    if not row then return nil end

    local level = tonumber(row.admin_level or 0) or 0

    return {
        uid = uid,
        username = row.username or getPlayerNameSafe(src),
        level = level,
        aduty = isDutyValue(row.aduty),
        rankName = Config.AdminRanks[level] or 'Staff'
    }
end

local function isStaffOnDuty(src)
    local data = getAdminData(src)

    if not data then return false, nil end

    if data.level < (Config.MinAdminLevel or 1) then
        return false, data
    end

    if Config.RequireAduty == true and not data.aduty then
        return false, data
    end

    return true, data
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then return nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getUid(src) == uid then
            return src
        end
    end

    return nil
end

local function getTicketByPlayerUid(uid)
    uid = tonumber(uid)

    for _, ticket in pairs(Tickets) do
        if tonumber(ticket.playerUid) == uid then
            return ticket
        end
    end

    return nil
end

local function getTicketList()
    local list = {}

    for _, ticket in pairs(Tickets) do
        list[#list + 1] = {
            id = ticket.id,
            playerName = ticket.playerName,
            playerUid = ticket.playerUid,
            title = ticket.title,
            subject = ticket.subject,
            createdAt = ticket.createdAt
        }
    end

    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list
end

local function sendCountTo(src)
    local ok = false

    pcall(function()
        ok = isStaffOnDuty(src)
    end)

    TriggerClientEvent('driftzone_tickets:client:count', src, ok and #getTicketList() or 0)
end

local function updateAdminCounters()
    local count = #getTicketList()

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        if src then
            local ok = false

            pcall(function()
                ok = isStaffOnDuty(src)
            end)

            TriggerClientEvent('driftzone_tickets:client:count', src, ok and count or 0)
        end
    end
end

local function createLog(eventName, data)
    pcall(function()
        TriggerEvent('logs:create', eventName, json.encode(data or {}))
    end)
end

local function teleportAdminToPlayer(adminSrc, targetSrc)
    local adminPed = GetPlayerPed(adminSrc)
    local targetPed = GetPlayerPed(targetSrc)

    if not adminPed or adminPed == 0 or not targetPed or targetPed == 0 then
        return false
    end

    local coords = GetEntityCoords(targetPed)
    local bucket = GetPlayerRoutingBucket(targetSrc)

    -- Fix: inainte teleporta o data instant si inca o data dupa 300ms.
    -- Acum face un singur teleport, dar pastreaza routing bucket-ul corect.
    SetPlayerRoutingBucket(adminSrc, bucket)
    SetEntityCoords(adminPed, coords.x + 1.3, coords.y + 1.3, coords.z + 0.2, false, false, false, false)
    SetEntityHeading(adminPed, GetEntityHeading(targetPed))

    return true
end

local function openTicketMenu(src)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat ca sa folosesti /ticket.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local staff = isStaffOnDuty(src)

    if staff then
        TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
        return
    end

    if getTicketByPlayerUid(uid) then
        notify(src, 'warning', 'Ai deja un ticket activ.')
        return
    end

    TriggerClientEvent('driftzone_tickets:client:openUser', src)
end

local function cancelTicket(src)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local ticket = getTicketByPlayerUid(uid)

    if not ticket then
        notify(src, 'warning', 'Nu ai niciun ticket activ.')
        return
    end

    Tickets[ticket.id] = nil

    notify(src, 'info', 'Ai anulat ticket-ul.')
    TriggerClientEvent('driftzone_tickets:client:close', src)

    updateAdminCounters()
end

RegisterNetEvent('driftzone_tickets:server:open', function()
    openTicketMenu(source)
end)

RegisterNetEvent('driftzone_tickets:server:cancel', function()
    cancelTicket(source)
end)

RegisterNetEvent('driftzone_tickets:server:requestCount', function()
    sendCountTo(source)
end)

RegisterNetEvent('driftzone_tickets:server:closed', function()
end)

RegisterNetEvent('driftzone_tickets:server:create', function(payload)
    local src = source

    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat ca sa creezi ticket.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local staff = isStaffOnDuty(src)

    if staff then
        notify(src, 'warning', 'Adminii ON DUTY nu pot crea ticket.')
        return
    end

    if getTicketByPlayerUid(uid) then
        notify(src, 'warning', 'Ai deja un ticket activ.')
        return
    end

    local data = payload

    if type(data) == 'string' then
        local ok, decoded = pcall(json.decode, data)
        data = ok and decoded or {}
    end

    if type(data) ~= 'table' then
        data = {}
    end

    local title = cleanText(data.title, Config.MaxTitleLength or 80)
    local subject = cleanText(data.subject, Config.MaxSubjectLength or 500)

    if title == '' then
        notify(src, 'warning', 'Titlul este obligatoriu.')
        return
    end

    if subject == '' then
        notify(src, 'warning', 'Subiectul este obligatoriu.')
        return
    end

    local ticket = {
        id = NextTicketId,
        playerSrc = src,
        playerName = getPlayerNameSafe(src),
        playerUid = uid,
        title = title,
        subject = subject,
        createdAt = os.date('%d.%m.%Y %H:%M')
    }

    NextTicketId = NextTicketId + 1
    Tickets[ticket.id] = ticket

    notify(src, 'info', 'Ai creat un ticket cu succes.')
    TriggerClientEvent('driftzone_tickets:client:close', src)

    updateAdminCounters()

    for _, id in ipairs(GetPlayers()) do
        local adminSrc = tonumber(id)
        if adminSrc then
            local ok = false
            pcall(function()
                ok = isStaffOnDuty(adminSrc)
            end)

            if ok then
                notify(adminSrc, 'info', ('Ticket nou #%s de la %s (%s).'):format(ticket.id, ticket.playerName, ticket.playerUid), 6000)
            end
        end
    end
end)

RegisterNetEvent('driftzone_tickets:server:accept', function(ticketId)
    local src = source
    local allowed, adminData = isStaffOnDuty(src)

    if not allowed then
        notify(src, 'warning', 'Trebuie sa fii staff ON DUTY.')
        return
    end

    local id = tonumber(ticketId or 0) or 0
    local ticket = Tickets[id]

    if not ticket then
        notify(src, 'warning', 'Ticket-ul nu mai exista.')
        TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
        updateAdminCounters()
        return
    end

    local target = getPlayerByUid(ticket.playerUid)

    if not target then
        Tickets[id] = nil
        notify(src, 'warning', 'Jucatorul nu mai este online.')
        TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
        updateAdminCounters()
        return
    end

    teleportAdminToPlayer(src, target)

    notify(target, 'info', ('Ticket-ul tau a fost preluat de %s (%s).'):format(getPlayerNameSafe(src), adminData.uid), 7000)
    notify(src, 'info', ('Ai preluat ticket-ul #%s.'):format(id))

    local targetPed = GetPlayerPed(target)
    local coords = targetPed ~= 0 and GetEntityCoords(targetPed) or vector3(0, 0, 0)

    createLog('acceptedtickets_logs', {
        ticket_id = id,
        player_name = ticket.playerName,
        player_uid = ticket.playerUid,
        admin_name = getPlayerNameSafe(src),
        admin_uid = adminData.uid,
        admin_level = adminData.level,
        title = ticket.title,
        subject = ticket.subject,
        player_x = coords.x,
        player_y = coords.y,
        player_z = coords.z
    })

    Tickets[id] = nil

    TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
    updateAdminCounters()
end)

RegisterNetEvent('driftzone_tickets:server:delete', function(ticketId)
    local src = source
    local allowed, adminData = isStaffOnDuty(src)

    if not allowed then
        notify(src, 'warning', 'Trebuie sa fii staff ON DUTY.')
        return
    end

    local id = tonumber(ticketId or 0) or 0
    local ticket = Tickets[id]

    if not ticket then
        notify(src, 'warning', 'Ticket-ul nu mai exista.')
        TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
        updateAdminCounters()
        return
    end

    local target = getPlayerByUid(ticket.playerUid)

    if target then
        notify(target, 'error', 'Ticket-ul tau a fost sters de un admin.')
    end

    createLog('deletedtickets_logs', {
        ticket_id = id,
        player_name = ticket.playerName,
        player_uid = ticket.playerUid,
        admin_name = getPlayerNameSafe(src),
        admin_uid = adminData.uid,
        admin_level = adminData.level,
        title = ticket.title,
        subject = ticket.subject,
        reason = 'Deleted by admin'
    })

    Tickets[id] = nil

    notify(src, 'info', 'Ai sters ticket-ul.')
    TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
    updateAdminCounters()
end)

RegisterNetEvent('driftzone_tickets:server:teleport', function(ticketId)
    local src = source
    local allowed = isStaffOnDuty(src)

    if not allowed then
        notify(src, 'warning', 'Trebuie sa fii staff ON DUTY.')
        return
    end

    local id = tonumber(ticketId or 0) or 0
    local ticket = Tickets[id]

    if not ticket then
        notify(src, 'warning', 'Ticket-ul nu mai exista.')
        TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
        updateAdminCounters()
        return
    end

    local target = getPlayerByUid(ticket.playerUid)

    if not target then
        Tickets[id] = nil
        notify(src, 'warning', 'Jucatorul nu mai este online.')
        TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
        updateAdminCounters()
        return
    end

    teleportAdminToPlayer(src, target)
    notify(src, 'info', ('Te-ai teleportat la %s (%s).'):format(ticket.playerName, ticket.playerUid))
end)

RegisterCommand('ticket', function(src)
    if src == 0 then return end
    openTicketMenu(src)
end, false)

RegisterCommand('tickets', function(src)
    if src == 0 then return end
    openTicketMenu(src)
end, false)

RegisterCommand('cancelticket', function(src)
    if src == 0 then return end
    cancelTicket(src)
end, false)

exports('OpenTickets', function(src)
    openTicketMenu(src)
end)

exports('CancelTicket', function(src)
    cancelTicket(src)
end)

exports('GetTickets', function()
    return getTicketList()
end)

exports('RunCommand', function(src, command)
    command = tostring(command or ''):lower()

    if command == 'ticket' or command == 'tickets' then
        return openTicketMenu(src)
    end

    if command == 'cancelticket' then
        return cancelTicket(src)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getUid(src)

    if not uid then return end

    local ticket = getTicketByPlayerUid(uid)

    if ticket then
        Tickets[ticket.id] = nil
        updateAdminCounters()
    end
end)

CreateThread(function()
    Wait(500)
    print('[DRIFTZONE_TICKETS] Server-side loaded. Modern UI + single teleport fix.')

    while true do
        updateAdminCounters()
        Wait(Config.CounterRefreshMs or 5000)
    end
end)
