local inventoryOpen = false
local addItemOpen = false
local selectorOpen = false
local itemsOpen = false
local addClothesOpen = false
local clothesItemsOpen = false
local pendingGive = nil
local cursorX, cursorY = 0.5, 0.5
local selectorTarget = nil
local selectorTargetPed = nil
local markerRotation = 0.0
local nearbyDrops = {}
local closeAll

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 4500, tostring(msg or ''))
end

local function setFocus(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function sendNui(data)
    SendNUIMessage(data)
end

local function runClientHook(name, data)
    if not Config or not Config.ClientHooks then return end
    local fn = Config.ClientHooks[name]
    if type(fn) ~= 'function' then return end

    local ok, err = pcall(fn, data or {})
    if not ok then
        print(('[DRIFTZONE_INVENTORY] Client hook %s error: %s'):format(tostring(name), tostring(err)))
    end
end

local function requestAnimDictSafe(dict, timeout)
    dict = tostring(dict or '')
    if dict == '' then return false end

    RequestAnimDict(dict)
    local expires = GetGameTimer() + (tonumber(timeout or 1800) or 1800)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
        if GetGameTimer() > expires then
            return false
        end
    end

    return true
end

local function playNativeAction(anim)
    if not anim or not anim.dict or not anim.anim then return false end

    local ped = PlayerPedId()
    if not ped or ped == 0 or IsPedDeadOrDying(ped, true) then return false end

    local duration = tonumber(anim.duration or 1200) or 1200
    local flag = tonumber(anim.flag or 0) or 0

    if requestAnimDictSafe(anim.dict, anim.timeout or 1800) then
        ClearPedSecondaryTask(ped)
        TaskPlayAnim(ped, anim.dict, anim.anim, 4.0, -4.0, duration, flag, 0.0, false, false, false)

        SetTimeout(duration + 80, function()
            local p = PlayerPedId()
            if p and p ~= 0 then
                StopAnimTask(p, anim.dict, anim.anim, 1.0)
            end
        end)

        return true
    end

    return false
end

local function playActionAnimation(actionName)
    local cfg = Config.ActionAnimations or {}
    if cfg.Enabled == false then return end

    local anim = cfg[actionName]
    if type(anim) ~= 'table' then return end

    local duration = tonumber(anim.duration or 1200) or 1200
    local emoteRes = tostring(cfg.EmotesResource or 'driftzone_emotes')

    if cfg.UseDriftzoneEmotes == true and anim.emote and GetResourceState(emoteRes) == 'started' then
        TriggerEvent('driftzone_emotes:client:play', tostring(anim.emote))
        SetTimeout(duration, function()
            TriggerEvent('driftzone_emotes:client:forceStop')
            local ped = PlayerPedId()
            if ped and ped ~= 0 then ClearPedSecondaryTask(ped) end
        end)
        return
    end

    playNativeAction(anim)
end


local function getClothingCategoryConfig(key)
    key = tostring(key or '')
    local cfg = Config.ClothingCategories and Config.ClothingCategories[key] or nil
    return cfg
end

local function applyClothingEntry(entry)
    if type(entry) ~= 'table' then return false end
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local category = tostring(entry.category or entry.category_key or '')
    local cfg = getClothingCategoryConfig(category) or {}
    local ctype = tostring(entry.clothes_type or cfg.type or 'component')
    local drawable = math.floor(tonumber(entry.drawable or 0) or 0)
    local texture = math.max(0, math.floor(tonumber(entry.texture or 0) or 0))

    if ctype == 'prop' then
        local propId = tonumber(entry.prop_id or cfg.propId or -1) or -1
        if propId < 0 then return false end
        if drawable < 0 then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, drawable, texture, true)
        end
        return true
    end

    local componentId = tonumber(entry.component_id or cfg.componentId or -1) or -1
    if componentId < 0 then return false end
    if drawable < 0 then drawable = 0 end
    SetPedComponentVariation(ped, componentId, drawable, texture, 0)
    return true
end

local function applyClothesPayload(payload)
    if type(payload) ~= 'table' then return end
    for _, entry in pairs(payload) do
        applyClothingEntry(entry)
    end
end

local function requestClothesLoadDelayed(ms)
    SetTimeout(tonumber(ms or 0) or 0, function()
        TriggerServerEvent('driftzone_inventory:server:requestClothesLoad')
    end)
