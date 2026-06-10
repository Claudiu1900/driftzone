local nuiReady = false
local tunningOpen = false
local freeCamera = false

local currentData = nil
local currentTuning = {}
local originalTuning = {}
local pendingChanges = {}

local appliedSignatures = {}
local categoryMap = {}
local availableCategories = {}

local lastPreviewAt = 0
local PREVIEW_THROTTLE_MS = 35

local function notify(t, msg, d)
    TriggerEvent('client:notify', t or 'info', d or 5000, tostring(msg or ''))
end

local function sendNui(data)
    if nuiReady then
        SendNUIMessage(data)
    end
end

local function deepCopy(value)
    if type(value) ~= 'table' then return {} end

    local ok, encoded = pcall(json.encode, value)
    if not ok then return {} end

    local okDecode, decoded = pcall(json.decode, encoded)
    if okDecode and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

local function getVehicle()
    local ped = PlayerPedId()

    if not IsPedInAnyVehicle(ped, false) then
        return 0
    end

    return GetVehiclePedIsIn(ped, false)
end

local function requestControl(entity, timeout)
    if not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    local endTime = GetGameTimer() + (timeout or 1200)

    repeat
        NetworkRequestControlOfEntity(entity)
        Wait(20)
    until NetworkHasControlOfEntity(entity) or GetGameTimer() >= endTime

    return NetworkHasControlOfEntity(entity)
end

