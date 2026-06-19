local state = {
    npc = nil,
    bossBlip = nil,
    menuOpen = false,
    menuActionPending = false,
    menuActionToken = 0,
    onDuty = false,
    hasTools = false,
    serviceVehicle = nil,
    serviceBlip = nil,
    taskBlip = nil,
    taskVehicle = nil,
    currentTask = nil,
    minigameOpen = false,
    savedOutfit = nil
}

local function debugPrint(message)
    if Config.Debug then
        print(('[driftzone_mechanic] %s'):format(message))
    end
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(20)
    end
    return HasModelLoaded(hash) and hash or nil
end

local function notify(kind, title, message, duration)
    if GetResourceState(Config.NotificationResource) == 'started' then
        TriggerEvent(Config.NotificationEvent, {
            type = kind,
            title = title,
            message = message,
            duration = duration or 5000
        })
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('~b~%s~s~\n%s'):format(title, message))
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterNetEvent('driftzone_mechanic:client:notify', notify)

local function drawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    SetTextScale(0.33, 0.33)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function createRouteBlip(coords, sprite, colour, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.85)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, colour)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function removeBlipSafe(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

local function saveOutfit()
    local ped = PlayerPedId()
    local data = { components = {}, props = {} }
    for component = 0, 11 do
        data.components[component] = {
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
            palette = GetPedPaletteVariation(ped, component)
        }
    end
    for prop = 0, 7 do
        data.props[prop] = {
            drawable = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop)
        }
    end
    state.savedOutfit = data
end

local function applyUniform()
    local ped = PlayerPedId()
    if not state.savedOutfit then saveOutfit() end
    local uniform = IsPedModel(ped, joaat('mp_f_freemode_01')) and Config.Uniforms.female or Config.Uniforms.male
    for component, variation in pairs(uniform) do
        SetPedComponentVariation(ped, component, variation.drawable, variation.texture or 0, 0)
    end
end

local function restoreOutfit()
    if not state.savedOutfit then return end
    local ped = PlayerPedId()
    for component, variation in pairs(state.savedOutfit.components) do
        SetPedComponentVariation(ped, component, variation.drawable, variation.texture, variation.palette)
    end
    for prop, variation in pairs(state.savedOutfit.props) do
        if variation.drawable and variation.drawable >= 0 then
            SetPedPropIndex(ped, prop, variation.drawable, variation.texture or 0, true)
        else
            ClearPedProp(ped, prop)
        end
    end
    state.savedOutfit = nil
end

local function closeMenu()
    state.menuOpen = false
    state.menuActionPending = false
    state.menuActionToken = state.menuActionToken + 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeAll' })
end

local function deleteEntitySafe(entity)
    if not entity or not DoesEntityExist(entity) then return end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(20)
        NetworkRequestControlOfEntity(entity)
    end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function cleanupTask()
    removeBlipSafe(state.taskBlip)
    state.taskBlip = nil
    deleteEntitySafe(state.taskVehicle)
    state.taskVehicle = nil
    state.currentTask = nil
end

local function cleanupShift()
    closeMenu()
    cleanupTask()
    removeBlipSafe(state.serviceBlip)
    state.serviceBlip = nil
    deleteEntitySafe(state.serviceVehicle)
    state.serviceVehicle = nil
    state.onDuty = false
    state.hasTools = false
    state.minigameOpen = false
    ClearPedTasks(PlayerPedId())
    restoreOutfit()
end

local function isSpawnClear(coords)
    return GetClosestVehicle(coords.x, coords.y, coords.z, Config.VehicleSpawnClearRadius, 0, 71) == 0
end

