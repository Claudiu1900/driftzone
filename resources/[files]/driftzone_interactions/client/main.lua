local nuiReady = false
local interactions = {}
local activeInteraction = nil
local lastShownId = nil
local lastUse = 0
local createdBlips = {}

local function sendNui(data)
    if not nuiReady then return end
    SendNUIMessage(data)
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

local function normalizeColor(value)
    value = type(value) == 'table' and value or {}
    local d = Config.Marker.color
    return {
        r = tonumber(value.r or value[1] or d.r) or d.r,
        g = tonumber(value.g or value[2] or d.g) or d.g,
        b = tonumber(value.b or value[3] or d.b) or d.b,
        a = tonumber(value.a or value[4] or d.a) or d.a
    }
end

local function createInteractionBlip(interaction)
    if not interaction or not interaction.blip then return end
    if createdBlips[interaction.id] then return end

    local b = interaction.blip
    local blip = AddBlipForCoord(interaction.coords.x, interaction.coords.y, interaction.coords.z)
    SetBlipSprite(blip, tonumber(b.sprite or 1) or 1)
    SetBlipColour(blip, tonumber(b.color or 3) or 3)
    SetBlipScale(blip, tonumber(b.scale or 0.8) or 0.8)
    SetBlipAsShortRange(blip, b.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(tostring(b.name or interaction.text or 'Interaction'))
    EndTextCommandSetBlipName(blip)
    createdBlips[interaction.id] = blip
end

local function removeInteractionBlip(id)
    local blip = createdBlips[id]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    createdBlips[id] = nil
end

local function normalizeInteraction(data)
    data = decodeData(data)
    if type(data) ~= 'table' then return nil end

    local id = trim(data.id)
    if id == '' then return nil end

    local coords = normalizeVector(data.coords or data.position or data.pos)
    if not coords then return nil end

    local range = tonumber(data.range or data.radius or Config.DefaultRange) or Config.DefaultRange
    local markerSize = data.markerSize or data.size or {}

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
        data = data.data or nil,
        marker = data.marker ~= false,
        markerType = tonumber(data.markerType or Config.Marker.type) or Config.Marker.type,
        markerColor = normalizeColor(data.markerColor or data.color),
        markerSize = {
            x = tonumber(markerSize.x or markerSize[1] or (range * Config.Marker.sizeMultiplier)) or 2.0,
            y = tonumber(markerSize.y or markerSize[2] or (range * Config.Marker.sizeMultiplier)) or 2.0,
            z = tonumber(markerSize.z or markerSize[3] or Config.Marker.height) or Config.Marker.height
        },
        requireVehicle = data.requireVehicle == true,
        requireOnFoot = data.requireOnFoot == true,
        hidden = data.hidden == true,
        blip = data.blip
    }
end

local function addInteraction(data)
    local interaction = normalizeInteraction(data)
    if not interaction then return false end
    if interactions[interaction.id] then removeInteractionBlip(interaction.id) end
    interactions[interaction.id] = interaction
    createInteractionBlip(interaction)
    return true
end

local function removeInteraction(id)
    id = tostring(id or '')
    interactions[id] = nil
    removeInteractionBlip(id)
    if activeInteraction and activeInteraction.id == id then
        activeInteraction = nil
        lastShownId = nil
        sendNui({ action = 'hide' })
    end
end

local function clearInteractions()
    for id in pairs(createdBlips) do removeInteractionBlip(id) end
    interactions = {}
    activeInteraction = nil
    lastShownId = nil
    sendNui({ action = 'hide' })
end

local function setHidden(id, hidden)
    local interaction = interactions[tostring(id or '')]
    if not interaction then return end
    interaction.hidden = hidden == true
    if interaction.hidden and activeInteraction and activeInteraction.id == interaction.id then
        activeInteraction = nil
        lastShownId = nil
        sendNui({ action = 'hide' })
    end
end

local function updateText(id, text, subText)
    local interaction = interactions[tostring(id or '')]
    if not interaction then return end
    if text ~= nil then interaction.text = tostring(text) end
    if subText ~= nil then interaction.subText = tostring(subText) end
    if activeInteraction and activeInteraction.id == interaction.id then lastShownId = nil end
