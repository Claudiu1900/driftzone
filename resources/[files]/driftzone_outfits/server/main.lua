
local WEAR_COOLDOWN_MS = 30 * 1000

local wearCooldown = {}
local AdminCache = {}
local OutfitListCache = nil
local OutfitListCacheExpires = 0
local OutfitByIdCache = {}
local UserClothesCache = {}

local ORDERED_KEYS = {
    'mask', 'hat', 'jacket', 'torso', 'top', 'pants', 'shoes', 'insignia', 'glasses'
}

local function nowMs()
    return os.time() * 1000
end

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function clearOutfitCache()
    OutfitListCache = nil
    OutfitListCacheExpires = 0
    OutfitByIdCache = {}
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

local function isDutyValue(value)
    if value == true then return true end

    local text = tostring(value or ''):lower()
    return tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function getAdminData(src)
    local uid = getUid(src)

    if not uid then return nil end

    local cached = AdminCache[uid]
    if cached and cached.expires > GetGameTimer() then
        return cached.data
    end

    local row = MySQL.single.await(
        'SELECT uid, username, admin_level, aduty FROM users WHERE uid = ? LIMIT 1',
        { uid }
    )

    if not row then return nil end

    local data = {
        uid = tonumber(row.uid or uid) or uid,
        username = tostring(row.username or GetPlayerName(src) or 'Admin'),
        level = tonumber(row.admin_level or 0) or 0,
        aduty = isDutyValue(row.aduty)
    }

    AdminCache[uid] = {
        expires = GetGameTimer() + 3000,
        data = data
    }

    return data
end

local function requireAdmin7(src)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local data = getAdminData(src)

    if not data or data.level < 7 then
        notify(src, 'warning', 'Nu ai acces la aceasta comanda.')
        return nil
    end

    if not data.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return data
end

local function cleanText(value, maxLength)
    value = tostring(value or ''):gsub('[\r\n\t]', ' '):gsub('%c', ''):gsub('%s+', ' ')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')

    return value:sub(1, maxLength or 64)
end

local function normalizeImage(value)
    value = cleanText(value, 512)

    local lower = value:lower()

    if value ~= '' and (lower:sub(1, 7) == 'http://' or lower:sub(1, 8) == 'https://') then
        return value
    end

    return ''
end

local function decodeJson(raw, fallback)
    if type(raw) == 'table' then return raw end

    local ok, decoded = pcall(json.decode, tostring(raw or '{}'))

    if ok and type(decoded) == 'table' then
        return decoded
    end

    return fallback or {}
end

local function sanitizeItem(item)
    if type(item) ~= 'table' then return nil end

    local drawable = math.floor(tonumber(item.drawable or 0) or 0)
    local texture = math.floor(tonumber(item.texture or 0) or 0)

    if texture < 0 then
        texture = 0
    end

    return {
        drawable = drawable,
        texture = texture
    }
end

local function cleanOutfitClothes(raw)
    local data = decodeJson(raw, {})
    local clean = {}

    for i = 1, #ORDERED_KEYS do
        local key = ORDERED_KEYS[i]
        local item = sanitizeItem(data[key])

        if item then
            clean[key] = item
        end
    end

    return clean
end

local function getOutfits()
    local now = GetGameTimer()

    if OutfitListCache and OutfitListCacheExpires > now then
        return OutfitListCache
    end

    local rows = MySQL.query.await(
        'SELECT id, name, image, created_at FROM outfits ORDER BY id DESC',
        {}
    ) or {}

    local list = {}

    for i = 1, #rows do
        local row = rows[i]

        list[#list + 1] = {
            id = tonumber(row.id or 0) or 0,
            name = tostring(row.name or 'Outfit'),
            image = tostring(row.image or ''),
            createdAt = tostring(row.created_at or '')
        }
    end

    OutfitListCache = list
    OutfitListCacheExpires = now + 5000

    return list
end

local function getOutfit(id)
    id = tonumber(id or 0) or 0

    if id <= 0 then return nil end

    local cached = OutfitByIdCache[id]

    if cached and cached.expires > GetGameTimer() then
        return cached.data
    end

    local row = MySQL.single.await(
        'SELECT id, name, image, clothes FROM outfits WHERE id = ? LIMIT 1',
        { id }
    )

    if not row then return nil end

    local data = {
        id = tonumber(row.id or 0) or 0,
        name = tostring(row.name or 'Outfit'),
        image = tostring(row.image or ''),
        clothes = cleanOutfitClothes(row.clothes)
    }

    OutfitByIdCache[id] = {
        expires = GetGameTimer() + 10000,
        data = data
    }

    return data
end

local function getSavedUserClothes(uid)
    uid = tonumber(uid)

    if not uid then return {} end

    local cached = UserClothesCache[uid]

    if cached and cached.expires > GetGameTimer() then
        return decodeJson(cached.clothes, {})
    end

    local row = MySQL.single.await(
        'SELECT clothes FROM users WHERE uid = ? LIMIT 1',
        { uid }
    )

    local clothes = row and decodeJson(row.clothes, {}) or {}

    UserClothesCache[uid] = {
        clothes = clothes,
        expires = GetGameTimer() + 1500
    }

    return clothes
end

local function saveUserClothes(uid, clothes)
    uid = tonumber(uid)

    if not uid then return end

    UserClothesCache[uid] = {
        clothes = clothes or {},
        expires = GetGameTimer() + 1500
    }

    MySQL.update.await(
        'UPDATE users SET clothes = ? WHERE uid = ?',
        { json.encode(clothes or {}), uid }
    )
end

