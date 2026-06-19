local RESOURCE = GetCurrentResourceName()
local Profiles = {}
local Sessions = {}
local RateLimits = {}
local Ready = false

math.randomseed(os.time() + GetGameTimer())

local function debugPrint(message)
    if Config.Debug then
        print(('^5[%s:server] %s^7'):format(RESOURCE, tostring(message)))
    end
end

local function rateLimited(src, action, customMs)
    src = tonumber(src or 0) or 0
    if src <= 0 then return true end

    local now = GetGameTimer()
    RateLimits[src] = RateLimits[src] or {}
    local last = RateLimits[src][action] or 0
    local cooldown = tonumber(customMs or Config.Security.ActionCooldownMs) or 700

    if now - last < cooldown then return true end
    RateLimits[src][action] = now
    return false
end

local function isNear(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 or not DoesEntityExist(ped) then
        return Config.Security.RequireOneSync ~= true
    end

    local playerCoords = GetEntityCoords(ped)
    if not playerCoords then return Config.Security.RequireOneSync ~= true end

    return #(playerCoords - vector3(coords.x, coords.y, coords.z)) <= (tonumber(maxDistance) or 5.0)
end

local function randomBetween(range)
    range = range or {}
    local minimum = math.floor(tonumber(range.min) or 0)
    local maximum = math.floor(tonumber(range.max) or minimum)
    if maximum < minimum then maximum = minimum end
    return math.random(minimum, maximum)
end

local function shuffledCopy(input)
    local output = {}
    for i = 1, #input do output[i] = input[i] end

    for i = #output, 2, -1 do
        local j = math.random(i)
        output[i], output[j] = output[j], output[i]
    end

    return output
end

local function makeToken(src)
    return ('%s:%s:%s:%s'):format(src, os.time(), GetGameTimer(), math.random(100000, 999999))
end

local function getProfile(src)
    local uid = DriftzoneElectricianBridge.GetUid(src)
    if not uid then return nil end

    local cached = Profiles[src]
    if cached and cached.uid == uid then return cached end

    local profile = DriftzoneElectricianStorage.Get(uid)
    if not profile then return nil end

    Profiles[src] = profile
    return profile
end

local function saveProfile(src)
    local profile = Profiles[src]
    if not profile then return false end
    return DriftzoneElectricianStorage.Save(profile)
end

local function payPlayer(src, profile, amount, reason, pendingMessage)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 or not profile then return false end

    if DriftzoneElectricianBridge.AddMoney(src, profile.uid, amount, reason) then
        profile.totalEarned = profile.totalEarned + amount
        return true
    end

    profile.pendingPay = profile.pendingPay + amount
    if pendingMessage ~= false then
        DriftzoneElectricianBridge.Notify(src, 'warning', Config.Text.paymentPending, 5000)
    end
    return false
end

local function tryPendingPayment(src, profile)
    if not profile or profile.pendingPay <= 0 then return end

    local amount = profile.pendingPay
    if DriftzoneElectricianBridge.AddMoney(src, profile.uid, amount, 'Electrician pending payment') then
        profile.pendingPay = 0
        profile.totalEarned = profile.totalEarned + amount
        DriftzoneElectricianStorage.Save(profile)
        DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.pendingPaid:format(amount), 5000)
    end
end

local function publicTask(task)
    return {
        id = task.id,
        type = task.type,
        label = task.label,
        description = task.description,
        voltage = task.voltage,
        area = task.area,
        coords = task.coords,
        duration = task.duration,
        allowedMistakes = task.allowedMistakes,
        pay = task.pay,
        xp = task.xp,
        completed = task.completed == true,
        attempts = task.attempts or 0
    }
end

local function publicSession(src)
    local session = Sessions[src]
    if not session then return nil end

    local tasks = {}
    for index, task in ipairs(session.tasks) do
        tasks[index] = publicTask(task)
    end

    return {
        active = true,
        tasks = tasks,
        activeIndex = session.activeIndex,
        completed = session.completed,
        total = #session.tasks,
        shiftEarned = session.shiftEarned,
        mistakes = session.mistakes,
        hasTools = session.hasTools,
        badWeather = session.badWeather == true,
        allComplete = session.completed >= #session.tasks,
        vehicleReady = (tonumber(session.vehicleNetId) or 0) > 0,
        startedAt = session.startedAt
    }
