local LoggedPlayers = {}
local LastSavedPositions = {}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function notifyAuth(src, message)
    TriggerClientEvent('driftzone_auth:client:status', src, tostring(message or 'Eroare'))
end

local function getIdentifier(src, prefix)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return ''
end

local function getPlayerIdentifiersData(src)
    return {
        license = getIdentifier(src, 'license:'),
        discord = getIdentifier(src, 'discord:'),
        steam = getIdentifier(src, 'steam:'),
        fivem = getIdentifier(src, 'fivem:')
    }
end

local function getPlayerIP(src)
    return tostring(GetPlayerEndpoint(src) or '')
end

local function getCleanPlayerName(src)
    return trim(GetPlayerName(src) or '')
end

local function isValidDriftZoneName(name)
    name = trim(name)

    if name == '' then
        return false, 'Numele tau este gol. Schimba numele din FiveM.'
    end

    if #name < 3 then
        return false, 'Numele trebuie sa aiba minim 3 caractere.'
    end

    if #name > 32 then
        return false, 'Numele trebuie sa aiba maxim 32 caractere.'
    end

    local allowed = name:match('^[A-Za-zĂÂÎȘȚăâîșț%.!]+$') ~= nil

    if not allowed then
        return false, 'Nume invalid. Foloseste doar litere, ! si . Schimba numele din FiveM.'
    end

    return true, ''
end

