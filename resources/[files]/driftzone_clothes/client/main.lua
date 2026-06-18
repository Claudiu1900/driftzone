local browserReady = false
local menuOpen = false
local cam = nil

local currentState = {}
local databaseClothes = {}
local blacklist = {}
local lastHeading = 180.0
local camDistance = 2.45
local camHeight = 0.75

local categories = {
    { key = 'hair',        label = 'Par',            icon = 'hair.svg',        type = 'component', componentId = 2 },
    { key = 'jacket',      label = 'Jacheta',        icon = 'jacket.svg',      type = 'component', componentId = 11 },
    { key = 'top',         label = 'Top',            icon = 'top.svg',         type = 'component', componentId = 8 },
    { key = 'vest',        label = 'Vesta',          icon = 'vest.svg',        type = 'component', componentId = 9 },
    { key = 'pants',       label = 'Pantaloni',      icon = 'pants.svg',       type = 'component', componentId = 4 },
    { key = 'shoes',       label = 'Pantofi',        icon = 'shoes.svg',       type = 'component', componentId = 6 },
    { key = 'hat',         label = 'Palarii',        icon = 'hat.svg',         type = 'prop',      propId = 0 },
    { key = 'mask',        label = 'Masca',          icon = 'mask.svg',        type = 'component', componentId = 1 },
    { key = 'accessories', label = 'Accesorii',      icon = 'accessories.svg', type = 'component', componentId = 7 },
    { key = 'watches',     label = 'Ceasuri',        icon = 'watches.svg',     type = 'prop',      propId = 6 },
    { key = 'bracelets',   label = 'Bratari',        icon = 'bracelets.svg',   type = 'prop',      propId = 7 },
    { key = 'glasses',     label = 'Ochelari',       icon = 'glasses.svg',     type = 'prop',      propId = 1 },
    { key = 'ears',        label = 'Urechi',         icon = 'ears.svg',        type = 'prop',      propId = 2 },
    { key = 'bag',         label = 'Geanta',         icon = 'bag.svg',         type = 'component', componentId = 5 },
    { key = 'torso',       label = 'Brate / Manusi', icon = 'arms.svg',        type = 'component', componentId = 3 },
    { key = 'insignia',    label = 'Insigne',        icon = 'badge.svg',       type = 'component', componentId = 10 }
}