end

RegisterNetEvent('driftzone_inventory:client:applyClothes', function(payload)
    payload = payload or {}
    applyClothesPayload(payload)

    -- Reaplica hainele/default-urile ca sa bata spawn/model-load intarziat.
    local count = tonumber((Config.ClothesLoad or {}).ApplyRepeatCount or 8) or 8
    local delay = tonumber((Config.ClothesLoad or {}).ApplyRepeatDelayMs or 500) or 500
    for i = 1, count do
        SetTimeout(delay * i, function()
            applyClothesPayload(payload)
        end)
    end
end)

RegisterNetEvent('driftzone_inventory:client:playActionAnimation', function(actionName)
    playActionAnimation(tostring(actionName or ''))
end)

RegisterNetEvent('driftzone_inventory:client:actionDone', function(actionName, data)
    actionName = tostring(actionName or '')
    if actionName == 'give' then
        runClientHook('OnGiveSuccess', data or {})
    elseif actionName == 'drop' then
        runClientHook('OnDropSuccess', data or {})
    elseif actionName == 'pickup' then
        runClientHook('OnPickupSuccess', data or {})
    end
end)

RegisterNetEvent('driftzone_inventory:client:forceClose', function()
    closeAll()
end)

RegisterNetEvent('driftzone_inventory:client:refreshDropsNow', function()
    TriggerServerEvent('driftzone_inventory:server:requestNearbyDrops')
end)


local function openInventory(data)
    runClientHook('OnInventoryOpen', data or {})
    inventoryOpen = true
    addItemOpen = false
    selectorOpen = false
    itemsOpen = false
    addClothesOpen = false
    clothesItemsOpen = false
    pendingGive = nil
    setFocus(true)
    sendNui({ action = 'openInventory', data = data or {} })
end

closeAll = function()
    runClientHook('OnInventoryClose')
    TriggerServerEvent('driftzone_inventory:server:closed')
    inventoryOpen = false
    addItemOpen = false
    selectorOpen = false
    itemsOpen = false
    addClothesOpen = false
    clothesItemsOpen = false
    pendingGive = nil
    setFocus(false)
    sendNui({ action = 'closeAll' })
end

local function openSelector(data)
    inventoryOpen = false
    addItemOpen = false
    selectorOpen = true
    itemsOpen = false
    addClothesOpen = false
    clothesItemsOpen = false
    selectorTarget = nil
    selectorTargetPed = nil
    pendingGive = data or pendingGive
    setFocus(true)
    sendNui({ action = 'openSelector' })
end

local function closeSelector()
    selectorOpen = false
    selectorTarget = nil
    selectorTargetPed = nil
    setFocus(false)
    sendNui({ action = 'closeSelector' })
end

RegisterCommand(Config.Command or 'inventory', function()
    TriggerServerEvent('driftzone_inventory:server:requestOpen')
end, false)

RegisterNetEvent('driftzone_inventory:client:open', function(data)
    openInventory(data or {})
end)

RegisterNetEvent('driftzone_inventory:client:addItemPanel', function(data)
    inventoryOpen = false
    addItemOpen = true
    selectorOpen = false
    itemsOpen = false
    addClothesOpen = false
    clothesItemsOpen = false
    setFocus(true)
    sendNui({ action = 'openAddItem', data = data or {} })
end)

RegisterNetEvent('driftzone_inventory:client:addItemResult', function(ok, message)
    sendNui({ action = 'addItemResult', ok = ok == true, message = tostring(message or '') })
end)

RegisterNetEvent('driftzone_inventory:client:itemsPanel', function(data)
    inventoryOpen = false
    addItemOpen = false
    selectorOpen = false
    itemsOpen = true
    addClothesOpen = false
    clothesItemsOpen = false
    setFocus(true)
    sendNui({ action = 'openItems', data = data or {} })
end)

RegisterNetEvent('driftzone_inventory:client:itemsResult', function(ok, message, items, itemId)
    sendNui({ action = 'itemsResult', ok = ok == true, message = tostring(message or ''), items = items or {}, itemId = itemId })
end)


