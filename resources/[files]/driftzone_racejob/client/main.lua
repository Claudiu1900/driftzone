local nuiReady = false
local menuOpen = false
local activeRace = nil
local raceVehicle = nil
local finishBlip = nil
local finishCheckpoint = nil
local raceEnding = false
local countdownActive = false
local currentDuoSession = nil

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
    if sendServer == true then TriggerServerEvent('driftzone_racejob:server:close') end
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds or 0) or 0))
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function requestControl(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local timeout = GetGameTimer() + (timeoutMs or 1500)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(25)
    end
    return NetworkHasControlOfEntity(entity)
end

local function clearRoute()
    SetWaypointOff()
    if finishBlip and DoesBlipExist(finishBlip) then RemoveBlip(finishBlip) end
    finishBlip = nil
    if finishCheckpoint then DeleteCheckpoint(finishCheckpoint) end
    finishCheckpoint = nil
end

local function cleanupVehicle()
    local veh = raceVehicle
    raceVehicle = nil
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        requestControl(veh, 2000)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end
end

local function returnPlayer(pos)
    pos = pos or {}
    local ped = PlayerPedId()
    local x = tonumber(pos.x or 0.0) or 0.0
    local y = tonumber(pos.y or 0.0) or 0.0
    local z = tonumber(pos.z or 0.0) or 0.0
    local h = tonumber(pos.h or pos.w or 0.0) or 0.0
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z + 0.1, false, false, false, false)
    SetEntityHeading(ped, h)
end

local function endLocalRace()
    raceEnding = true
    countdownActive = false
    sendNui({ action = 'raceHud', visible = false })
    sendNui({ action = 'countdown', visible = false })
    clearRoute()
    cleanupVehicle()
    activeRace = nil
    currentDuoSession = nil
    raceEnding = false
end

local function normalizeModel(value)
    local function pickFromTable(t)
        if type(t) ~= 'table' then return nil end
        local keys = { 'model', 'vehicle_model', 'spawn', 'spawnName', 'hash', 'name', 'vehicle', 'vehicleName' }
        for _, key in ipairs(keys) do
            local v = t[key]
            if v ~= nil and tostring(v) ~= '' then return v end
        end
        for _, v in pairs(t) do
            if type(v) == 'table' then
                local found = pickFromTable(v)
                if found then return found end
            elseif type(v) == 'string' or type(v) == 'number' then
                local text = tostring(v)
                if text ~= '' and text ~= '0' and not text:find('[{}%[%]]') then return text end
            end
        end
        return nil
    end

    if type(value) == 'table' then value = pickFromTable(value) or value.model or value[1] end
    local text = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text:sub(1, 1) == '{' or text:sub(1, 1) == '[' then
        local ok, decoded = pcall(json.decode, text)
        if ok and type(decoded) == 'table' then
            local picked = pickFromTable(decoded)
            if picked then text = tostring(picked) end
        end
    end
    text = text:gsub('^"', ''):gsub('"$', ''):gsub('^`', ''):gsub('`$', '')
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    return text
end