local function notify(notifyType, message, duration)
    TriggerEvent('client:notify', notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function requestSavedClothesReload()
    TriggerServerEvent('driftzone_clothes:server:reloadSaved')
end


local function sendNui(data)
    if not browserReady then return end
    SendNUIMessage(data)
end

local function getCat(key)
    for _, cat in ipairs(categories) do
        if cat.key == key then return cat end
    end
    return nil
end

local function isBlacklisted(key, drawable)
    local list = blacklist and blacklist[key]
    if type(list) ~= 'table' then return false end

    drawable = tonumber(drawable)
    for _, value in ipairs(list) do
        if tonumber(value) == drawable then return true end
    end

    return false
end

local function maxComponentDrawable(ped, componentId)
    local value = GetNumberOfPedDrawableVariations(ped, componentId)
    if not value or value < 1 then return 1 end
    return value
end

local function maxComponentTexture(ped, componentId, drawable)
    local value = GetNumberOfPedTextureVariations(ped, componentId, drawable)
    if not value or value < 1 then return 1 end
    return value
end

local function maxPropDrawable(ped, propId)
    local value = GetNumberOfPedPropDrawableVariations(ped, propId)
    if not value or value < 1 then return 1 end
    return value
end

local function maxPropTexture(ped, propId, drawable)
    if drawable < 0 then return 1 end

    local value = GetNumberOfPedPropTextureVariations(ped, propId, drawable)
    if not value or value < 1 then return 1 end
    return value
end

local function getMinDrawable(cat)
    if cat and cat.type == 'prop' then return -1 end
    return 0
end

local function getMaxDrawableForState(cat, state)
    local max = tonumber(state and state.maxDrawable or 1) or 1
    return math.max(1, max) - 1
end

local function normalizeDrawable(key, value)
    local cat = getCat(key)
    local state = currentState[key]
    if not cat or not state then return 0 end

    value = tonumber(value)
    if not value then value = getMinDrawable(cat) end
    value = math.floor(value)

    local min = getMinDrawable(cat)
    local max = getMaxDrawableForState(cat, state)

    if value < min then value = max end
    if value > max then value = min end

    return value
end

local function findNextAllowedDrawable(key, start, direction)
    local cat = getCat(key)
    local state = currentState[key]
    if not cat or not state then return 0 end

    local min = getMinDrawable(cat)
    local max = getMaxDrawableForState(cat, state)
    local dir = tonumber(direction or 1) or 1
    if dir >= 0 then dir = 1 else dir = -1 end

    local value = normalizeDrawable(key, start)
    local tries = (max - min) + 5

    for _ = 1, tries do
        if value == -1 or not isBlacklisted(key, value) then
            return value
        end

        value = value + dir
        if value > max then value = min end
        if value < min then value = max end
    end

    return min
end

local function readCurrentState()
    local ped = PlayerPedId()
    local output = {}

    for _, cat in ipairs(categories) do
        if cat.type == 'component' then
            local drawable = GetPedDrawableVariation(ped, cat.componentId)
            local texture = GetPedTextureVariation(ped, cat.componentId)

            output[cat.key] = {
                drawable = drawable,
                texture = texture,
                maxDrawable = maxComponentDrawable(ped, cat.componentId),
                maxTexture = maxComponentTexture(ped, cat.componentId, drawable)
            }
        else
            local drawable = GetPedPropIndex(ped, cat.propId)
            local texture = GetPedPropTextureIndex(ped, cat.propId)

            output[cat.key] = {
                drawable = drawable,
                texture = texture,
                maxDrawable = maxPropDrawable(ped, cat.propId),
                maxTexture = maxPropTexture(ped, cat.propId, drawable)
            }
        end
    end

    return output
end

local function updateMaxTexture(key)
    local ped = PlayerPedId()
    local cat = getCat(key)
    local state = currentState[key]
    if not cat or not state then return end

    if cat.type == 'component' then
        state.maxTexture = maxComponentTexture(ped, cat.componentId, state.drawable)
    else
        state.maxTexture = maxPropTexture(ped, cat.propId, state.drawable)
    end

    if state.texture >= state.maxTexture then
        state.texture = 0
    end
end

local function applyItem(key)
    local ped = PlayerPedId()
    local cat = getCat(key)
    local state = currentState[key]
    if not cat or not state then return end

    local drawable = tonumber(state.drawable or 0) or 0
    local texture = tonumber(state.texture or 0) or 0

    if cat.type == 'component' then
        drawable = math.max(0, drawable)
        texture = math.max(0, texture)
        SetPedComponentVariation(ped, cat.componentId, drawable, texture, 0)
    else
        if drawable < 0 then
            ClearPedProp(ped, cat.propId)
        else
            SetPedPropIndex(ped, cat.propId, drawable, math.max(0, texture), true)
        end
    end
end

local function mergeClothesIntoState(saved)
    local base = readCurrentState()
    saved = saved or {}

    currentState = base

    for _, cat in ipairs(categories) do
        local item = saved[cat.key]

        if type(item) == 'table' and base[cat.key] then
            base[cat.key].drawable = tonumber(item.drawable or 0) or 0
            base[cat.key].texture = tonumber(item.texture or 0) or 0
            base[cat.key].drawable = findNextAllowedDrawable(cat.key, base[cat.key].drawable, 1)
            updateMaxTexture(cat.key)
        end
    end

    return base
end

local function stripMaxValues(state)
    local output = {}

    for _, cat in ipairs(categories) do
        local item = state[cat.key]
        if item then
            output[cat.key] = {
                drawable = tonumber(item.drawable or 0) or 0,
                texture = tonumber(item.texture or 0) or 0
            }
        end
    end

    return output
end

local function sendStateToUi()
    sendNui({
        action = 'setState',
        payload = {
            categories = categories,
            state = currentState,
            blacklist = blacklist,
            mainColor = '#04c7f7'
        }
    })
end

local function applyClothes(clothes)
    currentState = mergeClothesIntoState(clothes or {})

    for _, cat in ipairs(categories) do
        applyItem(cat.key)
    end

    if menuOpen then
        sendStateToUi()
    end
end

local function setFocus(state)
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)

    if state then
        TriggerEvent('driftzone_hud:visible', false)
    else
        TriggerEvent('driftzone_hud:visible', true)
    end
