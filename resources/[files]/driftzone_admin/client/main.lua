local noclip = false
local noclipEntity = nil
local panelOpen = false
local teleporting = false

local AdminCommands = {
    'aduty','staff','goto','bring','kick','slap','warn','rwarn','warns','resetwarns','coords','gotocoords','tptow','nc','veh','fix','ban','tempban','unban',
    'ah','ap','freeze','unfreeze','spectate','mark','gotomark','giveveh','takeveh','transferveh','changeplate','addoutfit','cleanup','cancelcleanup','addveh','removeveh','lockveh','unlockveh','giveadm','wipe','givecash','givedzcoins','givevip','removevip','resettickets','configveh','vehs'
}

local function notify(type, message, duration)
    TriggerEvent('client:notify', type or 'info', duration or 5000, tostring(message or ''))
end

local function sendNui(data)
    SendNUIMessage(data)
end

local function setPanel(state)
    panelOpen = state == true
    SetNuiFocus(panelOpen, panelOpen)
    SetNuiFocusKeepInput(false)
end

for _, command in ipairs(AdminCommands) do
    RegisterCommand(command, function(_, args)
        TriggerServerEvent('driftzone_admin:server:run', command, args or {})
    end, false)
end

RegisterNetEvent('driftzone_admin:client:coordsPanel', function(data)
    setPanel(true)
    sendNui({ action = 'coords', data = data or {} })
end)

RegisterNetEvent('driftzone_admin:client:addCarPanel', function(data)
    setPanel(true)
    sendNui({ action = 'addVeh', data = data or {} })
end)

RegisterNetEvent('driftzone_admin:client:addCarResult', function(ok, message)
    sendNui({ action = 'addVehResult', ok = ok == true, message = tostring(message or '') })
end)

RegisterNetEvent('driftzone_admin:client:configVehPanel', function(data)
    setPanel(true)
    sendNui({ action = 'configVeh', data = data or {} })
end)

RegisterNetEvent('driftzone_admin:client:ownedVehsPanel', function(data)
    setPanel(true)
    sendNui({ action = 'ownedVehs', data = data or {} })
end)

RegisterNetEvent('driftzone_admin:client:adminPanelResult', function(ok, message)
    sendNui({ action = 'panelResult', ok = ok == true, message = tostring(message or '') })
end)

RegisterNUICallback('closePanel', function(_, cb)
    setPanel(false)
    cb({ ok = true })
end)