local function createLog(action, data)
    pcall(function()
        TriggerEvent('logs:create', 'clothes_logs', json.encode({
            action = action,
            data = json.encode(data or {}),
            created_at = os.date('%Y-%m-%d %H:%M:%S')
        }))
    end)
end

local function openMenu(src)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    TriggerClientEvent('driftzone_outfits:client:open', src, {
        outfits = getOutfits(),
        cooldownUntil = wearCooldown[uid] or 0,
        cooldown = WEAR_COOLDOWN_MS
    })
end

local function addOutfit(src, args)
    local admin = requireAdmin7(src)

    if not admin then return end

    args = args or {}

    if #args < 1 then
        notify(src, 'warning', 'Folosire: /addoutfit (nume) (link imagine optional)')
        return
    end

    local image = ''
    local nameParts = {}

    for i = 1, #args do
        local part = tostring(args[i] or '')
        local lower = part:lower()

        if i == #args and (lower:sub(1, 7) == 'http://' or lower:sub(1, 8) == 'https://') then
            image = normalizeImage(part)
        else
            nameParts[#nameParts + 1] = part
        end
    end

    local name = cleanText(table.concat(nameParts, ' '), 64)

    if name == '' then
        notify(src, 'warning', 'Folosire: /addoutfit (nume) (link imagine optional)')
        return
    end

    TriggerClientEvent('driftzone_outfits:client:captureForAdd', src, {
        name = name,
        image = image,
        adminUid = admin.uid,
        adminName = admin.username
    })
end

local function wearOutfit(src, outfitId)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getUid(src)

    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    local now = nowMs()
    local cooldownUntil = wearCooldown[uid] or 0

    if cooldownUntil > now then
        local seconds = math.ceil((cooldownUntil - now) / 1000)
        notify(src, 'warning', ('Mai ai cooldown %s secunde.'):format(seconds))
        TriggerClientEvent('driftzone_outfits:client:setCooldown', src, cooldownUntil)
        return
    end

    local outfit = getOutfit(outfitId)

    if not outfit then
        notify(src, 'warning', 'Outfit-ul nu exista.')
        return
    end

    local saved = getSavedUserClothes(uid)

    for i = 1, #ORDERED_KEYS do
        local key = ORDERED_KEYS[i]

        if outfit.clothes[key] ~= nil then
            saved[key] = outfit.clothes[key]
        end
    end

    saveUserClothes(uid, saved)

    cooldownUntil = now + WEAR_COOLDOWN_MS
    wearCooldown[uid] = cooldownUntil

    TriggerClientEvent('driftzone_outfits:client:apply', src, outfit.clothes)
    TriggerClientEvent('driftzone_outfits:client:setCooldown', src, cooldownUntil)

    pcall(function()
        TriggerClientEvent('client:clothes:fix', src, json.encode(saved))
    end)

    notify(src, 'info', ('Ai echipat outfit-ul "%s".'):format(outfit.name))

    createLog('wearoutfit', {
        user_id = uid,
        outfit_id = outfit.id,
        outfit_name = outfit.name,
        player_name = GetPlayerName(src) or ''
    })
end

RegisterNetEvent('driftzone_outfits:server:open', function()
    openMenu(source)
end)

RegisterNetEvent('driftzone_outfits:server:wear', function(outfitId)
    wearOutfit(source, outfitId)
end)

RegisterNetEvent('driftzone_outfits:server:addCaptured', function(payload)
    local src = source
    local admin = requireAdmin7(src)

    if not admin then return end

    local data = decodeJson(payload, {})
    local name = cleanText(data.name, 64)
    local image = normalizeImage(data.image)
    local clothes = cleanOutfitClothes(data.clothes)

    if name == '' then
        notify(src, 'warning', 'Nume outfit invalid.')
        return
    end

    local count = 0

    for _, _ in pairs(clothes) do
        count = count + 1
    end

    if count <= 0 then
        notify(src, 'warning', 'Nu am putut captura hainele outfit-ului.')
        return
    end

    MySQL.insert.await(
        'INSERT INTO outfits (name, image, clothes, created_by_uid, created_by_name) VALUES (?, ?, ?, ?, ?)',
        { name, image, json.encode(clothes), admin.uid, admin.username }
    )

    clearOutfitCache()

    notify(src, 'info', ('Ai creat outfit-ul "%s".'):format(name))

    createLog('addoutfit', {
        user_id = admin.uid,
        player_name = admin.username,
        outfit_name = name,
        image = image,
        clothes = clothes
    })
end)

local function runCommand(src, command, args)
    command = tostring(command or ''):lower()

    if command == 'outfit' or command == 'outfits' then
        openMenu(src)
        return
    end

    if command == 'addoutfit' then
        addOutfit(src, args or {})
        return
    end
end

RegisterCommand('outfit', function(src)
    if src ~= 0 then
        openMenu(src)
    end
end, false)

RegisterCommand('outfits', function(src)
    if src ~= 0 then
        openMenu(src)
    end
end, false)

RegisterCommand('addoutfit', function(src, args)
    if src ~= 0 then
        addOutfit(src, args or {})
    end
end, false)

exports('RunCommand', function(src, command, args)
    return runCommand(src, command, args or {})
end)

exports('Open', function(src)
    return openMenu(src)
end)

AddEventHandler('playerDropped', function()
    local uid = getUid(source)

    if uid then
        wearCooldown[uid] = nil
        AdminCache[uid] = nil
        UserClothesCache[uid] = nil
    end
end)

CreateThread(function()
    Wait(500)
    print('[DRIFTZONE_OUTFITS] Server-side loaded.')
end)
