local Inventories = {}
local ItemsCache = nil
local ItemsCacheExpires = 0
local ClothesItemsCache = nil
local ClothesItemsCacheExpires = 0
local OpenPlayers = {}
local GiveSessions = {}
local Drops = {}
local NextDropId = 0
local ClothesApplyRevision = {}
local ensureGradientItemColumns
local jsonDecode
local DIRTY_MONEY_STORAGE_KEY = '__dirtymoney'
local QUICK_SLOTS_STORAGE_KEY = '__quick_slots'

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function moneyItemId()
    return tostring(Config.MoneyItemId or 'money')
end

local function dirtyMoneyItemId()
    return tostring(Config.DirtyMoneyItemId or 'dirtymoney')
end

local function isMoneyItem(itemId)
    return trim(itemId) == moneyItemId()
end

local function isDirtyMoneyItem(itemId)
    return trim(itemId) == dirtyMoneyItemId()
end

local function isCurrencyItem(itemId)
    return isMoneyItem(itemId) or isDirtyMoneyItem(itemId)
end

local function currencyMaxStack()
    return math.max(1, math.floor(tonumber(Config.CurrencyMaxStack or 2147483647) or 2147483647))
end


local function normalizeClothingCategory(key)
    key = trim(key):lower():gsub('%s+', '_')
    local aliases = Config.ClothingAliases or {}
    key = aliases[key] or key
    local cats = Config.ClothingCategories or {}
    if cats[key] then return key end
    return nil
end

local function getClothingCategoryConfig(key)
    key = normalizeClothingCategory(key)
    if not key then return nil, nil end
    local cfg = (Config.ClothingCategories or {})[key]
    return key, cfg
end

local function clothingCategoryOrder()
    local order = Config.ClothingCategoryOrder or {}
    local out = {}
    for _, key in ipairs(order) do
        key = normalizeClothingCategory(key)
        if key and (Config.ClothingCategories or {})[key] then out[#out + 1] = key end
    end
    return out
end

local function buildClothingCategoriesPayload()
    local out = {}
    for _, key in ipairs(clothingCategoryOrder()) do
        local cfg = (Config.ClothingCategories or {})[key] or {}
        out[#out + 1] = {
            key = key,
            label = tostring(cfg.label or key),
            icon = tostring(cfg.icon or (key .. '.svg')),
            type = tostring(cfg.type or 'component'),
            componentId = tonumber(cfg.componentId or -1) or -1,
            propId = tonumber(cfg.propId or -1) or -1
        }
    end
    return out
end

local function clothingJson(raw)
    local data = jsonDecode(raw or '{}')
    if type(data) == 'table' then return data end
    return {}
end

local function normalizeQuickSlots(value)
    local out = {}
    if type(value) ~= 'table' then return out end

    for i = 1, 5 do
        local raw = value[i] or value[tostring(i)]
        local slot = tonumber(raw or 0) or 0
        if slot >= 1 and slot <= (Config.Slots or 49) then
            out[tostring(i)] = slot
        end
    end

    return out
end

local function hasTableValues(t)
    if type(t) ~= 'table' then return false end
    for _, _ in pairs(t) do return true end
    return false
end

local function currencyMeta(itemId)
    itemId = trim(itemId)
    if isMoneyItem(itemId) then
        return {
            item_id = moneyItemId(),
            item_name = tostring(Config.MoneyItemName or 'Money'),
            image = tostring(Config.MoneyImage or ''),
            tradable = true,
            stackable = true,
            usable = false,
            giveable = true,
            max_stack = currencyMaxStack(),
            is_currency = true,
            cash_source = true
        }
    end

    if isDirtyMoneyItem(itemId) then
        return {
            item_id = dirtyMoneyItemId(),
            item_name = tostring(Config.DirtyMoneyItemName or 'Dirty Money'),
            image = tostring(Config.DirtyMoneyImage or ''),
            tradable = true,
            stackable = true,
            usable = false,
            giveable = true,
            max_stack = currencyMaxStack(),
            is_currency = true
        }
    end

    return nil
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 4500, tostring(msg or ''))
end

local function runServerHook(name, data)
    if not Config or not Config.ServerHooks then return end
    local fn = Config.ServerHooks[name]
    if type(fn) ~= 'function' then return end

    local ok, err = pcall(fn, data or {})
    if not ok then
        print(('[DRIFTZONE_INVENTORY] Server hook %s error: %s'):format(tostring(name), tostring(err)))
    end
end


local function jsonEncode(data)
    local ok, res = pcall(json.encode, data or {})
    if ok then return res end
    return '[]'
end

jsonDecode = function(raw)
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

local function getUserCash(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return 0 end

    local row = MySQL.single.await(('SELECT %s AS cash FROM %s WHERE %s = ? LIMIT 1'):format(
        sqlName(Config.UsersCashColumn or 'cash'),
        sqlName(Config.UsersTable),
        sqlName(Config.UsersIdColumn)
    ), { uid })

    return math.max(0, math.floor(tonumber(row and row.cash or 0) or 0))
end

local function addUserCash(uid, amount)
    uid = tonumber(uid)
    amount = math.floor(tonumber(amount or 0) or 0)
    if not uid or uid <= 0 or amount <= 0 then return false, 'Date invalide.' end

    local affected = MySQL.update.await(('UPDATE %s SET %s = COALESCE(%s, 0) + ? WHERE %s = ?'):format(
        sqlName(Config.UsersTable),
        sqlName(Config.UsersCashColumn or 'cash'),
        sqlName(Config.UsersCashColumn or 'cash'),
        sqlName(Config.UsersIdColumn)
    ), { amount, uid })

    if affected and affected > 0 then return true, 'Bani adaugati.' end
    return false, 'Nu s-a putut actualiza cash-ul.'
end

local function takeUserCash(uid, amount)
    uid = tonumber(uid)
    amount = math.floor(tonumber(amount or 0) or 0)
    if not uid or uid <= 0 or amount <= 0 then return false, 'Date invalide.' end

    local affected = MySQL.update.await(('UPDATE %s SET %s = COALESCE(%s, 0) - ? WHERE %s = ? AND COALESCE(%s, 0) >= ?'):format(
        sqlName(Config.UsersTable),
        sqlName(Config.UsersCashColumn or 'cash'),
        sqlName(Config.UsersCashColumn or 'cash'),
        sqlName(Config.UsersIdColumn),
        sqlName(Config.UsersCashColumn or 'cash')
    ), { amount, uid, amount })

    if affected and affected > 0 then return true, 'Bani scosi.' end
    return false, 'Nu ai suficienti bani.'
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

    local function readStoredDirty(value)
        if type(value) == 'table' then
            return math.max(0, math.floor(tonumber(value.amount or value.count or 0) or 0))
        end
        return math.max(0, math.floor(tonumber(value or 0) or 0))
    end

    local dirtyAmount = readStoredDirty(inv[DIRTY_MONEY_STORAGE_KEY] or inv._dirtymoney or inv.dirtymoney)
    local quickSlots = normalizeQuickSlots(inv[QUICK_SLOTS_STORAGE_KEY] or inv._quick_slots or inv.quick_slots)

    for i = 1, Config.Slots do
        local item = inv[i] or inv[tostring(i)]
        if type(item) == 'table' then
            local itemId = trim(item.item_id or item.id or item.name)
            local amount = math.floor(tonumber(item.amount or item.count or 1) or 1)
            if itemId ~= '' and amount > 0 then
                if isMoneyItem(itemId) then
                    -- money nu se mai tine in inventory_json; vine direct din users.cash.
                elseif isDirtyMoneyItem(itemId) then
                    dirtyAmount = dirtyAmount + amount
                else
                    out[i] = { item_id = itemId, amount = amount }
                end
            end
        end
    end

    if dirtyAmount > 0 then out[DIRTY_MONEY_STORAGE_KEY] = dirtyAmount end
    if hasTableValues(quickSlots) then out[QUICK_SLOTS_STORAGE_KEY] = quickSlots end
    return out
end

local function serializeInventory(inv)
    local out = {}
    inv = normalizeInventory(inv)
    for i = 1, Config.Slots do
        if inv[i] then out[tostring(i)] = inv[i] end
    end

    local dirtyAmount = math.floor(tonumber(inv[DIRTY_MONEY_STORAGE_KEY] or 0) or 0)
    if dirtyAmount > 0 then
        out[DIRTY_MONEY_STORAGE_KEY] = { item_id = dirtyMoneyItemId(), amount = dirtyAmount }
    end

    local quickSlots = normalizeQuickSlots(inv[QUICK_SLOTS_STORAGE_KEY])
    if hasTableValues(quickSlots) then out[QUICK_SLOTS_STORAGE_KEY] = quickSlots end

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


local function reloadInventory(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return normalizeInventory({}) end

    Inventories[uid] = nil
    local row = MySQL.single.await(('SELECT inventory_json FROM %s WHERE uid = ? LIMIT 1'):format(sqlName(Config.InventoryTable)), { uid })
    if not row then
        MySQL.insert.await(('INSERT INTO %s (uid, inventory_json, updated_at) VALUES (?, ?, NOW())'):format(sqlName(Config.InventoryTable)), { uid, '{}' })
        Inventories[uid] = normalizeInventory({})
    else
        Inventories[uid] = normalizeInventory(jsonDecode(row.inventory_json))
    end

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


local function loadClothesItems(force)
    local now = GetGameTimer()
    if not force and ClothesItemsCache and ClothesItemsCacheExpires > now then return ClothesItemsCache end

    ClothesItemsCache = {}

    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT * FROM %s ORDER BY category_key ASC, item_name ASC, item_id ASC'):format(sqlName(Config.ClothesItemsTable or 'clothes_items')), {}) or {}
    end)

    if not ok then
        ClothesItemsCacheExpires = now + 5000
        return ClothesItemsCache
    end

    for _, row in ipairs(rows or {}) do
        local itemId = trim(row.item_id)
        local category, cfg = getClothingCategoryConfig(row.category_key)
        if itemId ~= '' and category and cfg then
            local ctype = tostring(row.clothes_type or cfg.type or 'component')
            local componentId = tonumber(row.component_id or cfg.componentId or -1) or -1
            local propId = tonumber(row.prop_id or cfg.propId or -1) or -1
            ClothesItemsCache[itemId] = {
                item_id = itemId,
                item_name = row.item_name or itemId,
                image = row.image or '',
                tradable = tonumber(row.tradable or 1) == 1,
                stackable = tonumber(row.stackable or 0) == 1,
                usable = tonumber(row.usable or 1) == 1,
                giveable = tonumber(row.giveable or 1) == 1,
                max_stack = math.max(1, tonumber(row.max_stack or 1) or 1),
                is_clothing = true,
                clothes_category = category,
                clothes_drawable = math.floor(tonumber(row.drawable or 0) or 0),
                clothes_texture = math.max(0, math.floor(tonumber(row.texture or 0) or 0)),
                clothes_type = ctype,
                component_id = componentId,
                prop_id = propId
            }
        end
    end

    ClothesItemsCacheExpires = now + 5000
    return ClothesItemsCache
end

local function getClothesItem(itemId)
    itemId = trim(itemId)
    if itemId == '' then return nil end
    return loadClothesItems(false)[itemId]
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
                max_stack = math.max(1, tonumber(row.max_stack or Config.ItemDefaults.max_stack or 100) or 100),
                is_gradient = (tonumber(row.is_gradient or 0) == 1) or (itemId:match('^%d+_gradient$') ~= nil),
                gradient_id = tonumber(row.gradient_id or itemId:match('^(%d+)_gradient$') or 0) or 0,
                is_take_gradient = itemId == tostring(Config.TakeGradientItemId or 'takegradient')
            }
        end
    end

    for _, currencyId in ipairs({ moneyItemId(), dirtyMoneyItemId() }) do
        if ItemsCache[currencyId] then
            ItemsCache[currencyId].stackable = true
            ItemsCache[currencyId].max_stack = currencyMaxStack()
            ItemsCache[currencyId].is_currency = true
            if isMoneyItem(currencyId) then ItemsCache[currencyId].cash_source = true end
        end
    end

    ItemsCacheExpires = now + 5000
    return ItemsCache
