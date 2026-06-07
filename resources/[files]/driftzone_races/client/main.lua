local nuiReady = false
local menuOpen = false
local currentRoom = nil
local activeRace = nil
local raceVehicle = nil
local finishBlip = nil
local finishCheckpoint = nil
local checkpointIndex = 1
local raceEnded = false
local raceGhostThread = false

local MOD_KEY_TYPES = {
    spoiler = 0, frontBumper = 1, rearBumper = 2, sideSkirt = 3, exhaust = 4, frame = 5, grille = 6,
    hood = 7, fender = 8, rightFender = 9, roof = 10, engine = 11, brakes = 12, transmission = 13,
    horns = 14, suspension = 15, armor = 16, turbo = 18, xenon = 22, frontWheels = 23, backWheels = 24,
    livery = 48
}

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 5000, tostring(msg or ''))
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

local function openMenu(payload)
    payload = payload or {}
    payload.action = 'open'
    payload.mainColor = Config.MainColor
    sendNui(payload)
    setFocus(true)
end

local function closeMenu(sendServer)
    sendNui({ action = 'close' })
    setFocus(false)
    if sendServer then TriggerServerEvent('driftzone_races:server:closeUi') end
end

local function requestControl(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local timeout = GetGameTimer() + (timeoutMs or 1500)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(20)
    end
    return NetworkHasControlOfEntity(entity)
end

local function decodeTuning(raw)
    if type(raw) == 'table' then return raw end
    raw = tostring(raw or '{}')
    if raw == '' or raw == 'null' or raw == 'nil' then return {} end
    for _ = 1, 3 do
        local ok, decoded = pcall(json.decode, raw)
        if not ok then break end
        if type(decoded) == 'table' then return decoded end
        if type(decoded) == 'string' then raw = decoded else break end
    end
    return {}
end

local function boolValue(v)
    if v == true then return true end
    if v == false or v == nil then return false end
    local n = tonumber(v)
    if n ~= nil then return n ~= 0 end
    local s = tostring(v):lower():gsub('%s+', '')
    return s == 'true' or s == 'yes' or s == 'on'
end

local function colorFrom(value)
    if type(value) == 'string' then
        local s = value:gsub('#', ''):gsub('0x', '')
        if #s == 6 then
            local r, g, b = tonumber(s:sub(1,2), 16), tonumber(s:sub(3,4), 16), tonumber(s:sub(5,6), 16)
            if r and g and b then return { r = r, g = g, b = b } end
        end
    end
    if type(value) ~= 'table' then return nil end
    local r = tonumber(value.r or value.red or value[1])
    local g = tonumber(value.g or value.green or value[2])
    local b = tonumber(value.b or value.blue or value[3])
    if r and g and b then return { r = math.floor(r), g = math.floor(g), b = math.floor(b) } end
end

local function applyTuning(vehicle, raw)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local tuning = decodeTuning(raw)
    requestControl(vehicle, 1200)
    SetVehicleModKit(vehicle, 0)

    local primary = tonumber(tuning.primaryColor or tuning.primaryColour or tuning.primary)
    local secondary = tonumber(tuning.secondaryColor or tuning.secondaryColour or tuning.secondary)
    if primary or secondary then
        local oldP, oldS = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, primary or oldP or 0, secondary or oldS or 0)
    end

    local cp = colorFrom(tuning.customPrimaryColor or tuning.primaryCustomColor or tuning.primaryRGB or tuning.color1)
    if cp then SetVehicleCustomPrimaryColour(vehicle, cp.r, cp.g, cp.b) end
    local cs = colorFrom(tuning.customSecondaryColor or tuning.secondaryCustomColor or tuning.secondaryRGB or tuning.color2)
    if cs then SetVehicleCustomSecondaryColour(vehicle, cs.r, cs.g, cs.b) end

    local pearl, wheel = GetVehicleExtraColours(vehicle)
    pearl = tonumber(tuning.pearlColor or tuning.pearlescentColor or tuning.pearl) or pearl or 0
    wheel = tonumber(tuning.wheelColor or tuning.rimColor) or wheel or 0
    SetVehicleExtraColours(vehicle, pearl, wheel)

    if tuning.wheelType or tuning.wheels then SetVehicleWheelType(vehicle, tonumber(tuning.wheelType or tuning.wheels) or 0) end
    if tuning.windowTint then SetVehicleWindowTint(vehicle, tonumber(tuning.windowTint) or 0) end
    if tuning.plateIndex or tuning.plateType then SetVehicleNumberPlateTextIndex(vehicle, tonumber(tuning.plateIndex or tuning.plateType) or 0) end

    for key, modType in pairs(MOD_KEY_TYPES) do
        if tuning[key] ~= nil then
            local value = tonumber(tuning[key])
            if value == nil then value = -1 end
            SetVehicleMod(vehicle, modType, value, boolValue(tuning.customTires or tuning.customTyres))
        end
    end

    local aliases = { modEngine = 11, modBrakes = 12, modTransmission = 13, modSuspension = 15, modArmor = 16, modTurbo = 18, modXenon = 22, modLivery = 48, modFrontWheels = 23, modBackWheels = 24 }
    for key, modType in pairs(aliases) do
        if tuning[key] ~= nil then
            local value = tonumber(tuning[key])
            if modType == 18 or modType == 22 then
                ToggleVehicleMod(vehicle, modType, boolValue(tuning[key]))
            else
                if value == nil then value = -1 end
                SetVehicleMod(vehicle, modType, value, boolValue(tuning.customTires or tuning.customTyres))
            end
        end
    end

    if type(tuning.mods) == 'table' then
        for k, v in pairs(tuning.mods) do
            local modType = tonumber(k)
            if modType then
                local value = type(v) == 'table' and (v.mod or v.index or v.value) or v
                value = tonumber(value)
                if value == nil then value = -1 end
                SetVehicleMod(vehicle, modType, value, type(v) == 'table' and boolValue(v.customTires or v.customTyres) or boolValue(tuning.customTires or tuning.customTyres))
            end
        end
    end

    if tuning.turbo ~= nil then ToggleVehicleMod(vehicle, 18, boolValue(tuning.turbo)) end
    if tuning.xenon ~= nil then ToggleVehicleMod(vehicle, 22, boolValue(tuning.xenon)) end
    if tuning.xenonColor ~= nil then ToggleVehicleMod(vehicle, 22, true); SetVehicleXenonLightsColor(vehicle, tonumber(tuning.xenonColor) or 0) end

    local neon = colorFrom(tuning.neonColor or tuning.neon)
    if neon then
        SetVehicleNeonLightsColour(vehicle, neon.r, neon.g, neon.b)
        for i = 0, 3 do SetVehicleNeonLightEnabled(vehicle, i, true) end
    end

    if type(tuning.extras or tuning.extra) == 'table' then
        for k, v in pairs(tuning.extras or tuning.extra) do
            local id = tonumber(k)
            if id then SetVehicleExtra(vehicle, id, boolValue(v) and 0 or 1) end
        end
    end

    if tuning.livery ~= nil then SetVehicleLivery(vehicle, tonumber(tuning.livery) or 0) end