end

local function syncState(src, openView)
    local profile = getProfile(src)
    if not profile then
        DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.uidMissing, 5000)
        return
    end

    TriggerClientEvent('driftzone_electrician:client:state', src, {
        profile = DriftzoneElectrician.FormatProfile(profile),
        shift = publicSession(src),
        openView = openView
    })
end

local function createTasks(profile, badWeather)
    local level, levelData = DriftzoneElectrician.GetLevelFromXp(profile.xp)
    local available = {}

    for _, intervention in ipairs(Config.Interventions) do
        local typeData = Config.TaskTypes[intervention.type]
        if typeData and level >= (tonumber(typeData.minLevel) or 1) then
            available[#available + 1] = intervention
        end
    end

    available = shuffledCopy(available)

    local minimum = math.max(1, tonumber(Config.Shift.minTasks) or 4)
    local maximum = math.max(minimum, tonumber(Config.Shift.maxTasks) or minimum)
    local count = math.random(minimum, maximum)
    local weatherAdded = false

    if badWeather == true and math.random(100) <= (tonumber(Config.Shift.badWeatherExtraChance) or 0) then
        local maxExtra = math.max(1, tonumber(Config.Shift.badWeatherMaxExtraTasks) or 1)
        count = count + math.random(1, maxExtra)
        weatherAdded = true
    end

    count = math.min(count, #available)
    local tasks = {}

    for index = 1, count do
        local intervention = available[index]
        local typeData = Config.TaskTypes[intervention.type]
        local multiplier = tonumber(levelData and levelData.multiplier) or 1.0

        tasks[#tasks + 1] = {
            id = ('%s:%s:%s'):format(intervention.id, makeToken(profile.uid), index),
            locationId = intervention.id,
            type = intervention.type,
            label = typeData.label,
            description = typeData.description,
            voltage = typeData.voltage,
            area = intervention.area,
            coords = DriftzoneElectrician.CopyCoords(intervention.coords),
            duration = math.max(5, tonumber(typeData.duration) or 12),
            allowedMistakes = math.max(0, tonumber(typeData.allowedMistakes) or 2),
            pay = math.max(1, math.floor(randomBetween(typeData.pay) * multiplier)),
            xp = math.max(1, randomBetween(typeData.xp)),
            scenario = typeData.scenario,
            completed = false,
            attempts = 0,
            repair = nil
        }
    end

    return tasks, weatherAdded
end

local function currentTask(src, taskId)
    local session = Sessions[src]
    if not session then return nil, nil end

    local task = session.tasks[session.activeIndex]
    if not task or task.completed or task.id ~= taskId then return session, nil end
    return session, task
end

local function cleanupVehicle(src, session, fullCleanup)
    session = session or Sessions[src]
    if not session then return end

    local netId = tonumber(session.vehicleNetId or 0) or 0
    session.vehicleNetId = 0

    if netId > 0 then
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    TriggerClientEvent(fullCleanup and 'driftzone_electrician:client:cleanupShift' or 'driftzone_electrician:client:cleanupVehicle', src)
end

CreateThread(function()
    local ok, err = pcall(function()
        DriftzoneElectricianStorage.Init()
        DriftzoneElectricianBridge.InitEconomy()
    end)

    if not ok then
        print(('^1[%s] Initializarea a esuat: %s^7'):format(RESOURCE, tostring(err)))
        return
    end

    Ready = true
    print(('^2[%s] Resource pornit corect.^7'):format(RESOURCE))
    TriggerClientEvent('driftzone_electrician:client:requestState', -1)
end)

RegisterNetEvent('driftzone_electrician:server:getState', function(openView)
    local src = source
    if not Ready then return end

    local profile = getProfile(src)
    if profile then tryPendingPayment(src, profile) end
    syncState(src, openView)
end)

RegisterNetEvent('driftzone_electrician:server:hire', function()
    local src = source
    if not Ready or rateLimited(src, 'hire') then return end
    if not isNear(src, Config.JobCenter.coords, Config.Security.JobCenterDistance) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end

    local profile = getProfile(src)
    if not profile then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.uidMissing) end
    if profile.employed then return syncState(src, 'company') end

    profile.employed = true
    saveProfile(src)
    DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.hired)
    syncState(src, 'company')
end)