local function spawnServiceVehicle()
    local selected
    for _, spawn in ipairs(Config.ServiceVehicle.spawnPoints) do
        if isSpawnClear(spawn) then
            selected = spawn
            break
        end
    end

    if not selected then
        notify('error', 'Atelier', Config.Text.spawnOccupied, 7000)
        TriggerServerEvent('driftzone_mechanic:server:abortShift')
        return false
    end

    local model = loadModel(Config.ServiceVehicle.model)
    if not model then
        notify('error', 'Atelier', 'Modelul vehiculului de serviciu nu poate fi încărcat.')
        TriggerServerEvent('driftzone_mechanic:server:abortShift')
        return false
    end

    local vehicle = CreateVehicle(model, selected.x, selected.y, selected.z, selected.w, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleNumberPlateText(vehicle, ('%s%03d'):format(Config.ServiceVehicle.platePrefix, math.random(1, 999)))
    SetVehicleColours(vehicle, Config.ServiceVehicle.primaryColor, Config.ServiceVehicle.secondaryColor)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetModelAsNoLongerNeeded(model)

    state.serviceVehicle = vehicle
    state.serviceBlip = AddBlipForEntity(vehicle)
    SetBlipSprite(state.serviceBlip, 225)
    SetBlipColour(state.serviceBlip, 47)
    SetBlipScale(state.serviceBlip, 0.85)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Vehicul mecanic')
    EndTextCommandSetBlipName(state.serviceBlip)

    TriggerServerEvent('driftzone_mechanic:server:registerServiceVehicle', NetworkGetNetworkIdFromEntity(vehicle))
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    return true
end

local function damageTaskVehicle(vehicle, taskType)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleUndriveable(vehicle, true)
    SetVehicleEngineHealth(vehicle, 220.0)
    SetVehicleBodyHealth(vehicle, 620.0)
    SetVehicleDirtLevel(vehicle, 10.0)

    if taskType == 'tire' then
        SetVehicleTyreBurst(vehicle, 0, true, 1000.0)
    elseif taskType == 'engine' then
        SetVehicleDoorOpen(vehicle, 4, false, false)
        SetVehicleEngineHealth(vehicle, 80.0)
    elseif taskType == 'battery' or taskType == 'diagnostics' then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    elseif taskType == 'brakes' then
        SetVehicleBrakeLights(vehicle, true)
    end
end

local function spawnTaskVehicle(task)
    cleanupTask()
    state.currentTask = task

    local model = loadModel(task.vehicleModel)
    if not model then
        notify('error', 'Dispecerat', 'Vehiculul intervenției nu a putut fi încărcat.')
        return
    end

    local c = task.coords
    local vehicle = CreateVehicle(model, c.x, c.y, c.z, c.w, true, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleNumberPlateText(vehicle, 'SERVICE')
    damageTaskVehicle(vehicle, task.type)
    SetModelAsNoLongerNeeded(model)
    state.taskVehicle = vehicle

    state.taskBlip = createRouteBlip(vector3(c.x, c.y, c.z), task.urgent and 161 or 446, task.urgent and 1 or 47, task.label)

    local prefix = task.urgent and 'INTERVENȚIE URGENTĂ' or 'Intervenție nouă'
    notify(task.urgent and 'error' or 'info', prefix, ('%s · plată estimată $%s–$%s'):format(task.label, task.estimatedMin, task.estimatedMax), 7000)
end

local function serviceVehicleNearby()
    if not state.serviceVehicle or not DoesEntityExist(state.serviceVehicle) then return false end
    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicleCoords = GetEntityCoords(state.serviceVehicle)
    return #(playerCoords - vehicleCoords) <= Config.ServiceVehicleMaxDistance
end

CreateThread(function()
    if Config.BossBlip.enabled then
        local c = Config.BossNPC.coords
        state.bossBlip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(state.bossBlip, Config.BossBlip.sprite)
        SetBlipColour(state.bossBlip, Config.BossBlip.colour)
        SetBlipScale(state.bossBlip, Config.BossBlip.scale)
        SetBlipAsShortRange(state.bossBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.BossBlip.label)
        EndTextCommandSetBlipName(state.bossBlip)
    end

    local model = loadModel(Config.BossNPC.model)
    if not model then return end

    local c = Config.BossNPC.coords
    state.npc = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(state.npc, true)
    SetBlockingOfNonTemporaryEvents(state.npc, true)
    FreezeEntityPosition(state.npc, true)
    TaskStartScenarioInPlace(state.npc, Config.BossNPC.scenario, 0, true)
    SetModelAsNoLongerNeeded(model)
end)

CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local boss = vector3(Config.BossNPC.coords.x, Config.BossNPC.coords.y, Config.BossNPC.coords.z)
        local distance = #(coords - boss)

        if distance < Config.DrawDistance then
            wait = 0
            DrawMarker(2, boss.x, boss.y, boss.z + 1.05, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.20, 0.20, 0.20, 255, 145, 40, 185, false, true, 2, false, nil, nil, false)
            if distance <= Config.InteractionDistance and not state.menuOpen and not state.minigameOpen then
                drawText3D(boss + vector3(0.0, 0.0, 1.20), Config.Text.interactBoss)
                if IsControlJustReleased(0, Config.InteractionKey) then
                    TriggerServerEvent('driftzone_mechanic:server:requestMenu')
                end
            end
        end

        if state.onDuty and not state.hasTools then
            local toolDistance = #(coords - Config.ToolDepot)
            if toolDistance < Config.DrawDistance then
                wait = 0
                DrawMarker(2, Config.ToolDepot.x, Config.ToolDepot.y, Config.ToolDepot.z + 0.25, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.25, 0.25, 0.25, 255, 145, 40, 190, false, true, 2, false, nil, nil, false)
                if toolDistance <= Config.InteractionDistance then
                    drawText3D(Config.ToolDepot + vector3(0.0, 0.0, 0.45), Config.Text.collectTools)
                    if IsControlJustReleased(0, Config.InteractionKey) then
                        TriggerServerEvent('driftzone_mechanic:server:collectTools')
                    end
                end
            end
        end

        if state.onDuty and state.currentTask and state.taskVehicle and DoesEntityExist(state.taskVehicle) then
            local vehicleCoords = GetEntityCoords(state.taskVehicle)
            local taskDistance = #(coords - vehicleCoords)
            if taskDistance < Config.DrawDistance then
                wait = 0
                local repairPoint = vehicleCoords + vector3(0.0, 0.0, 1.15)
                DrawMarker(0, repairPoint.x, repairPoint.y, repairPoint.z + 0.35, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.22, 0.22, 0.22, 255, 145, 40, 190, false, true, 2, false, nil, nil, false)
                if taskDistance <= Config.TaskInteractDistance and not state.minigameOpen then
                    drawText3D(repairPoint, Config.Text.repairVehicle)
                    if IsControlJustReleased(0, Config.InteractionKey) then
                        if IsPedInAnyVehicle(ped, false) then
                            notify('error', 'Intervenție', Config.Text.stayOnFoot)
                        elseif not serviceVehicleNearby() then
                            notify('error', 'Intervenție', Config.Text.noServiceVehicle)
                        else
                            TriggerServerEvent('driftzone_mechanic:server:startTask', state.currentTask.id)
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

RegisterNetEvent('driftzone_mechanic:client:openMenu', function(profile)
    state.menuOpen = true
    state.menuActionPending = false
    state.menuActionToken = state.menuActionToken + 1
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'setMenuBusy', busy = false })
    SendNUIMessage({ action = 'openMenu', profile = profile })
end)

