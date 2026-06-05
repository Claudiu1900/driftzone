local creatorOpen = false
local creatorCam = nil
local currentCharacter = nil
local lastApply = 0
local oldCoords = nil
local oldHeading = nil

local overlayMap = {
    blemishes = 0,
    beard = 1,
    eyebrows = 2,
    ageing = 3,
    makeup = 4,
    blush = 5,
    complexion = 6,
    sundamage = 7,
    lipstick = 8,
    moles = 9,
    chesthair = 10,
    bodyblemishes = 11
}

local overlayColorType = {
    beard = 1,
    eyebrows = 1,
    blush = 2,
    lipstick = 2,
    chesthair = 1
}

local defaultCharacter = {
    gender = 'male',

    parents = {
        mother = 21,
        father = 0,
        shapeMix = 0.50,
        skinMix = 0.50
    },

    hair = {
        style = 0,
        color = 0,
        highlight = 0
    },

    eyes = 0,

    features = {
        ['0'] = 0.0, ['1'] = 0.0, ['2'] = 0.0, ['3'] = 0.0, ['4'] = 0.0,
        ['5'] = 0.0, ['6'] = 0.0, ['7'] = 0.0, ['8'] = 0.0, ['9'] = 0.0,
        ['10'] = 0.0, ['11'] = 0.0, ['12'] = 0.0, ['13'] = 0.0, ['14'] = 0.0,
        ['15'] = 0.0, ['16'] = 0.0, ['17'] = 0.0, ['18'] = 0.0, ['19'] = 0.0
    },

    overlays = {
        blemishes = { id = 255, opacity = 0.0, color = 0 },
        beard = { id = 255, opacity = 0.0, color = 0 },
        eyebrows = { id = 0, opacity = 1.0, color = 0 },
        ageing = { id = 255, opacity = 0.0, color = 0 },
        makeup = { id = 255, opacity = 0.0, color = 0 },
        blush = { id = 255, opacity = 0.0, color = 0 },
        complexion = { id = 255, opacity = 0.0, color = 0 },
        sundamage = { id = 255, opacity = 0.0, color = 0 },
        lipstick = { id = 255, opacity = 0.0, color = 0 },
        moles = { id = 255, opacity = 0.0, color = 0 },
        chesthair = { id = 255, opacity = 0.0, color = 0 },
        bodyblemishes = { id = 255, opacity = 0.0, color = 0 }
    }
}

local function copy(value)
    return json.decode(json.encode(value))
end

local function nui(data)
    SendNUIMessage(data)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)

    RequestModel(hash)

    local timeout = GetGameTimer() + 8000

    while not HasModelLoaded(hash) do
        Wait(0)

        if GetGameTimer() > timeout then
            return false
        end
    end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    Wait(250)

    return true
end

local function normalize(data)
    local c = data or copy(defaultCharacter)

    c.gender = c.gender == 'female' and 'female' or 'male'

    c.parents = c.parents or {}
    c.parents.mother = tonumber(c.parents.mother) or 21
    c.parents.father = tonumber(c.parents.father) or 0
    c.parents.shapeMix = tonumber(c.parents.shapeMix) or 0.5
    c.parents.skinMix = tonumber(c.parents.skinMix) or 0.5

    c.hair = c.hair or {}
    c.hair.style = tonumber(c.hair.style) or 0
    c.hair.color = tonumber(c.hair.color) or 0
    c.hair.highlight = tonumber(c.hair.highlight) or 0

    c.eyes = tonumber(c.eyes) or 0

    c.features = c.features or {}

    for i = 0, 19 do
        c.features[tostring(i)] = tonumber(c.features[tostring(i)]) or 0.0
    end

    c.overlays = c.overlays or {}

    for key, _ in pairs(overlayMap) do
        c.overlays[key] = c.overlays[key] or {}
        c.overlays[key].id = tonumber(c.overlays[key].id)

        if c.overlays[key].id == nil then
            c.overlays[key].id = 255
        end

        c.overlays[key].opacity = tonumber(c.overlays[key].opacity) or 0.0
        c.overlays[key].color = tonumber(c.overlays[key].color) or 0
    end

    return c
end

local function applyCreatorClothes(gender)
    local ped = PlayerPedId()
    local set = gender == 'female' and Config.DefaultCreatorClothes.female or Config.DefaultCreatorClothes.male

    for _, item in pairs(set) do
        SetPedComponentVariation(ped, item.component, item.drawable, item.texture, 0)
    end

    ClearPedProp(ped, 0)
    ClearPedProp(ped, 1)
    ClearPedProp(ped, 2)
    ClearPedProp(ped, 6)
    ClearPedProp(ped, 7)
end