end

local function getItem(itemId)
    itemId = trim(itemId)
    local item = loadItems(false)[itemId]
    if item then return item end
    item = getClothesItem(itemId)
    if item then return item end
    return currencyMeta(itemId)
end

local function getDirtyMoneyAmount(inv)
    inv = normalizeInventory(inv)
    return math.max(0, math.floor(tonumber(inv[DIRTY_MONEY_STORAGE_KEY] or 0) or 0))
end

local function getQuickSlots(inv)
    inv = normalizeInventory(inv)
    return normalizeQuickSlots(inv[QUICK_SLOTS_STORAGE_KEY])
end

local function setQuickSlot(inv, quickIndex, slotIndex)
    inv[QUICK_SLOTS_STORAGE_KEY] = normalizeQuickSlots(inv[QUICK_SLOTS_STORAGE_KEY])
    quickIndex = tonumber(quickIndex or 0) or 0
    slotIndex = tonumber(slotIndex or 0) or 0
    if quickIndex < 1 or quickIndex > 5 then return false end

    if slotIndex >= 1 and slotIndex <= (Config.Slots or 49) then
        for i = 1, 5 do
            local key = tostring(i)
            if key ~= tostring(quickIndex) and tonumber(inv[QUICK_SLOTS_STORAGE_KEY][key] or 0) == slotIndex then
                inv[QUICK_SLOTS_STORAGE_KEY][key] = nil
            end
        end
        inv[QUICK_SLOTS_STORAGE_KEY][tostring(quickIndex)] = slotIndex
    else
        inv[QUICK_SLOTS_STORAGE_KEY][tostring(quickIndex)] = nil
    end

    if not hasTableValues(inv[QUICK_SLOTS_STORAGE_KEY]) then
        inv[QUICK_SLOTS_STORAGE_KEY] = nil
    end

    return true
end

local function clearQuickRefs(inv, slotIndex)
    slotIndex = tonumber(slotIndex or 0) or 0
    if slotIndex < 1 then return end

    local quickSlots = normalizeQuickSlots(inv[QUICK_SLOTS_STORAGE_KEY])
    local changed = false
    for i = 1, 5 do
        local key = tostring(i)
        if tonumber(quickSlots[key] or 0) == slotIndex then
            quickSlots[key] = nil
            changed = true
        end
    end

    if changed then
        inv[QUICK_SLOTS_STORAGE_KEY] = hasTableValues(quickSlots) and quickSlots or nil
    end
end

local function swapQuickRefs(inv, aSlot, bSlot)
    aSlot = tonumber(aSlot or 0) or 0
    bSlot = tonumber(bSlot or 0) or 0
    if aSlot < 1 or bSlot < 1 or aSlot == bSlot then return end

    local quickSlots = normalizeQuickSlots(inv[QUICK_SLOTS_STORAGE_KEY])
    local changed = false
    for i = 1, 5 do
        local key = tostring(i)
        local value = tonumber(quickSlots[key] or 0) or 0
        if value == aSlot then
            quickSlots[key] = bSlot
            changed = true
        elseif value == bSlot then
            quickSlots[key] = aSlot
            changed = true
        end
    end

    if changed then inv[QUICK_SLOTS_STORAGE_KEY] = quickSlots end
end

local function replaceQuickRefs(inv, oldSlot, newSlot)
    oldSlot = tonumber(oldSlot or 0) or 0
    newSlot = tonumber(newSlot or 0) or 0
    if oldSlot < 1 or newSlot < 1 or oldSlot == newSlot then return end

    local quickSlots = normalizeQuickSlots(inv[QUICK_SLOTS_STORAGE_KEY])
    local changed = false
    for i = 1, 5 do
        local key = tostring(i)
        if tonumber(quickSlots[key] or 0) == oldSlot then
            quickSlots[key] = newSlot
            changed = true
        end
    end

    if changed then inv[QUICK_SLOTS_STORAGE_KEY] = quickSlots end
end

local function hydrateQuickSlots(inv)
    inv = normalizeInventory(inv)
    local quickSlots = getQuickSlots(inv)
    local out = {}

    for i = 1, 5 do
        local slotIndex = tonumber(quickSlots[tostring(i)] or 0) or 0
        local slot = slotIndex > 0 and inv[slotIndex] or nil
        local meta = slot and getItem(slot.item_id) or nil
        if meta and meta.usable then out[tostring(i)] = slotIndex end
    end

    return out
end

