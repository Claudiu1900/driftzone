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
    -- FIX FINAL:
    -- ON DUTY = users.aduty = 1
    -- OFF DUTY = users.aduty = 0
    -- Acceptam si valori text pentru compatibilitate.
    if value == true then return true end

    local n = tonumber(value)
    if n ~= nil then
        return n == 1
    end

    local text = tostring(value or ''):lower():gsub('%s+', '')
    return text == 'yes' or text == 'true' or text == 'on'
end

local function getPlayerNameSafe(src)
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

local function getIdentifierMap(src)
    local ids = {}

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        local key, value = tostring(identifier):match('^([^:]+):(.+)$')

        if key and value then
            ids[key] = value
            ids[key .. '_full'] = tostring(identifier)
        end
    end

    return ids
end

local function getUidFromState(src)
    local state = Player(src).state
    if not state then return nil end

    local keys = {
        'dz_uid',
        'uid',
        'user_id',
        'userId'
    }

    for i = 1, #keys do
        local value = state[keys[i]]
        if tonumber(value) and tonumber(value) > 0 then
            return tonumber(value)
        end
    end

    return nil
end

local function getUidFromExports(src)
    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end,
        function() return exports.driftzone_auth:getUserId(src) end,
        function() return exports.driftzone_auth:GetPlayerUID(src) end,
        function() return exports.driftzone_auth:getPlayerUID(src) end
    }

    for i = 1, #attempts do
        local ok, uid = pcall(attempts[i])

        if ok and tonumber(uid) and tonumber(uid) > 0 then
            return tonumber(uid)
        end
    end

    return nil
end

local function queryUidByColumn(tableName, uidColumn, column, value)
    if not value or value == '' then return nil end

    local ok, row = pcall(function()
        return MySQL.single.await(
            ('SELECT `%s` AS uid FROM `%s` WHERE `%s` = ? LIMIT 1'):format(uidColumn, tableName, column),
            { value }
        )
    end)

    if ok and row and tonumber(row.uid) then
        return tonumber(row.uid)
    end

    return nil
end

local function getUidFromIdentifiers(src)
    local tableName = Config.UsersTable or 'users'
    local uidColumn = Config.UsersIdColumn or 'uid'
    local ids = getIdentifierMap(src)
    local playerName = getPlayerNameSafe(src)

    local checks = {
        { column = 'license', values = { ids.license_full, ids.license } },
        { column = 'identifier', values = { ids.license_full, ids.license, ids.steam_full, ids.steam } },
        { column = 'steam', values = { ids.steam_full, ids.steam } },
        { column = 'discord', values = { ids.discord_full, ids.discord } },
        { column = 'fivem', values = { ids.fivem_full, ids.fivem } },
        { column = 'username', values = { playerName } }
    }

    for _, check in ipairs(checks) do
        for _, value in ipairs(check.values or {}) do
            local uid = queryUidByColumn(tableName, uidColumn, check.column, value)
            if uid then return uid end
        end
    end

    return nil
end

