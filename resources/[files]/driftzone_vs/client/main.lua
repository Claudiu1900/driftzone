local vsEnabled = false
local vehiclesData = {}
local lastRequest = 0
local entityCache = {}

local drawDistance = Config.DrawDistance or 45.0
local drawDistanceSq = drawDistance * drawDistance
local maxHealth = Config.MaxHealth or 1000.0

local labelScale = Config.Label and Config.Label.scale or 0.32
local labelMinScale = Config.Label and Config.Label.minScale or 0.22
local labelMaxScale = Config.Label and Config.Label.maxScale or 0.38
local labelLineGap = Config.Label and Config.Label.lineGap or 0.023

local mainColor = Config.MainColor or { r = 4, g = 199, b = 247 }

local function notify(notifyType, message, duration)
    TriggerEvent('client:notify', notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function requestData(force)
    if not vsEnabled then return end

    local now = GetGameTimer()

    -- Nu schimb refresh rate-ul; pastram acelasi throttle de request ca in versiunea ta.
    if not force and now - lastRequest < 300 then
        return
    end

    lastRequest = now
    TriggerServerEvent('driftzone_vs:server:requestData')
end

local function getDistanceSq(a, b)
    local dx = a.x - (tonumber(b.x or 0) or 0)
    local dy = a.y - (tonumber(b.y or 0) or 0)
    local dz = a.z - (tonumber(b.z or 0) or 0)

    return dx * dx + dy * dy + dz * dz
end

local function getVehicleByNetId(netId)
    netId = tonumber(netId) or 0

    if netId <= 0 then return 0 end

    local cached = entityCache[netId]
    if cached and cached ~= 0 and DoesEntityExist(cached) then
        return cached
    end

    if not NetworkDoesNetworkIdExist(netId) then
        entityCache[netId] = nil
        return 0
    end

    local entity = NetToVeh(netId)

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        entityCache[netId] = entity
        return entity
    end

    entityCache[netId] = nil
    return 0
end

local function getDrawPosition(data)
    local entity = getVehicleByNetId(data.netId)

    if entity ~= 0 then
        local coords = GetEntityCoords(entity)

        return {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    end

    return {
        x = tonumber(data.x or 0) or 0,
        y = tonumber(data.y or 0) or 0,
        z = tonumber(data.z or 0) or 0
    }
end

local function drawText3D(text, x, y, z, scale, r, g, b, a)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)

    if not onScreen then return end

    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextCentre(true)
    SetTextOutline()

    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(tostring(text))
    EndTextCommandDisplayText(sx, sy)
end

local function drawVehicleLabel(data, playerCoords)
    local pos = getDrawPosition(data)
    local distSq = getDistanceSq(playerCoords, pos)

    if distSq > drawDistanceSq then return end

    local dist = math.sqrt(distSq)
    local scale = math.max(labelMinScale, math.min(labelMaxScale, labelScale + 0.06 - dist * 0.0045))
    local lineGap = 0.18
    local baseZ = pos.z + 1.75

    drawText3D(
        ('ID: %s | NET: %s'):format(data.spawnId or 0, data.netId or 0),
        pos.x, pos.y, baseZ + (5 * lineGap), scale + 0.03,
        mainColor.r or 4, mainColor.g or 199, mainColor.b or 247, 255
    )

    drawText3D(
        ('SQL: %s | SOURCE: %s'):format(data.sqlVehicleId or 0, data.source or 'unknown'),
        pos.x, pos.y, baseZ + (4 * lineGap), scale,
        255, 255, 255, 255
    )

    drawText3D(
        ('OWNER: %s (%s)'):format(data.ownerName or 'Unknown', data.ownerId or 0),
        pos.x, pos.y, baseZ + (3 * lineGap), scale,
        255, 255, 255, 255
    )

    drawText3D(
        ('MODEL: %s | PLATE: %s'):format(data.model or 'unknown', data.plate or 'N/A'),
        pos.x, pos.y, baseZ + (2 * lineGap), scale,
        255, 255, 255, 255
    )

    drawText3D(
        ('POS: %.2f %.2f %.2f'):format(pos.x or 0, pos.y or 0, pos.z or 0),
        pos.x, pos.y, baseZ + lineGap, scale,
        200, 200, 200, 255
    )

    drawText3D(
        ('HEALTH: %s/%s'):format(math.floor(data.health or 0), math.floor(data.maxHealth or maxHealth)),
        pos.x, pos.y, baseZ, scale,
        120, 255, 120, 255
    )
end

local function requestControl(entity, timeoutMs)
    if not DoesEntityExist(entity) then return false end

    local timeout = GetGameTimer() + (timeoutMs or 2500)

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(25)
    end

    return NetworkHasControlOfEntity(entity)
end

RegisterNetEvent('driftzone_vs:client:fixVehicle', function(netId)
    netId = tonumber(netId or 0)

    if netId <= 0 then return end

    local timeout = GetGameTimer() + 5000
    local veh = 0

    while GetGameTimer() < timeout do
        veh = getVehicleByNetId(netId)

        if veh ~= 0 then
            break
        end

        Wait(50)
    end

    if not veh or veh == 0 or not DoesEntityExist(veh) then
        TriggerEvent('client:notify', 'warning', 5000, 'Nu am gasit vehiculul client-side.')
        return
    end

    requestControl(veh, 3500)

    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
end)

RegisterNetEvent('driftzone_vs:client:toggle', function(payload)
    vsEnabled = not vsEnabled

    if vsEnabled then
        vehiclesData = payload or {}
        entityCache = {}
        lastRequest = 0

        requestData(true)

        SetTimeout(150, function() requestData(true) end)
        SetTimeout(400, function() requestData(true) end)
        SetTimeout(900, function() requestData(true) end)

        notify('info', ('Vehicle Status ON | Vehicule: %s'):format(#vehiclesData))
    else
        vehiclesData = {}
        entityCache = {}
        notify('info', 'Vehicle Status OFF')
    end
end)

RegisterNetEvent('driftzone_vs:client:data', function(payload)
    if not vsEnabled then return end

    vehiclesData = payload or {}
end)

for _, command in ipairs({ 'vs', 'dv', 'gotoveh', 'bringveh', 'fixveh' }) do
    RegisterCommand(command, function(_, args)
        TriggerServerEvent('driftzone_vs:server:run', command, args or {})
    end, false)
end

CreateThread(function()
    while true do
        if vsEnabled then
            requestData(false)

            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local coords = {
                x = playerCoords.x,
                y = playerCoords.y,
                z = playerCoords.z
            }

            for i = 1, #vehiclesData do
                drawVehicleLabel(vehiclesData[i], coords)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    vehiclesData = {}
    entityCache = {}
    vsEnabled = false
end)