local function randomSalt(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local salt = {}

    for i = 1, length do
        local index = math.random(1, #chars)
        salt[#salt + 1] = chars:sub(index, index)
    end

    return table.concat(salt)
end

local function hashPassword(password, salt)
    return MySQL.scalar.await(
        'SELECT SHA2(CONCAT(@password, @salt), 256)',
        {
            ['@password'] = tostring(password or ''),
            ['@salt'] = tostring(salt or '')
        }
    )
end

local function validEmail(email)
    email = trim(email):lower()

    if email == '' then return false end
    if not email:find('@', 1, true) then return false end
    if not email:find('.', 1, true) then return false end
    if #email > 128 then return false end

    return true
end

local function parseLastpos(lastpos)
    if not lastpos or tostring(lastpos) == '' or tostring(lastpos) == 'none' then
        return Config.DefaultSpawn
    end

    local ok, decoded = pcall(json.decode, tostring(lastpos))

    if ok and type(decoded) == 'table' then
        local x = tonumber(decoded.x)
        local y = tonumber(decoded.y)
        local z = tonumber(decoded.z)
        local h = tonumber(decoded.h or decoded.heading or 0.0)

        if x and y and z then
            return {
                x = x,
                y = y,
                z = z,
                h = h or 0.0
            }
        end
    end

    return Config.DefaultSpawn
end

local function makeLastpos(coords, heading)
    return json.encode({
        x = tonumber(string.format('%.4f', coords.x)),
        y = tonumber(string.format('%.4f', coords.y)),
        z = tonumber(string.format('%.4f', coords.z)),
        h = tonumber(string.format('%.4f', heading or 0.0))
    })
end

local function distance(a, b)
    if not a or not b then return 999999.0 end

    local dx = (a.x or 0.0) - (b.x or 0.0)
    local dy = (a.y or 0.0) - (b.y or 0.0)
    local dz = (a.z or 0.0) - (b.z or 0.0)

    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function shouldSave(uid, coords, heading, force)
    if force then return true end

    local last = LastSavedPositions[uid]

    if not last then return true end

    if distance(last, coords) >= Config.MinPositionChange then
        return true
    end

    if math.abs((last.h or 0.0) - (heading or 0.0)) >= Config.MinHeadingChange then
        return true
    end

    return false
end

local function updateLastSaved(uid, coords, heading)
    LastSavedPositions[uid] = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading or 0.0
    }
end

local function getUserByUsername(username)
    username = trim(username)

    if username == '' then return nil end

    return MySQL.single.await(
        'SELECT * FROM users WHERE username = @username LIMIT 1',
        {
            ['@username'] = username
        }
    )
end

local function getUserByUid(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then return nil end

    return MySQL.single.await(
        'SELECT * FROM users WHERE uid = @uid LIMIT 1',
        {
            ['@uid'] = uid
        }
    )
end

local function getUserByEmail(email)
    email = trim(email):lower()

    if email == '' then return nil end

    return MySQL.single.await(
        'SELECT uid FROM users WHERE email = @email LIMIT 1',
        {
            ['@email'] = email
        }
    )
end


local function cleanIdentifier(value)
    value = trim(value)

    if value == '' or value == '0' or value == 'nil' or value == 'null' then
        return ''
    end

    return value
end

local function findDuplicateAccountByIdentity(username, ids, ip)
    username = trim(username)
    ids = ids or {}

    if username == '' then return nil end

    local payload = {
        ['@username'] = username:lower(),
        ['@license'] = cleanIdentifier(ids.license),
        ['@discord'] = cleanIdentifier(ids.discord),
        ['@steam'] = cleanIdentifier(ids.steam),
        ['@fivem'] = cleanIdentifier(ids.fivem),
        ['@ip'] = cleanIdentifier(ip)
    }

    local ok, row = pcall(function()
        return MySQL.single.await(
            [[
                SELECT
                    uid,
                    username,
                    CASE
                        WHEN @license <> '' AND license = @license THEN 'license'
                        WHEN @discord <> '' AND discord = @discord THEN 'discord'
                        WHEN @steam <> '' AND steam = @steam THEN 'steam'
                        WHEN @fivem <> '' AND fivem = @fivem THEN 'fivem'
                        WHEN @ip <> '' AND ip = @ip THEN 'ip'
                        ELSE 'unknown'
                    END AS match_field
                FROM users
                WHERE LOWER(username) <> @username
                  AND (
                        (@license <> '' AND license = @license)
                     OR (@discord <> '' AND discord = @discord)
                     OR (@steam <> '' AND steam = @steam)
                     OR (@fivem <> '' AND fivem = @fivem)
                     OR (@ip <> '' AND ip = @ip)
                  )
                ORDER BY uid ASC
                LIMIT 1
            ]],
            payload
        )
    end)

    if ok and row then
        return row
    end

    return nil
end

local function buildDuplicateAccountMessage(row)
    local field = tostring(row and row.match_field or 'cont'):lower()
    local niceField = ({
        license = 'licenta FiveM',
        discord = 'Discord',
        steam = 'Steam',
        fivem = 'FiveM ID',
        ip = 'IP'
    })[field] or 'identificator'

    return ('Ai deja un cont creat pe DriftZone.\nAm detectat acelasi %s pe un alt nume.\nContul tau este pe numele: %s\nSchimba-ti numele din FiveM pe numele contului tau si reconecteaza-te.'):format(
        niceField,
        trim(row and row.username) ~= '' and trim(row.username) or 'contul vechi'
    )
end

local function checkDuplicateAccountForSource(src, username)
    local ids = getPlayerIdentifiersData(src)
    local duplicate = findDuplicateAccountByIdentity(username, ids, getPlayerIP(src))

    if duplicate then
        return false, buildDuplicateAccountMessage(duplicate)
    end

    return true, ''
end


local function getTableColumns(tableName)
    local columns = {}
    tableName = tostring(tableName or ''):gsub('`', '')

    if tableName == '' then return columns end

    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(tableName), {}) or {}
    end)

    if not ok or type(rows) ~= 'table' then
        return columns
    end

    for _, row in ipairs(rows) do
        if row.Field then
            columns[tostring(row.Field)] = true
        end
    end

    return columns
end

local function randomVehiclePlate(prefix)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = tostring(prefix or 'DZ'):upper():gsub('[^A-Z0-9]', ''):sub(1, 3)

    if plate == '' then plate = 'DZ' end

    while #plate < 8 do
        local index = math.random(1, #chars)
        plate = plate .. chars:sub(index, index)
    end

    return plate:sub(1, 8)
end

local function plateExists(plate, plateColumn)
    plate = tostring(plate or '')
    plateColumn = tostring(plateColumn or 'vehicle_plate'):gsub('`', '')

    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT id FROM `ownedvehicles` WHERE `%s` = @plate LIMIT 1'):format(plateColumn), {
            ['@plate'] = plate
        })
    end)

    return ok and row ~= nil
end

local function generateUniquePlate(plateColumn)
    local prefix = Config.StarterVehicle and Config.StarterVehicle.platePrefix or 'DZ'

    for _ = 1, 60 do
        local plate = randomVehiclePlate(prefix)
        if not plateExists(plate, plateColumn) then
            return plate
        end
    end

    return randomVehiclePlate(prefix)
end

local function jsonEncodeSafe(value)
    local ok, encoded = pcall(json.encode, value or {})
    if ok and encoded then return encoded end
    return '{}'
end