RegisterNetEvent('driftzone_inventory:client:addClothesPanel', function(data)
    inventoryOpen = false
    addItemOpen = false
    selectorOpen = false
    itemsOpen = false
    addClothesOpen = true
    clothesItemsOpen = false
    setFocus(true)
    sendNui({ action = 'openAddClothes', data = data or {} })
end)

RegisterNetEvent('driftzone_inventory:client:clothesResult', function(ok, message)
    sendNui({ action = 'clothesResult', ok = ok == true, message = tostring(message or '') })
end)

RegisterNetEvent('driftzone_inventory:client:clothesItemsPanel', function(data)
    inventoryOpen = false
    addItemOpen = false
    selectorOpen = false
    itemsOpen = false
    addClothesOpen = false
    clothesItemsOpen = true
    setFocus(true)
    sendNui({ action = 'openClothesItems', data = data or {} })
end)

RegisterNetEvent('driftzone_inventory:client:clothesItemsResult', function(ok, message, items, itemId)
    sendNui({ action = 'clothesItemsResult', ok = ok == true, message = tostring(message or ''), items = items or {}, itemId = itemId })
end)

RegisterNetEvent('driftzone_inventory:client:itemUsed', function(itemId)
    notify('info', ('Ai folosit %s.'):format(tostring(itemId or 'item')))
end)

RegisterNetEvent('driftzone_inventory:client:updateDropped', function(data)
    nearbyDrops = data and data.drops or {}
    sendNui({ action = 'updateDropped', data = { dropped = data and data.dropped or {} } })
end)


RegisterNetEvent('driftzone_inventory:client:closeForGradient', function()
    closeAll()
end)

RegisterNetEvent('driftzone_inventory:client:openGiveToPlayer', function(targetServerId)
    TriggerServerEvent('driftzone_inventory:server:startGiveToPlayer', tonumber(targetServerId or 0) or 0)
end)

RegisterCommand('giveinv', function(_, args)
    local target = tonumber(args[1] or 0) or 0
    if target <= 0 then
        notify('warning', 'Folosire: /giveinv id')
        return
    end
    TriggerServerEvent('driftzone_inventory:server:startGiveToPlayer', target)
end, false)

RegisterNUICallback('close', function(_, cb)
    closeAll()
    cb({ ok = true })
end)

RegisterNUICallback('move', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:move', data and data.from, data and data.to)
    cb({ ok = true })
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:useItem', data and data.slot)
    cb({ ok = true })
end)

RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:dropItem', data and data.slot, data and data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('pickupDrop', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:pickupDrop', data and data.dropId, data and data.index, data and data.to)
    cb({ ok = true })
end)

RegisterNUICallback('startGiveSelector', function(data, cb)
    local rawSlot = data and data.slot or 0
    local slot = tonumber(rawSlot) or tostring(rawSlot or '')
    pendingGive = { slot = slot, amount = tonumber(data and data.amount or 1) or 1 }
    openSelector(pendingGive)
    cb({ ok = true })
end)

RegisterNUICallback('setQuickSlot', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:setQuickSlot', data and data.index, data and data.slot)
    cb({ ok = true })
end)

RegisterNUICallback('useQuickSlot', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:useQuickSlot', data and data.index)
    cb({ ok = true })
end)


RegisterNUICallback('equipClothingSlot', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:equipClothingSlot', data and data.category, data and data.slot)
    cb({ ok = true })
end)

RegisterNUICallback('unequipClothingSlot', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:unequipClothingSlot', data and data.category, data and data.to)
    cb({ ok = true })
end)

RegisterNUICallback('submitAddClothes', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:addClothesSubmit', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('submitAdminClothesItem', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:updateClothesItemSubmit', data or {})
    cb({ ok = true })
end)



CreateThread(function()
    if Config.ClothesLoad and Config.ClothesLoad.Enabled == false then return end
    local delays = Config.ClothesLoad and Config.ClothesLoad.ClientRetryDelays or { 500, 1200, 2200, 3500, 5200, 7500, 10000, 13500, 17000 }
    local last = 0
    for _, delay in ipairs(delays) do
        delay = tonumber(delay or 0) or 0
        Wait(math.max(0, delay - last))
        last = delay
        TriggerServerEvent('driftzone_inventory:server:requestClothesLoad')
    end
end)