local function hydrateCurrencyItems(uid, inv)
    local out = {}
    local cash = getUserCash(uid)
    if cash > 0 then
        local meta = getItem(moneyItemId())
        out[moneyItemId()] = {
            slot = moneyItemId(),
            item_id = meta.item_id,
            item_name = meta.item_name,
            image = meta.image,
            amount = cash,
            tradable = meta.tradable,
            stackable = true,
            usable = meta.usable,
            giveable = meta.giveable,
            max_stack = currencyMaxStack(),
            special_currency = true,
            cash_source = true
        }
    end

    local dirtyAmount = getDirtyMoneyAmount(inv)
    if dirtyAmount > 0 then
        local meta = getItem(dirtyMoneyItemId())
        out[dirtyMoneyItemId()] = {
            slot = dirtyMoneyItemId(),
            item_id = meta.item_id,
            item_name = meta.item_name,
            image = meta.image,
            amount = dirtyAmount,
            tradable = meta.tradable,
            stackable = true,
            usable = meta.usable,
            giveable = meta.giveable,
            max_stack = currencyMaxStack(),
            special_currency = true
        }
    end

    return out
end

local function hydrateInventory(inv)
    local out = {}
    inv = normalizeInventory(inv)

    for i = 1, Config.Slots do
        local slot = inv[i]
        local meta = slot and getItem(slot.item_id) or nil
        if slot and meta and not isCurrencyItem(slot.item_id) then
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
                max_stack = meta.max_stack,
                is_gradient = meta.is_gradient,
                gradient_id = meta.gradient_id,
                is_take_gradient = meta.is_take_gradient,
                is_clothing = meta.is_clothing or nil,
                clothes_category = meta.clothes_category or nil,
                clothes_drawable = meta.clothes_drawable or nil,
                clothes_texture = meta.clothes_texture or nil
            }
        else
            out[i] = nil
        end
    end

    return out
end

local function hasFreeSlotOrStack(uid, itemId, amount)
    if isCurrencyItem(itemId) then return true end
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

    if isMoneyItem(itemId) then
        return addUserCash(uid, amount)
    end

    if isDirtyMoneyItem(itemId) then
        local inv = ensureInventory(uid)
        inv[DIRTY_MONEY_STORAGE_KEY] = getDirtyMoneyAmount(inv) + amount
        saveInventory(uid)
        return true, 'Dirty money adaugat.'
    end

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

    if isMoneyItem(itemId) then
        return takeUserCash(uid, amount)
    end

    if isDirtyMoneyItem(itemId) then
        local inv = ensureInventory(uid)
        local have = getDirtyMoneyAmount(inv)
        if have < amount then return false, 'Jucatorul nu are suficienti bani murdari.' end
        local left = have - amount
        inv[DIRTY_MONEY_STORAGE_KEY] = left > 0 and left or nil
        saveInventory(uid)
        return true, 'Dirty money scos.'
    end

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
            if slot.amount <= 0 then
                inv[i] = nil
                clearQuickRefs(inv, i)
            end
            if remaining <= 0 then break end
        end
    end

    saveInventory(uid)
    return true, 'Item scos.'
end


local function getPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    if not coords then return nil end
    return coords
end

