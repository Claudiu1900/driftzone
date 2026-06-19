local RESOURCE = GetCurrentResourceName()

local State = {
    profile = nil,
    shift = nil
}

local uiOpen = false
local repairing = false
local jobPed = 0
local staticBlip = 0
local activeBlip = 0
local jobVehicle = 0
local jobVehicleNetId = 0
local vehicleLostReported = false
local savedOutfit = nil
local currentRepair = nil

local function debugPrint(message)
    if Config.Debug then
        print(('^5[%s:client] %s^7'):format(RESOURCE, tostring(message)))
    end
end

local function notify(kind, message, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', kind or 'info', duration or 4000, tostring(message or ''))
end

local function helpText(message)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function requestControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not NetworkGetEntityIsNetworked(entity) then return true end
    if NetworkHasControlOfEntity(entity) then return true end

    local expires = GetGameTimer() + (timeout or 1000)
    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < expires do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end

    return NetworkHasControlOfEntity(entity)
end

local function loadModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end

    RequestModel(hash)
    local expires = GetGameTimer() + (timeout or 8000)
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(25) end

    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function currentTask()
    if not State.shift or not State.shift.active then return nil end
    local index = tonumber(State.shift.activeIndex) or 1
    return State.shift.tasks and State.shift.tasks[index] or nil
end

local function clearActiveBlip()
    if activeBlip ~= 0 and DoesBlipExist(activeBlip) then RemoveBlip(activeBlip) end
    activeBlip = 0
end

local function setRoute(coords, label, sprite, colour, silent)
    clearActiveBlip()

    activeBlip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(activeBlip, sprite or 354)
    SetBlipColour(activeBlip, colour or 5)
    SetBlipScale(activeBlip, 0.82)
    SetBlipRoute(activeBlip, true)
    SetBlipRouteColour(activeBlip, colour or 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Electrician')
    EndTextCommandSetBlipName(activeBlip)

    if not silent then notify('info', Config.Text.routeSet) end
end

local function syncRoute(silent)
    if not State.shift then
        clearActiveBlip()
        return
    end

    if not State.shift.hasTools then
        if State.shift.allComplete then
            setRoute(Config.JobCenter.coords, 'Intoarcere la dispecerat', 354, 5, silent)
        else
            setRoute(Config.ToolDepot.coords, 'Depozit unelte', 566, 3, silent)
        end
        return
    end

    if State.shift.allComplete then
        setRoute(Config.ToolDepot.coords, 'Returneaza trusa', 566, 3, silent)
        return
    end

    local task = currentTask()
    if task then
        setRoute(task.coords, task.label, 354, task.type == 'panel_high' and 1 or 5, silent)
    else
        clearActiveBlip()
    end
end

local function drawMarkerAt(coords, colour, scale)
    colour = colour or { 255, 196, 0, 150 }
    scale = scale or 0.6

    DrawMarker(
        1,
        coords.x + 0.0, coords.y + 0.0, coords.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale, scale, 0.25,
        colour[1] or 255, colour[2] or 196, colour[3] or 0, colour[4] or 150,
        false, false, 2, false, nil, nil, false
    )
end

local function saveOutfit()
    if savedOutfit then return end

    local ped = PlayerPedId()
    local outfit = {
        model = GetEntityModel(ped),
        components = {},
        props = {}
    }

    for component = 0, 11 do
        outfit.components[component] = {
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
            palette = GetPedPaletteVariation(ped, component)
        }
    end

    for prop = 0, 7 do
        outfit.props[prop] = {
            drawable = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop)
        }
    end

    savedOutfit = outfit
end

local function applyUniform()
    if Config.Uniform.enabled ~= true then return end

    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local uniform = nil

    if model == joaat('mp_m_freemode_01') then
        uniform = Config.Uniform.male
    elseif model == joaat('mp_f_freemode_01') then
        uniform = Config.Uniform.female
    else
        debugPrint('Uniforma nu a fost aplicata: ped-ul nu este freemode.')
        return
    end

    saveOutfit()

    for component, data in pairs(uniform.components or {}) do
        SetPedComponentVariation(ped, tonumber(component), tonumber(data.drawable) or 0, tonumber(data.texture) or 0, 0)
    end

    for prop, data in pairs(uniform.props or {}) do
        prop = tonumber(prop)
        if tonumber(data.drawable) and tonumber(data.drawable) >= 0 then
            SetPedPropIndex(ped, prop, tonumber(data.drawable), tonumber(data.texture) or 0, true)
        else
            ClearPedProp(ped, prop)
        end
    end
end

local function restoreOutfit()
    if not savedOutfit then return end

    local ped = PlayerPedId()
    if GetEntityModel(ped) ~= savedOutfit.model then
        savedOutfit = nil
        return
    end

    for component, data in pairs(savedOutfit.components or {}) do
        SetPedComponentVariation(ped, tonumber(component), data.drawable, data.texture, data.palette or 0)
    end

    for prop, data in pairs(savedOutfit.props or {}) do
        prop = tonumber(prop)
        if data.drawable and data.drawable >= 0 then
            SetPedPropIndex(ped, prop, data.drawable, data.texture or 0, true)
        else
            ClearPedProp(ped, prop)
        end
    end

    savedOutfit = nil
end

local function cleanupJobVehicle()
    local vehicle = jobVehicle
    local oldNetId = jobVehicleNetId

    jobVehicle = 0
    jobVehicleNetId = 0
    vehicleLostReported = false

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        requestControl(vehicle, 1200)
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    elseif oldNetId > 0 then
        local entity = NetToVeh(oldNetId)
        if entity ~= 0 and DoesEntityExist(entity) then
            requestControl(entity, 800)
            DeleteVehicle(entity)
        end
    end
end

local function findVehicleSpawn()
    for _, spawn in ipairs(Config.Vehicle.spawns or {}) do
        if not IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.0) then
            return spawn
        end
    end
    return nil