local function getUid(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return nil end

    return getUidFromState(src) or getUidFromExports(src) or getUidFromIdentifiers(src)
end

local function getSafeTicketUid(src)
    -- Pentru deschidere/creare ticket, nu blocam complet daca auth-ul intarzie.
    -- Daca UID-ul real lipseste, folosim source temporar ca sa se deschida UI-ul.
    return getUid(src) or tonumber(src)
end

local function isLogged(src)
    local state = Player(src).state

    if state and (state.dz_logged == true or state.logged == true or state.isLoggedIn == true) then
        return true
    end

    local attempts = {
        function() return exports.driftzone_auth:IsLoggedIn(src) end,
        function() return exports.driftzone_auth:isLoggedIn(src) end,
        function() return exports.driftzone_auth:IsLogged(src) end
    }

    for i = 1, #attempts do
        local ok, result = pcall(attempts[i])

        if ok and result == true then
            return true
        end
    end

    -- Fix: dupa /aduty off unele auth-uri nu mai raspund true, dar UID-ul exista.
    -- Nu blocam /ticket din cauza asta.
    return getSafeTicketUid(src) ~= nil
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then
        return nil, 'uid_missing'
    end

    local tableName = Config.UsersTable or 'users'
    local uidColumn = Config.UsersIdColumn or 'uid'
    local adminColumn = Config.AdminLevelColumn or 'admin_level'
    local adutyColumn = Config.AdminDutyColumn or 'aduty'

    local ok, row = pcall(function()
        return MySQL.single.await(
            ('SELECT `%s` AS uid, username, `%s` AS admin_level, `%s` AS aduty FROM `%s` WHERE `%s` = ? LIMIT 1'):format(
                uidColumn,
                adminColumn,
                adutyColumn,
                tableName,
                uidColumn
            ),
            { uid }
        )
    end)

    if not ok then
        print('[DRIFTZONE_TICKETS] getAdminData query failed: ' .. tostring(row))
        return nil, 'query_failed'
    end

    if not row then
        return nil, 'row_missing'
    end

    local level = tonumber(row.admin_level or 0) or 0

    return {
        uid = tonumber(row.uid or uid) or uid,
        username = row.username or getPlayerNameSafe(src),
        level = level,
        aduty = isDutyValue(row.aduty),
        rankName = Config.AdminRanks[level] or 'Staff'
    }, nil
end

local function isStaff(src)
    local data = getAdminData(src)
    return data ~= nil and data.level >= (Config.MinAdminLevel or 1), data
end

local function isStaffOnDuty(src)
    local data, reason = getAdminData(src)

    if not data then
        return false, nil, reason
    end

    if data.level < (Config.MinAdminLevel or 1) then
        return false, data, 'low_admin'
    end

    if Config.RequireAduty == true and not data.aduty then
        return false, data, 'off_duty'
    end

    return true, data, nil
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then return nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getSafeTicketUid(src) == uid then
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
    local allowed = false

    pcall(function()
        allowed = isStaffOnDuty(src) == true
    end)

    TriggerClientEvent('driftzone_tickets:client:count', src, allowed and #getTicketList() or 0)
end

local function updateAdminCounters()
    local count = #getTicketList()

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        if src then
            local allowed = false

            pcall(function()
                allowed = isStaffOnDuty(src) == true
            end)

            TriggerClientEvent('driftzone_tickets:client:count', src, allowed and count or 0)
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

    SetPlayerRoutingBucket(adminSrc, bucket)
    SetEntityCoords(adminPed, coords.x + 1.3, coords.y + 1.3, coords.z + 0.2, false, false, false, false)
    SetEntityHeading(adminPed, GetEntityHeading(targetPed))

    return true
end

local function openTicketMenu(src)
    -- FIX FINAL:
    -- /ticket trebuie sa mearga mereu:
    -- aduty = 1 => staff panel
    -- aduty = 0 => player ticket panel
    local uid = getSafeTicketUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local onDuty, adminData, reason = isStaffOnDuty(src)

    if onDuty then
        TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
        sendCountTo(src)
        return
    end

    -- Daca este admin OFF DUTY, curatam counter-ul si il tratam ca player normal.
    if adminData and reason == 'off_duty' then
        TriggerClientEvent('driftzone_tickets:client:count', src, 0)
    end

    if getTicketByPlayerUid(uid) then
        notify(src, 'warning', 'Ai deja un ticket activ.')
        return
    end

    TriggerClientEvent('driftzone_tickets:client:openUser', src)
end

local function cancelTicket(src)
    local uid = getSafeTicketUid(src)

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

RegisterNetEvent('driftzone_tickets:server:refreshState', function()
    sendCountTo(source)
end)

RegisterNetEvent('driftzone_tickets:server:closed', function()
end)

RegisterNetEvent('driftzone_tickets:server:create', function(payload)
    local src = source
    local uid = getSafeTicketUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local staffOnDuty = isStaffOnDuty(src)

    if staffOnDuty then
        notify(src, 'warning', 'Adminii ON DUTY nu pot crea ticket. Da /aduty off daca vrei sa creezi ticket ca player.')
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
            local allowed = false

            pcall(function()
                allowed = isStaffOnDuty(adminSrc) == true
            end)

            if allowed then
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

    createLog('deletetickets_logs', {
        ticket_id = id,
        player_name = ticket.playerName,
        player_uid = ticket.playerUid,
        admin_name = getPlayerNameSafe(src),
        admin_uid = adminData.uid,
        admin_level = adminData.level,
        title = ticket.title,
        subject = ticket.subject
    })

    Tickets[id] = nil

    TriggerClientEvent('driftzone_tickets:client:openAdmin', src, getTicketList())
    updateAdminCounters()
end)

RegisterNetEvent('driftzone_tickets:server:teleport', function(ticketId)
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

RegisterCommand('tikcet', function(src)
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
    command = tostring(command or ''):lower():gsub('^/', '')

    if command == 'ticket' or command == 'tickets' or command == 'tikcet' then
        openTicketMenu(src)
        return true
    end

    if command == 'cancelticket' then
        cancelTicket(src)
        return true
    end

    return false
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getSafeTicketUid(src)

    if not uid then return end

    local ticket = getTicketByPlayerUid(uid)

    if ticket then
        Tickets[ticket.id] = nil
        updateAdminCounters()
    end
end)

CreateThread(function()
    Wait(500)
    print('[DRIFTZONE_TICKETS] Server-side loaded. FINAL aduty 1/0 fix.')

    while true do
        updateAdminCounters()
        Wait(Config.CounterRefreshMs or 5000)
    end
end)
