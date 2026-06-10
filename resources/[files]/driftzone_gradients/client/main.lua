local uiReady = false
local selecting = false
local selectedVehicle = nil
local cursorX = 0.5
local cursorY = 0.5
local currentGradient = nil
local markerRot = 0.0

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 5000, tostring(msg or ''))
end

local function sendNui(data)
    SendNUIMessage(data)
end

local function waitUiReady(maxMs)
    if uiReady then return true end
    local timeout = GetGameTimer() + (maxMs or 1500)
    while not uiReady and GetGameTimer() < timeout do
        Wait(25)
    end
    return uiReady
end

local function setFocus(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function stopSelector(sendCancel)
    selecting = false
    selectedVehicle = nil
    currentGradient = nil
    setFocus(false)
    sendNui({ action = 'close' })
    if sendCancel then
        TriggerServerEvent('driftzone_gradients:server:cancel')
    end
end

local function project(coords)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then return x, y end
    return nil, nil
end

local function getVehicleScreenBox(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local points = {
        vector3(minDim.x, minDim.y, minDim.z), vector3(minDim.x, minDim.y, maxDim.z),
        vector3(minDim.x, maxDim.y, minDim.z), vector3(minDim.x, maxDim.y, maxDim.z),
        vector3(maxDim.x, minDim.y, minDim.z), vector3(maxDim.x, minDim.y, maxDim.z),
        vector3(maxDim.x, maxDim.y, minDim.z), vector3(maxDim.x, maxDim.y, maxDim.z)
    }

    local minX, maxX, minY, maxY = 1.0, 0.0, 1.0, 0.0
    local found = false

    for i = 1, #points do
        local world = GetOffsetFromEntityInWorldCoords(vehicle, points[i].x, points[i].y, points[i].z)
        local sx, sy = project(world)
        if sx and sy then
            found = true
            if sx < minX then minX = sx end
            if sx > maxX then maxX = sx end
            if sy < minY then minY = sy end
            if sy > maxY then maxY = sy end
        end
    end

    if not found then return nil end

    local padX = tonumber(Config.VehicleScreenPaddingX or 0.055) or 0.055
    local padY = tonumber(Config.VehicleScreenPaddingY or 0.075) or 0.075
    local centerX = (minX + maxX) / 2.0
    local centerY = (minY + maxY) / 2.0

    return {
        minX = minX - padX,
        maxX = maxX + padX,
        minY = minY - padY,
        maxY = maxY + padY,
        centerX = centerX,
        centerY = centerY
    }
end

local function findVehicleFromCursor()
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local best = nil
    local bestScore = 99999.0
    local maxDist = tonumber(Config.SelectionDistance or 10.0) or 10.0
    local radius = tonumber(Config.VehicleScreenRadius or 0.085) or 0.085

    local pool = GetGamePool('CVehicle') or {}
    for i = 1, #pool do
        local veh = pool[i]
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local dist = #(pcoords - GetEntityCoords(veh))
            if dist <= maxDist then
                local box = getVehicleScreenBox(veh)
                if box then
                    local inside = cursorX >= box.minX and cursorX <= box.maxX and cursorY >= box.minY and cursorY <= box.maxY
                    local dx = cursorX - box.centerX
                    local dy = cursorY - box.centerY
                    local screenDist = math.sqrt(dx * dx + dy * dy)
                    if inside or screenDist <= radius then
                        local score = screenDist + (dist * 0.003)
                        if score < bestScore then
                            bestScore = score
                            best = veh
                        end
                    end
                end
            end
        end
    end

    return best
end

local function drawArrow(vehicle)
    if not Config.Marker or Config.Marker.enabled ~= true then return end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local coords = GetEntityCoords(vehicle)
    local _, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local z = coords.z + (maxDim.z or 1.2) + (Config.Marker.zOffset or 2.15)
    markerRot = (markerRot + 1.5) % 360.0

    DrawMarker(
        Config.Marker.type or 2,
        coords.x, coords.y, z,
        0.0, 0.0, 0.0,
        180.0, 0.0, markerRot,
        Config.Marker.size or 0.38,
        Config.Marker.size or 0.38,
        Config.Marker.size or 0.38,
        Config.Marker.r or 4,
        Config.Marker.g or 199,
        Config.Marker.b or 247,
        Config.Marker.a or 230,
        false, true, 2, false, nil, nil, false
    )
end

local function requestVehicleControl(vehicle, timeoutMs)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if NetworkHasControlOfEntity(vehicle) then return true end

    local timeout = GetGameTimer() + (timeoutMs or 900)
    NetworkRequestControlOfEntity(vehicle)

    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(vehicle)
        Wait(0)
    end

    return NetworkHasControlOfEntity(vehicle)
end

local function applyGradientColors(vehicle, gradient, applyTo)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if type(gradient) ~= 'table' then return end

    local colorId = tonumber(gradient.colorId or gradient.colourId or gradient.color or 0) or 0
    if colorId <= 0 then return end

    requestVehicleControl(vehicle, 900)
    SetVehicleModKit(vehicle, 0)

    local currentPrimary, currentSecondary = GetVehicleColours(vehicle)
    currentPrimary = tonumber(currentPrimary or 0) or 0
    currentSecondary = tonumber(currentSecondary or 0) or 0

    applyTo = tostring(applyTo or 'both'):lower()

    if applyTo == 'primary' then
        ClearVehicleCustomPrimaryColour(vehicle)
        SetVehicleColours(vehicle, colorId, currentSecondary)
    elseif applyTo == 'secondary' then
        ClearVehicleCustomSecondaryColour(vehicle)
        SetVehicleColours(vehicle, currentPrimary, colorId)
    else
        ClearVehicleCustomPrimaryColour(vehicle)
        ClearVehicleCustomSecondaryColour(vehicle)
        SetVehicleColours(vehicle, colorId, colorId)
    end

    Wait(60)
    if DoesEntityExist(vehicle) then
        if applyTo == 'primary' then
            SetVehicleColours(vehicle, colorId, currentSecondary)
        elseif applyTo == 'secondary' then
            SetVehicleColours(vehicle, currentPrimary, colorId)
        else
            SetVehicleColours(vehicle, colorId, colorId)
        end
        SetVehicleDirtLevel(vehicle, 0.0)
    end
end

RegisterNetEvent('driftzone_gradients:client:startSelector', function(data)
    currentGradient = data and data.gradient or nil
    if not currentGradient then return notify('warning', 'Gradient invalid.') end

    CreateThread(function()
        waitUiReady(1500)
        selecting = true
        selectedVehicle = nil
        cursorX, cursorY = 0.5, 0.5
        setFocus(true)
        sendNui({ action = 'selector', mainColor = (data and data.mainColor) or Config.MainColor })
        notify('info', 'Selecteaza masina pe care vrei sa aplici gradientul.', 3500)
    end)
end)

RegisterNetEvent('driftzone_gradients:client:openApplyMenu', function(data)
    selecting = false
    setFocus(true)
    sendNui({
        action = 'applyMenu',
        mainColor = Config.MainColor,
        gradient = data and data.gradient or currentGradient,
        plate = data and data.plate or ''
    })
end)

RegisterNetEvent('driftzone_gradients:client:applyGradient', function(netId, gradient, applyTo)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    local vehicle = NetToVeh(netId)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        applyGradientColors(vehicle, gradient, tostring(applyTo or 'both'))
    end
end)

RegisterNetEvent('driftzone_gradients:client:applied', function()
    stopSelector(false)
end)

RegisterNUICallback('ready', function(_, cb)
    uiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('cursor', function(data, cb)
    cursorX = tonumber(data and data.x or cursorX) or cursorX
    cursorY = tonumber(data and data.y or cursorY) or cursorY
    cb({ ok = true })
end)

RegisterNUICallback('click', function(_, cb)
    if selecting and selectedVehicle and DoesEntityExist(selectedVehicle) then
        local netId = VehToNet(selectedVehicle)
        if netId and netId > 0 then
            TriggerServerEvent('driftzone_gradients:server:vehicleSelected', netId)
        else
            notify('warning', 'Nu pot selecta aceasta masina.')
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
    stopSelector(true)
    cb({ ok = true })
end)

RegisterNUICallback('apply', function(data, cb)
    TriggerServerEvent('driftzone_gradients:server:apply', data and data.applyTo or 'both')
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if selecting then
            selectedVehicle = findVehicleFromCursor()
            if selectedVehicle then drawArrow(selectedVehicle) end
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                stopSelector(true)
            end
            Wait(0)
        else
            Wait(350)
        end
    end
end)

exports('UseGradient', function(gradientId)
    TriggerServerEvent('driftzone_gradients:server:useGradient', gradientId)
end)

RegisterNetEvent('driftzone_gradients:client:useGradient', function(gradientId)
    TriggerServerEvent('driftzone_gradients:server:useGradient', gradientId)
end)