end

local function normalizeModel(value)
    local function pick(t)
        if type(t) ~= 'table' then return nil end
        for _, k in ipairs({ 'model', 'vehicle_model', 'spawn', 'spawnName', 'hash', 'name', 'vehicle' }) do
            if t[k] and tostring(t[k]) ~= '' then return t[k] end
        end
    end
    if type(value) == 'table' then value = pick(value) end
    local text = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text:sub(1,1) == '{' or text:sub(1,1) == '[' then
        local ok, decoded = pcall(json.decode, text)
        if ok and type(decoded) == 'table' then
            local p = pick(decoded)
            if p then text = tostring(p) end
        end
    end
    return text:gsub('^`', ''):gsub('`$', ''):gsub('^"', ''):gsub('"$', ''):gsub('%s+', '')
end

local function loadVehicleModel(model)
    model = normalizeModel(model)
    local candidates = { model, model:lower(), model:upper() }
    for _, candidate in ipairs(candidates) do
        local hash = tonumber(candidate) or joaat(candidate)
        if hash and hash ~= 0 and IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            RequestModel(hash)
            local timeout = GetGameTimer() + (Config.Vehicle.spawnTimeoutMs or 15000)
            while not HasModelLoaded(hash) and GetGameTimer() < timeout do
                RequestModel(hash)
                Wait(25)
            end
            if HasModelLoaded(hash) then return hash end
        end
    end
    return nil
end

local function protectVehicle(vehicle)
    if not Config.Vehicle.protectVehicle then return end
    SetEntityInvincible(vehicle, true)
    SetEntityCanBeDamaged(vehicle, false)
    SetVehicleCanBreak(vehicle, false)
    SetVehicleEngineCanDegrade(vehicle, false)
    SetVehicleTyresCanBurst(vehicle, false)
    SetVehicleWheelsCanBreak(vehicle, false)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
end

