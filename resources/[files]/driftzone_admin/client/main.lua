local noclip = false
local noclipEntity = nil
local coordsPanelOpen = false
local teleporting = false

local AdminCommands = {
    'aduty',
    'staff',
    'goto',
    'bring',
    'kick',
    'slap',
    'warn',
    'rwarn',
    'warns',
    'resetwarns',
    'coords',
    'gotocoords',
    'tptow',
    'nc',
    'veh',
    'fix',
    'ban',
    'tempban',
    'unban',
    'givecar',
    'takecar',
    'transfercar',
    'changeplate',
    'addoutfit'
}

local function notify(type, message, duration)
    TriggerEvent('client:notify', type or 'info', duration or 5000, tostring(message or ''))
end

local function sendNui(data)
    SendNUIMessage(data)
end

for _, command in ipairs(AdminCommands) do
    RegisterCommand(command, function(_, args)
        TriggerServerEvent('driftzone_admin:server:run', command, args or {})
    end, false)
end

RegisterNetEvent('driftzone_admin:client:coordsPanel', function(data)
    coordsPanelOpen = true

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    sendNui({
        action = 'coords',
        data = data
    })
end)

RegisterNUICallback('closeCoords', function(_, cb)
    coordsPanelOpen = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if coordsPanelOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function getForwardCoords(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)

    return vector3(
        coords.x + -math.sin(rad) * distance,
        coords.y + math.cos(rad) * distance,
        coords.z
    )
end

RegisterNetEvent('driftzone_admin:client:spawnVehicle', function(model)
    local modelName = tostring(model or ''):lower()
    local hash = joaat(modelName)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        TriggerServerEvent('driftzone_admin:server:vehSpawnResult', false, modelName, 'ADMIN', 0)
        return
    end

    RequestModel(hash)

    local timeout = GetGameTimer() + 8000

    while not HasModelLoaded(hash) do
        Wait(0)

        if GetGameTimer() > timeout then
            TriggerServerEvent('driftzone_admin:server:vehSpawnResult', false, modelName, 'ADMIN', 0)
            return
        end
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)

    local spawn = vector3(
        coords.x + -math.sin(rad) * 5.0,
        coords.y + math.cos(rad) * 5.0,
        coords.z + 0.5
    )

    if IsPedInAnyVehicle(ped, false) then
        local oldVeh = GetVehiclePedIsIn(ped, false)

        if oldVeh and oldVeh ~= 0 and DoesEntityExist(oldVeh) then
            SetEntityAsMissionEntity(oldVeh, true, true)
            DeleteEntity(oldVeh)
            Wait(150)
        end
    end

    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, heading, true, true)

    if not veh or veh == 0 or not DoesEntityExist(veh) then
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent('driftzone_admin:server:vehSpawnResult', false, modelName, 'ADMIN', 0)
        return
    end

    local plate = ('ADM%05d'):format(math.random(0, 99999)):sub(1, 8)

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleOnGroundProperly(veh)

    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)

    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetPedIntoVehicle(ped, veh, -1)

    local netId = VehToNet(veh)

    local netTimeout = GetGameTimer() + 5000

    while (not netId or netId == 0) and GetGameTimer() < netTimeout do
        Wait(50)
        netId = VehToNet(veh)
    end

    if netId and netId > 0 then
        SetNetworkIdCanMigrate(netId, true)
    end

    SetModelAsNoLongerNeeded(hash)

    TriggerServerEvent('driftzone_admin:server:vehSpawnResult', true, modelName, plate, netId or 0)
end)

RegisterNetEvent('driftzone_admin:client:fixVehicle', function()
    local ped = PlayerPedId()

    if not IsPedInAnyVehicle(ped, false) then
        notify('warning', 'Nu esti intr-o masina.')
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)

    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleEngineOn(veh, true, true, false)

    notify('info', 'Masina a fost reparata.')
end)