end

local function spawnJobVehicle(token)
    if Config.Vehicle.enabled ~= true then return end
    cleanupJobVehicle()

    local spawn = findVehicleSpawn()
    if not spawn then
        notify('warning', Config.Text.vehicleBlocked, 5000)
        return
    end

    local model = loadModel(Config.Vehicle.model, 8000)
    if not model then
        notify('error', 'Modelul dubei de serviciu nu a putut fi incarcat.', 5000)
        return
    end

    local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    SetModelAsNoLongerNeeded(model)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('error', 'Duba de serviciu nu a putut fi creata.', 5000)
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleColours(vehicle, Config.Vehicle.primaryColour or 111, Config.Vehicle.secondaryColour or 111)
    SetVehicleDirtLevel(vehicle, Config.Vehicle.dirtLevel or 0.0)
    SetVehicleFuelLevel(vehicle, Config.Vehicle.fuelLevel or 100.0)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')

    local plate = ('%s%03d'):format(tostring(Config.Vehicle.platePrefix or 'DZEL'):sub(1, 4), math.random(0, 999))
    SetVehicleNumberPlateText(vehicle, plate)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    Entity(vehicle).state:set('driftzone_job_vehicle', 'electrician', true)
    Entity(vehicle).state:set('driftzone_electrician_owner', GetPlayerServerId(PlayerId()), true)

    jobVehicle = vehicle
    jobVehicleNetId = netId
    vehicleLostReported = false

    TriggerServerEvent('driftzone_electrician:server:registerVehicle', token, netId)

    if Config.Vehicle.warpIntoVehicle == true then
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    end

    notify('success', Config.Text.vehicleSpawned)
end

local function openUi(view)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        view = view or 'company',
        state = State,
        config = {
            cleanBonus = Config.Shift.cleanBonus,
            levels = Config.Levels,
            vehicleEnabled = Config.Vehicle.enabled == true
        }
    })
end

local function closeUi(force)
    if repairing and not force then return end

    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = force and 'forceClose' or 'close' })
end

local function stopRepairUi(cancelServer)
    if cancelServer and currentRepair then
        TriggerServerEvent('driftzone_electrician:server:cancelRepair', currentRepair.id, currentRepair.nonce)
    end

    currentRepair = nil
    repairing = false
    ClearPedTasksImmediately(PlayerPedId())
    FreezeEntityPosition(PlayerPedId(), false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'forceClose' })
end

local function cleanupShift()
    stopRepairUi()
    cleanupJobVehicle()
    restoreOutfit()
    clearActiveBlip()
end

local function spawnJobPed()
    if jobPed ~= 0 and DoesEntityExist(jobPed) then return end

    local model = loadModel(Config.JobCenter.ped, 8000)
    if not model then
        print(('^1[%s] NPC model invalid: %s^7'):format(RESOURCE, tostring(Config.JobCenter.ped)))
        return
    end

    local c = Config.JobCenter.coords
    jobPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(model)

    SetEntityInvincible(jobPed, true)
    FreezeEntityPosition(jobPed, true)
    SetBlockingOfNonTemporaryEvents(jobPed, true)
    SetPedCanRagdoll(jobPed, false)
    TaskStartScenarioInPlace(jobPed, Config.JobCenter.scenario, 0, true)