local function loadVehicleModel(model, timeoutMs)
    model = normalizeModel(model)
    local candidates = {}
    local function add(v)
        v = tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if v ~= '' then candidates[#candidates + 1] = v end
    end
    add(model)
    add(model:lower())
    add(model:upper())
    add(model:gsub('%s+', ''))
    add(model:gsub('vehicle_', ''))

    for _, candidate in ipairs(candidates) do
        local hash = tonumber(candidate) or joaat(candidate)
        if hash and hash ~= 0 and IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            RequestModel(hash)
            local timeout = GetGameTimer() + (timeoutMs or 15000)
            while not HasModelLoaded(hash) and GetGameTimer() < timeout do
                RequestModel(hash)
                Wait(25)
            end
            if HasModelLoaded(hash) then return hash, nil end
        end
    end

    return nil, 'model_not_loaded'
end

local function decodeTuning(raw)
    if type(raw) == 'table' then return raw end

    raw = tostring(raw or '{}')
    if raw == '' or raw == 'null' or raw == 'nil' then return {} end

    -- Unele tabele salveaza JSON dublu-encodat: "{...}".
    for _ = 1, 3 do
        local ok, decoded = pcall(json.decode, raw)
        if not ok then break end
        if type(decoded) == 'table' then return decoded end
        if type(decoded) == 'string' then
            raw = decoded
        else
            break
        end
    end

    return {}
end

local function boolValue(value)
    if value == true then return true end
    if value == false or value == nil then return false end
    local n = tonumber(value)
    if n ~= nil then return n ~= 0 end
    local text = tostring(value):lower():gsub('%s+', '')
    return text == 'true' or text == 'yes' or text == 'on'
end

local function parseHexColor(value)
    local text = tostring(value or ''):gsub('#', ''):gsub('0x', '')
    if #text ~= 6 then return nil end

    local r = tonumber(text:sub(1, 2), 16)
    local g = tonumber(text:sub(3, 4), 16)
    local b = tonumber(text:sub(5, 6), 16)

    if r and g and b then
        return { r = r, g = g, b = b }
    end

    return nil
end

local function colorFrom(value)
    if type(value) == 'string' then
        return parseHexColor(value)
    end

    if type(value) ~= 'table' then return nil end

    local r = tonumber(value.r or value.red or value[1])
    local g = tonumber(value.g or value.green or value[2])
    local b = tonumber(value.b or value.blue or value[3])

    if r and g and b then
        return {
            r = math.floor(math.max(0, math.min(255, r))),
            g = math.floor(math.max(0, math.min(255, g))),
            b = math.floor(math.max(0, math.min(255, b)))
        }
    end

    return nil
end

local function setNumberMod(vehicle, modType, value, customTires)
    modType = tonumber(modType)
    if not modType or modType < 0 or modType > 60 then return end

    value = tonumber(value)
    if value == nil then value = -1 end

    SetVehicleMod(vehicle, modType, value, customTires == true)
end

local function applyColorData(vehicle, tuning)
    local primaryNumeric = tonumber(tuning.primaryColor or tuning.primaryColour or tuning.primary)
    local secondaryNumeric = tonumber(tuning.secondaryColor or tuning.secondaryColour or tuning.secondary)

    if primaryNumeric ~= nil or secondaryNumeric ~= nil then
        local oldPrimary, oldSecondary = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, primaryNumeric or oldPrimary or 0, secondaryNumeric or oldSecondary or 0)
    end

    local customPrimary = colorFrom(
        tuning.customPrimaryColor or tuning.primaryCustomColor or tuning.primaryRGB or tuning.color1 or
        tuning.primaryColorCustom or (type(tuning.colors) == 'table' and tuning.colors.primary)
    )
    if customPrimary then
        SetVehicleCustomPrimaryColour(vehicle, customPrimary.r, customPrimary.g, customPrimary.b)
    end

    local customSecondary = colorFrom(
        tuning.customSecondaryColor or tuning.secondaryCustomColor or tuning.secondaryRGB or tuning.color2 or
        tuning.secondaryColorCustom or (type(tuning.colors) == 'table' and tuning.colors.secondary)
    )
    if customSecondary then
        SetVehicleCustomSecondaryColour(vehicle, customSecondary.r, customSecondary.g, customSecondary.b)
    end

    local pearl, wheel = GetVehicleExtraColours(vehicle)
    if tuning.pearlColor ~= nil or tuning.pearlescentColor ~= nil or tuning.pearl ~= nil then
        pearl = tonumber(tuning.pearlColor or tuning.pearlescentColor or tuning.pearl) or pearl or 0
    end
    if tuning.wheelColor ~= nil or tuning.rimColor ~= nil then
        wheel = tonumber(tuning.wheelColor or tuning.rimColor) or wheel or 0
    end
    SetVehicleExtraColours(vehicle, pearl or 0, wheel or 0)

    if tuning.dashboardColor ~= nil then
        SetVehicleDashboardColour(vehicle, tonumber(tuning.dashboardColor) or 0)
    end

    if tuning.interiorColor ~= nil then
        SetVehicleInteriorColour(vehicle, tonumber(tuning.interiorColor) or 0)
    end

    if tuning.windowTint ~= nil then
        SetVehicleWindowTint(vehicle, tonumber(tuning.windowTint) or 0)
    end

    if tuning.plateIndex ~= nil or tuning.plateType ~= nil then
        SetVehicleNumberPlateTextIndex(vehicle, tonumber(tuning.plateIndex or tuning.plateType) or 0)
    end

    if tuning.xenonColor ~= nil then
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsColor(vehicle, tonumber(tuning.xenonColor) or 0)
    end

    local neonColor = colorFrom(tuning.neonColor or tuning.neon)
    if neonColor then
        SetVehicleNeonLightsColour(vehicle, neonColor.r, neonColor.g, neonColor.b)
    end

    local neonEnabled = tuning.neonEnabled or tuning.neonsEnabled
    if type(neonEnabled) == 'table' then
        for i = 0, 3 do
            local state = neonEnabled[i] or neonEnabled[i + 1]
            if state ~= nil then SetVehicleNeonLightEnabled(vehicle, i, boolValue(state)) end
        end
    elseif neonColor or boolValue(neonEnabled) then
        for i = 0, 3 do SetVehicleNeonLightEnabled(vehicle, i, true) end
    end

    local smoke = colorFrom(tuning.tyreSmokeColor or tuning.tireSmokeColor or tuning.smokeColor)
    if smoke then
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, smoke.r, smoke.g, smoke.b)
    end
