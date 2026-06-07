local nuiReady = false
local menuOpen = false
local activeRace = nil
local finishBlip = nil
local finishCheckpoint = nil
local finishReached = false
local raceVehicle = nil
local raceVehicleNet = nil
local pendingSpawn = nil

local MOD_KEY_TYPES = {
    spoiler = 0, frontBumper = 1, rearBumper = 2, sideSkirt = 3, exhaust = 4, frame = 5,
    grille = 6, hood = 7, fender = 8, rightFender = 9, roof = 10, engine = 11,
    brakes = 12, transmission = 13, horns = 14, suspension = 15, armor = 16,
    turbo = 18, xenon = 22, frontWheels = 23, backWheels = 24, plateHolder = 25,
    vanityPlates = 26, trimDesign = 27, ornaments = 28, dashboard = 29, dial = 30,
    doorSpeaker = 31, seats = 32, steeringWheel = 33, shiftLeavers = 34, plaques = 35,
    speakers = 36, trunk = 37, hydraulics = 38, engineBlock = 39, airFilter = 40,
    struts = 41, archCover = 42, aerials = 43, trim = 44, tank = 45, windows = 46,
    livery = 48
}

local function notify(type, message, duration)
    TriggerEvent('client:notify', type or 'info', duration or 5000, tostring(message or ''))
end

local function sendNui(data)
    if not nuiReady then return false end
    SendNUIMessage(data)
    return true
end

local function setFocus(state)
    menuOpen = state == true
    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)
    TriggerEvent('driftzone_hud:visible', not menuOpen)
end

local function closeMenu(sendServer)
    sendNui({ action = 'closeMenu' })
    setFocus(false)
    if sendServer == true then
        TriggerServerEvent('driftzone_racejob:server:close')
    end
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds or 0) or 0))
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function requestControl(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local timeout = GetGameTimer() + (timeoutMs or 2000)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(25)
    end
    return NetworkHasControlOfEntity(entity)
end

local function decodeTuning(raw)
    if type(raw) == 'table' then return raw end
    raw = tostring(raw or '{}')
    if raw == '' or raw == 'null' or raw == 'nil' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return {}
end

local function boolValue(value)
    if value == true then return true end
    if value == false or value == nil then return false end
    local n = tonumber(value)
    if n ~= nil then return n ~= 0 end
    local text = tostring(value):lower()
    return text == 'true' or text == 'yes' or text == 'on'
end

local function colorFrom(value)
    if type(value) ~= 'table' then return nil end
    local r = tonumber(value.r or value[1])
    local g = tonumber(value.g or value[2])
    local b = tonumber(value.b or value[3])
    if r and g and b then return { r = r, g = g, b = b } end
    return nil
end

local function applyColorData(vehicle, tuning)
    if tuning.primaryColor ~= nil or tuning.secondaryColor ~= nil then
        local p = tonumber(tuning.primaryColor or 0) or 0
        local s = tonumber(tuning.secondaryColor or 0) or 0
        SetVehicleColours(vehicle, p, s)
    end

    if tuning.pearlColor ~= nil or tuning.wheelColor ~= nil or tuning.pearlescentColor ~= nil then
        local pearl, wheel = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, tonumber(tuning.pearlColor or tuning.pearlescentColor or pearl) or pearl, tonumber(tuning.wheelColor or wheel) or wheel)
    end

    local primaryCustom = colorFrom(tuning.customPrimaryColor or tuning.primaryCustomColor or tuning.color1 or tuning.primary)
    if primaryCustom then SetVehicleCustomPrimaryColour(vehicle, primaryCustom.r, primaryCustom.g, primaryCustom.b) end

    local secondaryCustom = colorFrom(tuning.customSecondaryColor or tuning.secondaryCustomColor or tuning.color2 or tuning.secondary)
    if secondaryCustom then SetVehicleCustomSecondaryColour(vehicle, secondaryCustom.r, secondaryCustom.g, secondaryCustom.b) end

    local smoke = colorFrom(tuning.tyreSmokeColor or tuning.tireSmokeColor or tuning.smokeColor)
    if smoke then
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, smoke.r, smoke.g, smoke.b)
    end

    local neon = colorFrom(tuning.neonColor)
    if neon then
        SetVehicleNeonLightsColour(vehicle, neon.r, neon.g, neon.b)
        for i = 0, 3 do SetVehicleNeonLightEnabled(vehicle, i, true) end
    end

    if tuning.windowTint ~= nil then SetVehicleWindowTint(vehicle, tonumber(tuning.windowTint) or 0) end
    if tuning.xenonColor ~= nil then
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsColor(vehicle, tonumber(tuning.xenonColor) or 0)
    end