end

local function createStaticBlip()
    if Config.JobCenter.blip.enabled ~= true or staticBlip ~= 0 then return end

    local c = Config.JobCenter.coords
    staticBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(staticBlip, Config.JobCenter.blip.sprite)
    SetBlipColour(staticBlip, Config.JobCenter.blip.colour)
    SetBlipScale(staticBlip, Config.JobCenter.blip.scale)
    SetBlipAsShortRange(staticBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.JobCenter.blip.label)
    EndTextCommandSetBlipName(staticBlip)
end

local function isBadWeather()
    local weather = GetPrevWeatherTypeHashName()
    return weather == joaat('RAIN')
        or weather == joaat('THUNDER')
        or weather == joaat('CLEARING')
        or weather == joaat('SNOW')
        or weather == joaat('BLIZZARD')
        or weather == joaat('XMAS')
end

RegisterNetEvent('driftzone_electrician:client:notify', function(kind, message, duration)
    notify(kind, message, duration)
end)

RegisterNetEvent('driftzone_electrician:client:requestState', function()
    TriggerServerEvent('driftzone_electrician:server:getState')
end)

RegisterNetEvent('driftzone_electrician:client:state', function(newState)
    newState = type(newState) == 'table' and newState or {}
    local hadShift = State.shift ~= nil

    State.profile = newState.profile
    State.shift = newState.shift

    if State.shift and not hadShift then
        applyUniform()
    elseif not State.shift and hadShift then
        cleanupShift()
    end

    SendNUIMessage({ action = 'sync', state = State })
    syncRoute(true)

    if newState.openView then
        openUi(newState.openView)
    end
end)

RegisterNetEvent('driftzone_electrician:client:startShiftEffects', function(token)
    applyUniform()
    spawnJobVehicle(token)
end)

RegisterNetEvent('driftzone_electrician:client:spawnJobVehicle', function(token)
    spawnJobVehicle(token)
end)

RegisterNetEvent('driftzone_electrician:client:cleanupVehicle', function()
    cleanupJobVehicle()
end)

RegisterNetEvent('driftzone_electrician:client:cleanupShift', function()
    cleanupShift()
end)

RegisterNetEvent('driftzone_electrician:client:repairAuthorized', function(task)
    if repairing or type(task) ~= 'table' then return end

    repairing = true
    uiOpen = false
    currentRepair = {
        id = task.id,
        nonce = task.nonce,
        expiresAt = GetGameTimer() + ((tonumber(task.duration) or 12) + 30) * 1000
    }

    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, task.scenario or 'WORLD_HUMAN_WELDING', 0, true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'repair', task = task })
end)

RegisterNetEvent('driftzone_electrician:client:shock', function()
    local ped = PlayerPedId()
    SetPedToRagdoll(ped, 1800, 1800, 0, false, false, false)
    ApplyDamageToPed(ped, 8, false)
end)

RegisterNUICallback('close', function(_, cb)
    closeUi(false)
    cb({ ok = true })
end)

RegisterNUICallback('action', function(data, cb)
    local action = data and data.action

    if action == 'hire' then
        TriggerServerEvent('driftzone_electrician:server:hire')
    elseif action == 'resign' then
        TriggerServerEvent('driftzone_electrician:server:resign')
    elseif action == 'startShift' then
        TriggerServerEvent('driftzone_electrician:server:startShift', isBadWeather())
    elseif action == 'endShift' then
        TriggerServerEvent('driftzone_electrician:server:endShift')
    elseif action == 'takeTools' then
        TriggerServerEvent('driftzone_electrician:server:takeTools')
    elseif action == 'returnTools' then
        TriggerServerEvent('driftzone_electrician:server:returnTools')
    elseif action == 'routeTask' then
        syncRoute(false)
    elseif action == 'requestVehicle' then
        TriggerServerEvent('driftzone_electrician:server:requestVehicle')
    end

    cb({ ok = true })
end)