local function giveStarterVehicle(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then return false end
    if not Config.StarterVehicle or Config.StarterVehicle.enabled ~= true then return true end

    local cols = getTableColumns('ownedvehicles')
    local insertColumns = {}
    local placeholders = {}
    local params = {}

    local function addColumn(column, value)
        if not cols[column] then return end
        insertColumns[#insertColumns + 1] = ('`%s`'):format(column)
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = value
    end

    local ownerColumn = cols.owner_id and 'owner_id' or (cols.user_id and 'user_id' or (cols.uid and 'uid' or nil))
    local modelColumn = cols.vehicle_model and 'vehicle_model' or (cols.model and 'model' or nil)
    local plateColumn = cols.vehicle_plate and 'vehicle_plate' or (cols.plate and 'plate' or nil)
    local tuningColumn = cols.vehicle_tunning and 'vehicle_tunning' or (cols.vehicle_tuning and 'vehicle_tuning' or (cols.tuning and 'tuning' or nil))

    if not ownerColumn or not modelColumn then
        print('[DRIFTZONE_AUTH] Nu pot da starter car: lipseste owner/model column in ownedvehicles.')
        return false
    end

    local model = tostring(Config.StarterVehicle.model or 'caddy'):lower():gsub('%s+', '')
    local plate = plateColumn and generateUniquePlate(plateColumn) or ''
    local tuning = jsonEncodeSafe(Config.StarterVehicle.tuning or {})

    addColumn(ownerColumn, uid)
    addColumn(modelColumn, model)
    if plateColumn then addColumn(plateColumn, plate) end
    if tuningColumn then addColumn(tuningColumn, tuning) end

    -- Compatibilitate cu tabele care au coloane extra uzuale.
    addColumn('vehicle_name', Config.StarterVehicle.name or 'Caddy')
    addColumn('stored', 1)
    addColumn('state', 1)
    addColumn('garage', 'A')

    if #insertColumns <= 0 then return false end

    local sql = ('INSERT INTO `ownedvehicles` (%s) VALUES (%s)'):format(
        table.concat(insertColumns, ', '),
        table.concat(placeholders, ', ')
    )

    local ok, err = pcall(function()
        MySQL.insert.await(sql, params)
    end)

    if not ok then
        print('[DRIFTZONE_AUTH] Starter vehicle insert failed: ' .. tostring(err))
        return false
    end

    print(('[DRIFTZONE_AUTH] Starter vehicle %s dat pentru UID %s.'):format(model, uid))
    return true
end


local function isTempBanActive(uid)
    local active = MySQL.scalar.await(
        'SELECT IF(tempban IS NOT NULL AND tempban > NOW(), 1, 0) FROM users WHERE uid = @uid LIMIT 1',
        {
            ['@uid'] = tonumber(uid)
        }
    )

    return tonumber(active) == 1
end

local function clearExpiredTempBan(uid)
    MySQL.update.await(
        'UPDATE users SET tempban = NULL, tempbanreason = NULL WHERE uid = @uid AND tempban IS NOT NULL AND tempban <= NOW()',
        {
            ['@uid'] = tonumber(uid)
        }
    )
end

local function buildBanMessage(user)
    if not user then return false, '' end

    local ban = trim(user.ban):lower()

    if ban == 'yes' or ban == 'true' or ban == '1' then
        return true, ('Ai BAN PERMANENT pe DriftZone!\nMotiv: %s\nDaca vrei unban, intra pe %s'):format(
            trim(user.banreason) ~= '' and trim(user.banreason) or 'Nespecificat',
            Config.DiscordInvite
        )
    end

    if isTempBanActive(user.uid) then
        return true, ('Ai BAN TEMPORAR pe DriftZone!\nExpira la: %s\nMotiv: %s\nDaca vrei unban mai rapid, intra pe %s'):format(
            tostring(user.tempban or 'Necunoscut'),
            trim(user.tempbanreason) ~= '' and trim(user.tempbanreason) or 'Nespecificat',
            Config.DiscordInvite
        )
    end

    clearExpiredTempBan(user.uid)
    return false, ''
end

local function checkBan(src, user)
    local banned, message = buildBanMessage(user)

    if banned then
        notifyAuth(src, message)
        return false
    end

    return true
end

local function savePlayerPosition(src, force)
    local session = LoggedPlayers[src]

    if not session then return false end

    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)

    if not coords then return false end

    if coords.x == 0.0 and coords.y == 0.0 and coords.z == 0.0 then
        return false
    end

    local heading = GetEntityHeading(ped) or 0.0
    local uid = session.uid

    if not shouldSave(uid, coords, heading, force) then
        return false
    end

    local lastpos = makeLastpos(coords, heading)

    MySQL.update.await(
        'UPDATE users SET lastpos = @lastpos, ip = @ip WHERE uid = @uid',
        {
            ['@lastpos'] = lastpos,
            ['@ip'] = getPlayerIP(src),
            ['@uid'] = uid
        }
    )

    updateLastSaved(uid, coords, heading)

    return true
end

local function completeLogin(src, user)
    local uid = tonumber(user.uid)

    if not uid or uid <= 0 then
        return notifyAuth(src, 'UID invalid.')
    end

    local currentName = getCleanPlayerName(src)
    local validName, nameError = isValidDriftZoneName(currentName)

    if not validName then
        return notifyAuth(src, nameError)
    end

    if trim(user.username) ~= currentName then
        return notifyAuth(src, 'Contul acesta nu este pentru numele tau actual. Schimba numele sau inregistreaza un cont nou.')
    end

    local ids = getPlayerIdentifiersData(src)
    local spawn = parseLastpos(user.lastpos)

    LoggedPlayers[src] = {
        uid = uid,
        username = user.username,
        email = user.email,
        license = ids.license,
        admin_level = tonumber(user.admin_level or 0) or 0,
        aduty = tonumber(user.aduty or 0) == 1
    }

    LastSavedPositions[uid] = {
        x = spawn.x,
        y = spawn.y,
        z = spawn.z,
        h = spawn.h or 0.0
    }

    Player(src).state:set('dz_logged', true, true)
    Player(src).state:set('dz_uid', uid, true)
    Player(src).state:set('dz_username', user.username, true)
    Player(src).state:set('dz_admin_level', tonumber(user.admin_level or 0) or 0, true)
    Player(src).state:set('dz_aduty', tonumber(user.aduty or 0) == 1, true)

    SetPlayerRoutingBucket(src, 0)

    MySQL.update.await(
        [[
            UPDATE users
            SET license = @license,
                discord = @discord,
                steam = @steam,
                fivem = @fivem,
                ip = @ip,
                last_login = NOW()
            WHERE uid = @uid
        ]],
        {
            ['@license'] = ids.license,
            ['@discord'] = ids.discord,
            ['@steam'] = ids.steam,
            ['@fivem'] = ids.fivem,
            ['@ip'] = getPlayerIP(src),
            ['@uid'] = uid
        }
    )

    TriggerClientEvent('driftzone_auth:client:success', src, {
        uid = uid,
        username = user.username or currentName,
        cash = tonumber(user.cash or 0) or 0,
        bank = tonumber(user.bank or 0) or 0,
        admin_level = tonumber(user.admin_level or 0) or 0,
        spawn = spawn
    })
end

local function handleRegister(src, data)
    local ids = getPlayerIdentifiersData(src)
    local name = getCleanPlayerName(src)
    local email = trim(data.email):lower()
    local password = tostring(data.password or '')

    local validName, nameError = isValidDriftZoneName(name)

    if not validName then
        return notifyAuth(src, nameError)
    end

    local okDuplicate, duplicateMessage = checkDuplicateAccountForSource(src, name)

    if not okDuplicate then
        return notifyAuth(src, duplicateMessage)
    end

    if not validEmail(email) then
        return notifyAuth(src, 'Email invalid.')
    end

    if #password < Config.MinPasswordLength then
        return notifyAuth(src, ('Parola prea scurta. Minim %s caractere.'):format(Config.MinPasswordLength))
    end

    local existsName = getUserByUsername(name)

    if existsName then
        return notifyAuth(src, 'Exista deja un cont pe acest nume. Foloseste Login.')
    end

    local existsEmail = getUserByEmail(email)

    if existsEmail then
        return notifyAuth(src, 'Email-ul acesta este deja folosit.')
    end

    local salt = randomSalt(32)
    local passwordHash = hashPassword(password, salt)

    local insertId = MySQL.insert.await(
        [[
            INSERT INTO users
                (
                    username,
                    email,
                    password_hash,
                    password_salt,
                    license,
                    discord,
                    steam,
                    fivem,
                    ip,
                    cash,
                    bank,
                    admin_level,
                    aduty,
                    ban,
                    lastpos,
                    clothes,
                    tattoos,
                    outfit
                )
            VALUES
                (
                    @username,
                    @email,
                    @password_hash,
                    @password_salt,
                    @license,
                    @discord,
                    @steam,
                    @fivem,
                    @ip,
                    @cash,
                    @bank,
                    0,
                    0,
                    'no',
                    NULL,
                    NULL,
                    NULL,
                    NULL
                )
        ]],
        {
            ['@username'] = name,
            ['@email'] = email,
            ['@password_hash'] = passwordHash,
            ['@password_salt'] = salt,
            ['@license'] = ids.license,
            ['@discord'] = ids.discord,
            ['@steam'] = ids.steam,
            ['@fivem'] = ids.fivem,
            ['@ip'] = getPlayerIP(src),
            ['@cash'] = Config.StartCash,
            ['@bank'] = Config.StartBank
        }
    )

    if not insertId then
        return notifyAuth(src, 'Nu am putut crea contul.')
    end

    giveStarterVehicle(insertId)

    local user = getUserByUid(insertId)

    if not user then
        return notifyAuth(src, 'Cont creat, dar nu poate fi incarcat. Reconnect.')
    end

    completeLogin(src, user)
end

local function handleLogin(src, data)
    local name = getCleanPlayerName(src)
    local password = tostring(data.password or '')

    local validName, nameError = isValidDriftZoneName(name)

    if not validName then
        return notifyAuth(src, nameError)
    end

    local okDuplicate, duplicateMessage = checkDuplicateAccountForSource(src, name)

    if not okDuplicate then
        return notifyAuth(src, duplicateMessage)
    end

    if password == '' then
        return notifyAuth(src, 'Parola obligatorie.')
    end

    local user = getUserByUsername(name)

    if not user then
        return notifyAuth(src, 'Nu exista cont pe acest nume. Apasa Register.')
    end

    if not checkBan(src, user) then
        return
    end

    local passwordHash = hashPassword(password, user.password_salt or '')

    if passwordHash ~= tostring(user.password_hash or '') then
        return notifyAuth(src, 'Parola incorecta.')
    end

    completeLogin(src, user)
end


AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source

    deferrals.defer()
    Wait(0)

    deferrals.update('DriftZone verifica identitatea...')

    local name = trim(playerName or GetPlayerName(src) or '')
    local validName, nameError = isValidDriftZoneName(name)

    if not validName then
        deferrals.done(nameError)
        return
    end

    local okUser, user = pcall(function()
        return getUserByUsername(name)
    end)

    if okUser and user then
        local banned, message = buildBanMessage(user)

        if banned then
            deferrals.done(message)
            return
        end
    end

    deferrals.update('DriftZone verifica daca ai deja cont...')

    local okDuplicate, duplicateMessage = pcall(function()
        local ids = getPlayerIdentifiersData(src)
        local duplicate = findDuplicateAccountByIdentity(name, ids, getPlayerIP(src))

        if duplicate then
            return buildDuplicateAccountMessage(duplicate)
        end

        return nil
    end)

    if okDuplicate and duplicateMessage then
        deferrals.done(duplicateMessage)
        return
    end

    deferrals.done()
end)