AddEventHandler('playerSpawned', function()
    if Config.ClothesLoad and Config.ClothesLoad.Enabled == false then return end
    requestClothesLoadDelayed(250)
    requestClothesLoadDelayed(1000)
    requestClothesLoadDelayed(2500)
    requestClothesLoadDelayed(5000)
end)

local function projectWorldPoint(coords)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then return sx, sy end
    return nil, nil
end

local function getPedScreenBox(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end

    local coords = GetEntityCoords(ped)
    local points = {}
    local offsets = Config.BodySelectionOffsets or {
        { x = 0.00, y = 0.00, z = 0.95 },
        { x = 0.00, y = 0.00, z = 0.72 },
        { x = 0.00, y = 0.00, z = 0.48 },
        { x = 0.00, y = 0.00, z = 0.22 },
        { x = 0.00, y = 0.00, z = -0.10 }
    }

    for _, off in ipairs(offsets) do
        local point = vector3(coords.x + (off.x or 0.0), coords.y + (off.y or 0.0), coords.z + (off.z or 0.0))
        local sx, sy = projectWorldPoint(point)
        if sx and sy then points[#points + 1] = { x = sx, y = sy } end
    end

    local bones = Config.BodySelectionBones or { 31086, 24818, 11816, 58271, 63931 }
    for _, bone in ipairs(bones) do
        local bc = GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
        local sx, sy = projectWorldPoint(bc)
        if sx and sy then points[#points + 1] = { x = sx, y = sy } end
    end

    if #points <= 0 then return nil end

    local minX, maxX = 1.0, 0.0
    local minY, maxY = 1.0, 0.0
    for _, p in ipairs(points) do
        if p.x < minX then minX = p.x end
        if p.x > maxX then maxX = p.x end
        if p.y < minY then minY = p.y end
        if p.y > maxY then maxY = p.y end
    end

    local padX = tonumber(Config.BodySelectionPaddingX or 0.035) or 0.035
    local padY = tonumber(Config.BodySelectionPaddingY or 0.050) or 0.050
    local width = math.max(maxX - minX, tonumber(Config.BodySelectionMinWidth or 0.050) or 0.050)
    local centerX = (minX + maxX) / 2.0
    minX = centerX - (width / 2.0)
    maxX = centerX + (width / 2.0)

    return {
        minX = minX - padX,
        maxX = maxX + padX,
        minY = minY - padY,
        maxY = maxY + padY,
        centerX = centerX,
        centerY = (minY + maxY) / 2.0
    }
end

local function findPlayerFromCursor()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local bestTarget = nil
    local bestPed = nil
    local bestScore = 999999.0
    local radius = tonumber(Config.SelectionScreenRadius or 0.075) or 0.075
    local maxDist = tonumber(Config.GiveSelectDistance or Config.MaxSelectDistance or 6.0) or 6.0

    for _, playerIndex in ipairs(GetActivePlayers()) do
        if playerIndex ~= PlayerId() then
            local ped = GetPlayerPed(playerIndex)
            if ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
                local coords = GetEntityCoords(ped)
                local dist = #(myCoords - coords)
                if dist <= maxDist then
                    local box = getPedScreenBox(ped)
                    if box then
                        local insideBox = cursorX >= box.minX and cursorX <= box.maxX and cursorY >= box.minY and cursorY <= box.maxY
                        local dx = cursorX - box.centerX
                        local dy = cursorY - box.centerY
                        local screenDist = math.sqrt((dx * dx) + (dy * dy))
                        if insideBox or screenDist <= radius then
                            local score = screenDist + (dist * 0.002)
                            if score < bestScore then
                                bestScore = score
                                bestTarget = GetPlayerServerId(playerIndex)
                                bestPed = ped
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget, bestPed
end

RegisterNUICallback('selectorMove', function(data, cb)
    cursorX = tonumber(data and data.x or 0.5) or 0.5
    cursorY = tonumber(data and data.y or 0.5) or 0.5
    selectorTarget, selectorTargetPed = findPlayerFromCursor()
    cb({ ok = true })
end)

RegisterNUICallback('selectorClick', function(_, cb)
    if selectorOpen and pendingGive then
        local target = selectorTarget

        if target and target > 0 then
            TriggerServerEvent('driftzone_inventory:server:giveSelected', target, pendingGive.slot, pendingGive.amount)
            closeSelector()
        else
            notify('warning', 'Selecteaza un jucator mai aproape.')
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('submitAddItem', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:addItemSubmit', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('submitAdminItem', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:updateItemSubmit', data or {})
    cb({ ok = true })
end)

for i = 1, 5 do
    local quickIndex = i
    RegisterCommand(('dz_inv_quick_%s'):format(quickIndex), function()
        if addItemOpen or selectorOpen or itemsOpen or addClothesOpen or clothesItemsOpen then return end
        TriggerServerEvent('driftzone_inventory:server:useQuickSlot', quickIndex)
    end, false)

    RegisterKeyMapping(('dz_inv_quick_%s'):format(quickIndex), ('DriftZone Inventory Quick Slot %s'):format(quickIndex), 'keyboard', tostring(quickIndex))
end

CreateThread(function()
    while true do
        if Config.Drops and Config.Drops.RefreshAlways == false then
            if inventoryOpen or selectorOpen then
                TriggerServerEvent('driftzone_inventory:server:requestNearbyDrops')
                Wait(tonumber(Config.Drops.RefreshIntervalMs or 1500) or 1500)
            else
                Wait(tonumber(Config.Drops.RefreshIntervalClosedMs or 2200) or 2200)
            end
        else
            -- Refresh permanent: markerul drop-urilor se vede la tot serverul in radius.
            TriggerServerEvent('driftzone_inventory:server:requestNearbyDrops')
            if inventoryOpen or selectorOpen then
                Wait(tonumber(Config.Drops and Config.Drops.RefreshIntervalMs or 1500) or 1500)
            else
                Wait(tonumber(Config.Drops and Config.Drops.RefreshIntervalClosedMs or 2200) or 2200)
            end
        end
    end
end)

CreateThread(function()
    while true do
        if nearbyDrops and #nearbyDrops > 0 then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            markerRotation = (markerRotation + 2.8) % 360.0
            for _, drop in ipairs(nearbyDrops) do
                local coords = vector3(drop.x + 0.0, drop.y + 0.0, drop.z + 0.0)
                if #(pcoords - coords) <= (Config.DropMarkerRadius or 35.0) then
                    DrawMarker(
                        2,
                        coords.x, coords.y, coords.z + 0.25,
                        0.0, 0.0, 0.0,
                        180.0, 0.0, markerRotation,
                        0.28, 0.28, 0.28,
                        4, 199, 247, 205,
                        false, true, 2, false, nil, nil, false
                    )
                end
            end
            Wait(0)
        else
            Wait(600)
        end
    end
end)


CreateThread(function()
    while true do
        if selectorOpen and selectorTargetPed and DoesEntityExist(selectorTargetPed) then
            local myPed = PlayerPedId()
            local pcoords = GetEntityCoords(myPed)
            local tcoords = GetEntityCoords(selectorTargetPed)
            local maxDist = tonumber(Config.GiveSelectDistance or Config.MaxSelectDistance or 6.0) or 6.0

            if #(pcoords - tcoords) <= maxDist + 0.2 then
                markerRotation = (markerRotation + 2.2) % 360.0
                DrawMarker(
                    Config.Marker and Config.Marker.type or 25,
                    tcoords.x, tcoords.y, tcoords.z - 0.96 + (Config.Marker and Config.Marker.zOffset or 0.035),
                    0.0, 0.0, 0.0,
                    0.0, 0.0, markerRotation,
                    Config.Marker and Config.Marker.radius or 1.05,
                    Config.Marker and Config.Marker.radius or 1.05,
                    Config.Marker and Config.Marker.height or 0.035,
                    Config.Marker and Config.Marker.r or 4,
                    Config.Marker and Config.Marker.g or 199,
                    Config.Marker and Config.Marker.b or 247,
                    Config.Marker and Config.Marker.a or 190,
                    false, false, 2, false, nil, nil, false
                )
                Wait(0)
            else
                selectorTarget = nil
                selectorTargetPed = nil
                Wait(100)
            end
        else
            Wait(selectorOpen and 80 or 500)
        end
    end
end)

CreateThread(function()
    while true do
        if inventoryOpen or addItemOpen or selectorOpen or itemsOpen or addClothesOpen or clothesItemsOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
                closeAll()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