RegisterNetEvent('driftzone_electrician:server:resign', function()
    local src = source
    if not Ready or rateLimited(src, 'resign') then return end
    if Sessions[src] then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.activeShift) end
    if not isNear(src, Config.JobCenter.coords, Config.Security.JobCenterDistance) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end

    local profile = getProfile(src)
    if not profile then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.uidMissing) end
    if not profile.employed then return syncState(src, 'company') end

    profile.employed = false
    saveProfile(src)
    DriftzoneElectricianBridge.Notify(src, 'info', Config.Text.resigned)
    syncState(src, 'company')
end)

RegisterNetEvent('driftzone_electrician:server:startShift', function(clientBadWeather)
    local src = source
    if not Ready or rateLimited(src, 'startShift') then return end
    if Sessions[src] then return syncState(src, 'company') end
    if not isNear(src, Config.JobCenter.coords, Config.Security.JobCenterDistance) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end

    local profile = getProfile(src)
    if not profile then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.uidMissing) end
    if not profile.employed then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.notEmployed) end

    tryPendingPayment(src, profile)

    local tasks, weatherAdded = createTasks(profile, clientBadWeather == true)
    if #tasks == 0 then
        return DriftzoneElectricianBridge.Notify(src, 'error', 'Nu exista interventii configurate pentru nivelul tau.')
    end

    local vehicleToken = makeToken(src)
    Sessions[src] = {
        uid = profile.uid,
        tasks = tasks,
        activeIndex = 1,
        completed = 0,
        shiftEarned = 0,
        mistakes = 0,
        hasTools = false,
        badWeather = weatherAdded,
        startedAt = os.time(),
        vehicleToken = vehicleToken,
        vehicleNetId = 0,
        lastVehicleRespawn = 0
    }

    DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.shiftStarted)
    if weatherAdded then DriftzoneElectricianBridge.Notify(src, 'warning', Config.Text.badWeather, 5000) end

    TriggerClientEvent('driftzone_electrician:client:startShiftEffects', src, vehicleToken)
    syncState(src, 'tablet')
end)

RegisterNetEvent('driftzone_electrician:server:registerVehicle', function(token, netId)
    local src = source
    local session = Sessions[src]
    if not session or tostring(token or '') ~= session.vehicleToken then return end
    if not isNear(src, Config.JobCenter.coords, Config.Security.VehicleRegisterDistance) then return end

    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return end

    session.vehicleNetId = netId
    syncState(src)
end)

RegisterNetEvent('driftzone_electrician:server:vehicleLost', function(netId)
    local src = source
    local session = Sessions[src]
    if not session then return end

    netId = tonumber(netId or 0) or 0
    if netId > 0 and netId == (tonumber(session.vehicleNetId) or 0) then
        session.vehicleNetId = 0
        syncState(src)
    end
end)

RegisterNetEvent('driftzone_electrician:server:requestVehicle', function()
    local src = source
    local session = Sessions[src]
    if not session then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.noShift) end
    if not isNear(src, Config.JobCenter.coords, Config.Security.JobCenterDistance + 10.0) then
        return DriftzoneElectricianBridge.Notify(src, 'warning', Config.Text.vehicleOnlyAtCenter)
    end

    local now = os.time()
    local cooldown = tonumber(Config.Security.VehicleRespawnCooldownSeconds) or 20
    if now - (session.lastVehicleRespawn or 0) < cooldown then
        return DriftzoneElectricianBridge.Notify(src, 'warning', Config.Text.vehicleRespawnCooldown)
    end

    session.lastVehicleRespawn = now
    cleanupVehicle(src, session)
    TriggerClientEvent('driftzone_electrician:client:spawnJobVehicle', src, session.vehicleToken)