end

local function applyNumberMods(vehicle, tuning)
    for key, modType in pairs(MOD_KEY_TYPES) do
        if tuning[key] ~= nil then
            local value = tonumber(tuning[key])
            if value ~= nil then SetVehicleMod(vehicle, modType, value, false) end
        end
    end
    for key, value in pairs(tuning) do
        local modType = tonumber(key)
        if modType and modType >= 0 and modType <= 60 then
            SetVehicleMod(vehicle, modType, tonumber(value) or -1, false)
        end
    end
end

local function applyToggleMods(vehicle, tuning)
    if tuning.turbo ~= nil then ToggleVehicleMod(vehicle, 18, boolValue(tuning.turbo)) end
    if tuning.xenon ~= nil then ToggleVehicleMod(vehicle, 22, boolValue(tuning.xenon)) end
    if tuning.tireSmoke ~= nil or tuning.tyreSmoke ~= nil then ToggleVehicleMod(vehicle, 20, boolValue(tuning.tireSmoke or tuning.tyreSmoke)) end
end

local function applyTuning(vehicle, tuningRaw, plate)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    requestControl(vehicle, 4000)
    SetVehicleModKit(vehicle, 0)
    local tuning = decodeTuning(tuningRaw)
    applyColorData(vehicle, tuning)
    applyNumberMods(vehicle, tuning)
    applyToggleMods(vehicle, tuning)
    if plate then SetVehicleNumberPlateText(vehicle, tostring(plate):sub(1, 8)) end
    if tuning.plate ~= nil then SetVehicleNumberPlateText(vehicle, tostring(tuning.plate):sub(1, 8)) end
    pcall(function() TriggerEvent('client:tunning:applyVehicle', VehToNet(vehicle), tostring(tuningRaw or '{}')) end)
    pcall(function() TriggerEvent('driftzone_tunning:client:applyVehicle', VehToNet(vehicle), tostring(tuningRaw or '{}')) end)
    return true
end