RegisterNetEvent('driftzone_admin:client:slap', function()
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        Wait(450)
    end

    local coords = GetEntityCoords(ped)

    SetEntityCoords(ped, coords.x, coords.y, coords.z + 6.0, false, false, false, false)
end)

local function getNoclipTarget()
    return PlayerPedId()
end

local function forceExitVehicleBeforeNoclip()
    local ped = PlayerPedId()

    if not IsPedInAnyVehicle(ped, false) then
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local coords = GetEntityCoords(vehicle)
        local heading = GetEntityHeading(vehicle)

        TaskLeaveVehicle(ped, vehicle, 16)

        local timeout = GetGameTimer() + 900

        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < timeout do
            Wait(0)
        end

        if IsPedInAnyVehicle(ped, false) then
            ClearPedTasksImmediately(ped)
        end

        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 0.85, false, false, false)
        SetEntityHeading(ped, heading)
        SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
        SetVehicleForwardSpeed(vehicle, 0.0)
    end
end

local function setEntityNoclipState(entity, state)
    if not entity or not DoesEntityExist(entity) then return end

    FreezeEntityPosition(entity, state)
    SetEntityCollision(entity, not state, not state)
    SetEntityInvincible(entity, state)

    if state then
        SetEntityAlpha(entity, 120, false)
    else
        ResetEntityAlpha(entity)
    end
end

RegisterNetEvent('driftzone_admin:client:noclip', function(state)
    local enable = state == true

    if enable then
        forceExitVehicleBeforeNoclip()
    end

    noclip = enable
    noclipEntity = PlayerPedId()

    setEntityNoclipState(PlayerPedId(), noclip)

    if not noclip then
        setEntityNoclipState(PlayerPedId(), false)
        noclipEntity = nil
    end
end)

local function rotToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))

    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

CreateThread(function()
    while true do
        if noclip then
            local ped = PlayerPedId()
            local entity = noclipEntity or getNoclipTarget()

            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 36, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 38, true)

            local speed = 1.25

            if IsDisabledControlPressed(0, 21) then speed = 4.5 end
            if IsDisabledControlPressed(0, 36) then speed = 0.35 end

            local rot = GetGameplayCamRot(2)
            local forward = rotToDirection(rot)
            local right = vector3(forward.y, -forward.x, 0.0)
            local move = vector3(0.0, 0.0, 0.0)

            if IsDisabledControlPressed(0, 32) then move = move + forward end
            if IsDisabledControlPressed(0, 33) then move = move - forward end
            if IsDisabledControlPressed(0, 35) then move = move + right end
            if IsDisabledControlPressed(0, 34) then move = move - right end
            if IsDisabledControlPressed(0, 22) or IsDisabledControlPressed(0, 38) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, 44) then move = move - vector3(0.0, 0.0, 1.0) end

            if #(move) > 0.0 then
                move = move / #(move)
            end

            local coords = GetEntityCoords(entity)
            local nextPos = coords + move * speed

            SetEntityCoordsNoOffset(entity, nextPos.x, nextPos.y, nextPos.z, true, true, true)
            SetEntityHeading(entity, rot.z)

            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function requestCollision(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStartSphere(x, y, z, 70.0, 0)
end

local function stopCollisionLoad()
    if IsNewLoadSceneActive() then
        NewLoadSceneStop()
    end
end

local function getGroundZReliable(x, y, preferredZ)
    local heights = {
        preferredZ or 1200.0,
        1200.0,
        1000.0,
        850.0,
        700.0,
        550.0,
        400.0,
        300.0,
        220.0,
        160.0,
        120.0,
        80.0,
        50.0,
        30.0,
        5.0
    }

    for _ = 1, 6 do
        for _, height in ipairs(heights) do
            requestCollision(x, y, height)

            Wait(60)

            local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)

            if found and groundZ and groundZ > -100.0 then
                stopCollisionLoad()
                return groundZ + 1.7
            end
        end

        Wait(130)
    end

    stopCollisionLoad()
    return nil
end