end

local function applyNumberMods(vehicle, tuning)
    if tuning.wheelType ~= nil or tuning.wheels ~= nil then
        SetVehicleWheelType(vehicle, tonumber(tuning.wheelType or tuning.wheels) or 0)
    end

    for key, modType in pairs(MOD_KEY_TYPES) do
        if tuning[key] ~= nil then
            setNumberMod(vehicle, modType, tuning[key], tuning.customTires or tuning.customTyres)
        end
    end

    -- Compatibilitate cu chei de tip modEngine/modBrakes/modSpoilers etc.
    local aliases = {
        modSpoilers = 0, modFrontBumper = 1, modRearBumper = 2, modSideSkirt = 3, modExhaust = 4,
        modFrame = 5, modGrille = 6, modHood = 7, modFender = 8, modRightFender = 9, modRoof = 10,
        modEngine = 11, modBrakes = 12, modTransmission = 13, modHorns = 14, modSuspension = 15,
        modArmor = 16, modTurbo = 18, modXenon = 22, modFrontWheels = 23, modBackWheels = 24,
        modPlateHolder = 25, modVanityPlate = 26, modTrimA = 27, modOrnaments = 28, modDashboard = 29,
        modDial = 30, modDoorSpeaker = 31, modSeats = 32, modSteeringWheel = 33, modShifterLeavers = 34,
        modAPlate = 35, modSpeakers = 36, modTrunk = 37, modHydrolic = 38, modEngineBlock = 39,
        modAirFilter = 40, modStruts = 41, modArchCover = 42, modAerials = 43, modTrimB = 44,
        modTank = 45, modWindows = 46, modLivery = 48
    }
    for key, modType in pairs(aliases) do
        if tuning[key] ~= nil then
            setNumberMod(vehicle, modType, tuning[key], tuning.customTires or tuning.customTyres)
        end
    end

    -- Compatibilitate cu tuning.mods = { [11] = 3 }.
    if type(tuning.mods) == 'table' then
        for key, value in pairs(tuning.mods) do
            local modType = tonumber(key)
            if modType then
                if type(value) == 'table' then
                    setNumberMod(vehicle, modType, value.mod or value.index or value.value, value.customTires or value.customTyres)
                else
                    setNumberMod(vehicle, modType, value, tuning.customTires or tuning.customTyres)
                end
            end
        end
    end

    -- Compatibilitate cu chei numerice directe: "11": 3.
    for key, value in pairs(tuning) do
        local modType = tonumber(key)
        if modType then setNumberMod(vehicle, modType, value, tuning.customTires or tuning.customTyres) end

        local modFromText = tostring(key):match('^mod(%d+)$')
        if modFromText then setNumberMod(vehicle, tonumber(modFromText), value, tuning.customTires or tuning.customTyres) end
    end
end