local function protectVehicle(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityInvincible(entity, true)
    SetEntityCanBeDamaged(entity, false)
    SetVehicleCanBreak(entity, false)
    SetVehicleEngineCanDegrade(entity, false)
    SetVehicleStrong(entity, true)
    SetVehicleTyresCanBurst(entity, false)
    SetVehicleWheelsCanBreak(entity, false)
end

local function prepareVehicle(entity, data)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    requestControl(entity, 5000)
    SetVehicleNumberPlateText(entity, tostring(data.plate or 'DRIFT'):sub(1, 8))
    SetVehicleFixed(entity)
    SetVehicleDeformationFixed(entity)
    SetVehicleDirtLevel(entity, 0.0)
    SetVehicleEngineHealth(entity, 1000.0)
    SetVehicleBodyHealth(entity, 1000.0)
    SetVehiclePetrolTankHealth(entity, 1000.0)
    SetVehicleEngineOn(entity, true, true, false)
    SetVehicleOnGroundProperly(entity)
    protectVehicle(entity)
    applyTuning(entity, data.tuning or '{}', data.plate)
    SetPedIntoVehicle(PlayerPedId(), entity, -1)

    local delays = (Config.Vehicle and Config.Vehicle.tuningApplyDelays) or { 100, 350, 750, 1400, 2400 }
    for i = 1, #delays do
        Wait(delays[i])
        if not DoesEntityExist(entity) then break end
        requestControl(entity, 500)
        SetVehicleEngineOn(entity, true, true, false)
        SetVehicleFixed(entity)
        protectVehicle(entity)
        applyTuning(entity, data.tuning or '{}', data.plate)
    end
end

local function clearRaceVisuals()
    if finishCheckpoint and finishCheckpoint ~= 0 then DeleteCheckpoint(finishCheckpoint) end
    finishCheckpoint = nil
    if finishBlip and DoesBlipExist(finishBlip) then
        SetBlipRoute(finishBlip, false)
        RemoveBlip(finishBlip)
    end
    finishBlip = nil
    sendNui({ action = 'raceHud', visible = false })
end

local function createFinishVisual(finish, label)
    clearRaceVisuals()
    finishBlip = AddBlipForCoord(finish.x, finish.y, finish.z)
    SetBlipSprite(finishBlip, 38)
    SetBlipColour(finishBlip, 3)
    SetBlipScale(finishBlip, 0.95)
    SetBlipAsShortRange(finishBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Race Finish')
    EndTextCommandSetBlipName(finishBlip)
    SetBlipRoute(finishBlip, true)
    SetBlipRouteColour(finishBlip, 3)

    finishCheckpoint = CreateCheckpoint(4, finish.x, finish.y, finish.z + 0.25, finish.x, finish.y, finish.z + 1.5, 8.5, 4, 199, 247, 170, 0)
    SetCheckpointCylinderHeight(finishCheckpoint, 4.0, 4.0, 8.5)
end

local function setRaceControlsLocked(state)
    local ped = PlayerPedId()
    if raceVehicle and DoesEntityExist(raceVehicle) then FreezeEntityPosition(raceVehicle, state == true) end
    FreezeEntityPosition(ped, state == true)
end

local function deleteLocalRaceVehicle()
    if raceVehicle and raceVehicle ~= 0 and DoesEntityExist(raceVehicle) then
        requestControl(raceVehicle, 2000)
        DeleteEntity(raceVehicle)
    end
    raceVehicle = nil
    raceVehicleNet = nil
end

local function finishLocalCleanup(payload)
    payload = payload or {}
    clearRaceVisuals()
    activeRace = nil
    finishReached = false
    pendingSpawn = nil
    sendNui({ action = 'countdown', visible = false })
    sendNui({ action = 'raceHud', visible = false })
    deleteLocalRaceVehicle()

    local ret = payload.returnPos or {}
    if ret.x and ret.y and ret.z then
        local ped = PlayerPedId()
        SetEntityCoords(ped, ret.x + 0.0, ret.y + 0.0, ret.z + 0.0, false, false, false, false)
        SetEntityHeading(ped, tonumber(ret.h or 0.0) or 0.0)
    end
    TriggerEvent('driftzone_hud:visible', true)
    if payload.message then notify(payload.success and 'success' or 'warning', payload.message, 6000) end
end

local function startRaceLoop(race)
    CreateThread(function()
        local finish = race.finish
        local radius = tonumber(race.radius or 9.0) or 9.0
        local finishVec = vector3(finish.x, finish.y, finish.z)
        local endAt = GetGameTimer() + ((tonumber(race.timeLimit) or 180) * 1000)
        local lastShown = -1
        activeRace = race
        finishReached = false
        sendNui({ action = 'raceHud', visible = true, race = race.label or 'Race', time = formatTime(race.timeLimit) })

        while activeRace and activeRace.id == race.id do
            local leftMs = endAt - GetGameTimer()
            local left = math.ceil(leftMs / 1000)
            if left < 0 then left = 0 end
            if left ~= lastShown then
                lastShown = left
                sendNui({ action = 'timer', time = formatTime(left), danger = left <= 20 })
            end
            if left <= 0 then
                TriggerServerEvent('driftzone_racejob:server:fail', 'timeout')
                break
            end
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - finishVec)
            if dist <= radius and not finishReached then
                finishReached = true
                TriggerServerEvent('driftzone_racejob:server:finish', race.id)
                break
            end
            Wait(150)
        end
    end)
end

local function runCountdown(seconds, cb)
    seconds = tonumber(seconds or 3) or 3
    CreateThread(function()
        setRaceControlsLocked(true)
        for i = seconds, 1, -1 do
            sendNui({ action = 'countdown', visible = true, text = tostring(i) })
            Wait(1000)
        end
        sendNui({ action = 'countdown', visible = true, text = 'START' })
        setRaceControlsLocked(false)
        Wait(780)
        sendNui({ action = 'countdown', visible = false })
        if cb then cb() end
    end)
end

local function spawnRaceVehicle(payload)
    CreateThread(function()
        payload = payload or {}
        pendingSpawn = payload
        closeMenu(false)
        TriggerEvent('driftzone_hud:visible', false)

        local vehicleData = payload.vehicle or {}
        local start = payload.start or {}
        local model = tostring(vehicleData.model or ''):lower()
        if model == '' then
            TriggerServerEvent('driftzone_racejob:server:spawnFailed', payload.token, 'Model invalid.')
            return
        end

        local hash = joaat(model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
            TriggerServerEvent('driftzone_racejob:server:spawnFailed', payload.token, 'Modelul masinii nu este streamat corect.')
            return
        end

        RequestModel(hash)
        local timeout = GetGameTimer() + 12000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(25) end
        if not HasModelLoaded(hash) then
            TriggerServerEvent('driftzone_racejob:server:spawnFailed', payload.token, 'Nu s-a incarcat modelul masinii.')
            return
        end

        local x, y, z, h = tonumber(start.x), tonumber(start.y), tonumber(start.z), tonumber(start.h or 0.0)
        local entity = CreateVehicle(hash, x, y, z + ((Config.Vehicle and Config.Vehicle.spawnZOffset) or 0.45), h, true, true)
        SetModelAsNoLongerNeeded(hash)

        timeout = GetGameTimer() + 8000
        while (not entity or entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() < timeout do Wait(25) end
        if not entity or entity == 0 or not DoesEntityExist(entity) then
            TriggerServerEvent('driftzone_racejob:server:spawnFailed', payload.token, 'Masina cursei nu a putut fi creata.')
            return
        end

        raceVehicle = entity
        local netId = VehToNet(entity)
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, false)
        raceVehicleNet = netId

        prepareVehicle(entity, vehicleData)
        TriggerServerEvent('driftzone_racejob:server:vehicleCreated', payload.token, netId)
    end)
end

RegisterNetEvent('driftzone_racejob:client:openMenu', function(payload)
    payload = payload or {}
    payload.action = 'openMenu'
    sendNui(payload)
    setFocus(true)
end)

RegisterNetEvent('driftzone_racejob:client:spawnRaceVehicle', function(payload)
    spawnRaceVehicle(payload or {})
end)

RegisterNetEvent('driftzone_racejob:client:raceConfirmed', function(payload)
    payload = payload or {}
    if payload.cooldowns then sendNui({ action = 'cooldowns', cooldowns = payload.cooldowns, serverTime = payload.serverTime }) end
    local data = pendingSpawn or {}
    local race = data.race or {}
    createFinishVisual(race.finish, race.label or 'Race Finish')
    runCountdown(data.countdown or 3, function() startRaceLoop(race) end)
end)

RegisterNetEvent('driftzone_racejob:client:endRace', function(payload)
    finishLocalCleanup(payload or {})
end)

RegisterNetEvent('driftzone_racejob:client:forceEndLocal', function()
    finishLocalCleanup({ success = false, message = 'Cursa a fost oprita.' })
end)

RegisterNetEvent('driftzone_racejob:client:cooldownsReset', function()
    sendNui({ action = 'resetCooldowns' })
end)

RegisterNetEvent('driftzone_racejob:client:openFromInteraction', function()
    TriggerServerEvent('driftzone_racejob:server:open')
end)

RegisterCommand('racejob', function()
    TriggerServerEvent('driftzone_racejob:server:open')
end, false)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(false)
    cb({ ok = true })
end)

RegisterNUICallback('start', function(data, cb)
    data = data or {}
    TriggerServerEvent('driftzone_racejob:server:start', tostring(data.raceId or ''), tonumber(data.vehicleId or 0) or 0)
    cb({ ok = true })
end)

CreateThread(function()
    Wait(1500)
    pcall(function() exports.driftzone_interactions:AddInteraction(Config.Interaction) end)
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then closeMenu(false) end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearRaceVisuals()
    deleteLocalRaceVehicle()
    SetNuiFocus(false, false)
end)
