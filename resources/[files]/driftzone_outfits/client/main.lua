local browserReady = false
local outfitsOpen = false
local pendingOpen = nil
local lastPed = 0

local OUTFIT_ITEMS = {
    { key = 'mask', type = 'component', componentId = 1 },
    { key = 'hat', type = 'prop', propId = 0 },
    { key = 'jacket', type = 'component', componentId = 11 },
    { key = 'torso', type = 'component', componentId = 3 },
    { key = 'top', type = 'component', componentId = 8 },
    { key = 'pants', type = 'component', componentId = 4 },
    { key = 'shoes', type = 'component', componentId = 6 },
    { key = 'insignia', type = 'component', componentId = 10 },
    { key = 'glasses', type = 'prop', propId = 1 }
}

local MALE_MODEL = joaat('mp_m_freemode_01')
local FEMALE_MODEL = joaat('mp_f_freemode_01')

local function setHudVisible(state)
    local visible = state == true

    DisplayHud(visible)
    DisplayRadar(visible)

    TriggerEvent('driftzone_hud:visible', visible)
    TriggerEvent('client:hud:visible', visible)
    TriggerEvent('hud:visible', visible)
end

local function setMenuFocus(state)
    outfitsOpen = state == true

    SetNuiFocus(outfitsOpen, outfitsOpen)
    SetNuiFocusKeepInput(false)

    setHudVisible(not outfitsOpen)
end

local function getPed()
    local ped = PlayerPedId()

    if ped ~= lastPed then
        lastPed = ped
    end

    return lastPed
end

local function getPlayerSex()
    local ped = getPed()
    local model = GetEntityModel(ped)

    if model == FEMALE_MODEL then
        return 'f'
    end

    -- default male. Daca ai ped custom non-freemode, il considera male.
    return 'm'
end

local function requestOpenFromServer()
    TriggerServerEvent('driftzone_outfits:server:open', getPlayerSex())
end

local function captureOutfit()
    local ped = getPed()
    local clothes = {}

    for i = 1, #OUTFIT_ITEMS do
        local item = OUTFIT_ITEMS[i]

        if item.type == 'component' then
            clothes[item.key] = {
                drawable = GetPedDrawableVariation(ped, item.componentId),
                texture = GetPedTextureVariation(ped, item.componentId)
            }
        else
            clothes[item.key] = {
                drawable = GetPedPropIndex(ped, item.propId),
                texture = GetPedPropTextureIndex(ped, item.propId)
            }
        end
    end

    return clothes
end

local function applyOutfit(clothes)
    if type(clothes) ~= 'table' then return end

    local ped = getPed()

    for i = 1, #OUTFIT_ITEMS do
        local item = OUTFIT_ITEMS[i]
        local saved = clothes[item.key]

        if type(saved) == 'table' then
            local drawable = tonumber(saved.drawable or 0) or 0
            local texture = tonumber(saved.texture or 0) or 0

            if item.type == 'component' then
                SetPedComponentVariation(ped, item.componentId, drawable, texture, 0)
            else
                if drawable < 0 then
                    ClearPedProp(ped, item.propId)
                else
                    SetPedPropIndex(ped, item.propId, drawable, texture, true)
                end
            end
        end
    end
end

local function openMenu(payload)
    if not browserReady then
        pendingOpen = payload or {}
        return
    end

    setMenuFocus(true)

    SendNUIMessage({
        action = 'open',
        payload = payload or {}
    })
end

local function closeMenu()
    if not outfitsOpen then return end

    setMenuFocus(false)

    SendNUIMessage({
        action = 'close'
    })
end

RegisterNetEvent('driftzone_outfits:client:open', function(payload)
    openMenu(payload or {})
end)

-- Singura metoda client-side pentru deschidere.
-- Din driftzone_keybinds folosesti: TriggerEvent('driftzone_outfits:client:requestOpen')
RegisterNetEvent('driftzone_outfits:client:requestOpen', function()
    requestOpenFromServer()
end)

RegisterNetEvent('driftzone_outfits:client:apply', function(clothes)
    applyOutfit(clothes or {})
end)

RegisterNetEvent('driftzone_outfits:client:setCooldown', function(value)
    SendNUIMessage({
        action = 'setCooldown',
        cooldownUntil = tonumber(value or 0) or 0
    })
end)

RegisterNetEvent('driftzone_outfits:client:captureForAdd', function(data)
    data = data or {}

    TriggerServerEvent('driftzone_outfits:server:addCaptured', {
        name = tostring(data.name or ''),
        image = tostring(data.image or ''),
        sex = getPlayerSex(),
        clothes = captureOutfit()
    })
end)

RegisterNUICallback('ready', function(_, cb)
    browserReady = true

    if pendingOpen then
        local payload = pendingOpen
        pendingOpen = nil
        openMenu(payload)
    end

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('wear', function(data, cb)
    local outfitId = tonumber(data and data.id or 0) or 0

    if outfitId > 0 then
        TriggerServerEvent('driftzone_outfits:server:wear', outfitId, getPlayerSex())
    end

    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if outfitsOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                closeMenu()
            end

            DisplayHud(false)
            DisplayRadar(false)

            Wait(0)
        else
            Wait(600)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if outfitsOpen then
        setMenuFocus(false)
    end
end)

exports('Open', requestOpenFromServer)
exports('OpenMenu', requestOpenFromServer)
exports('RequestOpen', requestOpenFromServer)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_OUTFITS] Client-side loaded. Trigger-only mode.')
end)