local function setFocus(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function setFreeCamera(state)
    if not tunningOpen then return end

    freeCamera = state == true

    if freeCamera then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        sendNui({ action = 'camera', enabled = true })
    else
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        sendNui({ action = 'camera', enabled = false })
    end
end

local function ensureModKit(veh, needsControl)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end

    if needsControl ~= false then
        requestControl(veh, 450)
    end

    SetVehicleModKit(veh, 0)
    return true
end

local function getNumModsFast(veh, modType)
    if not veh or veh == 0 then return 0 end

    SetVehicleModKit(veh, 0)

    return GetNumVehicleMods(veh, tonumber(modType) or 0) or 0
end

local function getLiveryCountFast(veh)
    if not veh or veh == 0 then return 0 end

    SetVehicleModKit(veh, 0)

    local modCount = GetNumVehicleMods(veh, 48) or 0
    local nativeCount = GetVehicleLiveryCount(veh) or 0

    if nativeCount < 0 then nativeCount = 0 end
    return math.max(modCount, nativeCount)
end

local function hasVehicleExtraFast(veh, extraId)
    if not veh or veh == 0 then return false end
    return DoesExtraExist(veh, tonumber(extraId) or 0) == 1
end

local function captureRuntimeDefaults(veh, categories, tuning)
    if not DoesEntityExist(veh) then return tuning or {} end

    tuning = tuning or {}

    for i = 1, #(categories or {}) do
        local cat = categories[i]

        if cat and cat.type == 'extra' and tuning[cat.key] == nil and hasVehicleExtraFast(veh, cat.extraId) then
            tuning[cat.key] = IsVehicleExtraTurnedOn(veh, tonumber(cat.extraId) or 0) == 1
        end
    end

    return tuning
end

local function parseHex(hex)
    local clean = tostring(hex or ''):gsub('#', '')

    if not clean:match('^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
        return nil
    end

    return {
        r = tonumber(clean:sub(1, 2), 16),
        g = tonumber(clean:sub(3, 4), 16),
        b = tonumber(clean:sub(5, 6), 16)
    }
end

local function applyOneUnsafe(veh, key, value, category)
    if not DoesEntityExist(veh) or not category then return end

    if category.type == 'color' then
        if type(value) == 'string' then
            value = parseHex(value)
        end

        if not value then return end

        if key == 'primaryColor' then
            SetVehicleCustomPrimaryColour(veh, tonumber(value.r or 0), tonumber(value.g or 0), tonumber(value.b or 0))
        elseif key == 'secondaryColor' then
            SetVehicleCustomSecondaryColour(veh, tonumber(value.r or 0), tonumber(value.g or 0), tonumber(value.b or 0))
        end

        return
    end

    if category.type == 'classicColor' then
        local pearl, wheel = GetVehicleExtraColours(veh)

        if key == 'pearlescentColor' then
            pearl = tonumber(value) or 0
        elseif key == 'wheelColor' then
            wheel = tonumber(value) or 0
        end

        SetVehicleExtraColours(veh, pearl or 0, wheel or 0)
        return
    end

    if category.type == 'windowTint' then
        SetVehicleWindowTint(veh, tonumber(value) or 0)
        return
    end

    if category.type == 'xenonColor' then
        ToggleVehicleMod(veh, 22, true)
        SetVehicleXenonLightsColor(veh, tonumber(value) or 0)
        return
    end

    if category.type == 'toggle' then
        ToggleVehicleMod(veh, tonumber(category.modType) or 18, value == true)
        return
    end

    if category.type == 'extra' then
        local extraId = tonumber(category.extraId or 0) or 0
        if extraId > 0 and DoesExtraExist(veh, extraId) == 1 then
            -- FiveM native: 0 = ON, 1 = OFF. In tuning salvam true/false normal.
            SetVehicleExtra(veh, extraId, value == true and 0 or 1)
        end
        return
    end

    if category.type == 'mod' then
        local modType = tonumber(category.modType) or 0
        local modValue = tonumber(value) or -1

        if modType == 48 and (GetNumVehicleMods(veh, 48) or 0) <= 0 and (GetVehicleLiveryCount(veh) or 0) > 0 then
            SetVehicleLivery(veh, modValue)
        else
            SetVehicleMod(veh, modType, modValue, false)
        end
    end
end

local function applyOne(veh, key, value, category)
    if not DoesEntityExist(veh) or not category then return end

    ensureModKit(veh, true)
    applyOneUnsafe(veh, key, value, category)
end

local function resetVehicle(veh)
    if not DoesEntityExist(veh) then return end

    requestControl(veh, 900)
    SetVehicleModKit(veh, 0)

    ClearVehicleCustomPrimaryColour(veh)
    ClearVehicleCustomSecondaryColour(veh)
    SetVehicleExtraColours(veh, 0, 0)
    SetVehicleWindowTint(veh, 0)
    ToggleVehicleMod(veh, 18, false)
    ToggleVehicleMod(veh, 22, false)

    for i = 1, #Config.Categories do
        local cat = Config.Categories[i]

        if cat.type == 'mod' then
            local modType = tonumber(cat.modType) or 0
            SetVehicleMod(veh, modType, -1, false)
            if modType == 48 then
                SetVehicleLivery(veh, -1)
            end
        end
    end
end

local function applyTuningToVehicle(veh, tuning)
    if not DoesEntityExist(veh) then return end

    local data = tuning or {}

    requestControl(veh, 1100)
    SetVehicleModKit(veh, 0)

    resetVehicle(veh)

    for i = 1, #Config.Categories do
        local cat = Config.Categories[i]

        if data[cat.key] ~= nil then
            applyOneUnsafe(veh, cat.key, data[cat.key], cat)
        end
    end
end

local function rebuildCategoryMap(categories)
    categoryMap = {}

    for i = 1, #(categories or {}) do
        local cat = categories[i]

        if cat and cat.key then
            categoryMap[cat.key] = cat
        end
    end
end

local function buildAvailableCategories(veh, categories)
    local out = {}

    ensureModKit(veh, true)

    for i = 1, #(categories or {}) do
        local cat = categories[i]

        if cat.type == 'mod' then
            local count = getNumModsFast(veh, cat.modType)

            if tonumber(cat.modType) == 48 then
                count = getLiveryCountFast(veh)
            end

            if count <= 0 and tonumber(cat.forceCount or 0) > 0 then
                count = tonumber(cat.forceCount)
            end

            if count > 0 then
                local copy = {}

                for k, v in pairs(cat) do
                    copy[k] = v
                end

                copy.count = count
                out[#out + 1] = copy
            end
        elseif cat.type == 'extra' then
            if hasVehicleExtraFast(veh, cat.extraId) then
                local copy = {}

                for k, v in pairs(cat) do
                    copy[k] = v
                end

                copy.count = 2
                out[#out + 1] = copy
            end
        else
            local copy = {}

            for k, v in pairs(cat) do
                copy[k] = v
            end

            copy.count = cat.type == 'toggle' and 2 or 0
            out[#out + 1] = copy
        end
    end

    rebuildCategoryMap(out)
    return out
end

local function findCategory(key)
    return categoryMap[key] or nil
end

local function itemPrice(key)
    local base = tonumber(currentData and currentData.vehiclePrice or 0) or 0
    local percent = tonumber((currentData and currentData.pricePercent or Config.PricePercent or {})[key] or 1) or 1

    return math.max(1, math.ceil(base * percent / 100))
end

local function closeTunning(save)
    if not tunningOpen then return end

    local veh = getVehicle()

    if veh ~= 0 and not save then
        applyTuningToVehicle(veh, originalTuning or {})
    end

    tunningOpen = false
    freeCamera = false
    currentData = nil
    currentTuning = {}
    originalTuning = {}
    pendingChanges = {}
    categoryMap = {}
    availableCategories = {}

    setFocus(false)
    sendNui({ action = 'close' })
    TriggerEvent('driftzone_hud:visible', true)
end

local function openTunning(payload)
    local veh = getVehicle()

    if veh == 0 then
        notify('warning', 'Trebuie sa fii intr-o masina.')
        return
    end

    currentData = payload or {}
    availableCategories = buildAvailableCategories(veh, currentData.categories or Config.Categories or {})
    currentData.categories = availableCategories

    originalTuning = type(currentData.savedTuning) == 'table' and currentData.savedTuning or {}
    originalTuning = captureRuntimeDefaults(veh, availableCategories, originalTuning)
    currentTuning = deepCopy(originalTuning)
    pendingChanges = {}

    applyTuningToVehicle(veh, currentTuning)

    tunningOpen = true
    freeCamera = false

    setFocus(true)
    TriggerEvent('driftzone_hud:visible', false)
    sendNui({ action = 'open', data = currentData })
end

RegisterNetEvent('driftzone_tunning:client:open', openTunning)

RegisterNetEvent('driftzone_tunning:client:paid', function(data)
    originalTuning = data and data.tuning or currentTuning
    currentTuning = data and data.tuning or currentTuning
    closeTunning(true)
end)

RegisterNetEvent('driftzone_tunning:client:openFromInteraction', function()
    TriggerServerEvent('driftzone_tunning:server:open')
end)

RegisterNetEvent('driftzone_tunning:client:applyVehicle', function(netId, rawTuning)
    CreateThread(function()
        netId = tonumber(netId) or 0
        if netId <= 0 then return end

        local endTime = GetGameTimer() + 10000
        local veh = 0

        while GetGameTimer() < endTime do
            if NetworkDoesNetworkIdExist(netId) then
                veh = NetToVeh(netId)

                if veh ~= 0 and DoesEntityExist(veh) then
                    break
                end
            end

            Wait(150)
        end

        if veh == 0 or not DoesEntityExist(veh) then return end

        local tuning = {}

        if type(rawTuning) == 'table' then
            tuning = rawTuning
        else
            local ok, decoded = pcall(json.decode, tostring(rawTuning or '{}'))

            if ok and type(decoded) == 'table' then
                tuning = decoded
            end
        end

        local okSig, encoded = pcall(json.encode, tuning)
        local sig = tostring(netId) .. ':' .. (okSig and encoded or '')

        if appliedSignatures[sig] then return end

        appliedSignatures[sig] = true

        if #appliedSignatures > 150 then
            appliedSignatures = {}
        end

        applyTuningToVehicle(veh, tuning)
    end)
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    if not tunningOpen or not currentData then
        cb({ ok = false })
        return
    end

    local now = GetGameTimer()
    if now - lastPreviewAt < PREVIEW_THROTTLE_MS then
        cb({ ok = true })
        return
    end

    lastPreviewAt = now

    local veh = getVehicle()
    local key = tostring(data.key or '')
    local cat = findCategory(key)

    if veh ~= 0 and cat then
        local value = data.value
        currentTuning[key] = value

        local found = false

        for i = 1, #pendingChanges do
            local item = pendingChanges[i]

            if item.key == key then
                item.value = value
                item.price = itemPrice(key)
                item.variantLabel = data.variantLabel
                found = true
                break
            end
        end

        if not found then
            pendingChanges[#pendingChanges + 1] = {
                key = key,
                label = cat.label,
                value = value,
                variantLabel = data.variantLabel,
                type = cat.type,
                modType = cat.modType,
                price = itemPrice(key)
            }
        end

        applyOne(veh, key, value, cat)
        sendNui({ action = 'cart', items = pendingChanges })
    end

    cb({ ok = true })
end)

RegisterNUICallback('remove', function(data, cb)
    if not tunningOpen or not currentData then
        cb({ ok = false })
        return
    end

    local veh = getVehicle()
    local key = tostring(data.key or '')

    if key ~= '' then
        local newChanges = {}

        for i = 1, #pendingChanges do
            local item = pendingChanges[i]

            if item.key ~= key then
                newChanges[#newChanges + 1] = item
            end
        end

        pendingChanges = newChanges
        currentTuning[key] = nil

        if veh ~= 0 and DoesEntityExist(veh) then
            applyTuningToVehicle(veh, currentTuning or {})
        end

        sendNui({ action = 'cart', items = pendingChanges })
    end

    cb({ ok = true })
end)

RegisterNUICallback('buy', function(_, cb)
    if currentData then
        TriggerServerEvent('driftzone_tunning:server:buy', {
            vehicleId = currentData.vehicleId,
            changes = pendingChanges,
            tuning = currentTuning
        })
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeTunning(false)
    cb({ ok = true })
end)

RegisterNUICallback('toggleCamera', function(_, cb)
    setFreeCamera(not freeCamera)
    cb({ ok = true })
end)

RegisterCommand('tuning', function()
    TriggerServerEvent('driftzone_tunning:server:open')
end, false)

RegisterCommand('tune', function()
    TriggerServerEvent('driftzone_tunning:server:open')
end, false)

CreateThread(function()
    while true do
        if tunningOpen then
            if not freeCamera then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 322, true)
            end

            if IsControlJustPressed(0, 243) then
                setFreeCamera(not freeCamera)
            end

            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                closeTunning(false)
            end

            Wait(0)
        else
            Wait(350)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    setFocus(false)
    TriggerEvent('driftzone_hud:visible', true)
end)