RegisterNetEvent('driftzone_auth:server:requestInit', function()
    local src = source
    local name = getCleanPlayerName(src)

    SetPlayerRoutingBucket(src, src + 1000)

    local validName, nameError = isValidDriftZoneName(name)
    local hasAccount = false

    if validName then
        local user = getUserByUsername(name)
        hasAccount = user ~= nil
    end

    TriggerClientEvent('driftzone_auth:client:init', src, {
        name = name,
        hasAccount = hasAccount
    })

    if not validName then
        Wait(500)
        notifyAuth(src, nameError)
    end
end)

RegisterNetEvent('driftzone_auth:server:submit', function(payload)
    local src = source

    if LoggedPlayers[src] then return end

    local data = {}

    if type(payload) == 'table' then
        data = payload
    else
        local ok, decoded = pcall(json.decode, tostring(payload or '{}'))

        if ok and type(decoded) == 'table' then
            data = decoded
        end
    end

    if data.type == 'register' then
        handleRegister(src, data)
        return
    end

    if data.type == 'login' then
        handleLogin(src, data)
        return
    end

    notifyAuth(src, 'Actiune necunoscuta.')
end)

AddEventHandler('playerDropped', function()
    local src = source

    if LoggedPlayers[src] then
        savePlayerPosition(src, true)
        LastSavedPositions[LoggedPlayers[src].uid] = nil
        LoggedPlayers[src] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(Config.AutoSaveInterval)

        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)

            if src and LoggedPlayers[src] then
                pcall(function()
                    savePlayerPosition(src, false)
                end)
            end
        end
    end
end)

exports('GetUser', function(src)
    return LoggedPlayers[src]
end)

exports('GetUID', function(src)
    return LoggedPlayers[src] and LoggedPlayers[src].uid or nil
end)

exports('IsLoggedIn', function(src)
    return LoggedPlayers[src] ~= nil
end)

exports('GetAdminLevel', function(src)
    return LoggedPlayers[src] and LoggedPlayers[src].admin_level or 0
end)

exports('IsAdminDuty', function(src)
    return LoggedPlayers[src] and LoggedPlayers[src].aduty == true or false
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_AUTH] Server-side loaded.')
end)