local function applyToggleMods(vehicle, tuning)
    local turbo = tuning.turbo
    if turbo == nil then turbo = tuning.modTurbo end
    if turbo ~= nil then ToggleVehicleMod(vehicle, 18, boolValue(turbo)) end

    local xenon = tuning.xenon
    if xenon == nil then xenon = tuning.modXenon end
    if xenon ~= nil then ToggleVehicleMod(vehicle, 22, boolValue(xenon)) end

    local tireSmoke = tuning.tireSmoke or tuning.tyreSmoke or tuning.smokeEnabled
    if tireSmoke ~= nil then ToggleVehicleMod(vehicle, 20, boolValue(tireSmoke)) end
end

local function applyExtras(vehicle, tuning)
    local extras = tuning.extras or tuning.extra
    if type(extras) ~= 'table' then return end

    for key, value in pairs(extras) do
        local extraId = tonumber(key) or tonumber(value and value.id)
        if extraId and DoesExtraExist(vehicle, extraId) then
            local enabled
            if type(value) == 'table' then
                enabled = value.enabled
                if enabled == nil then enabled = value.state end
            else
                enabled = value
            end
            SetVehicleExtra(vehicle, extraId, boolValue(enabled) and 0 or 1)
        end
    end
end

local function applyLivery(vehicle, tuning)
    local livery = tuning.livery or tuning.modLivery
    if livery ~= nil then
        local value = tonumber(livery) or 0
        SetVehicleLivery(vehicle, value)
        SetVehicleMod(vehicle, 48, value, false)
    end
end

local function applyTuning(vehicle, raw)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    requestControl(vehicle, 2500)
    SetVehicleModKit(vehicle, 0)

    local tuning = decodeTuning(raw)
    if type(tuning) ~= 'table' then return false end

    applyColorData(vehicle, tuning)
    applyNumberMods(vehicle, tuning)
    applyToggleMods(vehicle, tuning)
    applyExtras(vehicle, tuning)
    applyLivery(vehicle, tuning)

    if tuning.plate ~= nil then
        SetVehicleNumberPlateText(vehicle, tostring(tuning.plate):sub(1, 8))
    end

    return true
end

local function forceTuning(vehicle, raw, vehicleData)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    raw = raw or '{}'
    local netId = VehToNet(vehicle)

    if netId and netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
    end

    local state = Entity(vehicle).state
    state:set('dz_garage_tuning', tostring(raw), true)
    state:set('vehicleTunning', tostring(raw), true)
    state:set('dz_vehicle_tunning', tostring(raw), true)
    state:set('dz_racejob_vehicle', true, true)
    state:set('dz_racejob_plate', tostring(vehicleData and vehicleData.plate or 'DRIFT'), true)

    applyTuning(vehicle, raw)

    -- Compatibilitate cu sistemul tau de tuning/garage.
    if netId and netId ~= 0 then
        TriggerEvent('client:tunning:applyVehicle', netId, tostring(raw))
        TriggerEvent('driftzone_tunning:client:applyVehicle', netId, tostring(raw))
        TriggerEvent('driftzone_garage:client:applyVehicleTuning', netId, { tuning = tostring(raw), plate = vehicleData and vehicleData.plate })
    end

    if vehicleData and vehicleData.plate then
        SetVehicleNumberPlateText(vehicle, tostring(vehicleData.plate):sub(1, 8))
    end

    return true
end

local function protectVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    SetEntityInvincible(vehicle, true)
    SetEntityCanBeDamaged(vehicle, false)
    SetVehicleCanBreak(vehicle, false)
    SetVehicleEngineCanDegrade(vehicle, false)
    SetVehicleTyresCanBurst(vehicle, false)
    SetVehicleWheelsCanBreak(vehicle, false)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
end

