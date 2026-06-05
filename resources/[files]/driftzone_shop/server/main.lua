local buying = {}

local function notify(src, notifyType, message, duration)
    if not Config.Notifications.enabled then return end
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
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

local function getPlayerNameClean(src)
    local name = GetPlayerName(src) or ('Player ' .. tostring(src))
    return tostring(name):gsub('%^%d', '')
end

local function sqlName(name)
    return ('`%s`'):format(tostring(name):gsub('`', ''))
end

local function getItem(itemId)
    itemId = tostring(itemId or '')
    for _, item in ipairs(Config.Items) do
        if tostring(item.id) == itemId then
            return item
        end
    end
    return nil
end

local function publicItem(item)
    return {
        id = tostring(item.id or ''),
        category = tostring(item.category or ''),
        title = tostring(item.title or 'Item'),
        tag = tostring(item.tag or ''),
        short = tostring(item.short or ''),
        description = tostring(item.description or ''),
        price = tonumber(item.price or 0) or 0,
        currency = tostring(item.currency or 'DriftZone Coins'),
        purchasable = item.purchasable == true,
        image = tostring(item.image or ''),
        amount = tonumber(item.amount or 0) or 0
    }
end

local function getShopData(src)
    local uid = getUid(src)
    if not uid then return nil end

    local usersTable = sqlName(Config.Database.usersTable)
    local uidColumn = sqlName(Config.Database.uidColumn)
    local coinsColumn = sqlName(Config.Database.dzCoinsColumn)

    local query = ([[
        SELECT COALESCE(%s, 0) AS dzcoins
        FROM %s
        WHERE %s = ?
        LIMIT 1
    ]]):format(coinsColumn, usersTable, uidColumn)

    local row = MySQL.single.await(query, { uid })

    if not row then return nil end

    local items = {}
    for _, item in ipairs(Config.Items) do
        items[#items + 1] = publicItem(item)
    end

    return {
        uid = uid,
        name = getPlayerNameClean(src),
        dzcoins = tonumber(row.dzcoins or 0) or 0,
        categories = Config.Categories,
        items = items,
        mainColor = Config.MainColor
    }
end

local function sendShopData(src)
    local data = getShopData(src)

    if not data then
        notify(src, Config.Notifications.warningType, 'Trebuie sa fii logat ca sa deschizi shop-ul.')
        return
    end

    TriggerClientEvent('driftzone_shop:client:open', src, data)
end

local function refreshShopData(src)
    local data = getShopData(src)
    if not data then return end
    TriggerClientEvent('driftzone_shop:client:update', src, data)
end

local function getTargetColumn(item)
    if item.type == 'cash' then
        return Config.Database.cashColumn
    end

    if item.type == 'garage_slots' then
        return Config.Database.garageSlotsColumn
    end

    if item.type == 'outside_vehicles' then
        return Config.Database.outsideVehiclesColumn
    end

    return nil
end

local function purchaseUpgrade(uid, item)
    local price = tonumber(item.price or 0) or 0
    local amount = tonumber(item.amount or 0) or 0

    if amount <= 0 then
        return false, 'Item invalid.'
    end

    local targetColumn = getTargetColumn(item)

    if not targetColumn then
        return false, 'Acest item nu poate fi cumparat.'
    end

    local usersTable = sqlName(Config.Database.usersTable)
    local uidColumn = sqlName(Config.Database.uidColumn)
    local coinsColumn = sqlName(Config.Database.dzCoinsColumn)
    local target = sqlName(targetColumn)

    local query = ([[
        UPDATE %s
        SET
            %s = %s - ?,
            %s = COALESCE(%s, 0) + ?
        WHERE %s = ?
          AND %s >= ?
        LIMIT 1
    ]]):format(usersTable, coinsColumn, coinsColumn, target, target, uidColumn, coinsColumn)

    local affected = MySQL.update.await(query, { price, amount, uid, price })

    if not affected or affected <= 0 then
        return false, 'Nu ai suficiente DriftZone Coins.'
    end

    return true, 'Ai cumparat ' .. tostring(item.title or 'item') .. '.'
end

RegisterNetEvent('driftzone_shop:server:open', function()
    sendShopData(source)
end)

RegisterNetEvent('driftzone_shop:server:purchase', function(itemId)
    local src = source
    local uid = getUid(src)

    if not uid then
        notify(src, Config.Notifications.warningType, 'Trebuie sa fii logat.')
        return
    end

    if buying[src] then
        notify(src, Config.Notifications.warningType, 'Asteapta cateva secunde.')
        return
    end

    local item = getItem(itemId)

    if not item then
        notify(src, Config.Notifications.warningType, 'Item invalid.')
        return
    end

    if item.purchasable ~= true then
        notify(src, Config.Notifications.warningType, 'Acest item nu este disponibil momentan.')
        refreshShopData(src)
        return
    end

    buying[src] = true

    local ok, success, message = pcall(function()
        return purchaseUpgrade(uid, item)
    end)

    buying[src] = nil

    if not ok then
        print('[DRIFTZONE_SHOP] Purchase error:')
        print(success)
        notify(src, Config.Notifications.errorType, 'Eroare la cumparare.')
        refreshShopData(src)
        return
    end

    if success then
        notify(src, Config.Notifications.successType, message or 'Cumparare reusita.')
    else
        notify(src, Config.Notifications.warningType, message or 'Cumpararea a esuat.')
    end

    refreshShopData(src)
end)

exports('OpenShop', function(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    sendShopData(src)
end)

exports('RefreshShop', function(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    refreshShopData(src)
end)

AddEventHandler('playerDropped', function()
    buying[source] = nil
end)