local function applyCharacter(data, creatorMode)
    local now = GetGameTimer()

    if creatorMode and now - lastApply < 45 then
        return
    end

    lastApply = now

    local c = normalize(data)
    local model = c.gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'

    loadModel(model)

    local ped = PlayerPedId()

    SetPedDefaultComponentVariation(ped)
    ClearPedDecorations(ped)

    SetPedHeadBlendData(
        ped,
        c.parents.mother,
        c.parents.father,
        0,
        c.parents.mother,
        c.parents.father,
        0,
        c.parents.shapeMix + 0.0,
        c.parents.skinMix + 0.0,
        0.0,
        false
    )

    for i = 0, 19 do
        SetPedFaceFeature(ped, i, tonumber(c.features[tostring(i)]) or 0.0)
    end

    SetPedComponentVariation(ped, 2, c.hair.style, 0, 0)
    SetPedHairColor(ped, c.hair.color, c.hair.highlight)
    SetPedEyeColor(ped, c.eyes)

    for key, overlayIndex in pairs(overlayMap) do
        local overlay = c.overlays[key] or {}
        local id = tonumber(overlay.id) or 255
        local opacity = tonumber(overlay.opacity) or 0.0
        local color = tonumber(overlay.color) or 0

        SetPedHeadOverlay(ped, overlayIndex, id, opacity + 0.0)

        if overlayColorType[key] then
            SetPedHeadOverlayColor(ped, overlayIndex, overlayColorType[key], color, color)
        end
    end

    if creatorMode then
        applyCreatorClothes(c.gender)
    end

    currentCharacter = c
end

local function createCam()
    if creatorCam then
        DestroyCam(creatorCam, false)
        creatorCam = nil
    end

    creatorCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    SetCamCoord(
        creatorCam,
        Config.CreatorCamera.x,
        Config.CreatorCamera.y,
        Config.CreatorCamera.z
    )

    PointCamAtCoord(
        creatorCam,
        Config.CreatorCamera.lookX,
        Config.CreatorCamera.lookY,
        Config.CreatorCamera.lookZ
    )

    SetCamFov(creatorCam, Config.CreatorCamera.fov or 34.0)
    SetCamActive(creatorCam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function destroyCam()
    if creatorCam then
        SetCamActive(creatorCam, false)
        DestroyCam(creatorCam, false)
        creatorCam = nil
    end

    RenderScriptCams(false, true, 500, true, true)
end

local function openCreator(characterData, isFirstCreation)
    if creatorOpen then return end

    creatorOpen = true

    local ped = PlayerPedId()
    oldCoords = GetEntityCoords(ped)
    oldHeading = GetEntityHeading(ped)

    DoScreenFadeOut(300)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    local character = characterData or copy(defaultCharacter)
    character = normalize(character)

    loadModel(character.gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01')

    ped = PlayerPedId()

    SetEntityCoordsNoOffset(
        ped,
        Config.CreatorCoords.x,
        Config.CreatorCoords.y,
        Config.CreatorCoords.z,
        false,
        false,
        false
    )

    SetEntityHeading(ped, Config.CreatorCoords.h)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)

    applyCharacter(character, true)

    createCam()

    DisplayRadar(false)
    DisplayHud(false)

    TriggerEvent('driftzone_hud:visible', false)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    nui({
        action = 'open',
        character = character,
        mainColor = Config.MainColor,
        firstCreation = isFirstCreation == true
    })

    Wait(400)
    DoScreenFadeIn(500)
end

local function closeCreator()
    creatorOpen = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    destroyCam()

    local ped = PlayerPedId()

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)

    if oldCoords then
        SetEntityCoordsNoOffset(ped, oldCoords.x, oldCoords.y, oldCoords.z, false, false, false)
        SetEntityHeading(ped, oldHeading or 0.0)
    end

    DisplayRadar(true)
    DisplayHud(true)

    TriggerEvent('driftzone_hud:visible', true)

    nui({
        action = 'close'
    })

    oldCoords = nil
    oldHeading = nil
end

RegisterNetEvent('driftzone_character:client:open', function(characterData, isFirstCreation)
    openCreator(characterData, isFirstCreation)
end)

RegisterNetEvent('driftzone_character:client:apply', function(data)
    applyCharacter(data, false)
end)

RegisterNetEvent('driftzone_character:client:saved', function(data)
    applyCharacter(data, false)
    closeCreator()
end)

RegisterNetEvent('driftzone_auth:client:success', function()
    Wait(1400)
    TriggerServerEvent('driftzone_character:server:check')
end)

RegisterNUICallback('update', function(data, cb)
    if creatorOpen then
        applyCharacter(data, true)
    end

    cb({ ok = true })
end)

RegisterNUICallback('save', function(data, cb)
    if creatorOpen then
        TriggerServerEvent('driftzone_character:server:save', data)
    end

    cb({ ok = true })
end)

RegisterNUICallback('rotate', function(data, cb)
    if creatorOpen then
        local delta = tonumber(data.delta) or 0
        local ped = PlayerPedId()

        SetEntityHeading(ped, GetEntityHeading(ped) + delta)
    end

    cb({ ok = true })
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if creatorOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)

            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(false)

            Wait(0)
        else
            Wait(500)
        end
    end
end)

exports('OpenCreator', function()
    openCreator(currentCharacter or copy(defaultCharacter), false)
end)

exports('ApplyCharacter', function(data)
    applyCharacter(data, false)
end)

RegisterCommand('character', function()
    TriggerServerEvent('driftzone_character:server:openCommand')
end, false)

RegisterCommand('fixcharacter', function()
    TriggerServerEvent('driftzone_character:server:fixCommand')
end, false)