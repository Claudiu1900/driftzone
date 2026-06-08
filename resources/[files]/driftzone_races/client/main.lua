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
local lobbyUiHidden = false

local MOD_KEY_TYPES = {
    spoiler = 0, frontBumper = 1, rearBumper = 2, sideSkirt = 3, exhaust = 4, frame = 5, grille = 6,
    hood = 7, fender = 8, rightFender = 9, roof = 10, engine = 11, brakes = 12, transmission = 13,
    horns = 14, suspension = 15, armor = 16, turbo = 18, xenon = 22, frontWheels = 23, backWheels = 24,
    livery = 48
}

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 5000, tostring(msg or ''))
end

local function setGarageBlockedLocal(state)
    TriggerEvent('driftzone_garage:client:setBlocked', state == true, 'Garaj indisponibil.')
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
    lobbyUiHidden = false
    payload = payload or {}
    payload.action = 'open'
    payload.mainColor = Config.MainColor
    sendNui(payload)
    setFocus(true)
end

local function closeMenu(sendServer)
    if currentRoom and not activeRace then lobbyUiHidden = true end
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

    -- Unele garaje salveaza tuning-ul sub un wrapper: props/properties/mods/vehicleTunning.
    local function unwrap(t)
        if type(t) ~= 'table' then return t end
        local wrappedKeys = {
            'vehicleTunning', 'vehicle_tunning', 'dz_vehicle_tunning', 'dz_garage_tuning',
            'props', 'properties', 'vehicleProps', 'vehicleProperties', 'modsData', 'tuning'
        }
        for _, key in ipairs(wrappedKeys) do
            local v = t[key]
            if type(v) == 'string' then
                local decoded = decodeTuning(v)
                if type(decoded) == 'table' and next(decoded) ~= nil then return decoded end
            elseif type(v) == 'table' and next(v) ~= nil then
                return v
            end
        end
        return t
    end
    tuning = unwrap(tuning)
    if type(tuning) ~= 'table' then tuning = {} end

    requestControl(vehicle, 3500)
    SetVehicleModKit(vehicle, 0)

    local function toNumber(value, fallback)
        local n = tonumber(value)
        if n == nil then return fallback end
        return n
    end

    local function setToggle(modType, value)
        ToggleVehicleMod(vehicle, tonumber(modType), boolValue(value))
    end

    local function setNumberMod(modType, value, customTires)
        modType = tonumber(modType)
        if not modType or modType < 0 or modType > 60 then return end
        local modValue = tonumber(value)
        if modValue == nil then modValue = -1 end
        SetVehicleMod(vehicle, modType, modValue, boolValue(customTires))
    end

    -- Formate uzuale: ESX/QB/vRP/custom garage.
    local modMap = {
        spoiler = 0, spoilers = 0, frontBumper = 1, rearBumper = 2, sideSkirt = 3, exhaust = 4,
        frame = 5, grille = 6, hood = 7, fender = 8, rightFender = 9, roof = 10,
        engine = 11, brakes = 12, transmission = 13, horn = 14, horns = 14, suspension = 15, armor = 16,
        turbo = 18, tyreSmoke = 20, tireSmoke = 20, xenon = 22,
        frontWheels = 23, wheelsMod = 23, backWheels = 24, plateHolder = 25, vanityPlate = 26,
        vanityPlates = 26, trimA = 27, trimDesign = 27, ornaments = 28, dashboard = 29, dial = 30,
        doorSpeaker = 31, seats = 32, steeringWheel = 33, shiftLever = 34, shiftLeavers = 34,
        plaques = 35, speakers = 36, trunk = 37, hydraulics = 38, hydrolic = 38,
        engineBlock = 39, airFilter = 40, struts = 41, archCover = 42, aerials = 43,
        trimB = 44, trim = 44, tank = 45, windows = 46, livery = 48,

        modSpoilers = 0, modFrontBumper = 1, modRearBumper = 2, modSideSkirt = 3, modExhaust = 4,
        modFrame = 5, modGrille = 6, modHood = 7, modFender = 8, modRightFender = 9, modRoof = 10,
        modEngine = 11, modBrakes = 12, modTransmission = 13, modHorns = 14, modSuspension = 15,
        modArmor = 16, modTurbo = 18, modSmokeEnabled = 20, modXenon = 22,
        modFrontWheels = 23, modBackWheels = 24, modPlateHolder = 25, modVanityPlate = 26,
        modTrimA = 27, modOrnaments = 28, modDashboard = 29, modDial = 30, modDoorSpeaker = 31,
        modSeats = 32, modSteeringWheel = 33, modShifterLeavers = 34, modAPlate = 35,
        modSpeakers = 36, modTrunk = 37, modHydrolic = 38, modEngineBlock = 39,
        modAirFilter = 40, modStruts = 41, modArchCover = 42, modAerials = 43,
        modTrimB = 44, modTank = 45, modWindows = 46, modLivery = 48
    }

    local customTires = tuning.customTires or tuning.customTyres or tuning.modCustomTiresF or tuning.modCustomTiresR

    -- Culori standard.
    local color1 = tuning.color1 or tuning.primaryColor or tuning.primaryColour or tuning.primary
    local color2 = tuning.color2 or tuning.secondaryColor or tuning.secondaryColour or tuning.secondary
    if color1 ~= nil or color2 ~= nil then
        local old1, old2 = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, toNumber(color1, old1 or 0), toNumber(color2, old2 or 0))
    end

    -- Culori extra/pearlescent/wheels.
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    pearl = toNumber(tuning.pearlescentColor or tuning.pearlColor or tuning.pearl or tuning.pearlescentColour, pearl or 0)
    wheel = toNumber(tuning.wheelColor or tuning.rimColor or tuning.wheelColour, wheel or 0)
    SetVehicleExtraColours(vehicle, pearl, wheel)

    -- RGB custom.
    local cp = colorFrom(tuning.customPrimaryColor or tuning.primaryCustomColor or tuning.primaryRGB or tuning.rgbColor1 or tuning.customColor1 or tuning.primaryColorCustom or (type(tuning.colors) == 'table' and tuning.colors.primary))
    if cp then SetVehicleCustomPrimaryColour(vehicle, cp.r, cp.g, cp.b) end

    local cs = colorFrom(tuning.customSecondaryColor or tuning.secondaryCustomColor or tuning.secondaryRGB or tuning.rgbColor2 or tuning.customColor2 or tuning.secondaryColorCustom or (type(tuning.colors) == 'table' and tuning.colors.secondary))
    if cs then SetVehicleCustomSecondaryColour(vehicle, cs.r, cs.g, cs.b) end

    if tuning.dashboardColor ~= nil or tuning.dashboardColour ~= nil then SetVehicleDashboardColour(vehicle, toNumber(tuning.dashboardColor or tuning.dashboardColour, 0)) end
    if tuning.interiorColor ~= nil or tuning.interiorColour ~= nil then SetVehicleInteriorColour(vehicle, toNumber(tuning.interiorColor or tuning.interiorColour, 0)) end
    if tuning.windowTint ~= nil or tuning.modWindows ~= nil then SetVehicleWindowTint(vehicle, toNumber(tuning.windowTint or tuning.modWindows, 0)) end
    if tuning.plateIndex ~= nil or tuning.plateType ~= nil then SetVehicleNumberPlateTextIndex(vehicle, toNumber(tuning.plateIndex or tuning.plateType, 0)) end
    if tuning.plateText or tuning.plate then SetVehicleNumberPlateText(vehicle, tostring(tuning.plateText or tuning.plate):sub(1, 8)) end

    if tuning.wheelType ~= nil or tuning.wheels ~= nil or tuning.modWheelType ~= nil then
        SetVehicleWheelType(vehicle, toNumber(tuning.wheelType or tuning.wheels or tuning.modWheelType, 0))
    end

    -- Mods cu chei directe.
    for key, modType in pairs(modMap) do
        if tuning[key] ~= nil then
            if modType == 18 or modType == 20 or modType == 22 then
                setToggle(modType, tuning[key])
                local n = tonumber(tuning[key])
                if n and n >= 0 and modType ~= 18 then setNumberMod(modType, n, customTires) end
            else
                setNumberMod(modType, tuning[key], customTires)
            end
        end
    end

    -- Mods in tabela: mods = { [11] = 3 } sau { engine = 3 } sau lista cu {modType=11, modIndex=3}.
    local function applyModEntry(key, value)
        local modType = tonumber(key) or modMap[key]
        local modValue = value
        local custom = customTires

        if type(value) == 'table' then
            modType = tonumber(value.modType or value.type or value.id or value[1]) or modType
            modValue = value.mod or value.index or value.value or value.modIndex or value[2]
            custom = value.customTires or value.customTyres or custom
        end

        if modType then
            if modType == 18 or modType == 20 or modType == 22 then
                setToggle(modType, modValue)
                local n = tonumber(modValue)
                if n and n >= 0 and modType ~= 18 then setNumberMod(modType, n, custom) end
            else
                setNumberMod(modType, modValue, custom)
            end
        end
    end

    if type(tuning.mods) == 'table' then
        for key, value in pairs(tuning.mods) do applyModEntry(key, value) end
    end
    if type(tuning.modifications) == 'table' then
        for key, value in pairs(tuning.modifications) do applyModEntry(key, value) end
    end

    -- Chei numerice directe: [11] = 3 sau ["mod11"] = 3.
    for key, value in pairs(tuning) do
        local modType = tonumber(key)
        if modType then applyModEntry(modType, value) end
        local modFromText = tostring(key):match('^mod(%d+)$')
        if modFromText then applyModEntry(tonumber(modFromText), value) end
    end

    -- Toggle-uri finale.
    if tuning.turbo ~= nil or tuning.modTurbo ~= nil then setToggle(18, tuning.turbo ~= nil and tuning.turbo or tuning.modTurbo) end
    if tuning.xenon ~= nil or tuning.modXenon ~= nil then setToggle(22, tuning.xenon ~= nil and tuning.xenon or tuning.modXenon) end
    if tuning.tireSmoke ~= nil or tuning.tyreSmoke ~= nil or tuning.smokeEnabled ~= nil then setToggle(20, tuning.tireSmoke or tuning.tyreSmoke or tuning.smokeEnabled) end

    if tuning.xenonColor ~= nil or tuning.xenonColour ~= nil then
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsColor(vehicle, toNumber(tuning.xenonColor or tuning.xenonColour, 0))
    end

    local neonColor = colorFrom(tuning.neonColor or tuning.neonColour or tuning.neon)
    if neonColor then SetVehicleNeonLightsColour(vehicle, neonColor.r, neonColor.g, neonColor.b) end

    local neonEnabled = tuning.neonEnabled or tuning.neonsEnabled or tuning.neon
    if type(neonEnabled) == 'table' and not neonColor then
        for i = 0, 3 do
            local state = neonEnabled[i] or neonEnabled[i + 1]
            if state ~= nil then SetVehicleNeonLightEnabled(vehicle, i, boolValue(state)) end
        end
    elseif type(neonEnabled) == 'table' then
        for i = 0, 3 do
            local state = neonEnabled[i] or neonEnabled[i + 1]
            if state ~= nil then SetVehicleNeonLightEnabled(vehicle, i, boolValue(state)) else SetVehicleNeonLightEnabled(vehicle, i, true) end
        end
    elseif neonColor or boolValue(neonEnabled) then
        for i = 0, 3 do SetVehicleNeonLightEnabled(vehicle, i, true) end
    end

    local smoke = colorFrom(tuning.tyreSmokeColor or tuning.tireSmokeColor or tuning.smokeColor)
    if smoke then
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, smoke.r, smoke.g, smoke.b)
    end

    local extras = tuning.extras or tuning.extra
    if type(extras) == 'table' then
        for key, value in pairs(extras) do
            local extraId = tonumber(key)
            if extraId and DoesExtraExist(vehicle, extraId) then
                -- GTA: 0 = enabled, 1 = disabled.
                SetVehicleExtra(vehicle, extraId, boolValue(value) and 0 or 1)
            end
        end
    end

    if tuning.livery ~= nil then SetVehicleLivery(vehicle, toNumber(tuning.livery, 0)) end
    if tuning.modLivery ~= nil then SetVehicleMod(vehicle, 48, toNumber(tuning.modLivery, -1), false) end

    -- Sanatate/fuel/dirt fara sa resetam modificarile vizuale.
    SetVehicleDirtLevel(vehicle, tonumber(tuning.dirtLevel or 0.0) or 0.0)
    SetVehicleEngineHealth(vehicle, tonumber(tuning.engineHealth or tuning.engine or 1000.0) or 1000.0)
    SetVehicleBodyHealth(vehicle, tonumber(tuning.bodyHealth or tuning.body or 1000.0) or 1000.0)
    SetVehiclePetrolTankHealth(vehicle, tonumber(tuning.tankHealth or 1000.0) or 1000.0)
