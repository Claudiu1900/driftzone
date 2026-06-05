local COMPONENTS = {
    mask = 1,
    hair = 2,
    torso = 3,
    pants = 4,
    bag = 5,
    shoes = 6,
    top = 8,
    insignia = 10,
    jacket = 11
}

local PROPS = {
    hat = 0,
    glasses = 1
}

local lastPayload = '{}'

local function decodeClothes(payload)
    if type(payload) == 'table' then
        return payload
    end

    if type(payload) ~= 'string' then
        return {}
    end

    if payload == '' or payload == 'null' then
        return {}
    end

    local ok, decoded = pcall(json.decode, payload)

    if ok and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

local function safeNumber(value, fallback)
    local n = tonumber(value)

    if n == nil then
        return fallback or 0
    end

    return math.floor(n)
end

local function waitForPed(timeoutMs)
    local timeout = GetGameTimer() + (timeoutMs or 7000)

    while GetGameTimer() < timeout do
        local ped = PlayerPedId()

        if ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
            return ped
        end

        Wait(100)
    end

    return PlayerPedId()
end

local function applyComponent(ped, componentId, item)
    if not item then return end

    local drawable = safeNumber(item.drawable, 0)
    local texture = safeNumber(item.texture, 0)

    if drawable < 0 then drawable = 0 end
    if texture < 0 then texture = 0 end

    local maxDrawable = GetNumberOfPedDrawableVariations(ped, componentId)
    if maxDrawable and maxDrawable > 0 and drawable >= maxDrawable then
        drawable = maxDrawable - 1
    end

    local maxTexture = GetNumberOfPedTextureVariations(ped, componentId, drawable)
    if maxTexture and maxTexture > 0 and texture >= maxTexture then
        texture = maxTexture - 1
    end

    SetPedComponentVariation(ped, componentId, drawable, texture, 0)
end

local function applyProp(ped, propId, item)
    if not item then return end

    local drawable = safeNumber(item.drawable, -1)
    local texture = safeNumber(item.texture, 0)

    if drawable < 0 then
        ClearPedProp(ped, propId)
        return
    end

    if texture < 0 then texture = 0 end

    local maxDrawable = GetNumberOfPedPropDrawableVariations(ped, propId)
    if maxDrawable and maxDrawable > 0 and drawable >= maxDrawable then
        drawable = maxDrawable - 1
    end

    local maxTexture = GetNumberOfPedPropTextureVariations(ped, propId, drawable)
    if maxTexture and maxTexture > 0 and texture >= maxTexture then
        texture = maxTexture - 1
    end

    SetPedPropIndex(ped, propId, drawable, texture, true)
end

local function applyClothesOnce(clothes)
    local ped = waitForPed(7000)

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    for key, componentId in pairs(COMPONENTS) do
        if clothes[key] then
            applyComponent(ped, componentId, clothes[key])
        end
    end

    for key, propId in pairs(PROPS) do
        if clothes[key] then
            applyProp(ped, propId, clothes[key])
        end
    end

    FreezeEntityPosition(ped, false)

    return true
end

local function applyClothes(payload)
    lastPayload = payload or '{}'
    local clothes = decodeClothes(payload)

    CreateThread(function()
        applyClothesOnce(clothes)

        local delays = { 250, 600, 1100, 1800, 2800, 4300, 6500, 9000 }

        for _, delay in ipairs(delays) do
            Wait(delay)
            applyClothesOnce(clothes)
        end
    end)
end

RegisterNetEvent('client:clothes:fix', function(payload)
    applyClothes(payload)
end)

RegisterNetEvent('driftzone_clothes:client:apply', function(payload)
    applyClothes(payload)
end)

RegisterNetEvent('driftzone_clothes:client:applySaved', function(payload)
    applyClothes(payload)
end)

RegisterNetEvent('client:clothes:forceUnfreeze', function()
    local ped = PlayerPedId()

    if ped and ped ~= 0 and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
    end
end)

RegisterCommand('reloadclotheslocal', function()
    applyClothes(lastPayload)
end, false)

exports('ApplyClothes', function(payload)
    applyClothes(payload)
end)