local function spawnRaceVehicle(vehicleData, start)
    local hash = loadVehicleModel(vehicleData.model)
    if not hash then return nil end
    local ped = PlayerPedId()
    local x, y, z, h = start.x, start.y, start.z, start.h or 0.0
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z + 0.3, false, false, false, false)
    SetEntityHeading(ped, h)
    Wait(250)
    local veh = CreateVehicle(hash, x, y, z + (Config.Vehicle.spawnZOffset or 0.55), h, true, false)
    if not veh or veh == 0 then return nil end
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, tostring(vehicleData.plate or 'DRIFT'):sub(1, 8))
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    protectVehicle(veh)

    local state = Entity(veh).state
    state:set('dz_race_vehicle', true, true)
    state:set('dz_race_room', activeRace and activeRace.roomId or 0, true)
    state:set('vehicleTunning', tostring(vehicleData.tuning or '{}'), true)
    state:set('dz_vehicle_tunning', tostring(vehicleData.tuning or '{}'), true)

    for _, delay in ipairs(Config.Vehicle.tuningApplyDelays or {100,350,750}) do
        SetTimeout(delay, function()
            if DoesEntityExist(veh) then applyTuning(veh, vehicleData.tuning) end
        end)
    end
    SetModelAsNoLongerNeeded(hash)
    return veh
end

local function cleanupRaceVehicle()
    local veh = raceVehicle
    raceVehicle = nil
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        requestControl(veh, 2000)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end
end

local function clearCheckpoint()
    SetWaypointOff()
    if finishBlip and DoesBlipExist(finishBlip) then RemoveBlip(finishBlip) end
    finishBlip = nil
    if finishCheckpoint then DeleteCheckpoint(finishCheckpoint) end
    finishCheckpoint = nil
end