local function getWaypointCoords()
    local blip = GetFirstBlipInfoId(8)

    if not DoesBlipExist(blip) then
        return nil
    end

    local coords = GetBlipInfoIdCoord(blip)

    return {
        x = coords.x,
        y = coords.y
    }
end

local function getTeleportEntity()
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false), true
    end

    return ped, false
end

local function setSafeEntityCoords(entity, x, y, z)
    SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
    RequestCollisionAtCoord(x, y, z)
end

local function verifyPosition(entity, target, distanceLimit)
    local coords = GetEntityCoords(entity)
    local distance = #(coords - vector3(target.x, target.y, target.z))

    return distance <= (distanceLimit or 12.0)
end

RegisterNetEvent('driftzone_admin:client:safeTeleport', function(target)
    local entity, inVehicle = getTeleportEntity()
    local ped = PlayerPedId()

    if not entity or not DoesEntityExist(entity) then return end

    local x = tonumber(target.x)
    local y = tonumber(target.y)
    local z = tonumber(target.z)

    if not x or not y or not z then return end

    DoScreenFadeOut(150)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    FreezeEntityPosition(entity, true)

    local finalZ = z + 1.0

    for _ = 1, 4 do
        requestCollision(x, y, z + 80.0)

        setSafeEntityCoords(entity, x, y, z + 45.0)

        Wait(450)

        for _ = 1, 18 do
            RequestCollisionAtCoord(x, y, z)
            Wait(45)
        end

        setSafeEntityCoords(entity, x, y, finalZ)

        Wait(350)

        if verifyPosition(entity, { x = x, y = y, z = finalZ }, 12.0) then
            break
        end
    end

    FreezeEntityPosition(entity, false)

    if inVehicle then
        SetPedIntoVehicle(ped, entity, -1)
        SetVehicleOnGroundProperly(entity)
    end

    stopCollisionLoad()

    DoScreenFadeIn(250)
end)

RegisterNetEvent('driftzone_admin:client:tptow', function(settings)
    if teleporting then return end

    local waypoint = getWaypointCoords()

    if not waypoint then
        notify('warning', 'Nu ai waypoint setat.')
        TriggerServerEvent('driftzone_admin:server:tptowResult', false, nil)
        return
    end

    teleporting = true

    local entity, inVehicle = getTeleportEntity()
    local ped = PlayerPedId()

    if not entity or not DoesEntityExist(entity) then
        teleporting = false
        TriggerServerEvent('driftzone_admin:server:tptowResult', false, nil)
        return
    end

    DoScreenFadeOut(250)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    FreezeEntityPosition(entity, true)

    local safeZ = getGroundZReliable(waypoint.x, waypoint.y, settings and settings.safeHeight or 950.0)

    if not safeZ then
        safeZ = 75.0
    end

    local target = {
        x = waypoint.x,
        y = waypoint.y,
        z = safeZ
    }

    local success = false
    local maxAttempts = settings and settings.maxAttempts or 5

    for attempt = 1, maxAttempts do
        requestCollision(target.x, target.y, target.z + 90.0)

        setSafeEntityCoords(entity, target.x, target.y, target.z + 55.0)

        Wait(650)

        for _ = 1, 22 do
            RequestCollisionAtCoord(target.x, target.y, target.z)
            Wait(40)
        end

        setSafeEntityCoords(entity, target.x, target.y, target.z)

        Wait(450)

        if verifyPosition(entity, target, settings and settings.verifyDistance or 12.0) then
            success = true
            break
        end

        safeZ = getGroundZReliable(waypoint.x, waypoint.y, 1200.0) or safeZ
        target.z = safeZ + attempt
    end

    FreezeEntityPosition(entity, false)

    if inVehicle then
        SetPedIntoVehicle(ped, entity, -1)
        SetVehicleOnGroundProperly(entity)
    end

    ClearPedTasksImmediately(ped)

    stopCollisionLoad()

    DoScreenFadeIn(350)

    teleporting = false

    TriggerServerEvent('driftzone_admin:server:tptowResult', success, target)
end)