local Inventories = {}
local ItemsCache = nil
local ItemsCacheExpires = 0
local OpenPlayers = {}
local GiveSessions = {}

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 4500, tostring(msg or ''))
end

local function jsonEncode(data)
    local ok, res = pcall(json.encode, data or {})
    if ok then return res end
    return '[]'
end

local function jsonDecode(raw)
    if type(raw) == 'table' then return raw end
    local ok, res = pcall(json.decode, tostring(raw or '[]'))
    if ok and type(res) == 'table' then return res end
    return {}
end

local function getUid(src)
    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, uid = pcall(fn)
        uid = tonumber(uid)
        if ok and uid and uid > 0 then return uid end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end
    local ok, result = pcall(function() return exports.driftzone_auth:IsLoggedIn(src) end)
    return ok and result == true or getUid(src) ~= nil
end

local function isAdutyValue(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true'
end

local function getAdminData(src)
    local uid = getUid(src)
    if not uid then return nil end

    local row = MySQL.single.await(('SELECT * FROM %s WHERE %s = ? LIMIT 1'):format(sqlName(Config.UsersTable), sqlName(Config.UsersIdColumn)), { uid })
    if not row then return nil end

    local level = tonumber(row[Config.AdminColumn] or row[Config.AdminColumnFallback] or 0) or 0
    local aduty = isAdutyValue(row[Config.AdutyColumn])

    return { uid = uid, level = level, aduty = aduty, name = row.username or GetPlayerName(src) or ('Player '..src) }
end

local function requireAdmin(src, minLevel)
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return nil
    end

    local data = getAdminData(src)
    if not data or data.level < minLevel then
        notify(src, 'warning', 'Nu ai acces la aceasta comanda.')
        return nil
    end

    if not data.aduty then
        notify(src, 'warning', 'Trebuie sa fii ON DUTY.')
        return nil
    end

    return data
end

local function normalizeInventory(inv)
    local out = {}
    for i = 1, Config.Slots do out[i] = nil end

    if type(inv) ~= 'table' then return out end

    for i = 1, Config.Slots do
        local item = inv[i] or inv[tostring(i)]
        if type(item) == 'table' then
            local itemId = trim(item.item_id or item.id or item.name)
            local amount = math.floor(tonumber(item.amount or item.count or 1) or 1)
            if itemId ~= '' and amount > 0 then
                out[i] = { item_id = itemId, amount = amount }
            end
        end
    end

    return out
end

local function serializeInventory(inv)
    local out = {}
    inv = normalizeInventory(inv)
    for i = 1, Config.Slots do
        if inv[i] then out[tostring(i)] = inv[i] end
    end
    return jsonEncode(out)
end

local function ensureInventory(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return normalizeInventory({}) end

    if Inventories[uid] then return Inventories[uid] end

    local row = MySQL.single.await(('SELECT inventory_json FROM %s WHERE uid = ? LIMIT 1'):format(sqlName(Config.InventoryTable)), { uid })
    if not row then
        MySQL.insert.await(('INSERT INTO %s (uid, inventory_json, updated_at) VALUES (?, ?, NOW())'):format(sqlName(Config.InventoryTable)), { uid, '{}' })
        Inventories[uid] = normalizeInventory({})
        return Inventories[uid]
    end

    Inventories[uid] = normalizeInventory(jsonDecode(row.inventory_json))
    return Inventories[uid]
end

local function saveInventory(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return false end

    local inv = ensureInventory(uid)
    MySQL.update.await(('INSERT INTO %s (uid, inventory_json, updated_at) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE inventory_json = VALUES(inventory_json), updated_at = NOW()'):format(sqlName(Config.InventoryTable)), {
        uid,
        serializeInventory(inv)
    })
    return true
end

local function clearInventory(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return false end
    Inventories[uid] = normalizeInventory({})
    return saveInventory(uid)
end

local function loadItems(force)
    local now = GetGameTimer()
    if not force and ItemsCache and ItemsCacheExpires > now then return ItemsCache end

    local rows = MySQL.query.await(('SELECT * FROM %s ORDER BY item_name ASC'):format(sqlName(Config.ItemsTable)), {}) or {}
    ItemsCache = {}

    for _, row in ipairs(rows) do
        local itemId = trim(row.item_id)
        if itemId ~= '' then
            ItemsCache[itemId] = {
                item_id = itemId,
                item_name = row.item_name or itemId,
                image = row.image or '',
                tradable = tonumber(row.tradable or 1) == 1,
                stackable = tonumber(row.stackable or 1) == 1,
                usable = tonumber(row.usable or 0) == 1,
                giveable = tonumber(row.giveable or 1) == 1,
                max_stack = math.max(1, tonumber(row.max_stack or Config.ItemDefaults.max_stack or 100) or 100)
            }
        end
    end

    ItemsCacheExpires = now + 5000
    return ItemsCache
end

local function getItem(itemId)
    return loadItems(false)[trim(itemId)]
end

local function hydrateInventory(inv)
    local items = loadItems(false)
    local out = {}
    inv = normalizeInventory(inv)

    for i = 1, Config.Slots do
        local slot = inv[i]
        if slot and items[slot.item_id] then
            local meta = items[slot.item_id]
            out[i] = {
                slot = i,
                item_id = slot.item_id,
                item_name = meta.item_name,
                image = meta.image,
                amount = slot.amount,
                tradable = meta.tradable,
                stackable = meta.stackable,
                usable = meta.usable,
                giveable = meta.giveable,
                max_stack = meta.max_stack
            }
        else
            out[i] = nil
        end
    end

    return out
end

local function hasFreeSlotOrStack(uid, itemId, amount)
    local item = getItem(itemId)
    if not item then return false end
    local inv = ensureInventory(uid)
    amount = math.floor(tonumber(amount or 1) or 1)

    if item.stackable then
        for i = 1, Config.Slots do
            local slot = inv[i]
            if slot and slot.item_id == item.item_id and slot.amount < item.max_stack then
                amount = amount - math.max(0, item.max_stack - slot.amount)
                if amount <= 0 then return true end
            end
        end
    end

    for i = 1, Config.Slots do
        if not inv[i] then
            if item.stackable then
                amount = amount - item.max_stack
            else
                amount = amount - 1
            end
            if amount <= 0 then return true end
        end
    end

    return false
end

local function giveItemToUid(uid, itemId, amount)
    uid = tonumber(uid)
    itemId = trim(itemId)
    amount = math.floor(tonumber(amount or 1) or 1)
    if not uid or uid <= 0 or itemId == '' or amount <= 0 then return false, 'Date invalide.' end

    local item = getItem(itemId)
    if not item then return false, 'Item ID invalid.' end

    local inv = ensureInventory(uid)
    local remaining = amount

    if item.stackable then
        for i = 1, Config.Slots do
            local slot = inv[i]
            if slot and slot.item_id == item.item_id and slot.amount < item.max_stack then
                local add = math.min(remaining, item.max_stack - slot.amount)
                slot.amount = slot.amount + add
                remaining = remaining - add
                if remaining <= 0 then break end
            end
        end
    end

    while remaining > 0 do
        local freeSlot = nil
        for i = 1, Config.Slots do
            if not inv[i] then freeSlot = i break end
        end

        if not freeSlot then
            saveInventory(uid)
            return false, 'Nu sunt sloturi disponibile.'
        end

        local put = item.stackable and math.min(remaining, item.max_stack) or 1
        inv[freeSlot] = { item_id = item.item_id, amount = put }
        remaining = remaining - put
    end

    saveInventory(uid)
    return true, 'Item adaugat.'
end

local function takeItemFromUid(uid, itemId, amount)
    uid = tonumber(uid)
    itemId = trim(itemId)
    amount = math.floor(tonumber(amount or 1) or 1)
    if not uid or uid <= 0 or itemId == '' or amount <= 0 then return false, 'Date invalide.' end

    local inv = ensureInventory(uid)
    local have = 0
    for i = 1, Config.Slots do
        local slot = inv[i]
        if slot and slot.item_id == itemId then have = have + slot.amount end
    end
    if have < amount then return false, 'Jucatorul nu are suficiente iteme.' end

    local remaining = amount
    for i = Config.Slots, 1, -1 do
        local slot = inv[i]
        if slot and slot.item_id == itemId then
            local take = math.min(remaining, slot.amount)
            slot.amount = slot.amount - take
            remaining = remaining - take
            if slot.amount <= 0 then inv[i] = nil end
            if remaining <= 0 then break end
        end
    end

    saveInventory(uid)
    return true, 'Item scos.'
end

local function pushInventory(src, mode, target)
    local uid = getUid(src)
    if not uid then return end
    local inv = ensureInventory(uid)
    TriggerClientEvent('driftzone_inventory:client:open', src, {
        slots = Config.Slots,
        columns = Config.Columns,
        inventory = hydrateInventory(inv),
        mainColor = Config.MainColor,
        mode = mode or 'normal',
        target = target or nil
    })
end

local function logAction(action, adminUid, targetUid, itemId, amount, details)
    pcall(function()
        MySQL.insert.await(('INSERT INTO %s (action, admin_uid, target_uid, item_id, amount, details, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())'):format(sqlName(Config.LogsTable)), {
            tostring(action or ''),
            tonumber(adminUid or 0) or 0,
            tonumber(targetUid or 0) or 0,
            tostring(itemId or ''),
            tonumber(amount or 0) or 0,
            jsonEncode(details or {})
        })
    end)
end

local function getPlayerByUid(uid)
    uid = tonumber(uid)
    if not uid then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and getUid(src) == uid then return src end
    end
    return nil
end

local function distanceOk(a, b)
    local pa = GetPlayerPed(a)
    local pb = GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return false end
    local ca = GetEntityCoords(pa)
    local cb = GetEntityCoords(pb)
    return #(ca - cb) <= (Config.MaxGiveDistance or 4.0)
end

RegisterCommand(Config.Command or 'inventory', function(src)
    if src <= 0 then return end
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.') end
    OpenPlayers[src] = true
    pushInventory(src, 'normal')
end, false)

RegisterCommand('additem', function(src)
    local admin = requireAdmin(src, Config.Admin.additem or 6)
    if not admin then return end
    TriggerClientEvent('driftzone_inventory:client:addItemPanel', src, { mainColor = Config.MainColor })
end, false)

RegisterCommand('giveitem', function(src, args)
    local admin = requireAdmin(src, Config.Admin.giveitem or 6)
    if not admin then return end

    local uid = tonumber(args[1] or 0)
    local itemId = trim(args[2])
    local amount = math.floor(tonumber(args[3] or 1) or 1)
    if not uid or uid <= 0 or itemId == '' or amount <= 0 then
        return notify(src, 'warning', 'Folosire: /giveitem uid item_id numar')
    end

    local ok, msg = giveItemToUid(uid, itemId, amount)
    if ok then
        logAction('admin_giveitem', admin.uid, uid, itemId, amount, { by = GetPlayerName(src) })
        notify(src, 'success', ('Ai dat %sx %s la UID %s.'):format(amount, itemId, uid))
        local target = getPlayerByUid(uid)
        if target then
            notify(target, 'info', ('Ai primit %sx %s.'):format(amount, itemId))
            pushInventory(target, 'normal')
        end
    else
        notify(src, 'warning', msg)
    end
end, false)

RegisterCommand('takeitem', function(src, args)
    local admin = requireAdmin(src, Config.Admin.takeitem or 6)
    if not admin then return end

    local uid = tonumber(args[1] or 0)
    local itemId = trim(args[2])
    local amount = math.floor(tonumber(args[3] or 1) or 1)
    if not uid or uid <= 0 or itemId == '' or amount <= 0 then
        return notify(src, 'warning', 'Folosire: /takeitem uid item_id numar')
    end

    local ok, msg = takeItemFromUid(uid, itemId, amount)
    if ok then
        logAction('admin_takeitem', admin.uid, uid, itemId, amount, { by = GetPlayerName(src) })
        notify(src, 'success', ('Ai scos %sx %s de la UID %s.'):format(amount, itemId, uid))
        local target = getPlayerByUid(uid)
        if target then pushInventory(target, 'normal') end
    else
        notify(src, 'warning', msg)
    end
end, false)

RegisterCommand('wipeinventory', function(src, args)
    local admin = requireAdmin(src, Config.Admin.wipeinventory or 6)
    if not admin then return end

    local uid = tonumber(args[1] or 0)
    if not uid or uid <= 0 then return notify(src, 'warning', 'Folosire: /wipeinventory uid') end

    clearInventory(uid)
    logAction('admin_wipeinventory', admin.uid, uid, '', 0, { by = GetPlayerName(src) })
    notify(src, 'success', ('Inventarul UID %s a fost sters.'):format(uid))

    local target = getPlayerByUid(uid)
    if target then
        notify(target, 'warning', 'Inventarul tau a fost resetat de un administrator.')
        pushInventory(target, 'normal')
    end
end, false)

RegisterNetEvent('driftzone_inventory:server:requestOpen', function()
    local src = source
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.') end
    OpenPlayers[src] = true
    pushInventory(src, 'normal')
end)

RegisterNetEvent('driftzone_inventory:server:move', function(fromSlot, toSlot)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    fromSlot = tonumber(fromSlot or 0) or 0
    toSlot = tonumber(toSlot or 0) or 0
    if fromSlot < 1 or fromSlot > Config.Slots or toSlot < 1 or toSlot > Config.Slots or fromSlot == toSlot then return end

    local inv = ensureInventory(uid)
    local a = inv[fromSlot]
    local b = inv[toSlot]
    if not a then return end

    local meta = getItem(a.item_id)
    if b and meta and meta.stackable and b.item_id == a.item_id then
        local maxStack = meta.max_stack or 100
        local free = math.max(0, maxStack - b.amount)
        local move = math.min(free, a.amount)
        if move > 0 then
            b.amount = b.amount + move
            a.amount = a.amount - move
            if a.amount <= 0 then inv[fromSlot] = nil end
        else
            inv[fromSlot], inv[toSlot] = inv[toSlot], inv[fromSlot]
        end
    else
        inv[fromSlot], inv[toSlot] = inv[toSlot], inv[fromSlot]
    end

    saveInventory(uid)
    pushInventory(src, 'normal')
end)

RegisterNetEvent('driftzone_inventory:server:addItemSubmit', function(data)
    local src = source
    local admin = requireAdmin(src, Config.Admin.additem or 6)
    if not admin then return end

    data = type(data) == 'table' and data or {}
    local itemId = trim(data.item_id):lower():gsub('%s+', '_')
    local name = trim(data.item_name)
    local image = trim(data.image)
    local tradable = tonumber(data.tradable or 1) == 1 and 1 or 0
    local stackable = tonumber(data.stackable or 1) == 1 and 1 or 0
    local usable = tonumber(data.usable or 0) == 1 and 1 or 0
    local giveable = tonumber(data.giveable or 1) == 1 and 1 or 0
    local maxStack = math.max(1, math.floor(tonumber(data.max_stack or 100) or 100))

    if itemId == '' or not itemId:match('^[a-z0-9_%-]+$') then
        return TriggerClientEvent('driftzone_inventory:client:addItemResult', src, false, 'Item ID invalid.')
    end

    if name == '' then
        return TriggerClientEvent('driftzone_inventory:client:addItemResult', src, false, 'Item Name obligatoriu.')
    end

    MySQL.update.await(('INSERT INTO %s (item_id, item_name, image, tradable, stackable, usable, giveable, max_stack, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), image = VALUES(image), tradable = VALUES(tradable), stackable = VALUES(stackable), usable = VALUES(usable), giveable = VALUES(giveable), max_stack = VALUES(max_stack), updated_at = NOW()'):format(sqlName(Config.ItemsTable)), {
        itemId, name, image, tradable, stackable, usable, giveable, maxStack
    })

    ItemsCache = nil
    logAction('admin_additem', admin.uid, 0, itemId, 0, data)
    TriggerClientEvent('driftzone_inventory:client:addItemResult', src, true, 'Item salvat cu succes.')
end)

RegisterNetEvent('driftzone_inventory:server:startGiveToPlayer', function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId or 0) or 0
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.') end
    if targetServerId <= 0 or not GetPlayerName(targetServerId) or targetServerId == src then return notify(src, 'warning', 'Jucator invalid.') end
    if not distanceOk(src, targetServerId) then return notify(src, 'warning', 'Jucatorul este prea departe.') end

    OpenPlayers[src] = true
    pushInventory(src, 'give', {
        serverId = targetServerId,
        name = GetPlayerName(targetServerId),
        uid = getUid(targetServerId)
    })
end)

RegisterNetEvent('driftzone_inventory:server:giveSelected', function(targetServerId, slotIndex, amount)
    local src = source
    local fromUid = getUid(src)
    targetServerId = tonumber(targetServerId or 0) or 0
    slotIndex = tonumber(slotIndex or 0) or 0
    amount = math.floor(tonumber(amount or 1) or 1)

    if not fromUid then return end
    if targetServerId <= 0 or not GetPlayerName(targetServerId) or targetServerId == src then return notify(src, 'warning', 'Jucator invalid.') end
    if not distanceOk(src, targetServerId) then return notify(src, 'warning', 'Jucatorul este prea departe.') end

    local toUid = getUid(targetServerId)
    if not toUid then return notify(src, 'warning', 'Jucatorul nu este logat.') end
    if slotIndex < 1 or slotIndex > Config.Slots or amount <= 0 then return end

    local inv = ensureInventory(fromUid)
    local slot = inv[slotIndex]
    if not slot or slot.amount < amount then return notify(src, 'warning', 'Nu ai suficiente bucati.') end

    local item = getItem(slot.item_id)
    if not item then return notify(src, 'warning', 'Item invalid.') end
    if not item.giveable then return notify(src, 'warning', 'Acest item nu poate fi oferit.') end
    if not item.tradable then return notify(src, 'warning', 'Acest item nu este tradable.') end
    if not hasFreeSlotOrStack(toUid, item.item_id, amount) then return notify(src, 'warning', 'Jucatorul nu are sloturi disponibile.') end

    slot.amount = slot.amount - amount
    if slot.amount <= 0 then inv[slotIndex] = nil end
    saveInventory(fromUid)

    local ok, msg = giveItemToUid(toUid, item.item_id, amount)
    if not ok then
        giveItemToUid(fromUid, item.item_id, amount)
        return notify(src, 'warning', msg or 'Nu s-a putut oferi itemul.')
    end

    logAction('player_giveitem', fromUid, toUid, item.item_id, amount, { from = GetPlayerName(src), to = GetPlayerName(targetServerId) })
    notify(src, 'success', ('Ai oferit %sx %s.'):format(amount, item.item_name))
    notify(targetServerId, 'info', ('Ai primit %sx %s.'):format(amount, item.item_name))
    pushInventory(src, 'give', { serverId = targetServerId, name = GetPlayerName(targetServerId), uid = toUid })
    pushInventory(targetServerId, 'normal')
end)

RegisterNetEvent('driftzone_inventory:server:useItem', function(slotIndex)
    local src = source
    local uid = getUid(src)
    slotIndex = tonumber(slotIndex or 0) or 0
    if not uid or slotIndex < 1 or slotIndex > Config.Slots then return end

    local inv = ensureInventory(uid)
    local slot = inv[slotIndex]
    if not slot then return end
    local item = getItem(slot.item_id)
    if not item or not item.usable then return notify(src, 'warning', 'Acest item nu se poate folosi.') end

    TriggerEvent('driftzone_inventory:server:itemUsed', src, uid, item.item_id, slotIndex)
    TriggerClientEvent('driftzone_inventory:client:itemUsed', src, item.item_id)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getUid(src)
    if uid and Inventories[uid] then saveInventory(uid) end
    OpenPlayers[src] = nil
end)

exports('GiveItem', function(uid, itemId, amount)
    return giveItemToUid(uid, itemId, amount)
end)

exports('TakeItem', function(uid, itemId, amount)
    return takeItemFromUid(uid, itemId, amount)
end)

exports('GetInventory', function(uid)
    return hydrateInventory(ensureInventory(uid))
end)

exports('HasSpaceForItem', function(uid, itemId, amount)
    return hasFreeSlotOrStack(uid, itemId, amount)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_INVENTORY] Loaded.')
end)