end

local function canUseInteraction(interaction)
    if not interaction or interaction.hidden then return false end
    local ped = PlayerPedId()
    if interaction.requireVehicle and not IsPedInAnyVehicle(ped, false) then return false end
    if interaction.requireOnFoot and IsPedInAnyVehicle(ped, false) then return false end
    return true
end

local function nearestInteraction()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nearest, nearestDistance = nil, 999999.0
    for _, interaction in pairs(interactions) do
        if canUseInteraction(interaction) then
            local dist = #(coords - interaction.coords)
            if dist <= interaction.range and dist < nearestDistance then
                nearest = interaction
                nearestDistance = dist
            end
        end
    end
    return nearest
end

local function showInteraction(interaction)
    if not interaction or lastShownId == interaction.id then return end
    lastShownId = interaction.id
    sendNui({ action = 'show', data = { key = interaction.key, text = interaction.text, subText = interaction.subText, mainColor = Config.MainColor } })
end

local function hideInteraction()
    if not lastShownId then return end
    lastShownId = nil
    sendNui({ action = 'hide' })
end

local function runInteraction(interaction)
    if not interaction then return end
    local now = GetGameTimer()
    if now - lastUse < 750 then return end
    lastUse = now
    local payload = interaction.data or {}
    if interaction.event ~= '' then TriggerEvent(interaction.event, payload, interaction.id) end
    if interaction.remoteEvent ~= '' then TriggerServerEvent(interaction.remoteEvent, payload, interaction.id) end
    if interaction.fallbackCommand ~= '' then ExecuteCommand(interaction.fallbackCommand) end
end

local function drawInteractionMarker(interaction)
    if not Config.Marker.enabled or not interaction.marker or interaction.hidden then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    if #(coords - interaction.coords) > (Config.DrawDistance or 35.0) then return end
    local c, s = interaction.markerColor, interaction.markerSize
    DrawMarker(interaction.markerType, interaction.coords.x, interaction.coords.y, interaction.coords.z + Config.Marker.zOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, s.x, s.y, s.z, c.r, c.g, c.b, c.a, false, false, 2, false, nil, nil, false)
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_interactions:client:add', addInteraction)
RegisterNetEvent('driftzone_interactions:client:remove', removeInteraction)
RegisterNetEvent('driftzone_interactions:client:clear', clearInteractions)
RegisterNetEvent('driftzone_interactions:client:updateText', updateText)
RegisterNetEvent('driftzone_interactions:client:setHidden', setHidden)
RegisterNetEvent('interactions:add', addInteraction)
RegisterNetEvent('interactions:remove', removeInteraction)
RegisterNetEvent('interactions:clear', clearInteractions)
RegisterNetEvent('interactions:updateText', updateText)
RegisterNetEvent('interactions:setHidden', setHidden)

CreateThread(function()
    Wait(900)
    for _, interaction in ipairs(Config.DefaultInteractions or {}) do addInteraction(interaction) end
    print('[DRIFTZONE_INTERACTIONS] Client-side loaded.')
end)

CreateThread(function()
    while true do
        activeInteraction = nearestInteraction()
        if activeInteraction then showInteraction(activeInteraction) else hideInteraction() end
        Wait(Config.CheckInterval or 180)
    end
end)

CreateThread(function()
    while true do
        local hasMarkers = false
        for _, interaction in pairs(interactions) do
            if interaction.marker and not interaction.hidden then
                hasMarkers = true
                drawInteractionMarker(interaction)
            end
        end
        Wait(hasMarkers and 0 or 500)
    end
end)

CreateThread(function()
    while true do
        if activeInteraction then
            if IsControlJustPressed(0, Config.Key or 38) then
                local ped = PlayerPedId()
                if #(GetEntityCoords(ped) - activeInteraction.coords) <= activeInteraction.range then runInteraction(activeInteraction) end
            end
            Wait(0)
        else
            Wait(120)
        end
    end
end)

exports('AddInteraction', addInteraction)
exports('RemoveInteraction', removeInteraction)
exports('ClearInteractions', clearInteractions)
exports('UpdateInteractionText', updateText)
exports('SetInteractionHidden', setHidden)