end

local function forceRaceVehicleTuning(vehicle, raw)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local tuningRaw = raw
    if type(tuningRaw) == 'table' then
        local ok, encoded = pcall(json.encode, tuningRaw)
        tuningRaw = ok and encoded or '{}'
    end
    tuningRaw = tostring(tuningRaw or '{}')
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local state = Entity(vehicle).state
    state:set('dz_race_tuning', tuningRaw, true)
    state:set('dz_garage_tuning', tuningRaw, true)
    state:set('vehicleTunning', tuningRaw, true)
    state:set('dz_vehicle_tunning', tuningRaw, true)

    applyTuning(vehicle, tuningRaw)

    -- Compatibilitate cu orice tuning/garage existent pe server.
    pcall(function() TriggerEvent('client:tunning:applyVehicle', vehicle, tuningRaw) end)
    pcall(function() TriggerEvent('client:tunning:applyVehicle', netId, tuningRaw) end)
    pcall(function() TriggerEvent('driftzone_tunning:client:applyVehicle', vehicle, tuningRaw) end)
    pcall(function() TriggerEvent('driftzone_tunning:client:applyVehicle', netId, tuningRaw) end)
    pcall(function() TriggerEvent('driftzone_garage:client:applyVehicleTuning', vehicle, tuningRaw) end)
    pcall(function() TriggerEvent('driftzone_garage:client:applyVehicleTuning', netId, tuningRaw) end)
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
    local tuningRaw = tostring(vehicleData.tuning or '{}')
    state:set('vehicleTunning', tuningRaw, true)
    state:set('dz_vehicle_tunning', tuningRaw, true)
    state:set('dz_race_tuning', tuningRaw, true)
    state:set('dz_garage_tuning', tuningRaw, true)

    forceRaceVehicleTuning(veh, tuningRaw)
    for _, delay in ipairs(Config.Vehicle.tuningApplyDelays or { 50, 150, 350, 750, 1400, 2400, 3600, 5200 }) do
        SetTimeout(delay, function()
            if DoesEntityExist(veh) then forceRaceVehicleTuning(veh, tuningRaw) end
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

local function returnToRaceHub(pos)
    pos = pos or Config.ReturnPosition
    if not pos then return end
    local ped = PlayerPedId()
    local x = tonumber(pos.x or pos[1]) or 0.0
    local y = tonumber(pos.y or pos[2]) or 0.0
    local z = tonumber(pos.z or pos[3]) or 0.0
    local h = tonumber(pos.h or pos.w or pos[4]) or 0.0
    RequestCollisionAtCoord(x, y, z)
    local timeout = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(25)
    end
    SetEntityCoords(ped, x, y, z + 0.15, false, false, false, false)
    SetEntityHeading(ped, h)
    ClearPedTasksImmediately(ped)
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

    local checkpointType = (cp.direction == 'finish') and 4 or 1
    finishCheckpoint = CreateCheckpoint(checkpointType, coords.x, coords.y, coords.z + 0.8, nextCoords.x, nextCoords.y, nextCoords.z, activeRace.checkpointRadius or 12.0, 4, 199, 247, 165, 0)
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
    currentRoom = nil
    lobbyUiHidden = false
    checkpointIndex = 1
    raceGhostThread = false
    setGarageBlockedLocal(false)
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


local function forceOpenRoom(room, message)
    currentRoom = room
    lobbyUiHidden = false
    sendNui({ action = 'forceRoom', room = room, message = message or '' })
    setFocus(true)
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

RegisterNetEvent('driftzone_races:client:roomUpdate', function(room, forceOpen)
    currentRoom = room
    if forceOpen == true then
        forceOpenRoom(room, '')
        return
    end

    sendNui({ action = 'room', room = room, forceOpen = false })

    if not lobbyUiHidden then
        setFocus(true)
    end
end)

RegisterNetEvent('driftzone_races:client:createdRoom', function(room)
    forceOpenRoom(room, 'Party-ul a fost creat cu succes.')
end)

RegisterNetEvent('driftzone_races:client:joinedRoom', function(room)
    forceOpenRoom(room, 'Ai intrat in party.')
end)

RegisterNetEvent('driftzone_races:client:leftRoom', function()
    currentRoom = nil
    lobbyUiHidden = false
    sendNui({ action = 'leftRoom' })
end)

RegisterNetEvent('driftzone_races:client:startRace', function(payload)
    lobbyUiHidden = false
    closeMenu(false)
    setGarageBlockedLocal(true)
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
        setGarageBlockedLocal(false)
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
    result = result or {}
    local won = result.won == true
    if won then
        notify('success', ('Ai castigat cursa si ai primit $%s.'):format(tostring(result.prize or 0)), 8000)
    else
        notify('warning', ('Cursa a fost castigata de %s.'):format(tostring(result.winnerName or 'alt jucator')), 8000)
    end
    sendNui({ action = 'finishScreen', result = result })
    Wait(2500)
    endLocalRace()
    Wait(150)
    returnToRaceHub(result.returnPosition or Config.ReturnPosition)
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