RegisterNetEvent('driftzone_mechanic:client:menuActionFinished', function(showMessage)
    state.menuActionPending = false
    state.menuActionToken = state.menuActionToken + 1
    SendNUIMessage({ action = 'setMenuBusy', busy = false })
    if showMessage then
        notify('error', 'Atelier', 'Acțiunea nu a putut fi finalizată.')
    end
end)

RegisterNetEvent('driftzone_mechanic:client:shiftStarted', function()
    closeMenu()
    state.onDuty = true
    state.hasTools = false
    applyUniform()

    if spawnServiceVehicle() then
        SetNewWaypoint(Config.ToolDepot.x, Config.ToolDepot.y)
        notify('success', 'Tură începută', 'Ia trusa de scule din depozit. Vehiculul tău este marcat permanent pe hartă.', 6500)
    end
end)

RegisterNetEvent('driftzone_mechanic:client:toolsCollected', function()
    state.hasTools = true
    notify('success', 'Echipament', 'Ai ridicat trusa de scule. Dispeceratul caută o intervenție.')
end)

RegisterNetEvent('driftzone_mechanic:client:taskAssigned', function(task)
    spawnTaskVehicle(task)
end)

RegisterNetEvent('driftzone_mechanic:client:beginMinigame', function(task)
    if not state.currentTask or state.currentTask.id ~= task.id then return end
    state.minigameOpen = true
    TaskStartScenarioInPlace(PlayerPedId(), 'WORLD_HUMAN_VEHICLE_MECHANIC', 0, true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'startGame', task = task })
end)