end)

RegisterNetEvent('driftzone_electrician:server:takeTools', function()
    local src = source
    if rateLimited(src, 'tools') then return end

    local session = Sessions[src]
    if not session then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.noShift) end
    if not isNear(src, Config.ToolDepot.coords, Config.Security.DepotDistance) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end
    if session.hasTools then return DriftzoneElectricianBridge.Notify(src, 'info', Config.Text.alreadyTools) end

    session.hasTools = true
    DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.toolsTaken)
    syncState(src)
end)

RegisterNetEvent('driftzone_electrician:server:returnTools', function()
    local src = source
    if rateLimited(src, 'tools') then return end

    local session = Sessions[src]
    if not session then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.noShift) end
    if not isNear(src, Config.ToolDepot.coords, Config.Security.DepotDistance) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end
    if not session.hasTools then return DriftzoneElectricianBridge.Notify(src, 'info', Config.Text.notTools) end

    session.hasTools = false
    DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.toolsReturned)
    syncState(src)
end)

RegisterNetEvent('driftzone_electrician:server:beginRepair', function(taskId)
    local src = source
    if rateLimited(src, 'beginRepair') then return end

    local session, task = currentTask(src, taskId)
    if not session or not task then return end
    if not session.hasTools then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.noTools) end
    if not isNear(src, task.coords, Config.Security.InterventionDistance) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end

    local now = GetGameTimer()
    if task.repair and now <= task.repair.expiresAt then return end

    local nonce = makeToken(src)
    task.repair = {
        nonce = nonce,
        startedAt = now,
        expiresAt = now + ((task.duration + (tonumber(Config.Security.RepairMaxExtraSeconds) or 20)) * 1000)
    }

    TriggerClientEvent('driftzone_electrician:client:repairAuthorized', src, {
        id = task.id,
        type = task.type,
        label = task.label,
        voltage = task.voltage,
        duration = task.duration,
        allowedMistakes = task.allowedMistakes,
        scenario = task.scenario,
        nonce = nonce
    })
end)

RegisterNetEvent('driftzone_electrician:server:cancelRepair', function(taskId, nonce)
    local src = source
    local _, task = currentTask(src, taskId)
    if not task or not task.repair then return end
    if tostring(nonce or '') ~= task.repair.nonce then return end
    task.repair = nil
end)

RegisterNetEvent('driftzone_electrician:server:completeRepair', function(taskId, nonce, clientSuccess, clientMistakes)
    local src = source
    if rateLimited(src, 'completeRepair') then return end

    local session, task = currentTask(src, taskId)
    if not session or not task or not task.repair then return end
    if tostring(nonce or '') ~= task.repair.nonce then return end

    local now = GetGameTimer()
    local elapsed = now - task.repair.startedAt
    local minimum = math.floor(task.duration * 1000 * (tonumber(Config.Security.RepairTimeTolerance) or 0.78))
    local expired = now > task.repair.expiresAt
    task.repair = nil

    if not isNear(src, task.coords, Config.Security.InterventionDistance + 3.0) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end

    if elapsed < minimum then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.repairTooFast)
    end

    if expired then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.repairExpired)
    end

    local mistakes = math.floor(tonumber(clientMistakes) or 0)
    mistakes = math.max(0, math.min(mistakes, tonumber(Config.Security.MaxClientMistakes) or 10))

    if clientSuccess ~= true or mistakes > task.allowedMistakes then
        task.attempts = (task.attempts or 0) + 1
        local failureMistakes = math.max(tonumber(Config.Shift.failedRepairBaseMistake) or 1, mistakes)
        session.mistakes = session.mistakes + failureMistakes

        if task.type == 'panel_high' then
            TriggerClientEvent('driftzone_electrician:client:shock', src)
        end

        DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.taskFailed)
        syncState(src)
        return
    end

    local profile = getProfile(src)
    if not profile then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.uidMissing) end

    local oldLevel = DriftzoneElectrician.GetLevelFromXp(profile.xp)
    local penalty = math.min(0.25, mistakes * 0.05)
    local payment = math.max(1, math.floor(task.pay * (1.0 - penalty)))

    task.completed = true
    task.attempts = (task.attempts or 0) + 1
    session.completed = session.completed + 1
    session.activeIndex = session.activeIndex + 1
    session.shiftEarned = session.shiftEarned + payment
    session.mistakes = session.mistakes + mistakes

    profile.xp = profile.xp + task.xp
    profile.totalJobs = profile.totalJobs + 1

    payPlayer(src, profile, payment, ('Electrician: %s'):format(task.label))
    saveProfile(src)

    DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.taskComplete:format(payment, task.xp))

    local newLevel, newLevelData = DriftzoneElectrician.GetLevelFromXp(profile.xp)
    if newLevel > oldLevel then
        DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.promoted:format(newLevelData.name), 6000)
    end

    if session.completed >= #session.tasks then
        DriftzoneElectricianBridge.Notify(src, 'info', Config.Text.allComplete, 5000)
    end

    syncState(src, 'tablet')
