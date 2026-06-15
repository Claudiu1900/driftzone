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

local tuningVehicle = 0
local vehicleWasFrozen = false
local vehicleFreezeActive = false
local gradientPreviewActive = false

local function notify(t, msg, d)
    TriggerEvent('client:notify', t or 'info', d or 5000, tostring(msg or ''))
end

local function sendNui(data)
    SendNUIMessage(data)
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

local function isEntityFrozenSafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local ok, result = pcall(function()
        return IsEntityPositionFrozen(entity)
    end)

    return ok and result == true
end

local function freezeVehicleForTunning(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    tuningVehicle = veh
    vehicleWasFrozen = isEntityFrozenSafe(veh)
    vehicleFreezeActive = true

    requestControl(veh, 1200)
    FreezeEntityPosition(veh, true)
    SetVehicleHandbrake(veh, true)
    SetVehicleDirtLevel(veh, 0.0)
end

local function restoreVehicleFreeze()
    if vehicleFreezeActive and tuningVehicle ~= 0 and DoesEntityExist(tuningVehicle) then
        requestControl(tuningVehicle, 900)
        SetVehicleHandbrake(tuningVehicle, false)
        FreezeEntityPosition(tuningVehicle, vehicleWasFrozen == true)
    end

    tuningVehicle = 0
    vehicleWasFrozen = false
    vehicleFreezeActive = false
end

local function getActiveTuningVehicle()
    if tuningVehicle ~= 0 and DoesEntityExist(tuningVehicle) then
        return tuningVehicle
    end

    return getVehicle()
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
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end

    modType = tonumber(modType) or 0

    -- Rapid: buildAvailableCategories face deja requestControl + SetVehicleModKit o singura data.
    -- Nu mai asteptam pe fiecare categorie, ca meniul sa se deschida instant.
    local ok, count = pcall(function()
        return GetNumVehicleMods(veh, modType)
    end)

    count = tonumber(ok and count or 0) or 0
    if count < 0 then count = 0 end
    if count > 120 then count = 120 end

    return math.floor(count)
end

local function getNativeLiveryCountSafe(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end

    local ok, count = pcall(function()
        return GetVehicleLiveryCount(veh)
    end)

    count = tonumber(ok and count or 0) or 0
    if count < 0 then count = 0 end
    return count
end

local function getWheelTypeSafe(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end
    local ok, result = pcall(function() return GetVehicleWheelType(veh) end)
    return tonumber(ok and result or 0) or 0
end

local function getModLabelSafe(veh, modType, index, fallback)
    if index == -1 then return 'Stock' end
    local label = nil
    pcall(function()
        label = GetModTextLabel(veh, tonumber(modType) or 0, tonumber(index) or 0)
    end)
    local text = nil
    if label and label ~= '' and label ~= 'NULL' then
        pcall(function() text = GetLabelText(label) end)
    end
    if not text or text == '' or text == 'NULL' then
        text = fallback or ('Option ' .. tostring((tonumber(index) or 0) + 1))
    end
    return tostring(text)
end

local function buildModOptions(veh, cat, count)
    local opts = { { value = -1, label = 'Stock' } }
    local modType = tonumber(cat.modType) or 0

    if cat.type == 'wheel' then
        local oldWheelType = getWheelTypeSafe(veh)
        SetVehicleWheelType(veh, tonumber(cat.wheelType) or 0)
        for i = 0, math.max(0, (tonumber(count) or 0) - 1) do
            opts[#opts + 1] = { value = i, label = getModLabelSafe(veh, modType, i, ('Wheel ' .. tostring(i + 1))) }
        end
        SetVehicleWheelType(veh, oldWheelType)
        return opts
    end

    if cat.nativeLivery == true then
        for i = 0, math.max(0, (tonumber(count) or 0) - 1) do
            local label = nil
            pcall(function() label = GetLiveryName(veh, i) end)
            local text = nil
            if label and label ~= '' and label ~= 'NULL' then pcall(function() text = GetLabelText(label) end) end
            if not text or text == '' or text == 'NULL' then text = getModLabelSafe(veh, modType, i, ('Livery ' .. tostring(i + 1))) end
            opts[#opts + 1] = { value = i, label = text }
        end
        return opts
    end

    for i = 0, math.max(0, (tonumber(count) or 0) - 1) do
        opts[#opts + 1] = { value = i, label = getModLabelSafe(veh, modType, i, ((cat.label or 'Option') .. ' ' .. tostring(i + 1))) }
    end
    return opts
end

local function extraExistsSafe(veh, extraId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local ok, exists = pcall(function()
        return DoesExtraExist(veh, tonumber(extraId) or -1)
    end)
    return ok and exists == true
end

local function isExtraOnSafe(veh, extraId)
    if not extraExistsSafe(veh, extraId) then return false end
    local ok, disabled = pcall(function()
        return IsVehicleExtraTurnedOn(veh, tonumber(extraId) or -1)
    end)
    return ok and disabled == true
end

local function setExtraSafe(veh, extraId, state)
    if not extraExistsSafe(veh, extraId) then return end
    SetVehicleExtra(veh, tonumber(extraId) or -1, state == true and 0 or 1)
end

local function appendValidExtras(veh, out)
    local added = {}
    local ids = Config.ExtraIds or {}

    for i = 1, #ids do
        local extraId = tonumber(ids[i])
        if extraId and not added[extraId] and extraExistsSafe(veh, extraId) then
            added[extraId] = true
            out[#out + 1] = {
                key = ('extra_%s'):format(extraId),
                label = ('Extra %s'):format(extraId),
                type = 'extra',
                extraId = extraId,
                count = 2
            }
        end
    end
end

local function applyExtraTuningData(veh, data)
    if not DoesEntityExist(veh) or type(data) ~= 'table' then return end

    for key, value in pairs(data) do
        local extraId = tostring(key or ''):match('^extra_(%d+)$')
        if extraId then
            setExtraSafe(veh, tonumber(extraId), value == true)
        end
    end
end

local function getCategoryCount(veh, cat)
    if not cat then return 0 end

    if cat.type == 'wheel' then
        local oldWheelType = getWheelTypeSafe(veh)
        SetVehicleWheelType(veh, tonumber(cat.wheelType) or 0)
        local count = getNumModsFast(veh, cat.modType or 23)
        SetVehicleWheelType(veh, oldWheelType)
        if count < 0 then count = 0 end
        if count > 180 then count = 180 end
        return math.floor(count)
    end

    if cat.type ~= 'mod' then return 0 end

    local count = getNumModsFast(veh, cat.modType)

    if cat.nativeLivery == true then
        local liveryCount = getNativeLiveryCountSafe(veh)
        if liveryCount > count then count = liveryCount end
    end

    -- Performance upgrades pot avea fallback, deoarece sunt GTA upgrades standard.
    -- Vizualele de add-on NU sunt fortate: apar doar daca GetNumVehicleMods/GetVehicleLiveryCount confirma ca exista.
    if count <= 0 and cat.performance == true and tonumber(cat.forceCount or 0) > 0 then
        count = tonumber(cat.forceCount) or 0
    end

    if count < 0 then count = 0 end
    if count > 120 then count = 120 end

    return math.floor(count)
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


local function getGradientPreviewById(id)
    id = tonumber(id or 0) or 0
    for _, item in ipairs(Config.GradientPreviewColors or {}) do
        if tonumber(item.id or 0) == id then return item end
    end
    return nil
end

local function getGradientPreviewOptions()
    local out = {}
    for _, item in ipairs(Config.GradientPreviewColors or {}) do
        local id = tonumber(item.id or 0) or 0
        local colorId = tonumber(item.colorId or item.colourId or 0) or 0
        if id > 0 and colorId > 0 then
            out[#out + 1] = {
                value = id,
                label = tostring(item.label or ('Gradient ' .. id)),
                colorId = colorId,
                previewOnly = true
            }
        end
    end
    return out
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


    if category.type == 'gradientPreview' then
        local gradient = getGradientPreviewById(value)
        if not gradient then return end

        local colorId = tonumber(gradient.colorId or 0) or 0
        if colorId <= 0 then return end

        ClearVehicleCustomPrimaryColour(veh)
        ClearVehicleCustomSecondaryColour(veh)
        local primary, secondary = GetVehicleColours(veh)
        primary = tonumber(primary or 0) or 0
        secondary = tonumber(secondary or 0) or 0

        local applyTo = tostring(category.applyTo or 'primary'):lower()
        if applyTo == 'secondary' then
            SetVehicleColours(veh, primary, colorId)
        else
            SetVehicleColours(veh, colorId, secondary)
        end
        SetVehicleDirtLevel(veh, 0.0)
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

    if category.type == 'vehicleColor' then
        if category.target == 'dashboard' then
            SetVehicleDashboardColour(veh, tonumber(value) or 0)
        elseif category.target == 'interior' then
            SetVehicleInteriorColour(veh, tonumber(value) or 0)
        end
        return
    end

    if category.type == 'plateIndex' then
        SetVehicleNumberPlateTextIndex(veh, tonumber(value) or 0)
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
        setExtraSafe(veh, tonumber(category.extraId) or -1, value == true)
        return
    end

    if category.type == 'wheel' then
        local modValue = tonumber(value) or -1
        local wheelType = tonumber(category.wheelType) or 0
        SetVehicleWheelType(veh, wheelType)
        SetVehicleMod(veh, 23, modValue, false)
        if IsThisModelABike(GetEntityModel(veh)) then
            SetVehicleMod(veh, 24, modValue, false)
        end
        return
    end

    if category.type == 'mod' then
        local modValue = tonumber(value) or -1
        local modType = tonumber(category.modType) or 0

        if category.nativeLivery == true then
            local nativeCount = getNativeLiveryCountSafe(veh)
            if nativeCount > 0 then
                if modValue < 0 then
                    SetVehicleLivery(veh, -1)
                else
                    SetVehicleLivery(veh, modValue)
                end
            end
        end

        SetVehicleMod(veh, modType, modValue, false)
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
    SetVehicleWheelType(veh, 0)
    SetVehicleMod(veh, 23, -1, false)
    if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, -1, false) end

    for i = 1, #Config.Categories do
        local cat = Config.Categories[i]

        if cat.type == 'mod' then
            if cat.nativeLivery == true then
                pcall(function()
                    SetVehicleLivery(veh, -1)
                end)
            end
            SetVehicleMod(veh, tonumber(cat.modType) or 0, -1, false)
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

        if cat and cat.key and data[cat.key] ~= nil and cat.type ~= 'gradientPreview' and cat.previewOnly ~= true then
            applyOneUnsafe(veh, cat.key, data[cat.key], cat)
        end
    end

    applyExtraTuningData(veh, data)
    SetVehicleDirtLevel(veh, 0.0)
end

local function restoreGradientPreview(veh)
    if not gradientPreviewActive then return end

    veh = veh or getActiveTuningVehicle()
    if veh ~= 0 and DoesEntityExist(veh) then
        applyTuningToVehicle(veh, currentTuning or {})
    end

    gradientPreviewActive = false
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

        if cat.type == 'gradientPreview' then
            local copy = {}
            for k, v in pairs(cat) do copy[k] = v end
            copy.options = getGradientPreviewOptions()
            copy.count = #copy.options
            if copy.count > 0 then out[#out + 1] = copy end
        elseif cat.type == 'mod' or cat.type == 'wheel' then
            local count = getCategoryCount(veh, cat)

            if count > 0 then
                local copy = {}

                for k, v in pairs(cat) do
                    copy[k] = v
                end

                copy.count = count
                copy.realCount = cat.type == 'wheel' and count or getNumModsFast(veh, cat.modType)
                copy.options = buildModOptions(veh, cat, count)
                if cat.nativeLivery == true then
                    copy.nativeLiveryCount = getNativeLiveryCountSafe(veh)
                end
                out[#out + 1] = copy
            end
        else
            local copy = {}

            for k, v in pairs(cat) do
                copy[k] = v
            end

            copy.count = (cat.type == 'toggle' or cat.type == 'extra') and 2 or 0
            out[#out + 1] = copy
        end
    end

    appendValidExtras(veh, out)

    rebuildCategoryMap(out)
    return out
end

local function tableHasData(value)
    if type(value) ~= 'table' then return false end
    for _ in pairs(value) do return true end
    return false
end

local function captureCurrentTuning(veh, categories)
    local captured = {}
    if not DoesEntityExist(veh) then return captured end

    ensureModKit(veh, true)

    for i = 1, #(categories or {}) do
        local cat = categories[i]
        if cat and cat.key then
            if cat.type == 'gradientPreview' then
                -- Preview only: nu se captureaza si nu se salveaza.
            elseif cat.type == 'color' then
                local r, g, b = 0, 0, 0
                if cat.key == 'primaryColor' then
                    r, g, b = GetVehicleCustomPrimaryColour(veh)
                elseif cat.key == 'secondaryColor' then
                    r, g, b = GetVehicleCustomSecondaryColour(veh)
                end
                captured[cat.key] = { r = tonumber(r or 0) or 0, g = tonumber(g or 0) or 0, b = tonumber(b or 0) or 0 }
            elseif cat.type == 'classicColor' then
                local pearl, wheel = GetVehicleExtraColours(veh)
                if cat.key == 'pearlescentColor' then captured[cat.key] = tonumber(pearl or 0) or 0 end
                if cat.key == 'wheelColor' then captured[cat.key] = tonumber(wheel or 0) or 0 end
            elseif cat.type == 'vehicleColor' then
                if cat.target == 'dashboard' then captured[cat.key] = tonumber(GetVehicleDashboardColour(veh) or 0) or 0 end
                if cat.target == 'interior' then captured[cat.key] = tonumber(GetVehicleInteriorColour(veh) or 0) or 0 end
            elseif cat.type == 'plateIndex' then
                captured[cat.key] = tonumber(GetVehicleNumberPlateTextIndex(veh) or 0) or 0
            elseif cat.type == 'windowTint' then
                captured[cat.key] = tonumber(GetVehicleWindowTint(veh) or 0) or 0
            elseif cat.type == 'xenonColor' then
                captured[cat.key] = tonumber(GetVehicleXenonLightsColor(veh) or 0) or 0
            elseif cat.type == 'toggle' then
                captured[cat.key] = IsToggleModOn(veh, tonumber(cat.modType) or 18) == true
            elseif cat.type == 'extra' then
                captured[cat.key] = isExtraOnSafe(veh, tonumber(cat.extraId) or -1)
            elseif cat.type == 'wheel' then
                local oldWheelType = getWheelTypeSafe(veh)
                SetVehicleWheelType(veh, tonumber(cat.wheelType) or 0)
                captured[cat.key] = tonumber(GetVehicleMod(veh, 23) or -1) or -1
                SetVehicleWheelType(veh, oldWheelType)
            elseif cat.type == 'mod' then
                local value = tonumber(GetVehicleMod(veh, tonumber(cat.modType) or 0) or -1) or -1
                if cat.nativeLivery == true then
                    local native = tonumber(GetVehicleLivery(veh) or -1) or -1
                    if native >= 0 then value = native end
                end
                captured[cat.key] = value
            end
        end
    end

    return captured
end

local function findCategory(key)
    return categoryMap[key] or nil
end

local function itemPrice(key)
    local base = tonumber(currentData and currentData.vehiclePrice or 0) or 0
    local percent = tonumber((currentData and currentData.pricePercent or Config.PricePercent or {})[key] or 1) or 1
    if tostring(key or ''):match('^extra_%d+$') then
        percent = tonumber(Config.ExtraPricePercent or percent) or percent
    end

    return math.max(1, math.ceil(base * percent / 100))
end

local function closeTunning(save)
    if not tunningOpen then return end

    local veh = getActiveTuningVehicle()

    if veh ~= 0 and DoesEntityExist(veh) then
        if not save then
            applyTuningToVehicle(veh, originalTuning or {})
        else
            restoreGradientPreview(veh)
        end
    end

    restoreVehicleFreeze()

    tunningOpen = false
    freeCamera = false
    gradientPreviewActive = false
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

    freezeVehicleForTunning(veh)

    currentData = payload or {}
    availableCategories = buildAvailableCategories(veh, currentData.categories or Config.Categories or {})
    currentData.categories = availableCategories

    local capturedNow = captureCurrentTuning(veh, availableCategories)
    originalTuning = capturedNow or {}

    if type(currentData.savedTuning) == 'table' then
        for k, v in pairs(currentData.savedTuning) do
            originalTuning[k] = v
        end
    end

    currentTuning = deepCopy(originalTuning)
    pendingChanges = {}
    gradientPreviewActive = false

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
    gradientPreviewActive = false

    local veh = getActiveTuningVehicle()
    if veh ~= 0 and DoesEntityExist(veh) then
        applyTuningToVehicle(veh, currentTuning or {})
    end

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

    local veh = getActiveTuningVehicle()
    local key = tostring(data.key or '')
    local cat = findCategory(key)

    if veh ~= 0 and cat then
        local value = data.value

        if cat.previewOnly == true or cat.type == 'gradientPreview' then
            applyOne(veh, key, value, cat)
            gradientPreviewActive = true
            cb({ ok = true })
            return
        end

        -- Daca a fost aplicat un gradient de preview, il curatam inainte de orice alt preview/cumparare.
        restoreGradientPreview(veh)

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
        local veh = getActiveTuningVehicle()
        if veh ~= 0 and DoesEntityExist(veh) then
            restoreGradientPreview(veh)
        end

        TriggerServerEvent('driftzone_tunning:server:buy', {
            vehicleId = currentData.vehicleId,
            adminMode = currentData.adminMode == true,
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

RegisterCommand('tunning', function()
    TriggerServerEvent('driftzone_tunning:server:adminOpen')
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

    if tunningOpen then
        local veh = getActiveTuningVehicle()
        if veh ~= 0 and DoesEntityExist(veh) then
            applyTuningToVehicle(veh, originalTuning or {})
        end
    end

    restoreVehicleFreeze()
    setFocus(false)
    TriggerEvent('driftzone_hud:visible', true)
end)
