local UidCache = {}
local MetaCache = {}
local MutedPlayers = {}
local DisabledPlayers = {}
local CommandRouteCache = nil

local GlobalChatEnabled = true
local GlobalChatLocked = false

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function adutyValue(value)
    if value == true then return true end
    if value == false or value == nil then return false end

    local text = tostring(value):lower()
    return text == '1' or text == 'true' or text == 'yes' or text == 'on'
end

local function cleanText(text, maxLength)
    local value = tostring(text or '')

    value = value:gsub('!%{[^}]*%}', '')
    value = value:gsub('[\r\n\t]', ' ')
    value = value:gsub('%c', '')
    value = value:gsub('%s+', ' ')
    value = trim(value)

    return value:sub(1, maxLength or 160)
end

local function getChatConfig(key, fallback)
    if Config and Config.Chat and Config.Chat[key] ~= nil then
        return Config.Chat[key]
    end

    return fallback
end

local function debugPrint(...)
    if Config and Config.Debug then
        print('[DRIFTZONE_CHAT]', ...)
    end
end

local function getAdminRanks()
    if Config and Config.AdminRanks then
        return Config.AdminRanks
    end

    return {}
end

local function sanitizeHexColor(value, fallback)
    local raw = trim(value):gsub('#', '')

    if raw:match('^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return '#' .. raw
    end

    if raw:match('^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return '#' .. raw
    end

    return fallback or '#cbd5e1'
end

local function getTimeString()
    return os.date('%H:%M')
end

local function getPlayerNameSafe(src)
    return cleanText(GetPlayerName(src) or 'Player', getChatConfig('MaxNameLength', 32))
end

local function isLoggedIn(src)
    local state = Player(src).state

    if state and state.dz_logged == true then
        return true
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:IsLoggedIn(src)
    end)

    return ok and result == true
end

local function getAuthUID(src)
    local state = Player(src).state

    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:GetUID(src)
    end)

    if ok and tonumber(result) and tonumber(result) > 0 then
        return tonumber(result)
    end

    return nil
end

local function isChatEnabledFor(src)
    if not GlobalChatEnabled then return false end
    if DisabledPlayers[src] == true then return false end

    return true
end

local function isMuted(src)
    return MutedPlayers[src] == true
end

local function sendToClient(src, payload)
    TriggerClientEvent('driftzone_chat:client:addMessage', src, payload)
end

local function sendError(src, text)
    sendToClient(src, {
        type = 'error',
        time = getTimeString(),
        text = cleanText(text, 240)
    })
end

local function sendSystem(src, text)
    sendToClient(src, {
        type = 'system',
        time = getTimeString(),
        text = cleanText(text, 240)
    })
end

local function sendSystemMessage(text)
    local payload = {
        type = 'system',
        time = getTimeString(),
        text = cleanText(text, 240)
    }

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        if src and isLoggedIn(src) and isChatEnabledFor(src) then
            sendToClient(src, payload)
        end
    end
end

local function broadcast(payload)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        if src and isLoggedIn(src) and isChatEnabledFor(src) then
            sendToClient(src, payload)
        end
    end
end

local function getPlayerUid(src)
    local now = GetGameTimer()
    local cached = UidCache[src]

    if cached and cached.uid and cached.expires > now then
        return cached.uid
    end

    local authUid = getAuthUID(src)

    if authUid then
        UidCache[src] = {
            uid = authUid,
            expires = now + getChatConfig('UidCacheMs', 30000)
        }
        return authUid
    end

    local name = GetPlayerName(src)

    if not name or name == '' then
        return nil
    end

    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT uid FROM users WHERE username = ? LIMIT 1',
            { name }
        )
    end)

    if not ok or not row then return nil end

    local uid = tonumber(row.uid)

    if not uid or uid <= 0 then return nil end

    UidCache[src] = {
        uid = uid,
        expires = now + getChatConfig('UidCacheMs', 30000)
    }

    return uid
end

local function invalidateSourceMeta(src)
    src = tonumber(src)
    if not src then return end

    local cached = UidCache[src]
    local uid = cached and cached.uid or nil

    if not uid then
        uid = getAuthUID(src)
    end

    if uid then
        MetaCache[uid] = nil
    end