RegisterNUICallback('submitAddCar', function(data, cb)
    TriggerServerEvent('driftzone_admin:server:addCarSubmit', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('configVehSave', function(data, cb)
    TriggerServerEvent('driftzone_admin:server:configVehSave', data and data.id, data and data.payload or {})
    cb({ ok = true })
end)

RegisterNUICallback('configVehDelete', function(data, cb)
    TriggerServerEvent('driftzone_admin:server:configVehDelete', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('ownedVehAction', function(data, cb)
    TriggerServerEvent('driftzone_admin:server:ownedVehAction', data and data.action, data and data.uid, data and data.vehicleId, data and data.extra or {})
    cb({ ok = true })
end)

local function requestControl(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not NetworkGetEntityIsNetworked(entity) then return true end
    local timeout = GetGameTimer() + (timeoutMs or 900)
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return NetworkHasControlOfEntity(entity)
end

local function isVehicleUnoccupied(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return false end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    return not driver or driver == 0 or not DoesEntityExist(driver)
end

local function deleteVehicleLocal(vehicle)
    if not isVehicleUnoccupied(vehicle) then return false end
    requestControl(vehicle, 950)
    if not isVehicleUnoccupied(vehicle) then return false end
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, false)
    SetVehicleAsNoLongerNeeded(vehicle)
    for _ = 1, 8 do
        if not DoesEntityExist(vehicle) then return true end
        DeleteVehicle(vehicle)
        DeleteEntity(vehicle)
        Wait(0)
    end
    return not DoesEntityExist(vehicle)
end

RegisterNetEvent('driftzone_admin:client:cleanupVehicles', function(serial)
    local deleted = 0
    local vehicles = GetGamePool('CVehicle') or {}
    for _, vehicle in ipairs(vehicles) do
        if deleteVehicleLocal(vehicle) then deleted = deleted + 1 end
    end
    TriggerServerEvent('driftzone_admin:server:cleanupClientReport', serial or 0, deleted)
end)

CreateThread(function()
    while true do
        if panelOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

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
    local spawn = vector3(coords.x + -math.sin(rad) * 5.0, coords.y + math.cos(rad) * 5.0, coords.z + 0.5)
    if IsPedInAnyVehicle(ped, false) then
        local oldVeh = GetVehiclePedIsIn(ped, false)
        if oldVeh and oldVeh ~= 0 and DoesEntityExist(oldVeh) then SetEntityAsMissionEntity(oldVeh, true, true) DeleteEntity(oldVeh) Wait(150) end
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
    if netId and netId > 0 then SetNetworkIdCanMigrate(netId, true) end
    SetModelAsNoLongerNeeded(hash)
    TriggerServerEvent('driftzone_admin:server:vehSpawnResult', true, modelName, plate, netId or 0)
end)

RegisterNetEvent('driftzone_admin:client:spawnOwnedVehicle', function(data)
    data = type(data) == 'table' and data or {}
    local modelName = tostring(data.model or ''):lower():gsub('%s+', '')
    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        TriggerServerEvent('driftzone_admin:server:ownedVehSpawnResult', false, data, 0)
        return
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 9000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then
            TriggerServerEvent('driftzone_admin:server:ownedVehSpawnResult', false, data, 0)
            return
        end
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    local x = coords.x + -math.sin(rad) * 5.0
    local y = coords.y + math.cos(rad) * 5.0
    local z = coords.z + 0.65
    local veh = CreateVehicle(hash, x, y, z, heading, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        TriggerServerEvent('driftzone_admin:server:ownedVehSpawnResult', false, data, 0)
        return
    end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, tostring(data.plate or 'DRIFT'):sub(1, 8))
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    local netId = VehToNet(veh)
    local netTimeout = GetGameTimer() + 5000
    while (not netId or netId == 0 or not NetworkDoesNetworkIdExist(netId)) and GetGameTimer() < netTimeout do
        Wait(50)
        netId = VehToNet(veh)
    end
    if netId and netId > 0 then
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
    end
    Wait(350)

    -- Integrare cu driftzone_vehicleconfig: masina spawnata din /vehs primeste SQL ID, owner, motor oprit si lock default.
    if GetResourceState('driftzone_vehicleconfig') == 'started' then
        TriggerEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', veh, tonumber(data.vehicleId or data.id or 0) or 0, tonumber(data.uid or data.owner_id or 0) or 0)
    end

    TriggerServerEvent('driftzone_admin:server:ownedVehSpawnResult', true, data, netId or 0)
end)

RegisterNetEvent('driftzone_admin:client:fixVehicle', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then notify('warning', 'Nu esti intr-o masina.') return end
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
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) Wait(350) end
    ApplyForceToEntity(ped, 1, 0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
end)

RegisterNetEvent('driftzone_admin:client:safeTeleport', function(coords)
    if teleporting then return end
    teleporting = true
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, coords.h or 0.0)
    Wait(300)
    teleporting = false
end)

RegisterNetEvent('driftzone_admin:client:tptow', function(config)
    local ped = PlayerPedId()
    local waypoint = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypoint) then TriggerServerEvent('driftzone_admin:server:tptowResult', false, nil) return end
    local coords = GetBlipInfoIdCoord(waypoint)
    SetEntityCoords(ped, coords.x, coords.y, 1000.0, false, false, false, false)
    Wait(600)
    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, 1000.0, false)
    SetEntityCoords(ped, coords.x, coords.y, found and z + 1.0 or 50.0, false, false, false, false)
    TriggerServerEvent('driftzone_admin:server:tptowResult', true, { x = coords.x, y = coords.y, z = found and z or 50.0 })
end)

RegisterNetEvent('driftzone_admin:client:noclip', function(state)
    noclip = state == true
    local ped = PlayerPedId()
    noclipEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    SetEntityVisible(noclipEntity, not noclip, false)
    SetEntityInvincible(noclipEntity, noclip)
    SetEntityCollision(noclipEntity, not noclip, not noclip)
    FreezeEntityPosition(noclipEntity, noclip)
end)

CreateThread(function()
    while true do
        if noclip and noclipEntity and DoesEntityExist(noclipEntity) then
            local speed = IsControlPressed(0, 21) and 3.5 or 1.2
            local coords = GetEntityCoords(noclipEntity)
            local camRot = GetGameplayCamRot(2)
            local heading = math.rad(camRot.z)
            local pitch = math.rad(camRot.x)
            local forward = vector3(-math.sin(heading) * math.cos(pitch), math.cos(heading) * math.cos(pitch), math.sin(pitch))
            local right = vector3(math.cos(heading), math.sin(heading), 0.0)
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + forward end
            if IsControlPressed(0, 33) then move = move - forward end
            if IsControlPressed(0, 34) then move = move - right end
            if IsControlPressed(0, 35) then move = move + right end
            if IsControlPressed(0, 22) then move = move + vector3(0.0,0.0,1.0) end
            if IsControlPressed(0, 36) then move = move - vector3(0.0,0.0,1.0) end
            SetEntityCoordsNoOffset(noclipEntity, coords.x + move.x * speed, coords.y + move.y * speed, coords.z + move.z * speed, true, true, true)
            SetEntityHeading(noclipEntity, camRot.z)
            Wait(0)
        else
            Wait(350)
        end
    end
end)


-- =============================
-- DriftZone Admin V3 additions
-- =============================
local frozen = false
local savedMark = nil
local spectating = false
local spectateTarget = nil
local spectateReturn = nil
local spectateWasInVehicle = false

local function setEntityFrozenState(state)
    frozen = state == true
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, frozen)
    SetEntityInvincible(ped, frozen)
    if frozen then
        ClearPedTasksImmediately(ped)
    end
end

RegisterNetEvent('driftzone_admin:client:setFrozen', function(state)
    setEntityFrozenState(state == true)
    notify(state and 'warning' or 'info', state and 'Ai primit freeze.' or 'Ai primit unfreeze.')
end)

CreateThread(function()
    while true do
        if frozen then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('driftzone_admin:client:mark', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    savedMark = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
    notify('info', ('Mark salvat: %.2f %.2f %.2f'):format(c.x, c.y, c.z))
end)

RegisterNetEvent('driftzone_admin:client:gotoMark', function()
    if not savedMark then
        notify('warning', 'Nu ai niciun mark salvat. Foloseste /mark.')
        return
    end
    local ped = PlayerPedId()
    local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    SetEntityCoordsNoOffset(ent, savedMark.x + 0.0, savedMark.y + 0.0, savedMark.z + 0.0, false, false, false)
    SetEntityHeading(ent, savedMark.h or 0.0)
    notify('info', 'Te-ai teleportat la mark.')
end)

local function stopSpectate()
    if not spectating then return end
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    SetPoliceIgnorePlayer(PlayerId(), false)
    if spectateReturn then
        local ent = ped
        if spectateWasInVehicle and IsPedInAnyVehicle(ped, false) then ent = GetVehiclePedIsIn(ped, false) end
        SetEntityCoordsNoOffset(ent, spectateReturn.x, spectateReturn.y, spectateReturn.z, false, false, false)
        SetEntityHeading(ent, spectateReturn.h or 0.0)
    end
    spectating = false
    spectateTarget = nil
    spectateReturn = nil
    spectateWasInVehicle = false
    notify('info', 'Spectate oprit.')
end

RegisterNetEvent('driftzone_admin:client:stopSpectate', function()
    stopSpectate()
end)

RegisterNetEvent('driftzone_admin:client:startSpectate', function(targetServerId)
    targetServerId = tonumber(targetServerId or 0) or 0
    if targetServerId <= 0 then return end
    if spectating then stopSpectate() Wait(150) end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    spectateReturn = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
    spectateWasInVehicle = IsPedInAnyVehicle(ped, false)
    spectateTarget = targetServerId
    spectating = true
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEveryoneIgnorePlayer(PlayerId(), true)
    SetPoliceIgnorePlayer(PlayerId(), true)
    notify('info', 'Spectate pornit. Foloseste iar /spectate ca sa iesi.')
end)

CreateThread(function()
    while true do
        if spectating and spectateTarget then
            local player = GetPlayerFromServerId(spectateTarget)
            if player == -1 then
                stopSpectate()
            else
                local targetPed = GetPlayerPed(player)
                local ped = PlayerPedId()
                if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
                    local tc = GetEntityCoords(targetPed)
                    SetEntityCoordsNoOffset(ped, tc.x, tc.y, tc.z - 2.0, false, false, false)
                    SetEntityVisible(ped, false, false)
                    SetEntityCollision(ped, false, false)
                    FreezeEntityPosition(ped, true)
                    NetworkSetInSpectatorMode(true, targetPed)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('driftzone_admin:client:openAdminHelp', function(payload)
    setPanel(true)
    sendNui({ action = 'adminHelp', data = payload or {} })
end)

RegisterNetEvent('driftzone_admin:client:openAdminPanel', function(payload)
    setPanel(true)
    sendNui({ action = 'adminPanel', data = payload or {} })
end)

RegisterNUICallback('runAdminCommand', function(data, cb)
    TriggerServerEvent('driftzone_admin:server:runFromPanel', data and data.command, data and data.args or '')
    cb({ ok = true })
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if spectating then stopSpectate() end
    if frozen then FreezeEntityPosition(PlayerPedId(), false) end
end)