end

local function unfreeze()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    if not menuOpen then
        SetNuiFocus(false, false)
        RenderScriptCams(false, false, 0, true, false)
    end
end

local function destroyCamera()
    if cam then
        DestroyCam(cam, false)
        cam = nil
    end

    RenderScriptCams(false, false, 0, true, false)
end

local function updateCamera()
    if not cam then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)

    local x = coords.x + math.sin(-rad) * camDistance
    local y = coords.y + math.cos(rad) * camDistance
    local z = coords.z + camHeight

    SetCamCoord(cam, x, y, z)
    PointCamAtCoord(cam, coords.x, coords.y, coords.z + 0.55)
end

local function createCamera()
    destroyCamera()

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)

    camDistance = 2.45
    camHeight = 0.75

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, coords.x + math.sin(-rad) * camDistance, coords.y + math.cos(rad) * camDistance, coords.z + camHeight)
    PointCamAtCoord(cam, coords.x, coords.y, coords.z + 0.55)
    SetCamFov(cam, 45.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)
end

local function forceFrontFacing()
    local ped = PlayerPedId()
    lastHeading = 180.0
    SetEntityHeading(ped, lastHeading)
end

local function openMenu(data)
    if menuOpen then return end

    data = data or {}
    databaseClothes = data.clothes or {}
    blacklist = data.blacklist or {}

    currentState = mergeClothesIntoState(databaseClothes)

    menuOpen = true

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    forceFrontFacing()
    setFocus(true)
    createCamera()

    sendNui({ action = 'open' })
    sendStateToUi()
end

local function closeUiOnly()
    menuOpen = false
    destroyCamera()
    setFocus(false)
    FreezeEntityPosition(PlayerPedId(), false)
    sendNui({ action = 'close' })

    SetTimeout(100, unfreeze)
    SetTimeout(400, unfreeze)
end

local function changeDrawable(key, direction)
    local item = currentState[key]
    if not item then return end

    local dir = tonumber(direction or 0) or 0
    item.drawable = findNextAllowedDrawable(key, (tonumber(item.drawable or 0) or 0) + dir, dir)
    item.texture = 0

    updateMaxTexture(key)
    applyItem(key)
    sendStateToUi()
end

local function setDrawableManual(key, value)
    local item = currentState[key]
    if not item then return end

    value = tonumber(value)
    if not value then return end
    value = math.floor(value)

    local nextValue = findNextAllowedDrawable(key, value, 1)
    item.drawable = nextValue
    item.texture = 0

    updateMaxTexture(key)
    applyItem(key)
    sendStateToUi()

    if nextValue ~= value then
        notify('warning', ('Numarul %s este blocat. Am selectat %s.'):format(value, nextValue))
    end
end

local function changeTexture(key, direction)
    local item = currentState[key]
    if not item then return end

    local max = math.max(1, tonumber(item.maxTexture or 1) or 1)
    item.texture = (tonumber(item.texture or 0) or 0) + (tonumber(direction or 0) or 0)

    if item.texture < 0 then item.texture = max - 1 end
    if item.texture >= max then item.texture = 0 end

    applyItem(key)
    sendStateToUi()
end

