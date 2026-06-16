local nuiReady = false
local interactions = {}
local createdBlips = {}
local dismissed = {}
local activeId = nil
local lastShownId = nil
local lastUse = 0
local markerTick = 0.0

local function sendNui(data)
    if nuiReady then SendNUIMessage(data) end
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function decodeData(data)
    if type(data) ~= 'string' then return data end
    local ok, decoded = pcall(json.decode, data)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

local function normalizeVector(value)
    if not value then return nil end
    if type(value) == 'vector3' then return value end
    if type(value) == 'table' then
        local x = tonumber(value.x or value[1])
        local y = tonumber(value.y or value[2])
        local z = tonumber(value.z or value[3])
        if x and y and z then return vector3(x, y, z) end
    end
    return nil
end

local function markerDefaults()
    local m = Config.Marker or {}
    return m.color or { r = 4, g = 199, b = 247, a = 120 }
end

local function normalizeColor(value)
    value = type(value) == 'table' and value or {}
    local d = markerDefaults()
    return {
        r = tonumber(value.r or value[1] or d.r) or 4,
        g = tonumber(value.g or value[2] or d.g) or 199,
        b = tonumber(value.b or value[3] or d.b) or 247,
        a = tonumber(value.a or value[4] or d.a) or 120
    }
end

local function removeBlip(id)
    local blip = createdBlips[id]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    createdBlips[id] = nil
end