local function spawnVehicle(vehicleData, start)
    vehicleData = vehicleData or {}
    start = start or {}
    cleanupVehicle()

    local hash, err = loadVehicleModel(vehicleData.model, (Config.Vehicle and Config.Vehicle.clientSpawnTimeoutMs) or 15000)
    if not hash then return 0, err end

    local x = tonumber(start.x or 0.0) or 0.0
    local y = tonumber(start.y or 0.0) or 0.0
    local z = tonumber(start.z or 0.0) or 0.0
    local h = tonumber(start.h or start.w or 0.0) or 0.0
    local ped = PlayerPedId()
    local offset = (Config.Vehicle and tonumber(Config.Vehicle.spawnZOffset)) or 0.45

    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z + 0.2, false, false, false, false)
    SetEntityHeading(ped, h)
    local timeout = GetGameTimer() + 3500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(25)
    end

    local veh = CreateVehicle(hash, x, y, z + offset, h, true, true)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        SetModelAsNoLongerNeeded(hash)
        return 0, 'create_failed'
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, tostring(vehicleData.plate or 'DRIFT'))
    SetVehicleOnGroundProperly(veh)
    SetVehicleFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleNeedsToBeHotwired(veh, false)
    if Config.Vehicle and Config.Vehicle.protectVehicle then protectVehicle(veh) end
    SetPedIntoVehicle(ped, veh, -1)
    raceVehicle = veh
    SetModelAsNoLongerNeeded(hash)

    forceTuning(veh, vehicleData.tuning, vehicleData)
    CreateThread(function()
        -- Aplicari repetate dupa spawn pentru masini care primesc tuning greu sau dupa streaming.
        for _, delay in ipairs((Config.Vehicle and Config.Vehicle.tuningApplyDelays) or {}) do
            Wait(tonumber(delay) or 0)
            if raceVehicle == veh and DoesEntityExist(veh) then
                forceTuning(veh, vehicleData.tuning, vehicleData)
            end
        end
    end)

    return veh, nil
end

local function createFinish(finish)
    clearRoute()
    finish = finish or {}
    local x, y, z = tonumber(finish.x or 0.0) or 0.0, tonumber(finish.y or 0.0) or 0.0, tonumber(finish.z or 0.0) or 0.0
    finishBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(finishBlip, 38)
    SetBlipColour(finishBlip, 3)
    SetBlipScale(finishBlip, 0.9)
    SetBlipRoute(finishBlip, true)
    SetBlipRouteColour(finishBlip, 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Race Finish')
    EndTextCommandSetBlipName(finishBlip)
    finishCheckpoint = CreateCheckpoint(4, x, y, z + 0.8, x, y, z, 7.2, 4, 199, 247, 170, 0)
end

local function showCountdown(seconds)
    countdownActive = true
    seconds = tonumber(seconds or Config.CountdownSeconds or 3) or 3
    for i = seconds, 1, -1 do
        sendNui({ action = 'countdown', visible = true, text = tostring(i) })
        Wait(850)
    end
    sendNui({ action = 'countdown', visible = true, text = 'START' })
    Wait(700)
    sendNui({ action = 'countdown', visible = false })
    countdownActive = false
end

local function startTimerLoop()
    CreateThread(function()
        while activeRace and not raceEnding do
            local left = math.max(0, math.floor((activeRace.endAt or GetGameTimer()) - GetGameTimer()) / 1000)
            sendNui({ action = 'timer', time = formatTime(left), danger = left <= 20 })
            if left <= 0 then
                if activeRace.type == 'solo' then
                    TriggerServerEvent('driftzone_racejob:server:soloFail', 'Timpul a expirat. Ai pierdut cursa.')
                elseif activeRace.type == 'duo' then
                    TriggerServerEvent('driftzone_racejob:server:duoFail', activeRace.sessionId, 'Timpul a expirat. Ati pierdut cursa.')
                end
                break
            end
            Wait(250)
        end
    end)
end

local function startMonitorLoop()
    CreateThread(function()
        while activeRace and not raceEnding do
            Wait(150)
            if countdownActive then goto continue end
            local ped = PlayerPedId()
            if raceVehicle == nil or raceVehicle == 0 or not DoesEntityExist(raceVehicle) then
                if activeRace.type == 'solo' then TriggerServerEvent('driftzone_racejob:server:soloFail', 'Masina cursei nu mai exista.')
                else TriggerServerEvent('driftzone_racejob:server:duoFail', activeRace.sessionId, 'O masina nu mai exista.') end
                break
            end
            if not IsPedInVehicle(ped, raceVehicle, false) then
                if activeRace.type == 'solo' then TriggerServerEvent('driftzone_racejob:server:soloFail', 'Ai coborat din masina. Ai pierdut cursa.')
                else TriggerServerEvent('driftzone_racejob:server:duoFail', activeRace.sessionId, 'Un jucator a coborat din masina. Cursa a fost pierduta.') end
                break
            end
            local coords = GetEntityCoords(ped)
            local f = activeRace.finish
            local dist = #(coords - vector3(f.x, f.y, f.z))
            if dist <= (activeRace.finishRadius or 9.0) then
                if activeRace.type == 'solo' then TriggerServerEvent('driftzone_racejob:server:soloFinish')
                else TriggerServerEvent('driftzone_racejob:server:duoFinish', activeRace.sessionId) end
                break
            end
            ::continue::
        end
    end)
end

local function beginLocalRace(raceType, data)
    data = data or {}
    local race = data.race or {}
    activeRace = {
        type = raceType,
        sessionId = data.sessionId,
        label = race.label or 'Race',
        finish = race.finish,
        finishRadius = tonumber(data.finishRadius or Config.FinishRadius or 9.0) or 9.0,
        endAt = GetGameTimer() + ((tonumber(race.timeLimit or 180) or 180) * 1000)
    }
    raceEnding = false
    TriggerEvent('driftzone_hud:visible', true)
    createFinish(race.finish)
    sendNui({ action = 'raceHud', visible = true, race = activeRace.label, time = formatTime(race.timeLimit or 0) })
    startTimerLoop()
    startMonitorLoop()
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb({ ok = true })
end)

