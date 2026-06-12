local ActiveSessions = {}
local UidCache = {}
local AdminCache = {}

local function cleanSql(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent(Config.NotifyEvent or 'client:notify', src, typ or 'info', duration or 5000, tostring(msg or ''))
end

local function getUid(src)
    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local cached = UidCache[src]
    if cached and cached.expires > GetGameTimer() then return cached.uid end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:GetUserId(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, value = pcall(fn)
        local uid = tonumber(value)
        if ok and uid and uid > 0 then
            UidCache[src] = { uid = uid, expires = GetGameTimer() + 30000 }
            return uid
        end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end
    local ok, result = pcall(function() return exports.driftzone_auth:IsLoggedIn(src) end)
    return ok and result == true
end

local function isAduty(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true'
end

local UserColumns = nil

local function getUserColumns()
    if UserColumns then return UserColumns end
    UserColumns = {}

    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM %s'):format(cleanSql(Config.UsersTable or 'users')), {}) or {}
    end)

    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row and row.Field then UserColumns[tostring(row.Field)] = true end
        end
    end

    return UserColumns
end

local function getAdminData(src)
    local uid = getUid(src)
    if not uid then return nil end

    local cached = AdminCache[uid]
    if cached and cached.expires > GetGameTimer() then return cached.data end

    local cols = getUserColumns()
    local adminCol = tostring(Config.AdminColumn or 'admin_level')
    local fallbackCol = Config.AdminColumnFallback and tostring(Config.AdminColumnFallback) or nil
    local adutyCol = tostring(Config.AdutyColumn or 'aduty')
    local selectParts = {}

    if cols[adminCol] then selectParts[#selectParts + 1] = ('%s AS admin_level'):format(cleanSql(adminCol)) else selectParts[#selectParts + 1] = '0 AS admin_level' end
    if fallbackCol and fallbackCol ~= '' and cols[fallbackCol] then selectParts[#selectParts + 1] = ('%s AS admin_fallback'):format(cleanSql(fallbackCol)) else selectParts[#selectParts + 1] = '0 AS admin_fallback' end
    if cols[adutyCol] then selectParts[#selectParts + 1] = ('%s AS aduty'):format(cleanSql(adutyCol)) else selectParts[#selectParts + 1] = '0 AS aduty' end

    local row = MySQL.single.await((
        'SELECT %s FROM %s WHERE %s = ? LIMIT 1'
    ):format(table.concat(selectParts, ', '), cleanSql(Config.UsersTable or 'users'), cleanSql(Config.UsersIdColumn or 'uid')), { uid })

    if not row then return nil end

    local level = tonumber(row.admin_level or row.admin_fallback or 0) or 0
    local data = { uid = uid, level = level, aduty = isAduty(row.aduty) }
    AdminCache[uid] = { data = data, expires = GetGameTimer() + 2500 }
    return data
end

local function requireAdmin(src)
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return false end
    local admin = getAdminData(src)
    if not admin or admin.level < (Config.AdminLevel or 6) then notify(src, 'warning', 'Nu ai gradul necesar pentru aceasta comanda.') return false end
    if not admin.aduty then notify(src, 'warning', 'Trebuie sa fii ON DUTY.') return false end
    return true
end

local function getGradient(id)
    id = tonumber(id or 0) or 0
    if id <= 0 then return nil end
    return Config.Gradients and Config.Gradients[id] or nil
end

local function itemIdForGradient(id)
    return tostring(id) .. tostring(Config.InventoryItemSuffix or '_gradient')
end

local function getInventoryResource()
    return tostring(Config.InventoryResource or 'driftzone_inventory')
end

local function takeInventoryItem(uid, itemId, amount)
    local res = getInventoryResource()
    if GetResourceState(res) ~= 'started' then return false, 'inventory_not_started' end
    local ok, result = pcall(function()
        return exports[res]:TakeItem(uid, itemId, amount or 1)
    end)
    return ok and result == true, itemId
end

local function giveInventoryItem(uid, itemId, amount)
    local res = getInventoryResource()
    if GetResourceState(res) ~= 'started' then return false, 'inventory_not_started' end
    local ok, result = pcall(function()
        return exports[res]:GiveItem(uid, itemId, amount or 1)
    end)
    return ok and result == true, itemId
end

local function removeGradientItem(uid, gradientId)
    return takeInventoryItem(uid, itemIdForGradient(gradientId), 1)
end

local function takeTakeGradientItem(uid)
    return takeInventoryItem(uid, tostring(Config.TakeGradientItem or 'takegradient'), 1)
end

local function getVehicleStateData(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local state = Entity(entity).state
    local plate = tostring(state.dz_garage_plate or state.dz_vs_plate or GetVehicleNumberPlateText(entity) or '')
    plate = plate:gsub('^%s+', ''):gsub('%s+$', '')

    return {
        entity = entity,
        vehicleId = tonumber(state.dz_garage_db_id or state.vehicleDbId or state.ownedVehicleId or state.dz_vs_sql_id or 0) or 0,
        ownerUid = tonumber(state.dz_garage_owner_uid or state.dz_vs_owner_id or 0) or 0,
        plate = plate
    }
end

local function findVehicleRow(vdata)
    if not vdata then return nil end

    local t = cleanSql(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanSql(Config.OwnedVehiclesIdColumn or 'id')
    local ownerCol = cleanSql(Config.OwnedVehiclesOwnerColumn or 'owner_id')
    local plateCol = cleanSql(Config.OwnedVehiclesPlateColumn or 'vehicle_plate')
    local gradCol = cleanSql(Config.OwnedVehiclesGradientColumn or 'gradient')

    if vdata.vehicleId and vdata.vehicleId > 0 then
        return MySQL.single.await(('SELECT %s AS id, %s AS owner_id, %s AS plate, %s AS gradient FROM %s WHERE %s = ? LIMIT 1'):format(idCol, ownerCol, plateCol, gradCol, t, idCol), { vdata.vehicleId })
    end

    if vdata.plate and vdata.plate ~= '' then
        return MySQL.single.await(('SELECT %s AS id, %s AS owner_id, %s AS plate, %s AS gradient FROM %s WHERE TRIM(%s) = TRIM(?) LIMIT 1'):format(idCol, ownerCol, plateCol, gradCol, t, plateCol), { vdata.plate })
    end

    return nil
end

local function setVehicleGradient(vehicleId, data)
    vehicleId = tonumber(vehicleId or 0) or 0
    if vehicleId <= 0 then return false end

    local t = cleanSql(Config.OwnedVehiclesTable or 'ownedvehicles')
    local idCol = cleanSql(Config.OwnedVehiclesIdColumn or 'id')
    local gradCol = cleanSql(Config.OwnedVehiclesGradientColumn or 'gradient')

    if data == nil then
        local affected = MySQL.update.await(('UPDATE %s SET %s = NULL WHERE %s = ? LIMIT 1'):format(t, gradCol, idCol), { vehicleId })
        return affected and affected > 0
    end

    local payload = json.encode(data or {})
    local affected = MySQL.update.await(('UPDATE %s SET %s = ? WHERE %s = ? LIMIT 1'):format(t, gradCol, idCol), { payload, vehicleId })
    return affected and affected > 0
end

local function updateVehicleGradient(vehicleId, data)
    return setVehicleGradient(vehicleId, data)
end

local function safeDecode(raw)
    if type(raw) == 'table' then return raw end
    if raw == nil then return {} end
    local text = tostring(raw or '')
    if text == '' or text == 'null' then return {} end
    local ok, decoded = pcall(json.decode, text)
    if ok and type(decoded) == 'table' then return decoded end
    return {}
end

local function gradientPartFromData(data)
    if type(data) ~= 'table' or not tonumber(data.id) then return nil end
    return {
        id = tonumber(data.id),
        name = data.name or data.label or ('Gradient ' .. tostring(data.id)),
        type = data.type,
        colorId = data.colorId,
        originalRamp = data.originalRamp,
        appliedAt = data.appliedAt or os.time()
    }
end

local function getGradientParts(raw)
    local data = safeDecode(raw)
    local parts = {}

    if type(data.primary) == 'table' and tonumber(data.primary.id) then parts.primary = gradientPartFromData(data.primary) end
    if type(data.secondary) == 'table' and tonumber(data.secondary.id) then parts.secondary = gradientPartFromData(data.secondary) end

    if not parts.primary and not parts.secondary and tonumber(data.id) then
        local part = gradientPartFromData(data)
        local applyTo = tostring(data.applyTo or 'both'):lower()
        if applyTo == 'primary' then
            parts.primary = part
        elseif applyTo == 'secondary' then
            parts.secondary = part
        else
            parts.primary = part
            parts.secondary = part
        end
    end

    return parts, data
end

local function hasAnyPart(parts)
    return type(parts) == 'table' and (parts.primary ~= nil or parts.secondary ~= nil)
end

local function availablePartPayload(parts)
    local payload = {}
    if parts.primary then payload.primary = true end
    if parts.secondary then payload.secondary = true end
    if parts.primary and parts.secondary then payload.both = true end
    return payload
end

local function firstGradientPart(parts)
    return parts.primary or parts.secondary or {}
end

local function storeFromParts(parts)
    if not parts or (not parts.primary and not parts.secondary) then return nil end

    local primary = parts.primary
    local secondary = parts.secondary

    if primary and secondary and tonumber(primary.id) == tonumber(secondary.id) then
        return {
            id = tonumber(primary.id),
            name = primary.name,
            type = primary.type,
            colorId = primary.colorId,
            originalRamp = primary.originalRamp,
            applyTo = 'both',
            appliedAt = os.time()
        }
    end

    if primary and not secondary then
        return {
            id = tonumber(primary.id),
            name = primary.name,
            type = primary.type,
            colorId = primary.colorId,
            originalRamp = primary.originalRamp,
            applyTo = 'primary',
            appliedAt = os.time()
        }
    end

    if secondary and not primary then
        return {
            id = tonumber(secondary.id),
            name = secondary.name,
            type = secondary.type,
            colorId = secondary.colorId,
            originalRamp = secondary.originalRamp,
            applyTo = 'secondary',
            appliedAt = os.time()
        }
    end

    return {
        id = tonumber(primary.id),
        name = primary.name,
        type = primary.type,
        colorId = primary.colorId,
        originalRamp = primary.originalRamp,
        applyTo = 'custom',
        primary = primary,
        secondary = secondary,
        appliedAt = os.time()
    }
end

local function logGradient(src, uid, row, gradient, applyTo, mode, itemRemoved)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO `gradient_logs`
            (`uid`, `player_name`, `vehicle_id`, `plate`, `gradient_id`, `gradient_name`, `apply_to`, `mode`, `item_removed`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]], {
            uid or 0,
            GetPlayerName(src) or 'Unknown',
            row and tonumber(row.id or 0) or 0,
            row and tostring(row.plate or '') or '',
            gradient and tonumber(gradient.id or 0) or 0,
            gradient and (gradient.label or gradient.name or ('Gradient ' .. tostring(gradient.id or ''))) or '',
            applyTo,
            mode,
            itemRemoved and 1 or 0
        })
    end)
end

local function startApplySession(src, gradientId, mode, requireOwner, removeItem)
    gradientId = tonumber(gradientId or 0) or 0
    local gradient = getGradient(gradientId)
    if not gradient then return false end

    ActiveSessions[src] = {
        gradientId = gradientId,
        mode = mode or 'item',
        requireOwner = requireOwner ~= false,
        removeItem = removeItem == true,
        expires = GetGameTimer() + 120000
    }

    TriggerClientEvent('driftzone_gradients:client:startSelector', src, {
        gradient = gradient,
        mode = mode or 'item',
        mainColor = Config.MainColor
    })

    return true
end

local function startRemoveSession(src)
    if not isLogged(src) then notify(src, 'warning', 'Trebuie sa fii logat.') return false end

    ActiveSessions[src] = {
        mode = 'remove',
        requireOwner = Config.RequireOwnerForTrigger ~= false,
        removeTakeItem = true,
        expires = GetGameTimer() + 120000
    }

    TriggerClientEvent('driftzone_gradients:client:startSelector', src, {
        mode = 'remove',
        mainColor = Config.MainColor
    })

    return true
end

RegisterCommand(Config.Command or 'gradient', function(src, args)
    if src == 0 then return end
    if not requireAdmin(src) then return end

    local gradientId = tonumber(args[1] or 0) or 0
    if not getGradient(gradientId) then
        notify(src, 'warning', 'Folosire: /gradient id_gradient')
        return
    end

    startApplySession(src, gradientId, 'admin', false, false)
end, false)

RegisterCommand(Config.TakeGradientCommand or 'takegradient', function(src)
    if src == 0 then return end
    startRemoveSession(src)
end, false)

RegisterNetEvent('driftzone_gradients:server:useGradient', function(gradientId)
    local src = source
    if not isLogged(src) then return notify(src, 'warning', 'Trebuie sa fii logat.') end

    gradientId = tonumber(gradientId or 0) or 0
    if not getGradient(gradientId) then return notify(src, 'warning', 'Gradient invalid.') end

    startApplySession(src, gradientId, 'item', Config.RequireOwnerForTrigger ~= false, true)
end)

RegisterNetEvent('driftzone_gradients:server:useTakeGradient', function()
    startRemoveSession(source)
end)

RegisterNetEvent('driftzone_gradients:server:cancel', function()
    ActiveSessions[source] = nil
end)

RegisterNetEvent('driftzone_gradients:server:vehicleSelected', function(netId)
    local src = source
    local session = ActiveSessions[src]
    if not session or session.expires < GetGameTimer() then
        ActiveSessions[src] = nil
        return notify(src, 'warning', 'Selectia a expirat.')
    end

    local uid = getUid(src)
    local vdata = getVehicleStateData(netId)
    local row = findVehicleRow(vdata)

    if session.requireOwner then
        if not uid then return notify(src, 'warning', 'Nu ti-am gasit UID-ul.') end
        if not row then return notify(src, 'warning', 'Masina selectata nu este personala.') end
        if tonumber(row.owner_id or 0) ~= tonumber(uid) then
            return notify(src, 'warning', 'Aceasta masina nu iti apartine.')
        end
    end

    ActiveSessions[src].selectedNetId = tonumber(netId)
    ActiveSessions[src].selectedVehicleId = row and tonumber(row.id or 0) or 0
    ActiveSessions[src].selectedPlate = row and tostring(row.plate or '') or (vdata and vdata.plate or '')

    if session.mode == 'remove' then
        local parts = row and select(1, getGradientParts(row.gradient)) or {}
        if not hasAnyPart(parts) then
            ActiveSessions[src] = nil
            return notify(src, 'warning', 'Masina selectata nu are gradient.')
        end

        local first = firstGradientPart(parts)
        TriggerClientEvent('driftzone_gradients:client:openRemoveMenu', src, {
            gradient = first,
            plate = ActiveSessions[src].selectedPlate or '',
            parts = availablePartPayload(parts)
        })
        return
    end

    local gradient = getGradient(session.gradientId)
    if not gradient then return notify(src, 'warning', 'Gradient invalid.') end

    TriggerClientEvent('driftzone_gradients:client:openApplyMenu', src, {
        gradient = gradient,
        plate = ActiveSessions[src].selectedPlate or '',
        mode = session.mode
    })
end)

RegisterNetEvent('driftzone_gradients:server:apply', function(applyTo)
    local src = source
    local session = ActiveSessions[src]
    if not session or session.expires < GetGameTimer() then
        ActiveSessions[src] = nil
        return notify(src, 'warning', 'Selectia a expirat.')
    end

    applyTo = tostring(applyTo or 'both'):lower()
    if applyTo ~= 'primary' and applyTo ~= 'secondary' and applyTo ~= 'both' then applyTo = 'both' end

    local gradient = getGradient(session.gradientId)
    if not gradient then return notify(src, 'warning', 'Gradient invalid.') end

    local uid = getUid(src)
    local vdata = getVehicleStateData(session.selectedNetId)
    local row = findVehicleRow(vdata)

    if session.requireOwner then
        if not uid then return notify(src, 'warning', 'Nu ti-am gasit UID-ul.') end
        if not row then return notify(src, 'warning', 'Masina selectata nu este personala.') end
        if tonumber(row.owner_id or 0) ~= tonumber(uid) then return notify(src, 'warning', 'Aceasta masina nu iti apartine.') end
    end

    local itemRemoved = false
    if session.removeItem then
        local okRemove, itemId = removeGradientItem(uid, gradient.id)
        if not okRemove then
            return notify(src, 'warning', ('Nu ai itemul necesar: %s'):format(tostring(itemId or itemIdForGradient(gradient.id))))
        end
        itemRemoved = true
    end

    local saveData = {
        id = gradient.id,
        name = gradient.label,
        type = gradient.type,
        colorId = gradient.colorId,
        originalRamp = gradient.originalRamp,
        applyTo = applyTo,
        appliedAt = os.time()
    }

    if row and tonumber(row.id or 0) > 0 then updateVehicleGradient(row.id, saveData) end

    logGradient(src, uid, row, gradient, applyTo, session.mode, itemRemoved)

    TriggerClientEvent('driftzone_gradients:client:applyGradient', -1, session.selectedNetId, gradient, applyTo)
    TriggerClientEvent('driftzone_gradients:client:applied', src)
    notify(src, 'success', ('Gradient aplicat: %s.'):format(gradient.label or gradient.id), 5000)
    ActiveSessions[src] = nil
end)

RegisterNetEvent('driftzone_gradients:server:remove', function(applyTo)
    local src = source
    local session = ActiveSessions[src]
    if not session or session.mode ~= 'remove' or session.expires < GetGameTimer() then
        ActiveSessions[src] = nil
        return notify(src, 'warning', 'Selectia a expirat.')
    end

    applyTo = tostring(applyTo or 'both'):lower()
    if applyTo ~= 'primary' and applyTo ~= 'secondary' and applyTo ~= 'both' then applyTo = 'both' end

    local uid = getUid(src)
    local vdata = getVehicleStateData(session.selectedNetId)
    local row = findVehicleRow(vdata)

    if session.requireOwner then
        if not uid then return notify(src, 'warning', 'Nu ti-am gasit UID-ul.') end
        if not row then return notify(src, 'warning', 'Masina selectata nu este personala.') end
        if tonumber(row.owner_id or 0) ~= tonumber(uid) then return notify(src, 'warning', 'Aceasta masina nu iti apartine.') end
    end

    local parts = row and select(1, getGradientParts(row.gradient)) or {}
    if not hasAnyPart(parts) then
        ActiveSessions[src] = nil
        return notify(src, 'warning', 'Masina nu mai are gradient.')
    end

    if applyTo == 'primary' and not parts.primary then return notify(src, 'warning', 'Masina nu are gradient pe primary.') end
    if applyTo == 'secondary' and not parts.secondary then return notify(src, 'warning', 'Masina nu are gradient pe secondary.') end
    if applyTo == 'both' and not (parts.primary or parts.secondary) then return notify(src, 'warning', 'Masina nu are gradient.') end

    local okTake, takeItem = takeTakeGradientItem(uid)
    if not okTake then
        return notify(src, 'warning', ('Nu ai itemul necesar: %s'):format(tostring(takeItem or Config.TakeGradientItem or 'takegradient')))
    end

    local giveCounts = {}
    local removedGradientForLog = nil

    local function removePart(partName)
        local part = parts[partName]
        if not part or not tonumber(part.id) then return end
        removedGradientForLog = removedGradientForLog or part
        local id = tonumber(part.id)
        giveCounts[id] = (giveCounts[id] or 0) + 1
        parts[partName] = nil
    end

    if applyTo == 'primary' then
        removePart('primary')
    elseif applyTo == 'secondary' then
        removePart('secondary')
    else
        if parts.primary and parts.secondary and tonumber(parts.primary.id) == tonumber(parts.secondary.id) then
            removedGradientForLog = parts.primary
            giveCounts[tonumber(parts.primary.id)] = 1
            parts.primary = nil
            parts.secondary = nil
        else
            removePart('primary')
            removePart('secondary')
        end
    end

    for gradientId, amount in pairs(giveCounts) do
        local itemId = itemIdForGradient(gradientId)
        local okGive = giveInventoryItem(uid, itemId, amount)
        if not okGive then
            notify(src, 'warning', ('Nu am putut da inapoi itemul %s. Verifica inventory export GiveItem.'):format(itemId), 7000)
        end
    end

    local newStored = storeFromParts(parts)
    if row and tonumber(row.id or 0) > 0 then setVehicleGradient(row.id, newStored) end

    logGradient(src, uid, row, removedGradientForLog or {}, applyTo, 'remove', true)

    TriggerClientEvent('driftzone_gradients:client:removeGradient', -1, session.selectedNetId, applyTo)
    TriggerClientEvent('driftzone_gradients:client:applied', src)
    notify(src, 'success', 'Gradient scos de pe masina.', 5000)
    ActiveSessions[src] = nil
end)

exports('OpenGradient', function(src, gradientId)
    src = tonumber(src or 0) or 0
    gradientId = tonumber(gradientId or 0) or 0
    if src <= 0 or not getGradient(gradientId) then return false end
    return startApplySession(src, gradientId, 'item', Config.RequireOwnerForTrigger ~= false, true)
end)

exports('OpenTakeGradient', function(src)
    src = tonumber(src or 0) or 0
    if src <= 0 then return false end
    return startRemoveSession(src)
end)

AddEventHandler('playerDropped', function()
    ActiveSessions[source] = nil
    UidCache[source] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_GRADIENTS] Loaded.')
end)