local function createBlip(interaction)
    if not interaction or not interaction.blip or createdBlips[interaction.id] then return end
    local b = interaction.blip
    local blip = AddBlipForCoord(interaction.coords.x, interaction.coords.y, interaction.coords.z)
    SetBlipSprite(blip, tonumber(b.sprite or 1) or 1)
    SetBlipColour(blip, tonumber(b.color or 3) or 3)
    SetBlipScale(blip, tonumber(b.scale or 0.75) or 0.75)
    SetBlipAsShortRange(blip, b.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(tostring(b.name or interaction.text or 'Locatie'))
    EndTextCommandSetBlipName(blip)
    createdBlips[interaction.id] = blip
end

local function normalizeInteraction(data)
    data = decodeData(data)
    if type(data) ~= 'table' then return nil end

    local id = trim(data.id)
    if id == '' then return nil end

    local coords = normalizeVector(data.coords or data.position or data.pos)
    if not coords then return nil end

    local range = tonumber(data.range or data.radius or Config.DefaultRange or 2.5) or 2.5
    local markerSize = data.markerSize or data.size or {}
    local cfgMarker = Config.Marker or {}

    return {
        id = id,
        coords = coords,
        range = range,
        key = tostring(data.key or 'E'):upper(),
        text = tostring(data.text or 'Apasa E pentru a interactiona'),
        subText = tostring(data.subText or data.subtitle or ''),
        event = data.event and tostring(data.event) or '',
        remoteEvent = data.remoteEvent and tostring(data.remoteEvent) or '',
        fallbackCommand = data.fallbackCommand and tostring(data.fallbackCommand) or '',
        data = data.data or {},
        marker = data.marker ~= false,
        markerType = tonumber(data.markerType or cfgMarker.type or 1) or 1,
        markerColor = normalizeColor(data.markerColor or data.color),
        markerSize = {
            x = tonumber(markerSize.x or markerSize[1] or (range * (cfgMarker.sizeMultiplier or 1.2))) or 2.0,
            y = tonumber(markerSize.y or markerSize[2] or (range * (cfgMarker.sizeMultiplier or 1.2))) or 2.0,
            z = tonumber(markerSize.z or markerSize[3] or cfgMarker.height or 0.35) or 0.35
        },
        requireVehicle = data.requireVehicle == true,
        requireOnFoot = data.requireOnFoot == true,
        hidden = data.hidden == true,
        blip = data.blip,
        autoRemoveOnUse = data.autoRemoveOnUse == true,
        personal = data.personal == true or data.localOnly == true,
        setWaypoint = data.setWaypoint == true
    }
end

local function addInteraction(data)
    local interaction = normalizeInteraction(data)
    if not interaction then return false end
    if interactions[interaction.id] then removeBlip(interaction.id) end
    interactions[interaction.id] = interaction
    dismissed[interaction.id] = nil
    createBlip(interaction)
    if interaction.setWaypoint then SetNewWaypoint(interaction.coords.x + 0.0, interaction.coords.y + 0.0) end
    return true
end

local function addPersonalWaypoint(data)
    data = type(data) == 'table' and data or {}
    data.personal = true
    if data.setWaypoint ~= false then data.setWaypoint = true end
    return addInteraction(data)
end

local function removeInteraction(id)
    id = tostring(id or '')
    interactions[id] = nil
    dismissed[id] = nil
    removeBlip(id)
    if activeId == id then activeId = nil end
    if lastShownId == id then
        lastShownId = nil
        sendNui({ action = 'hide' })
    end
end

local function clearInteractions()
    for id in pairs(createdBlips) do removeBlip(id) end
    interactions = {}
    dismissed = {}
    activeId = nil
    lastShownId = nil
    sendNui({ action = 'hide' })
end

local function setHidden(id, hidden)
    local interaction = interactions[tostring(id or '')]
    if not interaction then return end
    interaction.hidden = hidden == true
    if not interaction.hidden then dismissed[interaction.id] = nil end
    if interaction.hidden and lastShownId == interaction.id then
        lastShownId = nil
        sendNui({ action = 'hide' })
    end
end

local function updateText(id, text, subText)
    local interaction = interactions[tostring(id or '')]
    if not interaction then return end
    if text ~= nil then interaction.text = tostring(text) end
    if subText ~= nil then interaction.subText = tostring(subText) end
    if lastShownId == interaction.id then lastShownId = nil end
end

local function canUse(interaction)
    if not interaction or interaction.hidden then return false end
    local ped = PlayerPedId()
    if interaction.requireVehicle and not IsPedInAnyVehicle(ped, false) then return false end
    if interaction.requireOnFoot and IsPedInAnyVehicle(ped, false) then return false end
    return true
end

local function nearestInteraction()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nearest, nearestDist = nil, 999999.0
    for _, interaction in pairs(interactions) do
        if canUse(interaction) then
            local dist = #(coords - interaction.coords)
            if dismissed[interaction.id] and dist > interaction.range then dismissed[interaction.id] = nil end
            if not dismissed[interaction.id] and dist <= interaction.range and dist < nearestDist then
                nearest, nearestDist = interaction, dist
            end
        else
            dismissed[interaction.id] = nil
        end
    end
    return nearest, nearestDist
end

local function showInteraction(interaction)
    if not interaction or lastShownId == interaction.id then return end
    lastShownId = interaction.id
    sendNui({
        action = 'show',
        data = {
            key = interaction.key,
            text = interaction.text,
            subText = interaction.subText,
            mainColor = Config.MainColor or '#04c7f7'
        }
    })
end

local function hideInteraction()
    if not lastShownId then return end
    lastShownId = nil
    sendNui({ action = 'hide' })
end

local function runInteraction(interaction)
    if not interaction then return end
    local now = GetGameTimer()
    if now - lastUse < 600 then return end
    lastUse = now

    dismissed[interaction.id] = true
    hideInteraction()
    activeId = nil

    local payload = interaction.data or {}
    if interaction.event ~= '' then TriggerEvent(interaction.event, payload, interaction.id) end
    if interaction.remoteEvent ~= '' then TriggerServerEvent(interaction.remoteEvent, payload, interaction.id) end
    if interaction.fallbackCommand ~= '' then ExecuteCommand(interaction.fallbackCommand) end
    if interaction.autoRemoveOnUse then removeInteraction(interaction.id) end
end

local function drawMarkerFor(interaction)
    local marker = Config.Marker or {}
    if marker.enabled == false or not interaction.marker or interaction.hidden then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local dist = #(coords - interaction.coords)
    if dist > (Config.DrawDistance or 35.0) then return end
    local c, s = interaction.markerColor, interaction.markerSize
    local zOffset = tonumber(marker.zOffset or -1.0) or -1.0
    DrawMarker(interaction.markerType, interaction.coords.x, interaction.coords.y, interaction.coords.z + zOffset, 0.0, 0.0, 0.0, 0.0, 0.0, markerTick, s.x, s.y, s.z, c.r, c.g, c.b, c.a, false, false, 2, false, nil, nil, false)
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_interactions:client:add', addInteraction)
RegisterNetEvent('driftzone_interactions:client:addPersonalWaypoint', addPersonalWaypoint)
RegisterNetEvent('driftzone_interactions:client:remove', removeInteraction)
RegisterNetEvent('driftzone_interactions:client:clear', clearInteractions)
RegisterNetEvent('driftzone_interactions:client:updateText', updateText)
RegisterNetEvent('driftzone_interactions:client:setHidden', setHidden)

RegisterNetEvent('driftzone_implements:client:add', addInteraction)
RegisterNetEvent('driftzone_implements:client:addPersonalWaypoint', addPersonalWaypoint)
RegisterNetEvent('driftzone_implements:client:remove', removeInteraction)
RegisterNetEvent('driftzone_implements:client:clear', clearInteractions)
RegisterNetEvent('driftzone_implements:client:updateText', updateText)
RegisterNetEvent('driftzone_implements:client:setHidden', setHidden)

RegisterNetEvent('interactions:add', addInteraction)
RegisterNetEvent('interactions:remove', removeInteraction)
RegisterNetEvent('interactions:clear', clearInteractions)
RegisterNetEvent('interactions:updateText', updateText)
RegisterNetEvent('interactions:setHidden', setHidden)

CreateThread(function()
    Wait(650)
    for _, interaction in ipairs(Config.DefaultInteractions or {}) do addInteraction(interaction) end
    print('[DRIFTZONE_IMPLEMENTS] Loaded optimized local interactions.')
end)

CreateThread(function()
    while true do
        local nearest = nearestInteraction()
        if nearest then
            activeId = nearest.id
            showInteraction(nearest)
            Wait(90)
        else
            activeId = nil
            hideInteraction()
            Wait(Config.CheckInterval or 180)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 650
        for _, interaction in pairs(interactions) do
            if interaction.marker and not interaction.hidden then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                if #(coords - interaction.coords) <= (Config.DrawDistance or 35.0) then
                    drawMarkerFor(interaction)
                    sleep = 0
                end
            end
        end
        markerTick = markerTick + 1.2
        if markerTick > 360.0 then markerTick = 0.0 end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if activeId and interactions[activeId] then
            if IsControlJustPressed(0, Config.Key or 38) then
                runInteraction(interactions[activeId])
            end
            Wait(0)
        else
            Wait(120)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearInteractions()
end)

exports('AddInteraction', addInteraction)
exports('AddPersonalWaypoint', addPersonalWaypoint)
exports('RemoveInteraction', removeInteraction)
exports('ClearInteractions', clearInteractions)
exports('UpdateInteractionText', updateText)
exports('SetInteractionHidden', setHidden)