RegisterNUICallback('start', function(data, cb)
    data = data or {}
    if tostring(data.raceId or '') == 'special' then
        sendNui({ action = 'openInvite' })
        setFocus(true)
    else
        TriggerServerEvent('driftzone_racejob:server:startSolo', data.raceId, tonumber(data.vehicleId or 0) or 0)
        closeMenu(false)
    end
    cb({ ok = true })
end)

RegisterNUICallback('duoInvite', function(data, cb)
    TriggerServerEvent('driftzone_racejob:server:duoInvite', tonumber(data and data.targetUid or data and data.targetId or 0) or 0)
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_racejob:client:duoInviteResult', function(data)
    data = data or {}
    sendNui({
        action = 'duoInviteResult',
        ok = data.ok == true,
        message = tostring(data.message or '')
    })

    if data.ok == true then
        setFocus(false)
    else
        setFocus(true)
    end
end)

RegisterNUICallback('duoReady', function(data, cb)
    TriggerServerEvent('driftzone_racejob:server:duoReady', tonumber(data and data.sessionId or 0) or 0, tonumber(data and data.vehicleId or 0) or 0)
    cb({ ok = true })
end)

RegisterNetEvent('driftzone_racejob:client:openFromInteraction', function()
    TriggerServerEvent('driftzone_racejob:server:open')
end)

RegisterNetEvent('driftzone_racejob:client:openMenu', function(data)
    sendNui({ action = 'openMenu', races = data.races or {}, vehicles = data.vehicles or {}, mainColor = data.mainColor or Config.MainColor })
    setFocus(true)
end)

RegisterNetEvent('driftzone_racejob:client:startSolo', function(data)
    closeMenu(false)
    TriggerEvent('driftzone_hud:visible', true)
    Wait(350)
    local veh, err = spawnVehicle(data.vehicle, data.race and data.race.start or {})
    if veh == 0 then
        notify('warning', 'Masina nu a putut fi spawnata: ' .. tostring(err), 6000)
        TriggerServerEvent('driftzone_racejob:server:soloFail', 'Masina nu a putut fi spawnata.')
        return
    end
    if Config.Vehicle and Config.Vehicle.freezeDuringCountdown then FreezeEntityPosition(veh, true) end
    beginLocalRace('solo', data)
    showCountdown(data.countdown or Config.CountdownSeconds or 3)
    if DoesEntityExist(veh) then
        FreezeEntityPosition(veh, false)
        SetVehicleHandbrake(veh, false)
        SetVehicleEngineOn(veh, true, true, false)
    end
end)