RegisterNetEvent('driftzone_mechanic:client:taskFailed', function()
    state.minigameOpen = false
    SetNuiFocus(false, false)
    ClearPedTasks(PlayerPedId())
    notify('error', 'Reparație nereușită', 'Ai făcut o greșeală. Verifică procedura și încearcă din nou.', 5500)
end)

RegisterNetEvent('driftzone_mechanic:client:taskCompleted', function(result)
    state.minigameOpen = false
    SetNuiFocus(false, false)
    ClearPedTasks(PlayerPedId())

    if state.taskVehicle and DoesEntityExist(state.taskVehicle) then
        SetVehicleFixed(state.taskVehicle)
        SetVehicleUndriveable(state.taskVehicle, false)
        SetVehicleEngineOn(state.taskVehicle, true, true, false)
        SetVehicleDoorsLocked(state.taskVehicle, 1)
        SetVehicleDoorShut(state.taskVehicle, 4, false)
    end

    local moneyText = result.framework == 'internal' and ('$%s în soldul intern'):format(result.reward) or ('$%s'):format(result.reward)
    notify('success', 'Intervenție finalizată', ('Ai primit %s și %s XP. Tură: %s lucrări, %s greșeli.'):format(moneyText, result.xp, result.completed, result.mistakes), 7000)

    if result.promoted then
        notify('success', 'PROMOVARE', ('Ai fost promovat la %s!'):format(result.rankName), 8000)
    end

    local oldVehicle = state.taskVehicle
    removeBlipSafe(state.taskBlip)
    state.taskBlip = nil
    state.currentTask = nil
    state.taskVehicle = nil

    CreateThread(function()
        Wait(5000)
        deleteEntitySafe(oldVehicle)
        if state.onDuty then
            TriggerServerEvent('driftzone_mechanic:server:requestTask')
        end
    end)
end)

RegisterNetEvent('driftzone_mechanic:client:shiftEnded', function(result)
    cleanupShift()
    if result.aborted then return end

    if result.bonusMoney > 0 then
        notify('success', 'Tură perfectă', ('Fără greșeli! Bonus: $%s și %s XP.'):format(result.bonusMoney, result.bonusXP), 8000)
    else
        notify('info', 'Tură încheiată', 'Vehiculul și echipamentul au fost returnate.')
    end
end)

RegisterNUICallback('menuAction', function(data, cb)
    local action = data.action
    if action == 'close' then
        closeMenu()
        cb({ ok = true })
        return
    end

    if state.menuActionPending then
        cb({ ok = false, error = 'pending' })
        return
    end

    local eventByAction = {
        hire = 'driftzone_mechanic:server:hire',
        resign = 'driftzone_mechanic:server:resign',
        start = 'driftzone_mechanic:server:startShift',
        stop = 'driftzone_mechanic:server:endShift'
    }

    local serverEvent = eventByAction[action]
    if not serverEvent then
        cb({ ok = false, error = 'invalid_action' })
        return
    end

    state.menuActionPending = true
    state.menuActionToken = state.menuActionToken + 1
    local requestToken = state.menuActionToken
    SendNUIMessage({ action = 'setMenuBusy', busy = true })
    TriggerServerEvent(serverEvent)

    CreateThread(function()
        local requestedAction = action
        Wait(8000)
        if state.menuActionPending and state.menuActionToken == requestToken then
            state.menuActionPending = false
            SendNUIMessage({ action = 'setMenuBusy', busy = false })
            notify('error', 'Atelier', ('Serverul nu a confirmat acțiunea „%s”. Verifică consola serverului.'):format(requestedAction), 7000)
        end
    end)

    cb({ ok = true })
end)

RegisterNUICallback('gameResult', function(data, cb)
    if not state.minigameOpen or not state.currentTask then
        cb({ ok = false })
        return
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeGame' })
    TriggerServerEvent('driftzone_mechanic:server:taskResult', state.currentTask.id, data.success == true)
    cb({ ok = true })
end)

RegisterNUICallback('escapeGame', function(_, cb)
    if state.minigameOpen and state.currentTask then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeGame' })
        TriggerServerEvent('driftzone_mechanic:server:taskResult', state.currentTask.id, false)
    end
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupShift()
    if state.npc and DoesEntityExist(state.npc) then
        DeleteEntity(state.npc)
    end
    removeBlipSafe(state.bossBlip)
end)