end)

RegisterNetEvent('driftzone_electrician:server:endShift', function()
    local src = source
    if rateLimited(src, 'endShift') then return end

    local session = Sessions[src]
    if not session then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.noShift) end
    if not isNear(src, Config.JobCenter.coords, Config.Security.JobCenterDistance) then
        return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.tooFar)
    end
    if session.hasTools then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.returnToolsFirst) end
    if Config.Shift.allowEarlyFinish ~= true and session.completed < #session.tasks then return end

    local profile = getProfile(src)
    if not profile then return DriftzoneElectricianBridge.Notify(src, 'error', Config.Text.uidMissing) end

    local allComplete = session.completed >= #session.tasks
    if allComplete then
        profile.shiftsCompleted = profile.shiftsCompleted + 1
    end

    if allComplete and session.mistakes == 0 then
        local bonus = math.max(0, tonumber(Config.Shift.cleanBonus) or 0)
        if bonus > 0 then
            session.shiftEarned = session.shiftEarned + bonus
            profile.cleanShifts = profile.cleanShifts + 1
            payPlayer(src, profile, bonus, 'Electrician clean shift bonus')
            DriftzoneElectricianBridge.Notify(src, 'success', Config.Text.cleanBonus:format(bonus), 5500)
        end
    end

    cleanupVehicle(src, session, true)
    Sessions[src] = nil
    saveProfile(src)

    DriftzoneElectricianBridge.Notify(src, 'info', Config.Text.shiftEnded)
    syncState(src, 'company')
end)

CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        local maxSeconds = tonumber(Config.Security.MaxShiftSeconds) or 10800
        local expired = {}

        for src, session in pairs(Sessions) do
            if now - (session.startedAt or now) >= maxSeconds then
                expired[#expired + 1] = src
            end
        end

        for _, src in ipairs(expired) do
            local session = Sessions[src]
            if session then
                cleanupVehicle(src, session, true)
                Sessions[src] = nil
                DriftzoneElectricianBridge.Notify(src, 'warning', Config.Text.shiftExpired, 6000)
                syncState(src, 'company')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local session = Sessions[src]
    if session then cleanupVehicle(src, session, true) end
    saveProfile(src)

    Profiles[src] = nil
    Sessions[src] = nil
    RateLimits[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end

    for src, session in pairs(Sessions) do
        cleanupVehicle(src, session, true)
    end

    for src in pairs(Profiles) do
        saveProfile(src)
    end
end)

exports('GetElectricianProfile', function(src)
    local profile = getProfile(tonumber(src))
    return profile and DriftzoneElectrician.FormatProfile(profile) or nil
end)

exports('HasActiveElectricianShift', function(src)
    return Sessions[tonumber(src)] ~= nil
end)

exports('GetElectricianUid', function(src)
    return DriftzoneElectricianBridge.GetUid(tonumber(src))
end)