RegisterNetEvent('driftzone_racejob:client:prepareDuoRace', function(data)
    closeMenu(false)
    TriggerEvent('driftzone_hud:visible', true)
    sendNui({ action = 'closeDuoGarage' })
    currentDuoSession = data.sessionId
    Wait(400)
    local veh, err = spawnVehicle(data.vehicle, data.start or {})
    if veh == 0 then
        notify('warning', 'Masina nu a putut fi spawnata: ' .. tostring(err), 6000)
        TriggerServerEvent('driftzone_racejob:server:duoSpawned', data.sessionId, false)
        return
    end
    if Config.Vehicle and Config.Vehicle.freezeDuringCountdown then FreezeEntityPosition(veh, true) end
    activeRace = {
        type = 'duo', sessionId = data.sessionId, pendingData = data,
        finish = data.race and data.race.finish or {}, finishRadius = data.finishRadius or Config.FinishRadius or 9.0,
        label = 'Duo Race'
    }
    createFinish(data.race.finish)
    TriggerServerEvent('driftzone_racejob:server:duoSpawned', data.sessionId, true)
end)

RegisterNetEvent('driftzone_racejob:client:beginDuoRace', function(data)
    if not activeRace or activeRace.type ~= 'duo' or tonumber(activeRace.sessionId) ~= tonumber(data.sessionId) then return end
    local pending = activeRace.pendingData or {}
    if raceVehicle and DoesEntityExist(raceVehicle) then FreezeEntityPosition(raceVehicle, true) end
    beginLocalRace('duo', pending)
    showCountdown(data.countdown or Config.CountdownSeconds or 3)
    if raceVehicle and DoesEntityExist(raceVehicle) then
        FreezeEntityPosition(raceVehicle, false)
        SetVehicleHandbrake(raceVehicle, false)
        SetVehicleEngineOn(raceVehicle, true, true, false)
    end
end)

RegisterNetEvent('driftzone_racejob:client:openDuoGarage', function(data)
    data = data or {}
    sendNui({ action = 'openDuoGarage', sessionId = data.sessionId, vehicles = data.vehicles or {}, partner = data.partner or 'Player', selfName = data.selfName or 'Tu', mainColor = data.mainColor or Config.MainColor })
    setFocus(true)
end)

RegisterNetEvent('driftzone_racejob:client:duoStatus', function(data)
    sendNui({ action = 'duoStatus', p1Ready = data.p1Ready == true, p2Ready = data.p2Ready == true })
end)

RegisterNetEvent('driftzone_racejob:client:raceCompleted', function(data)
    data = data or {}
    notify('success', data.message or 'Ai finalizat cursa.', 6500)
    if data.xp and tonumber(data.xp) and tonumber(data.xp) > 0 then notify('info', 'Ai primit +' .. tostring(data.xp) .. ' XP.', 4500) end
    local pos = data.returnPosition or Config.ReturnPosition
    endLocalRace()
    returnPlayer(pos)
end)

RegisterNetEvent('driftzone_racejob:client:raceFailed', function(reason)
    notify('warning', tostring(reason or 'Ai pierdut cursa.'), 6500)
    local pos = Config.ReturnPosition
    endLocalRace()
    returnPlayer(pos)
end)

RegisterNetEvent('driftzone_racejob:client:duoFailed', function(reason)
    notify('warning', tostring(reason or 'Ati pierdut cursa.'), 6500)
    local pos = Config.ReturnPosition
    endLocalRace()
    returnPlayer(pos)
end)

RegisterNetEvent('driftzone_racejob:client:duoCompleted', function(data)
    data = data or {}
    local pos = data.returnPosition or Config.ReturnPosition
    clearRoute()
    cleanupVehicle()
    activeRace = nil
    sendNui({ action = 'raceHud', visible = false })
    sendNui({ action = 'duoReward', data = data })
    notify('success', 'Ati finalizat Duo Race.', 5500)
    Wait(9200)
    sendNui({ action = 'duoRewardHide' })
    returnPlayer(pos)
end)

RegisterNetEvent('driftzone_racejob:client:cooldownsReset', function()
    localStorage = nil
    notify('success', 'Cooldown-ul tau la race a fost resetat.', 4000)
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then closeMenu(true) end
            Wait(0)
        else
            Wait(450)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearRoute()
    cleanupVehicle()
    SetNuiFocus(false, false)
end)