local function distanceCoords(a, b)
    if not a or not b then return 999999.0 end
    local dx = (a.x or 0.0) - (b.x or 0.0)
    local dy = (a.y or 0.0) - (b.y or 0.0)
    local dz = (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function hydrateDropItems(items)
    local out = {}
    for _, slot in ipairs(items or {}) do
        if slot and slot.item_id and slot.amount and slot.amount > 0 then
            local meta = getItem(slot.item_id)
            if meta then
                out[#out + 1] = {
                    item_id = meta.item_id,
                    item_name = meta.item_name,
                    image = meta.image,
                    amount = slot.amount,
                    tradable = meta.tradable,
                    stackable = meta.stackable,
                    usable = meta.usable,
                    giveable = meta.giveable,
                    max_stack = meta.max_stack,
                    special_currency = meta.is_currency == true or nil,
                    is_clothing = meta.is_clothing or nil,
                    clothes_category = meta.clothes_category or nil
                }
            end
        end
    end
    return out
end

local function getNearbyDropsForCoords(coords, radius)
    local out = {}
    radius = tonumber(radius or 4.0) or 4.0
    for id, drop in pairs(Drops) do
        if drop and drop.items and #drop.items > 0 then
            local dcoords = vector3(drop.x + 0.0, drop.y + 0.0, drop.z + 0.0)
            if #(coords - dcoords) <= radius then
                out[#out + 1] = {
                    id = id,
                    x = drop.x,
                    y = drop.y,
                    z = drop.z,
                    items = hydrateDropItems(drop.items)
                }
            end
        end
    end
    return out
end

local function getMarkerDropsForCoords(coords, radius)
    local out = {}
    radius = tonumber(radius or 35.0) or 35.0
    for id, drop in pairs(Drops) do
        if drop and drop.items and #drop.items > 0 then
            local dcoords = vector3(drop.x + 0.0, drop.y + 0.0, drop.z + 0.0)
            if #(coords - dcoords) <= radius then
                out[#out + 1] = { id = id, x = drop.x, y = drop.y, z = drop.z }
            end
        end
    end
    return out
end

local function findDropNear(coords)
    for id, drop in pairs(Drops) do
        if drop and drop.items and #drop.items > 0 then
            local dcoords = vector3(drop.x + 0.0, drop.y + 0.0, drop.z + 0.0)
            if #(coords - dcoords) <= (Config.DropMergeRadius or 4.0) then
                return id, drop
            end
        end
    end
    return nil, nil
end

local function addToDrop(drop, itemId, amount)
    local meta = getItem(itemId)
    if not meta then return false end
    amount = math.floor(tonumber(amount or 1) or 1)
    if amount <= 0 then return false end

    if meta.stackable then
        for _, slot in ipairs(drop.items) do
            if slot.item_id == itemId then
                slot.amount = slot.amount + amount
                return true
            end
        end
    end

    drop.items[#drop.items + 1] = { item_id = itemId, amount = amount }
    return true
end

local function addItemToUidPreferred(uid, itemId, amount, preferredSlot)
    uid = tonumber(uid)
    itemId = trim(itemId)
    amount = math.floor(tonumber(amount or 1) or 1)
    preferredSlot = tonumber(preferredSlot or 0) or 0
    if not uid or uid <= 0 or itemId == '' or amount <= 0 then return false, 'Date invalide.' end

    if isCurrencyItem(itemId) then
        return giveItemToUid(uid, itemId, amount)
    end

    local item = getItem(itemId)
    if not item then return false, 'Item ID invalid.' end
    local inv = ensureInventory(uid)
    local remaining = amount

    if preferredSlot >= 1 and preferredSlot <= Config.Slots then
        local slot = inv[preferredSlot]
        if not slot then
            local put = item.stackable and math.min(remaining, item.max_stack) or 1
            inv[preferredSlot] = { item_id = item.item_id, amount = put }
            remaining = remaining - put
        elseif item.stackable and slot.item_id == item.item_id and slot.amount < item.max_stack then
            local add = math.min(remaining, item.max_stack - slot.amount)
            slot.amount = slot.amount + add
            remaining = remaining - add
        end
    end

    if remaining > 0 then
        local ok, msg = giveItemToUid(uid, itemId, remaining)
        if not ok then
            saveInventory(uid)
            return false, msg
        end
    end

    saveInventory(uid)
    return true, 'Item adaugat.'
end


local function ensureUserClothesRow(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return false end
    local ok = pcall(function()
        MySQL.insert.await(('INSERT IGNORE INTO %s (uid) VALUES (?)'):format(sqlName(Config.UsersClothesTable or 'users_clothes')), { uid })
    end)
    return ok == true
end

local function getUserClothes(uid)
    uid = tonumber(uid)
    local out = {}
    if not uid or uid <= 0 then return out end
    ensureUserClothesRow(uid)

    local ok, row = pcall(function()
        return MySQL.single.await(('SELECT * FROM %s WHERE uid = ? LIMIT 1'):format(sqlName(Config.UsersClothesTable or 'users_clothes')), { uid })
    end)
    if not ok or not row then return out end

    for _, category in ipairs(clothingCategoryOrder()) do
        local raw = row[category]
        local data = raw and clothingJson(raw) or {}
        if type(data) == 'table' and trim(data.item_id) ~= '' then
            local meta = getClothesItem(data.item_id)
            if meta then
                out[category] = {
                    item_id = meta.item_id,
                    item_name = meta.item_name,
                    image = meta.image,
                    category_key = category,
                    drawable = meta.clothes_drawable,
                    texture = meta.clothes_texture,
                    clothes_type = meta.clothes_type,
                    component_id = meta.component_id,
                    prop_id = meta.prop_id
                }
            else
                local _, cfg = getClothingCategoryConfig(category)
                out[category] = {
                    item_id = trim(data.item_id),
                    item_name = tostring(data.item_name or data.item_id),
                    image = tostring(data.image or ''),
                    category_key = category,
                    drawable = math.floor(tonumber(data.drawable or 0) or 0),
                    texture = math.max(0, math.floor(tonumber(data.texture or 0) or 0)),
                    clothes_type = tostring(data.clothes_type or (cfg and cfg.type) or 'component'),
                    component_id = tonumber(data.component_id or (cfg and cfg.componentId) or -1) or -1,
                    prop_id = tonumber(data.prop_id or (cfg and cfg.propId) or -1) or -1
                }
            end
        end
    end

    return out
end

local function saveUserClothing(uid, category, data)
    uid = tonumber(uid)
    category = normalizeClothingCategory(category)
    if not uid or uid <= 0 or not category then return false end
    ensureUserClothesRow(uid)

    local value = nil
    if type(data) == 'table' and trim(data.item_id) ~= '' then
        value = jsonEncode({
            item_id = trim(data.item_id),
            item_name = tostring(data.item_name or data.item_id or ''),
            image = tostring(data.image or ''),
            drawable = math.floor(tonumber(data.drawable or 0) or 0),
            texture = math.max(0, math.floor(tonumber(data.texture or 0) or 0)),
            clothes_type = tostring(data.clothes_type or 'component'),
            component_id = tonumber(data.component_id or -1) or -1,
            prop_id = tonumber(data.prop_id or -1) or -1
        })
    end

    local ok = pcall(function()
        MySQL.update.await(('UPDATE %s SET %s = ?, updated_at = NOW() WHERE uid = ?'):format(sqlName(Config.UsersClothesTable or 'users_clothes'), sqlName(category)), { value, uid })
    end)

    return ok == true
end

local function clothingToInventoryMeta(data)
    if type(data) ~= 'table' or trim(data.item_id) == '' then return nil end
    return { item_id = trim(data.item_id), amount = 1 }
end

local function buildUserClothesForUi(uid)
    local saved = getUserClothes(uid)
    local out = {}
    for category, item in pairs(saved) do
        out[category] = {
            slot = category,
            item_id = item.item_id,
            item_name = item.item_name,
            image = item.image,
            amount = 1,
            tradable = true,
            stackable = false,
            usable = true,
            giveable = true,
            max_stack = 1,
            is_clothing = true,
            equipped = true,
            clothes_category = category,
            clothes_drawable = item.drawable,
            clothes_texture = item.texture
        }
    end
    return out
end

local function buildEmptyClothingApplyEntry(category)
    category = normalizeClothingCategory(category)
    if not category then return nil end

    local _, cfg = getClothingCategoryConfig(category)
    if not cfg then return nil end

    local defaults = Config.EmptyClothingDefaults or Config.EmptyClothes or {}
    local def = defaults[category] or {}
    local ctype = tostring(def.type or cfg.type or 'component')

    return {
        category = category,
        item_id = '',
        empty = true,
        drawable = math.floor(tonumber(def.drawable or 0) or 0),
        texture = math.max(0, math.floor(tonumber(def.texture or 0) or 0)),
        clothes_type = ctype,
        component_id = tonumber(def.componentId or def.component_id or cfg.componentId or -1) or -1,
        prop_id = tonumber(def.propId or def.prop_id or cfg.propId or -1) or -1
    }
end

local function buildUserClothesApplyPayload(uid)
    local saved = getUserClothes(uid)
    local out = {}

    for _, category in ipairs(clothingCategoryOrder()) do
        local item = saved[category]
        if item and item.item_id then
            out[category] = {
                category = category,
                item_id = item.item_id,
                drawable = item.drawable,
                texture = item.texture,
                clothes_type = item.clothes_type,
                component_id = item.component_id,
                prop_id = item.prop_id,
                empty = false
            }
        else
            out[category] = buildEmptyClothingApplyEntry(category)
        end
    end

    return out
end

local function sendClothesPayloadToClient(src, payload)
    src = tonumber(src or 0) or 0
    if src <= 0 or not GetPlayerName(src) then return end

    ClothesApplyRevision[src] = (tonumber(ClothesApplyRevision[src] or 0) or 0) + 1

    TriggerClientEvent(
        'driftzone_inventory:client:applyClothes',
        src,
        payload or {},
        buildClothingCategoriesPayload(),
        ClothesApplyRevision[src]
    )
end

local function buildSingleClothingApplyPayload(uid, category)
    category = normalizeClothingCategory(category)
    if not category then return {} end

    local saved = getUserClothes(uid)
    local item = saved[category]

    if item and item.item_id then
        return {
            [category] = {
                category = category,
                item_id = item.item_id,
                drawable = item.drawable,
                texture = item.texture,
                clothes_type = item.clothes_type,
                component_id = item.component_id,
                prop_id = item.prop_id,
                empty = false
            }
        }
    end

    return { [category] = buildEmptyClothingApplyEntry(category) }
end

local function pushClothesToClient(src, uid)
    if not src or src <= 0 then return end
    uid = uid or getUid(src)
    if not uid then return end
    sendClothesPayloadToClient(src, buildUserClothesApplyPayload(uid))
end

local function pushSingleClothingToClient(src, uid, category)
    if not src or src <= 0 then return end
    uid = uid or getUid(src)
    if not uid then return end
    sendClothesPayloadToClient(src, buildSingleClothingApplyPayload(uid, category))
end

local function equipClothingFromSlot(src, uid, category, slotIndex)
    category = normalizeClothingCategory(category)
    slotIndex = tonumber(slotIndex or 0) or 0
    if not category or slotIndex < 1 or slotIndex > Config.Slots then return false, 'Slot sau categorie invalida.' end

    local inv = ensureInventory(uid)
    local slot = inv[slotIndex]
    if not slot or (tonumber(slot.amount or 0) or 0) <= 0 then return false, 'Nu ai item in slotul selectat.' end

    local meta = getItem(slot.item_id)
    if not meta or not meta.is_clothing then return false, 'Itemul nu este haina.' end
    if normalizeClothingCategory(meta.clothes_category) ~= category then
        return false, ('Itemul merge doar pe categoria %s.'):format(tostring(meta.clothes_category or ''))
    end

    local saved = getUserClothes(uid)
    local old = saved[category]
    if old and old.item_id and (tonumber(slot.amount or 1) or 1) > 1 and not hasFreeSlotOrStack(uid, old.item_id, 1) then
        return false, 'Nu ai slot liber pentru haina veche.'
    end

    slot.amount = (tonumber(slot.amount or 1) or 1) - 1
    local sourceBecameEmpty = slot.amount <= 0
    if sourceBecameEmpty then
        inv[slotIndex] = nil
        clearQuickRefs(inv, slotIndex)
    end

    if old and old.item_id then
        if sourceBecameEmpty and not inv[slotIndex] then
            inv[slotIndex] = clothingToInventoryMeta(old)
        else
            local okOld, msgOld = addItemToUidPreferred(uid, old.item_id, 1, 0)
            if not okOld then
                -- rollback simplu: punem itemul inapoi
                if inv[slotIndex] and inv[slotIndex].item_id == meta.item_id then
                    inv[slotIndex].amount = inv[slotIndex].amount + 1
                elseif not inv[slotIndex] then
                    inv[slotIndex] = { item_id = meta.item_id, amount = 1 }
                end
                saveInventory(uid)
                return false, msgOld or 'Nu am putut scoate haina veche.'
            end
            inv = ensureInventory(uid)
        end
    end

    saveUserClothing(uid, category, {
        item_id = meta.item_id,
        item_name = meta.item_name,
        image = meta.image,
        drawable = meta.clothes_drawable,
        texture = meta.clothes_texture,
        clothes_type = meta.clothes_type,
        component_id = meta.component_id,
        prop_id = meta.prop_id
    })

    saveInventory(uid)
    pushSingleClothingToClient(src, uid, category)
    return true, ('Ai echipat %s.'):format(meta.item_name or meta.item_id)
end

local function unequipClothingToSlot(src, uid, category, toSlot)
    category = normalizeClothingCategory(category)
    toSlot = tonumber(toSlot or 0) or 0
    if not category then return false, 'Categorie invalida.' end

    local saved = getUserClothes(uid)
    local old = saved[category]
    if not old or not old.item_id then return false, 'Nu ai haina echipata acolo.' end

    if not hasFreeSlotOrStack(uid, old.item_id, 1) then return false, 'Nu ai slot liber in inventar.' end
    local okAdd, msgAdd = addItemToUidPreferred(uid, old.item_id, 1, toSlot)
    if not okAdd then return false, msgAdd or 'Nu pot pune haina in inventar.' end

    saveUserClothing(uid, category, nil)
    saveInventory(uid)
    pushSingleClothingToClient(src, uid, category)
    return true, 'Haina a fost scoasa si scoasa de pe caracter.'
end

local function requestClothesLoadForPlayer(src, attempt)
    src = tonumber(src or 0) or 0
    attempt = tonumber(attempt or 0) or 0
    if src <= 0 or not GetPlayerName(src) then return false end
    if Config.ClothesLoad and Config.ClothesLoad.Enabled == false then return false end

    local uid = getUid(src)
    if not uid then
        local max = tonumber((Config.ClothesLoad or {}).RetryCount or 18) or 18
        local delay = tonumber((Config.ClothesLoad or {}).RetryDelayMs or 850) or 850
        if attempt < max then
            SetTimeout(delay, function()
                requestClothesLoadForPlayer(src, attempt + 1)
            end)
        end
        return false
    end

    pushClothesToClient(src, uid)
    return true
end

local function pushNearbyDrops(src)
    local coords = getPlayerCoords(src)
    if not coords then return end
    TriggerClientEvent('driftzone_inventory:client:updateDropped', src, {
        dropped = getNearbyDropsForCoords(coords, Config.DropShowRadius or 4.0),
        drops = getMarkerDropsForCoords(coords, Config.DropMarkerRadius or 35.0)
    })
end

local function pushDropsToAll()
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target and target > 0 then
            pushNearbyDrops(target)
        end
    end
end


local function pushInventory(src, mode, target, forceReload)
    local uid = getUid(src)
    if not uid then return end
    if forceReload == true then
        ItemsCache = nil
        ClothesItemsCache = nil
    end
    local inv = forceReload == true and reloadInventory(uid) or ensureInventory(uid)
    TriggerClientEvent('driftzone_inventory:client:open', src, {
        slots = Config.Slots,
        columns = Config.Columns,
        inventory = hydrateInventory(inv),
        moneyItems = hydrateCurrencyItems(uid, inv),
        quickSlots = hydrateQuickSlots(inv),
        clothesSlots = buildUserClothesForUi(uid),
        clothingCategories = buildClothingCategoriesPayload(),
        mainColor = Config.MainColor,
        mode = mode or 'normal',
        target = target or nil,
        dropped = (function()
            local coords = getPlayerCoords(src)
            if coords then return getNearbyDropsForCoords(coords, Config.DropShowRadius or 4.0) end
            return {}
        end)()
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


local function buildAdminItemsList()
    ensureGradientItemColumns()
    local rows = MySQL.query.await(('SELECT item_id, item_name, image, tradable, stackable, usable, giveable, max_stack, is_gradient, gradient_id FROM %s ORDER BY item_name ASC, item_id ASC'):format(sqlName(Config.ItemsTable)), {}) or {}
    local out = {}

    for _, row in ipairs(rows) do
        out[#out + 1] = {
            item_id = tostring(row.item_id or ''),
            item_name = tostring(row.item_name or row.item_id or ''),
            image = tostring(row.image or ''),
            tradable = tonumber(row.tradable or 1) == 1 and 1 or 0,
            stackable = tonumber(row.stackable or 1) == 1 and 1 or 0,
            usable = tonumber(row.usable or 0) == 1 and 1 or 0,
            giveable = tonumber(row.giveable or 1) == 1 and 1 or 0,
            max_stack = math.max(1, math.floor(tonumber(row.max_stack or 100) or 100)),
            is_gradient = tonumber(row.is_gradient or 0) == 1 and 1 or 0,
            gradient_id = math.max(0, math.floor(tonumber(row.gradient_id or 0) or 0))
        }
    end

    return out
end

local function saveInventoryItemFromAdmin(admin, data)
    data = type(data) == 'table' and data or {}
    local originalId = trim(data.original_id)
    local itemId = trim(data.item_id):lower():gsub('%s+', '_')
    local name = trim(data.item_name)
    local image = trim(data.image)
    local tradable = tonumber(data.tradable or 1) == 1 and 1 or 0
    local stackable = tonumber(data.stackable or 1) == 1 and 1 or 0
    local usable = tonumber(data.usable or 0) == 1 and 1 or 0
    local giveable = tonumber(data.giveable or 1) == 1 and 1 or 0
    local maxStack = math.max(1, math.floor(tonumber(data.max_stack or 100) or 100))
    local isGradient = tonumber(data.is_gradient or 0) == 1 and 1 or 0
    local gradientId = math.max(0, math.floor(tonumber(data.gradient_id or 0) or 0))

    if originalId ~= '' and itemId ~= originalId then
        return false, 'Item ID nu poate fi schimbat din /items ca sa nu strice itemele deja existente.', originalId
    end

    if isGradient == 1 then
        if gradientId <= 0 then
            return false, 'Trebuie sa pui ID-ul gradientului.', itemId
        end
        if originalId == '' then itemId = tostring(gradientId) .. tostring(Config.GradientItemSuffix or '_gradient') end
        if name == '' then name = ('Gradient %s'):format(gradientId) end
        usable = 1
        giveable = 1
        stackable = 1
    end

    if itemId == '' or not itemId:match('^[a-z0-9_%-]+$') then
        return false, 'Item ID invalid.', itemId
    end

    if isCurrencyItem(itemId) then
        stackable = 1
        maxStack = currencyMaxStack()
    end

    if name == '' then
        return false, 'Item Name obligatoriu.', itemId
    end

    ensureGradientItemColumns()

    local okSave, errSave = pcall(function()
        MySQL.update.await(('INSERT INTO %s (item_id, item_name, image, tradable, stackable, usable, giveable, max_stack, is_gradient, gradient_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), image = VALUES(image), tradable = VALUES(tradable), stackable = VALUES(stackable), usable = VALUES(usable), giveable = VALUES(giveable), max_stack = VALUES(max_stack), is_gradient = VALUES(is_gradient), gradient_id = VALUES(gradient_id), updated_at = NOW()'):format(sqlName(Config.ItemsTable)), {
            itemId, name, image, tradable, stackable, usable, giveable, maxStack, isGradient, gradientId
        })
    end)

    if not okSave then
        print('[DRIFTZONE_INVENTORY] item save error: ' .. tostring(errSave))
        return false, 'Eroare SQL la salvare. Verifica consola.', itemId
    end

    ItemsCache = nil
    return true, 'Item salvat cu succes: ' .. itemId, itemId
end


local function buildAdminClothesList()
    local rows = {}
    pcall(function()
        rows = MySQL.query.await(('SELECT * FROM %s ORDER BY category_key ASC, item_name ASC, item_id ASC'):format(sqlName(Config.ClothesItemsTable or 'clothes_items')), {}) or {}
    end)

    local out = {}
    for _, row in ipairs(rows or {}) do
        local category, cfg = getClothingCategoryConfig(row.category_key)
        if category and cfg then
            out[#out + 1] = {
                item_id = tostring(row.item_id or ''),
                item_name = tostring(row.item_name or row.item_id or ''),
                image = tostring(row.image or ''),
                category_key = category,
                category_label = tostring(cfg.label or category),
                drawable = math.floor(tonumber(row.drawable or 0) or 0),
                texture = math.max(0, math.floor(tonumber(row.texture or 0) or 0)),
                clothes_type = tostring(row.clothes_type or cfg.type or 'component'),
                component_id = tonumber(row.component_id or cfg.componentId or -1) or -1,
                prop_id = tonumber(row.prop_id or cfg.propId or -1) or -1,
                tradable = tonumber(row.tradable or 1) == 1 and 1 or 0,
                stackable = tonumber(row.stackable or 0) == 1 and 1 or 0,
                usable = tonumber(row.usable or 1) == 1 and 1 or 0,
                giveable = tonumber(row.giveable or 1) == 1 and 1 or 0,
                max_stack = math.max(1, math.floor(tonumber(row.max_stack or 1) or 1))
            }
        end
    end
    return out
end

local function saveClothesItemFromAdmin(admin, data)
    data = type(data) == 'table' and data or {}
    local originalId = trim(data.original_id)
    local itemId = trim(data.item_id):lower():gsub('%s+', '_')
    local name = trim(data.item_name)
    local image = trim(data.image)
    local category, cfg = getClothingCategoryConfig(data.category_key)
    local drawable = math.floor(tonumber(data.drawable or data.clothes_id or 0) or 0)
    local texture = math.max(0, math.floor(tonumber(data.texture or 0) or 0))
    local tradable = tonumber(data.tradable or 1) == 1 and 1 or 0
    local stackable = tonumber(data.stackable or 0) == 1 and 1 or 0
    local usable = tonumber(data.usable or 1) == 1 and 1 or 0
    local giveable = tonumber(data.giveable or 1) == 1 and 1 or 0
    local maxStack = math.max(1, math.floor(tonumber(data.max_stack or 1) or 1))

    if originalId ~= '' and itemId ~= originalId then
        return false, 'Item ID nu poate fi schimbat la editare.', originalId
    end
    if itemId == '' or not itemId:match('^[a-z0-9_%-]+$') then return false, 'Item ID invalid.', itemId end
    if name == '' then return false, 'Item Name obligatoriu.', itemId end
    if not category or not cfg then return false, 'Categorie invalida.', itemId end

    local ctype = tostring(cfg.type or 'component')
    local componentId = tonumber(cfg.componentId or -1) or -1
    local propId = tonumber(cfg.propId or -1) or -1

    local okSave, errSave = pcall(function()
        MySQL.update.await(('INSERT INTO %s (item_id, item_name, image, category_key, drawable, texture, clothes_type, component_id, prop_id, tradable, stackable, usable, giveable, max_stack, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), image = VALUES(image), category_key = VALUES(category_key), drawable = VALUES(drawable), texture = VALUES(texture), clothes_type = VALUES(clothes_type), component_id = VALUES(component_id), prop_id = VALUES(prop_id), tradable = VALUES(tradable), stackable = VALUES(stackable), usable = VALUES(usable), giveable = VALUES(giveable), max_stack = VALUES(max_stack), updated_at = NOW()'):format(sqlName(Config.ClothesItemsTable or 'clothes_items')), {
            itemId, name, image, category, drawable, texture, ctype, componentId, propId, tradable, stackable, usable, giveable, maxStack
        })
    end)

    if not okSave then
        print('[DRIFTZONE_INVENTORY] clothes item save error: ' .. tostring(errSave))
        return false, 'Eroare SQL la salvare. Verifica SQL.sql si consola.', itemId
    end

    ClothesItemsCache = nil
    return true, 'Haina salvata cu succes: ' .. itemId, itemId
end

RegisterCommand(Config.Command or 'inventory', function(src)
    if src <= 0 then return end
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.') end
    OpenPlayers[src] = true
    pushInventory(src, 'normal', nil, true)
end, false)

RegisterCommand('additem', function(src)
    local admin = requireAdmin(src, Config.Admin.additem or 6)
    if not admin then return end
    TriggerClientEvent('driftzone_inventory:client:addItemPanel', src, { mainColor = Config.MainColor })
end, false)

RegisterCommand('items', function(src)
    local admin = requireAdmin(src, Config.Admin.items or 6)
    if not admin then return end
    TriggerClientEvent('driftzone_inventory:client:itemsPanel', src, {
        mainColor = Config.MainColor,
        items = buildAdminItemsList()
    })
end, false)


RegisterCommand('addclothes', function(src)
    local admin = requireAdmin(src, Config.Admin.addclothes or 6)
    if not admin then return end
    TriggerClientEvent('driftzone_inventory:client:addClothesPanel', src, {
        mainColor = Config.MainColor,
        categories = buildClothingCategoriesPayload()
    })
end, false)

RegisterCommand('clothesitems', function(src)
    local admin = requireAdmin(src, Config.Admin.clothesitems or 6)
    if not admin then return end
    TriggerClientEvent('driftzone_inventory:client:clothesItemsPanel', src, {
        mainColor = Config.MainColor,
        categories = buildClothingCategoriesPayload(),
        items = buildAdminClothesList()
    })
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
    pushInventory(src, 'normal', nil, true)
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
    local swapped = false
    if b and meta and meta.stackable and b.item_id == a.item_id then
        local maxStack = meta.max_stack or 100
        local free = math.max(0, maxStack - b.amount)
        local move = math.min(free, a.amount)
        if move > 0 then
            b.amount = b.amount + move
            a.amount = a.amount - move
            if a.amount <= 0 then
                inv[fromSlot] = nil
                replaceQuickRefs(inv, fromSlot, toSlot)
            end
        else
            inv[fromSlot], inv[toSlot] = inv[toSlot], inv[fromSlot]
            swapped = true
        end
    else
        inv[fromSlot], inv[toSlot] = inv[toSlot], inv[fromSlot]
        swapped = true
    end

    if swapped then swapQuickRefs(inv, fromSlot, toSlot) end
    saveInventory(uid)
    pushInventory(src, 'normal')
end)

RegisterNetEvent('driftzone_inventory:server:addItemSubmit', function(data)
    local src = source
    local admin = requireAdmin(src, Config.Admin.additem or 6)
    if not admin then return end

    local ok, msg, itemId = saveInventoryItemFromAdmin(admin, data)
    if ok then logAction('admin_additem', admin.uid, 0, itemId, 0, data or {}) end
    TriggerClientEvent('driftzone_inventory:client:addItemResult', src, ok == true, msg or '')
end)

RegisterNetEvent('driftzone_inventory:server:updateItemSubmit', function(data)
    local src = source
    local admin = requireAdmin(src, Config.Admin.items or 6)
    if not admin then return end

    local ok, msg, itemId = saveInventoryItemFromAdmin(admin, data)
    if ok then logAction('admin_edititem', admin.uid, 0, itemId, 0, data or {}) end
    TriggerClientEvent('driftzone_inventory:client:itemsResult', src, ok == true, msg or '', buildAdminItemsList(), itemId)
end)


RegisterNetEvent('driftzone_inventory:server:addClothesSubmit', function(data)
    local src = source
    local admin = requireAdmin(src, Config.Admin.addclothes or 6)
    if not admin then return end

    local ok, msg, itemId = saveClothesItemFromAdmin(admin, data)
    if ok then logAction('admin_addclothes', admin.uid, 0, itemId, 0, data or {}) end
    TriggerClientEvent('driftzone_inventory:client:clothesResult', src, ok == true, msg or '')
end)

RegisterNetEvent('driftzone_inventory:server:updateClothesItemSubmit', function(data)
    local src = source
    local admin = requireAdmin(src, Config.Admin.clothesitems or 6)
    if not admin then return end

    local ok, msg, itemId = saveClothesItemFromAdmin(admin, data)
    if ok then logAction('admin_editclothes', admin.uid, 0, itemId, 0, data or {}) end
    TriggerClientEvent('driftzone_inventory:client:clothesItemsResult', src, ok == true, msg or '', buildAdminClothesList(), itemId)
end)

RegisterNetEvent('driftzone_inventory:server:equipClothingSlot', function(category, slotIndex)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    local ok, msg = equipClothingFromSlot(src, uid, category, slotIndex)
    notify(src, ok and 'success' or 'warning', msg or '')
    pushInventory(src, 'normal')
end)

RegisterNetEvent('driftzone_inventory:server:unequipClothingSlot', function(category, toSlot)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    local ok, msg = unequipClothingToSlot(src, uid, category, toSlot)
    notify(src, ok and 'success' or 'warning', msg or '')
    pushInventory(src, 'normal')
end)

RegisterNetEvent('driftzone_inventory:server:requestClothesLoad', function()
    requestClothesLoadForPlayer(source, 0)
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
    }, true)
end)

RegisterNetEvent('driftzone_inventory:server:giveSelected', function(targetServerId, slotIndex, amount)
    local src = source
    local fromUid = getUid(src)
    targetServerId = tonumber(targetServerId or 0) or 0
    local rawSlot = tostring(slotIndex or '')
    local specialItemId = nil
    if isMoneyItem(rawSlot) then specialItemId = moneyItemId() end
    if isDirtyMoneyItem(rawSlot) then specialItemId = dirtyMoneyItemId() end
    amount = math.floor(tonumber(amount or 1) or 1)

    if not fromUid then return end
    if targetServerId <= 0 or not GetPlayerName(targetServerId) or targetServerId == src then return notify(src, 'warning', 'Jucator invalid.') end
    if not distanceOk(src, targetServerId) then return notify(src, 'warning', 'Jucatorul este prea departe.') end

    local toUid = getUid(targetServerId)
    if not toUid then return notify(src, 'warning', 'Jucatorul nu este logat.') end
    if amount <= 0 then return end

    local item = nil
    local itemId = nil

    if specialItemId then
        item = getItem(specialItemId)
        if not item then return notify(src, 'warning', 'Item invalid.') end
        if not item.giveable then return notify(src, 'warning', 'Acest item nu poate fi oferit.') end
        itemId = item.item_id

        local okTake, takeMsg = takeItemFromUid(fromUid, itemId, amount)
        if not okTake then return notify(src, 'warning', takeMsg or 'Nu ai suficiente bucati.') end
    else
        slotIndex = tonumber(slotIndex or 0) or 0
        if slotIndex < 1 or slotIndex > Config.Slots then return end

        local inv = ensureInventory(fromUid)
        local slot = inv[slotIndex]
        if not slot or slot.amount < amount then return notify(src, 'warning', 'Nu ai suficiente bucati.') end

        item = getItem(slot.item_id)
        if not item then return notify(src, 'warning', 'Item invalid.') end
        if not item.giveable then return notify(src, 'warning', 'Acest item nu poate fi oferit.') end
        if not hasFreeSlotOrStack(toUid, item.item_id, amount) then return notify(src, 'warning', 'Jucatorul nu are sloturi disponibile.') end

        itemId = item.item_id
        slot.amount = slot.amount - amount
        if slot.amount <= 0 then
            inv[slotIndex] = nil
            clearQuickRefs(inv, slotIndex)
        end
        saveInventory(fromUid)
    end

    local ok, msg = giveItemToUid(toUid, itemId, amount)
    if not ok then
        giveItemToUid(fromUid, itemId, amount)
        return notify(src, 'warning', msg or 'Nu s-a putut oferi itemul.')
    end

    logAction('player_giveitem', fromUid, toUid, itemId, amount, { from = GetPlayerName(src), to = GetPlayerName(targetServerId) })

    runServerHook('OnPlayerGiveItem', {
        source = src,
        target = targetServerId,
        fromUid = fromUid,
        toUid = toUid,
        itemId = itemId,
        itemName = item.item_name,
        amount = amount
    })

    notify(src, 'success', ('Ai oferit %sx %s.'):format(amount, item.item_name))
    notify(targetServerId, 'info', ('Ai primit %sx %s.'):format(amount, item.item_name))

    -- Nu mai redeschide inventarul dupa GIVE.
    TriggerClientEvent('driftzone_inventory:client:actionDone', src, 'give', {
        target = targetServerId,
        itemId = itemId,
        amount = amount
    })
end)

local function useInventorySlot(src, uid, slotIndex)
    slotIndex = tonumber(slotIndex or 0) or 0
    if not uid or slotIndex < 1 or slotIndex > Config.Slots then return end

    local inv = ensureInventory(uid)
    local slot = inv[slotIndex]
    if not slot then return end
    local item = getItem(slot.item_id)
    if not item or not item.usable then return notify(src, 'warning', 'Acest item nu se poate folosi.') end

    if item.is_clothing then
        local ok, msg = equipClothingFromSlot(src, uid, item.clothes_category, slotIndex)
        notify(src, ok and 'success' or 'warning', msg or '')
        pushInventory(src, 'normal')
        return
    end

    if item.item_id == tostring(Config.TakeGradientItemId or 'takegradient') or item.is_take_gradient then
        local gradientRes = tostring(Config.GradientResource or 'driftzone_gradients')

        if GetResourceState(gradientRes) ~= 'started' then
            return notify(src, 'warning', 'Sistemul de gradient nu este pornit.')
        end

        TriggerClientEvent('driftzone_inventory:client:closeForGradient', src)

        -- Itemul NU este scos de inventar aici.
        -- driftzone_gradients il scoate doar dupa ce gradientul a fost scos cu succes si returneaza itemul ID_gradient.
        local ok, result = pcall(function()
            if exports[gradientRes] and exports[gradientRes].OpenTakeGradient then
                return exports[gradientRes]:OpenTakeGradient(src)
            end
            return false
        end)

        if ok and result == true then
            TriggerEvent('driftzone_inventory:server:itemUsed', src, uid, item.item_id, slotIndex, { take_gradient = true })
            return
        end

        TriggerEvent('driftzone_gradients:server:useTakeGradient')
        TriggerEvent('driftzone_inventory:server:itemUsed', src, uid, item.item_id, slotIndex, { take_gradient = true, fallback = true })
        return
    end

    if item.is_gradient and (tonumber(item.gradient_id or 0) or 0) > 0 then
        local gradientId = tonumber(item.gradient_id or 0) or 0
        local gradientRes = tostring(Config.GradientResource or 'driftzone_gradients')

        if GetResourceState(gradientRes) ~= 'started' then
            return notify(src, 'warning', 'Sistemul de gradient nu este pornit.')
        end

        TriggerClientEvent('driftzone_inventory:client:closeForGradient', src)

        local ok, result = pcall(function()
            return exports[gradientRes]:OpenGradient(src, gradientId)
        end)

        if ok and result == true then
            TriggerEvent('driftzone_inventory:server:itemUsed', src, uid, item.item_id, slotIndex, { gradient_id = gradientId })
            return
        end

        TriggerClientEvent('driftzone_gradients:client:useGradient', src, gradientId)
        TriggerEvent('driftzone_inventory:server:itemUsed', src, uid, item.item_id, slotIndex, { gradient_id = gradientId, fallback = true })
        return
    end

    TriggerEvent('driftzone_inventory:server:itemUsed', src, uid, item.item_id, slotIndex)
    TriggerClientEvent('driftzone_inventory:client:itemUsed', src, item.item_id)
end

local function useCurrencyItem(src, uid, itemId)
    itemId = trim(itemId)
    if not isCurrencyItem(itemId) then return end

    local item = getItem(itemId)
    if not item or not item.usable then return notify(src, 'warning', 'Acest item nu se poate folosi.') end

    local amount = 0
    if isMoneyItem(itemId) then
        amount = getUserCash(uid)
    elseif isDirtyMoneyItem(itemId) then
        amount = getDirtyMoneyAmount(ensureInventory(uid))
    end

    if amount <= 0 then return notify(src, 'warning', 'Nu ai acest item.') end

    TriggerEvent('driftzone_inventory:server:itemUsed', src, uid, item.item_id, item.item_id, { currency = true, amount = amount })
    TriggerClientEvent('driftzone_inventory:client:itemUsed', src, item.item_id)
end

RegisterNetEvent('driftzone_inventory:server:useItem', function(slotIndex)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    local rawSlot = tostring(slotIndex or '')
    if isMoneyItem(rawSlot) then return useCurrencyItem(src, uid, moneyItemId()) end
    if isDirtyMoneyItem(rawSlot) then return useCurrencyItem(src, uid, dirtyMoneyItemId()) end

    useInventorySlot(src, uid, slotIndex)
end)

RegisterNetEvent('driftzone_inventory:server:useQuickSlot', function(quickIndex)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    quickIndex = tonumber(quickIndex or 0) or 0
    if quickIndex < 1 or quickIndex > 5 then return end

    local inv = ensureInventory(uid)
    local quickSlots = getQuickSlots(inv)
    local slotIndex = tonumber(quickSlots[tostring(quickIndex)] or 0) or 0
    if slotIndex < 1 or slotIndex > Config.Slots then return end

    useInventorySlot(src, uid, slotIndex)
end)

RegisterNetEvent('driftzone_inventory:server:setQuickSlot', function(quickIndex, slotIndex)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    quickIndex = tonumber(quickIndex or 0) or 0
    slotIndex = tonumber(slotIndex or 0) or 0
    if quickIndex < 1 or quickIndex > 5 then return end

    local inv = ensureInventory(uid)
    if slotIndex > 0 then
        if slotIndex < 1 or slotIndex > Config.Slots then return end
        local slot = inv[slotIndex]
        if not slot then return notify(src, 'warning', 'Slot invalid.') end
        local item = getItem(slot.item_id)
        if not item or not item.usable then return notify(src, 'warning', 'Doar itemele usable pot fi puse pe quick slot.') end
    end

    setQuickSlot(inv, quickIndex, slotIndex)
    saveInventory(uid)
    pushInventory(src, 'normal')
end)


RegisterNetEvent('driftzone_inventory:server:requestNearbyDrops', function()
    local src = source
    if not src or src <= 0 then return end
    pushNearbyDrops(src)
end)

RegisterNetEvent('driftzone_inventory:server:dropItem', function(slotIndex, amount)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    local rawSlot = tostring(slotIndex or '')
    local specialItemId = nil
    if isMoneyItem(rawSlot) then specialItemId = moneyItemId() end
    if isDirtyMoneyItem(rawSlot) then specialItemId = dirtyMoneyItemId() end

    amount = math.floor(tonumber(amount or 1) or 1)
    if amount <= 0 then return end

    local coords = getPlayerCoords(src)
    if not coords then return end

    local item = nil
    local itemId = nil

    if specialItemId then
        itemId = specialItemId
        item = getItem(itemId)
        if not item then return notify(src, 'warning', 'Item invalid.') end

        local okTake, takeMsg = takeItemFromUid(uid, itemId, amount)
        if not okTake then return notify(src, 'warning', takeMsg or 'Nu ai suficiente bucati.') end
    else
        slotIndex = tonumber(slotIndex or 0) or 0
        if slotIndex < 1 or slotIndex > Config.Slots then return end

        local inv = ensureInventory(uid)
        local slot = inv[slotIndex]
        if not slot or slot.amount < amount then return notify(src, 'warning', 'Nu ai suficiente bucati.') end

        item = getItem(slot.item_id)
        if not item then return notify(src, 'warning', 'Item invalid.') end
        if isCurrencyItem(item.item_id) then return notify(src, 'warning', 'Banii se arunca doar din slotul special.') end

        itemId = item.item_id
        slot.amount = slot.amount - amount
        if slot.amount <= 0 then
            inv[slotIndex] = nil
            clearQuickRefs(inv, slotIndex)
        end
        saveInventory(uid)
    end

    local dropId, drop = findDropNear(coords)
    if not drop then
        NextDropId = NextDropId + 1
        dropId = ('DZD-%s-%s'):format(os.time(), NextDropId)
        drop = { id = dropId, x = coords.x, y = coords.y, z = coords.z - 0.95, items = {}, createdAt = os.time() }
        Drops[dropId] = drop
    end

    if not addToDrop(drop, itemId, amount) then
        giveItemToUid(uid, itemId, amount)
        return notify(src, 'warning', 'Nu s-a putut arunca itemul.')
    end

    logAction('player_dropitem', uid, 0, itemId, amount, { name = GetPlayerName(src), drop = dropId })

    runServerHook('OnPlayerDropItem', {
        source = src,
        uid = uid,
        itemId = itemId,
        itemName = item.item_name,
        amount = amount,
        dropId = dropId,
        coords = { x = drop.x, y = drop.y, z = drop.z }
    })

    TriggerClientEvent('driftzone_inventory:client:actionDone', src, 'drop', {
        itemId = itemId,
        amount = amount,
        dropId = dropId
    })

    pushInventory(src, 'normal')
    pushDropsToAll()
end)

RegisterNetEvent('driftzone_inventory:server:pickupDrop', function(dropId, index, toSlot)
    local src = source
    local uid = getUid(src)
    if not uid then return end

    dropId = tostring(dropId or '')
    index = tonumber(index or 0) or 0
    toSlot = tonumber(toSlot or 0) or 0
    local drop = Drops[dropId]
    if not drop or not drop.items or not drop.items[index] then return end

    local coords = getPlayerCoords(src)
    if not coords then return end
    local dcoords = vector3(drop.x + 0.0, drop.y + 0.0, drop.z + 0.0)
    if #(coords - dcoords) > (Config.DropPickupRadius or 4.0) then
        return notify(src, 'warning', 'Esti prea departe de item.')
    end

    local slot = drop.items[index]
    local itemId = slot.item_id
    local amount = math.floor(tonumber(slot.amount or 1) or 1)
    if not hasFreeSlotOrStack(uid, itemId, amount) then return notify(src, 'warning', 'Nu ai sloturi disponibile.') end

    local ok, msg = addItemToUidPreferred(uid, itemId, amount, toSlot)
    if not ok then return notify(src, 'warning', msg or 'Nu poti lua itemul.') end

    table.remove(drop.items, index)
    if #drop.items <= 0 then Drops[dropId] = nil end

    logAction('player_pickupitem', 0, uid, itemId, amount, { name = GetPlayerName(src), drop = dropId })

    runServerHook('OnPlayerPickupItem', {
        source = src,
        uid = uid,
        itemId = itemId,
        amount = amount,
        dropId = dropId
    })

    TriggerClientEvent('driftzone_inventory:client:actionDone', src, 'pickup', {
        itemId = itemId,
        amount = amount,
        dropId = dropId
    })

    pushInventory(src, 'normal')
    pushDropsToAll()
end)


RegisterNetEvent('driftzone_inventory:server:closed', function()
    local src = source
    OpenPlayers[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    local uid = getUid(src)
    if uid and Inventories[uid] then saveInventory(uid) end
    OpenPlayers[src] = nil
    ClothesApplyRevision[src] = nil
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

exports('ReloadClothes', function(src)
    return requestClothesLoadForPlayer(src, 0)
end)

exports('GetClothes', function(uid)
    return getUserClothes(uid)
end)


local function tableNameRaw(name)
    return tostring(name or ''):gsub('`', '')
end

local function columnExists(tableName, columnName)
    local row = MySQL.single.await([[
        SELECT COUNT(*) AS total
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
        LIMIT 1
    ]], { tableNameRaw(tableName), tostring(columnName or '') })

    return row and tonumber(row.total or 0) and tonumber(row.total or 0) > 0
end

local function ensureColumn(tableName, columnName, definition)
    tableName = tableNameRaw(tableName)
    columnName = tostring(columnName or '')
    if tableName == '' or columnName == '' then return false end

    local okExists, exists = pcall(function() return columnExists(tableName, columnName) end)
    if okExists and exists then return true end

    local okAlter, err = pcall(function()
        MySQL.update.await(('ALTER TABLE %s ADD COLUMN `%s` %s'):format(sqlName(tableName), columnName:gsub('`', ''), tostring(definition or 'TEXT NULL')), {})
    end)

    if not okAlter then
        print(('[DRIFTZONE_INVENTORY] Nu pot adauga coloana %s.%s: %s'):format(tableName, columnName, tostring(err)))
        return false
    end

    return true
end


local function ensureClothesTables()
    local cols = {}
    for _, category in ipairs(clothingCategoryOrder()) do
        cols[#cols + 1] = ('`%s` LONGTEXT NULL'):format(category)
    end

    local sql = ([[
        CREATE TABLE IF NOT EXISTS %s (
            `uid` INT NOT NULL,
            %s,
            `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`uid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]):format(sqlName(Config.UsersClothesTable or 'users_clothes'), table.concat(cols, ',\n            '))

    MySQL.query.await(sql, {})

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS %s (
            `item_id` VARCHAR(64) NOT NULL,
            `item_name` VARCHAR(128) NOT NULL,
            `image` TEXT NULL,
            `category_key` VARCHAR(32) NOT NULL,
            `drawable` INT NOT NULL DEFAULT 0,
            `texture` INT NOT NULL DEFAULT 0,
            `clothes_type` VARCHAR(16) NOT NULL DEFAULT 'component',
            `component_id` INT NOT NULL DEFAULT -1,
            `prop_id` INT NOT NULL DEFAULT -1,
            `tradable` TINYINT NOT NULL DEFAULT 1,
            `stackable` TINYINT NOT NULL DEFAULT 0,
            `usable` TINYINT NOT NULL DEFAULT 1,
            `giveable` TINYINT NOT NULL DEFAULT 1,
            `max_stack` INT NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`item_id`),
            KEY `idx_category_key` (`category_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]):format(sqlName(Config.ClothesItemsTable or 'clothes_items')), {})
end

ensureGradientItemColumns = function()
    ensureColumn(Config.ItemsTable, 'is_gradient', 'TINYINT NOT NULL DEFAULT 0')
    ensureColumn(Config.ItemsTable, 'gradient_id', 'INT NOT NULL DEFAULT 0')
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    ensureGradientItemColumns()
    local okClothes, errClothes = pcall(ensureClothesTables)
    if not okClothes then
        print('[DRIFTZONE_INVENTORY] Clothes SQL setup failed: ' .. tostring(errClothes))
    end
    ClothesItemsCache = nil
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target and target > 0 then
            SetTimeout(1500, function()
                requestClothesLoadForPlayer(target, 0)
            end)
        end
    end
    print('[DRIFTZONE_INVENTORY] Loaded.')
end)