RegisterNUICallback('repairFinished', function(data, cb)
    if not repairing then
        cb({ ok = false })
        return
    end

    currentRepair = nil
    repairing = false
    ClearPedTasksImmediately(PlayerPedId())
    FreezeEntityPosition(PlayerPedId(), false)
    SetNuiFocus(false, false)
    uiOpen = false

    TriggerServerEvent(
        'driftzone_electrician:server:completeRepair',
        data and data.taskId,
        data and data.nonce,
        data and data.success == true,
        tonumber(data and data.mistakes) or 0
    )

    cb({ ok = true })
end)

RegisterCommand(Config.Command, function()
    if not State.profile then
        TriggerServerEvent('driftzone_electrician:server:getState', 'company')
        return
    end

    openUi(State.shift and 'tablet' or 'company')
end, false)

RegisterKeyMapping(Config.Command, 'Deschide tableta electricianului', 'keyboard', Config.TabletKey)

CreateThread(function()
    spawnJobPed()
    createStaticBlip()
    TriggerServerEvent('driftzone_electrician:server:getState')

    CreateThread(function()
        for _ = 1, 6 do
            Wait(2000)
            if State.profile then return end
            TriggerServerEvent('driftzone_electrician:server:getState')
        end
    end)

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local jobCoords = Config.JobCenter.coords
        local depotCoords = Config.ToolDepot.coords
        local jobDistance = #(coords - vector3(jobCoords.x, jobCoords.y, jobCoords.z))

        if jobDistance < Config.DrawDistance.JobCenter then
            sleep = jobDistance < 12.0 and 0 or 250
            drawMarkerAt(jobCoords, { 255, 196, 0, 135 }, 0.68)

            if jobDistance < 2.0 and not repairing then
                helpText(Config.Text.interactNpc)
                if IsControlJustReleased(0, Config.InteractKey) then
                    if State.profile then
                        openUi('company')
                    else
                        TriggerServerEvent('driftzone_electrician:server:getState', 'company')
                    end
                end
            end
        end

        if State.shift then
            local depotDistance = #(coords - depotCoords)
            if depotDistance < Config.DrawDistance.Depot then
                sleep = depotDistance < 12.0 and 0 or math.min(sleep, 250)
                drawMarkerAt(depotCoords, { 0, 174, 255, 145 }, 0.78)

                if depotDistance < 1.8 and not repairing then
                    helpText(Config.Text.interactDepot)
                    if IsControlJustReleased(0, Config.InteractKey) then
                        TriggerServerEvent(State.shift.hasTools and 'driftzone_electrician:server:returnTools' or 'driftzone_electrician:server:takeTools')
                    end
                end
            end

            local task = currentTask()
            if task and not task.completed then
                local taskCoords = vector3(task.coords.x, task.coords.y, task.coords.z)
                local taskDistance = #(coords - taskCoords)

                if taskDistance < Config.DrawDistance.Intervention then
                    sleep = taskDistance < 15.0 and 0 or math.min(sleep, 250)
                    local typeData = Config.TaskTypes[task.type]
                    drawMarkerAt(task.coords, typeData and typeData.markerColour or nil, 0.84)

                    if taskDistance < 2.0 and not repairing then
                        helpText(State.shift.hasTools and Config.Text.interactRepair or Config.Text.noTools)
                        if IsControlJustReleased(0, Config.InteractKey) then
                            if State.shift.hasTools then
                                TriggerServerEvent('driftzone_electrician:server:beginRepair', task.id)
                            else
                                notify('warning', Config.Text.noTools)
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(2500)

        if repairing and IsEntityDead(PlayerPedId()) then
            stopRepairUi(true)
        elseif repairing and currentRepair and GetGameTimer() > currentRepair.expiresAt then
            stopRepairUi(true)
            notify('error', Config.Text.repairExpired, 5000)
        end

        if State.shift and jobVehicleNetId > 0 and not vehicleLostReported then
            if jobVehicle == 0 or not DoesEntityExist(jobVehicle) or IsEntityDead(jobVehicle) then
                vehicleLostReported = true
                local oldNetId = jobVehicleNetId
                cleanupJobVehicle()
                TriggerServerEvent('driftzone_electrician:server:vehicleLost', oldNetId)
                notify('warning', 'Duba de serviciu a fost pierduta. O poti recupera de la dispecerat.', 5000)
            end
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= RESOURCE then return end
    TriggerServerEvent('driftzone_electrician:server:getState')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end

    if jobPed ~= 0 and DoesEntityExist(jobPed) then DeleteEntity(jobPed) end
    if staticBlip ~= 0 and DoesBlipExist(staticBlip) then RemoveBlip(staticBlip) end

    cleanupShift()
    SetNuiFocus(false, false)
end)