local function createCheckpointFor(index)
    clearCheckpoint()
    if not activeRace then return end
    local cp = activeRace.checkpoints[index]
    if not cp then return end
    local coords = cp.coords
    local nextCp = activeRace.checkpoints[index + 1]
    local nextCoords = nextCp and nextCp.coords or coords

    finishBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(finishBlip, 1)
    SetBlipColour(finishBlip, 3)
    SetBlipScale(finishBlip, 0.95)
    SetBlipRoute(finishBlip, true)
    SetBlipRouteColour(finishBlip, 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cp.direction == 'finish' and 'Finish' or ('Checkpoint ' .. tostring(index)))
    EndTextCommandSetBlipName(finishBlip)

    finishCheckpoint = CreateCheckpoint(1, coords.x, coords.y, coords.z + 0.8, nextCoords.x, nextCoords.y, nextCoords.z, activeRace.checkpointRadius or 12.0, 4, 199, 247, 165, 0)
    SetCheckpointCylinderHeight(finishCheckpoint, 4.5, 4.5, activeRace.checkpointRadius or 12.0)
    sendNui({ action = 'raceHud', visible = true, direction = cp.direction or 'straight', index = index, total = #activeRace.checkpoints })
end

local function endLocalRace()
    raceEnded = true
    sendNui({ action = 'raceHud', visible = false })
    sendNui({ action = 'countdown', visible = false })
    clearCheckpoint()
    cleanupRaceVehicle()
    SetLocalPlayerAsGhost(false)
    NetworkSetFriendlyFireOption(true)
    activeRace = nil
    checkpointIndex = 1
    raceGhostThread = false
end

local function ghostLoop()
    if raceGhostThread then return end
    raceGhostThread = true
    CreateThread(function()
        while activeRace and raceVehicle and DoesEntityExist(raceVehicle) do
            if Config.Vehicle.ghostPlayers then
                SetLocalPlayerAsGhost(true)
                local myVeh = raceVehicle
                for _, ply in ipairs(GetActivePlayers()) do
                    if ply ~= PlayerId() then
                        local ped = GetPlayerPed(ply)
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 and DoesEntityExist(veh) then
                            SetEntityNoCollisionEntity(myVeh, veh, true)
                            SetEntityNoCollisionEntity(veh, myVeh, true)
                        end
                    end
                end
            end
            Wait(0)
        end
    end)
end

local function countdown(seconds)
    seconds = tonumber(seconds or Config.CountdownSeconds or 3) or 3
    for i = seconds, 1, -1 do
        sendNui({ action = 'countdown', visible = true, text = tostring(i) })
        Wait(1000)
    end
    sendNui({ action = 'countdown', visible = true, text = 'START' })
    Wait(750)
    sendNui({ action = 'countdown', visible = false })
end

RegisterNetEvent('driftzone_races:client:openFromInteraction', function()
    TriggerServerEvent('driftzone_races:server:open')
end)

RegisterNetEvent('driftzone_races:client:open', function(payload)
    openMenu(payload or {})
end)

RegisterNetEvent('driftzone_races:client:vehicles', function(payload)
    sendNui({ action = 'vehicles', raceId = payload.raceId, vehicles = payload.vehicles or {} })
end)

RegisterNetEvent('driftzone_races:client:rooms', function(rooms)
    sendNui({ action = 'rooms', rooms = rooms or {} })
end)

RegisterNetEvent('driftzone_races:client:roomUpdate', function(room)
    currentRoom = room
    sendNui({ action = 'room', room = room })
    setFocus(true)
end)

RegisterNetEvent('driftzone_races:client:leftRoom', function()
    currentRoom = nil
    sendNui({ action = 'leftRoom' })
end)

RegisterNetEvent('driftzone_races:client:startRace', function(payload)
    closeMenu(false)
    raceEnded = false
    activeRace = payload
    checkpointIndex = 1
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)

    raceVehicle = spawnRaceVehicle(payload.vehicle, payload.start)
    if not raceVehicle then
        FreezeEntityPosition(ped, false)
        notify('error', 'Nu s-a putut spawna masina pentru cursa.', 5000)
        return
    end

    if Config.Vehicle.freezeDuringCountdown then
        FreezeEntityPosition(raceVehicle, true)
        SetVehicleHandbrake(raceVehicle, true)
    end

    ghostLoop()
    countdown(payload.countdown or Config.CountdownSeconds)

    FreezeEntityPosition(ped, false)
    if raceVehicle and DoesEntityExist(raceVehicle) then
        FreezeEntityPosition(raceVehicle, false)
        SetVehicleHandbrake(raceVehicle, false)
        SetVehicleEngineOn(raceVehicle, true, true, false)
    end

    createCheckpointFor(checkpointIndex)
end)

RegisterNetEvent('driftzone_races:client:raceFinished', function(result)
    local won = result and result.won == true
    if won then
        notify('success', ('Ai castigat cursa si ai primit $%s.'):format(tostring(result.prize or 0)), 8000)
    else
        notify('warning', ('Cursa a fost castigata de %s.'):format(tostring(result.winnerName or 'alt jucator')), 8000)
    end
    sendNui({ action = 'finishScreen', result = result or {} })
    Wait(2500)
    endLocalRace()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb({ ok = true })
end)

RegisterNUICallback('getVehicles', function(data, cb)
    TriggerServerEvent('driftzone_races:server:getVehicles', data and data.raceId)
    cb({ ok = true })
end)

RegisterNUICallback('refreshRooms', function(_, cb)
    TriggerServerEvent('driftzone_races:server:refreshRooms')
    cb({ ok = true })
end)

RegisterNUICallback('createRoom', function(data, cb)
    TriggerServerEvent('driftzone_races:server:createRoom', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('joinRoom', function(data, cb)
    TriggerServerEvent('driftzone_races:server:joinRoom', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('readyRoom', function(data, cb)
    TriggerServerEvent('driftzone_races:server:setReady', data and data.ready == true)
    cb({ ok = true })
end)

RegisterNUICallback('leaveRoom', function(_, cb)
    TriggerServerEvent('driftzone_races:server:leaveRoom')
    cb({ ok = true })
end)

RegisterCommand('draces', function()
    TriggerServerEvent('driftzone_races:server:open')
end, false)

CreateThread(function()
    while true do
        if activeRace and raceVehicle and DoesEntityExist(raceVehicle) and not raceEnded then
            local ped = PlayerPedId()
            local cp = activeRace.checkpoints and activeRace.checkpoints[checkpointIndex]
            if cp then
                local coords = GetEntityCoords(ped)
                local dist = #(coords - vector3(cp.coords.x, cp.coords.y, cp.coords.z))
                if dist <= (activeRace.checkpointRadius or Config.CheckpointRadius or 12.0) then
                    TriggerServerEvent('driftzone_races:server:checkpoint', activeRace.roomId, checkpointIndex)
                    if cp.direction == 'finish' or checkpointIndex >= #activeRace.checkpoints then
                        raceEnded = true
                        TriggerServerEvent('driftzone_races:server:finish', activeRace.roomId)
                    else
                        checkpointIndex = checkpointIndex + 1
                        createCheckpointFor(checkpointIndex)
                    end
                    Wait(750)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    endLocalRace()
    SetNuiFocus(false, false)
end)