end

local function getAdminLevelFromState(src)
    local state = Player(src).state

    if state and tonumber(state.dz_admin_level) then
        return tonumber(state.dz_admin_level) or 0
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:GetAdminLevel(src)
    end)

    if ok and tonumber(result) then
        return tonumber(result) or 0
    end

    return 0
end

local function getAdutyFromState(src)
    local state = Player(src).state

    -- Important:
    -- Daca dz_aduty exista in state, il folosim direct.
    -- Inainte, cand era false/no, functia cadea pe export si putea lua valoare veche,
    -- de aici ramanea gradul de staff in chat dupa /aduty off.
    if state and state.dz_aduty ~= nil then
        return adutyValue(state.dz_aduty)
    end

    local ok, result = pcall(function()
        return exports.driftzone_auth:IsAdminDuty(src)
    end)

    if ok then
        return adutyValue(result)
    end

    return false
end

local function getPlayerChatMeta(src, uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then
        return {
            admin = nil,
            rank = nil
        }
    end

    -- LIVE CHECK:
    -- Nu mai folosim MetaCache pentru admin/aduty/rank la trimiterea mesajului.
    -- Asa daca adminul da /aduty no, urmatorul mesaj nu mai afiseaza gradul.
    local meta = {
        admin = nil,
        rank = nil
    }

    local adminLevel = getAdminLevelFromState(src)
    local aduty = getAdutyFromState(src)
    local adminRanks = getAdminRanks()
    local adminInfo = adminRanks[adminLevel]

    if adminInfo and aduty then
        meta.admin = {
            level = adminLevel,
            label = adminInfo.label,
            color = adminInfo.color
        }
    end

    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT rank, rankcolor FROM users WHERE uid = ? LIMIT 1',
            { uid }
        )
    end)

    if ok and row then
        local rankText = cleanText(row.rank or '', 32)
        local rankColor = sanitizeHexColor(row.rankcolor or '', '#cbd5e1')

        if rankText ~= '' then
            meta.rank = {
                label = rankText,
                color = rankColor
            }
        end
    end

    return meta
end