local function rotate(deltaX, deltaY)
    if not menuOpen then return end

    deltaX = tonumber(deltaX or 0) or 0
    deltaY = tonumber(deltaY or 0) or 0

    lastHeading = lastHeading + deltaX * 0.32
    if lastHeading < 0 then lastHeading = lastHeading + 360.0 end
    if lastHeading >= 360.0 then lastHeading = lastHeading - 360.0 end

    camHeight = camHeight - deltaY * 0.004
    camHeight = math.max(0.15, math.min(1.65, camHeight))

    SetEntityHeading(PlayerPedId(), lastHeading)
    updateCamera()
end

local function zoom(delta)
    if not menuOpen then return end

    delta = tonumber(delta or 0) or 0

    if delta > 0 then camDistance = camDistance + 0.18 else camDistance = camDistance - 0.18 end
    camDistance = math.max(1.25, math.min(4.1, camDistance))

    updateCamera()
end

RegisterNetEvent('driftzone_clothes:client:open', function(data)
    openMenu(data or {})
end)

RegisterNetEvent('driftzone_clothes:client:fix', function(data)
    applyClothes(data or {})
    unfreeze()
end)

RegisterNetEvent('driftzone_clothes:client:closeSaved', function()
    closeUiOnly()
end)

RegisterNetEvent('driftzone_clothes:client:closeAbandoned', function()
    closeUiOnly()
end)

RegisterNetEvent('driftzone_clothes:client:resetSkin', function()
    menuOpen = false
    destroyCamera()
    setFocus(false)
    FreezeEntityPosition(PlayerPedId(), false)

    local ped = PlayerPedId()

    for _, componentId in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do
        SetPedComponentVariation(ped, componentId, 0, 0, 0)
    end

    for _, propId in ipairs({ 0, 1, 2, 6, 7 }) do
        ClearPedProp(ped, propId)
    end

    sendNui({ action = 'close' })
    unfreeze()
end)

RegisterNetEvent('driftzone_clothes:client:forceUnfreeze', function()
    unfreeze()
end)

RegisterNUICallback('ready', function(_, cb)
    browserReady = true
    cb({ ok = true })
end)

RegisterNUICallback('changeDrawable', function(data, cb)
    changeDrawable(tostring(data.key or ''), tonumber(data.direction or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('setDrawable', function(data, cb)
    setDrawableManual(tostring(data.key or ''), tonumber(data.value or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('changeTexture', function(data, cb)
    changeTexture(tostring(data.key or ''), tonumber(data.direction or 0) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('rotate', function(data, cb)
    rotate(data.deltaX, data.deltaY)
    cb({ ok = true })
end)

RegisterNUICallback('zoom', function(data, cb)
    zoom(data.delta)
    cb({ ok = true })
end)

RegisterNUICallback('save', function(_, cb)
    TriggerServerEvent('driftzone_clothes:server:save', stripMaxValues(currentState))
    cb({ ok = true })
end)

RegisterNUICallback('abandon', function(_, cb)
    TriggerServerEvent('driftzone_clothes:server:abandon')
    cb({ ok = true })
end)

RegisterCommand('haine', function()
    TriggerServerEvent('driftzone_clothes:server:open')
end, false)

RegisterCommand('clothes', function()
    TriggerServerEvent('driftzone_clothes:server:open')
end, false)

AddEventHandler('playerSpawned', function()
    -- Nu incarcam automat users.clothes la join/spawn.
    -- Pastrez doar unfreeze ca protectie daca meniul a ramas blocat dupa reconnect/resource restart.
    unfreeze()
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 249, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                SetNuiFocus(true, true)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('driftzone_clothes:client:reloadSaved', function()
    requestSavedClothesReload()
end)

RegisterCommand('reloadclothes', function()
    requestSavedClothesReload()
    notify('info', 'Se reincarca hainele salvate...')
end, false)

exports('ApplyClothes', function(clothes)
    applyClothes(clothes or {})
end)