local function splitCommand(commandLine)
    local args = {}

    for word in tostring(commandLine or ''):gmatch('%S+') do
        args[#args + 1] = word
    end

    local command = string.lower(args[1] or '')

    if command == '' then
        return '', {}
    end

    table.remove(args, 1)

    return command, args
end

local function getCommandRoutes()
    if CommandRouteCache then return CommandRouteCache end

    CommandRouteCache = {}

    local routes = Config and Config.CommandRoutes or {}

    for resourceName, commands in pairs(routes) do
        if type(commands) == 'table' then
            for _, command in ipairs(commands) do
                command = tostring(command or ''):lower()
                if command ~= '' then
                    CommandRouteCache[command] = resourceName
                end
            end
        end
    end

    return CommandRouteCache
end

local function runExportCommand(src, resourceName, command, args)
    local state = GetResourceState(resourceName)

    if state ~= 'started' and state ~= 'starting' then
        sendError(src, ('Resource-ul %s nu este pornit.'):format(resourceName))
        return true
    end

    local ok, result = pcall(function()
        return exports[resourceName]:RunCommand(src, command, args or {})
    end)

    if ok then
        if command == 'aduty' or command == 'duty' then
            invalidateSourceMeta(src)
            SetTimeout(250, function()
                invalidateSourceMeta(src)
            end)
            SetTimeout(1000, function()
                invalidateSourceMeta(src)
            end)
        end

        return true
    end

    print(('[DRIFTZONE_CHAT] /%s export error from %s:'):format(command, resourceName))
    print(result)

    local fallbackOk, fallbackErr = pcall(function()
        TriggerEvent(('%s:server:runFromChat'):format(resourceName), src, command, args or {})
    end)

    if not fallbackOk then
        print(('[DRIFTZONE_CHAT] /%s fallback error from %s:'):format(command, resourceName))
        print(fallbackErr)
        sendError(src, ('Eroare la /%s. Verifica %s.'):format(command, resourceName))
    end

    return true
end

local function runSpecialCommand(src, command, args)
    local specials = Config and Config.SpecialCommands or {}
    local special = specials[command]

    if not special then return false end

    local resourceName, exportName = tostring(special):match('^([^:]+):(.+)$')

    if not resourceName or not exportName then
        sendError(src, 'Special command invalid in config.')
        return true
    end

    if GetResourceState(resourceName) ~= 'started' then
        sendError(src, ('Resource-ul %s nu este pornit.'):format(resourceName))
        return true
    end

    local ok, err = pcall(function()
        exports[resourceName][exportName](src, table.unpack(args or {}))
    end)

    if not ok then
        print(('[DRIFTZONE_CHAT] /%s special command error:'):format(command))
        print(err)
        sendError(src, ('Eroare la /%s.'):format(command))
    end

    return true
end

local function executeClientCommand(src, commandLine)
    -- Fallback universal:
    -- orice resource care are RegisterCommand pe CLIENT va merge fara sa mai fie bagat in chat.
    TriggerClientEvent('driftzone_chat:client:executeCommand', src, commandLine)
end

local function handleCommand(src, rawText)
    local commandLine = trim(rawText:sub(2))

    if commandLine == '' then return end

    local command, args = splitCommand(commandLine)

    if command == '' then return end

    local routes = getCommandRoutes()
    local resourceName = routes[command]

    if resourceName then
        runExportCommand(src, resourceName, command, args)
        return
    end

    if runSpecialCommand(src, command, args) then
        return
    end

    executeClientCommand(src, commandLine)
end

local function handleInput(src, input)
    local rawText = trim(input)

    if rawText == '' then return end

    if rawText:sub(1, 1) == '/' then
        handleCommand(src, rawText)
        return
    end

    if not isLoggedIn(src) then
        sendError(src, 'Trebuie sa fii logat.')
        return
    end

    if not isChatEnabledFor(src) then
        return
    end

    if isMuted(src) then
        sendError(src, 'Esti muted.')
        return
    end

    local message = cleanText(rawText, getChatConfig('MaxMessageLength', 160))

    if message == '' then return end

    local uid = getPlayerUid(src)

    if not uid then
        sendError(src, 'Nu ti-am gasit ID-ul.')
        return
    end

    MetaCache[uid] = nil
    local meta = getPlayerChatMeta(src, uid)

    if GlobalChatLocked and not meta.admin then
        sendError(src, 'Chat-ul este blocat.')
        return
    end

    broadcast({
        type = 'chat',
        time = getTimeString(),
        uid = uid,
        name = getPlayerNameSafe(src),
        text = message,
        admin = meta.admin,
        rank = meta.rank
    })
end

RegisterNetEvent('driftzone_chat:server:submit', function(input)
    local src = source

    local ok, err = pcall(function()
        handleInput(src, input)
    end)

    if not ok then
        print('[DRIFTZONE_CHAT] Input error:')
        print(err)

        sendError(src, 'Eroare server.')
    end
end)

RegisterNetEvent('driftzone_chat:server:requestStart', function()
    local src = source

    TriggerClientEvent('driftzone_chat:client:setEnabled', src, GlobalChatEnabled and not DisabledPlayers[src])
    TriggerClientEvent('driftzone_chat:client:setMuted', src, MutedPlayers[src] == true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local cached = UidCache[src]
    local uid = cached and cached.uid or nil

    if uid then
        MetaCache[uid] = nil
    end

    UidCache[src] = nil
    MutedPlayers[src] = nil
    DisabledPlayers[src] = nil
end)

RegisterNetEvent('driftzone_chat:server:invalidateMeta', function(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then return end

    MetaCache[uid] = nil
end)

RegisterNetEvent('driftchat:clearAll', function()
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('driftzone_chat:client:clear', tonumber(id))
    end
end)

RegisterNetEvent('driftchat:clearPlayer', function(target)
    target = tonumber(target)

    if not target then return end

    TriggerClientEvent('driftzone_chat:client:clear', target)
end)

RegisterNetEvent('driftchat:setEnabledAll', function(enabled)
    GlobalChatEnabled = enabled == true

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        TriggerClientEvent('driftzone_chat:client:setEnabled', src, GlobalChatEnabled and not DisabledPlayers[src])
    end
end)

RegisterNetEvent('driftchat:setEnabledPlayer', function(target, enabled)
    target = tonumber(target)

    if not target then return end

    if enabled == true then
        DisabledPlayers[target] = nil
    else
        DisabledPlayers[target] = true
    end

    TriggerClientEvent('driftzone_chat:client:setEnabled', target, GlobalChatEnabled and not DisabledPlayers[target])
end)

RegisterNetEvent('driftchat:setMutedPlayer', function(target, muted)
    target = tonumber(target)

    if not target then return end

    MutedPlayers[target] = muted == true

    TriggerClientEvent('driftzone_chat:client:setMuted', target, MutedPlayers[target])
end)

RegisterNetEvent('driftchat:systemMessage', function(text)
    sendSystemMessage(text)
end)

RegisterNetEvent('driftchat:toggleLock', function(adminName, adminUid)
    GlobalChatLocked = not GlobalChatLocked

    local stateText = GlobalChatLocked and 'blocat' or 'deblocat'

    sendSystemMessage(
        ('Chat-ul a fost %s de catre admin-ul %s (%s)!'):format(
            stateText,
            tostring(adminName or 'Admin'),
            tostring(adminUid or '?')
        )
    )
end)


RegisterNetEvent('driftzone_chat:server:invalidateSourceMeta', function(target)
    local src = tonumber(target) or source
    invalidateSourceMeta(src)
end)

RegisterNetEvent('driftzone_chat:server:refreshMyMeta', function()
    invalidateSourceMeta(source)
end)

-- Actualizeaza imediat badge-ul de staff cand se schimba aduty/admin_level in Player state.
-- Asta pastreaza chat-ul optimizat, dar nu lasa MetaCache-ul sa ramana vechi.
AddStateBagChangeHandler('dz_aduty', nil, function(bagName)
    local src = tonumber(bagName:match('player:(%d+)') or '')

    if src then
        invalidateSourceMeta(src)
    end
end)

AddStateBagChangeHandler('dz_admin_level', nil, function(bagName)
    local src = tonumber(bagName:match('player:(%d+)') or '')

    if src then
        invalidateSourceMeta(src)
    end
end)

AddStateBagChangeHandler('dz_uid', nil, function(bagName)
    local src = tonumber(bagName:match('player:(%d+)') or '')

    if src then
        UidCache[src] = nil
        invalidateSourceMeta(src)
    end
end)

exports('ClearPlayerChat', function(target)
    TriggerClientEvent('driftzone_chat:client:clear', tonumber(target))
end)

exports('ClearAllChats', function()
    TriggerEvent('driftchat:clearAll')
end)

exports('SetPlayerChatEnabled', function(target, enabled)
    TriggerEvent('driftchat:setEnabledPlayer', target, enabled)
end)

exports('SetGlobalChatEnabled', function(enabled)
    TriggerEvent('driftchat:setEnabledAll', enabled)
end)

exports('SetPlayerMuted', function(target, muted)
    TriggerEvent('driftchat:setMutedPlayer', target, muted)
end)

exports('IsMuted', function(target)
    return MutedPlayers[tonumber(target)] == true
end)

exports('IsChatEnabled', function(target)
    return isChatEnabledFor(tonumber(target))
end)

exports('HandleCommand', function(src, rawText)
    return handleCommand(src, rawText)
end)

exports('SendSystem', function(src, text)
    return sendSystem(src, text)
end)

exports('SendError', function(src, text)
    return sendError(src, text)
end)

exports('ReloadCommandRoutes', function()
    CommandRouteCache = nil
    return true
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        CommandRouteCache = nil
        print('[DRIFTZONE_CHAT] Server-side loaded.')
    else
        -- Daca pornesti un resource dupa chat, nu trebuie restart la chat pentru fallback client.
        CommandRouteCache = nil
    end
end)
