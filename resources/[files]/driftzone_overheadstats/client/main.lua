local nuiReady = false
local showOthers = true
local showSelf = true
local pendingUpdate = nil

local KVP_OTHERS = 'driftzone_overheadstats_show_others'
local KVP_SELF = 'driftzone_overheadstats_show_self'

local function boolFromKvp(key, fallback)
    local value = GetResourceKvpString(key)

    if value == nil then return fallback end
    if value == '1' or value == 'true' or value == 'yes' then return true end
    if value == '0' or value == 'false' or value == 'no' then return false end

    return fallback
end

local function saveBool(key, value)
    SetResourceKvp(key, value and '1' or '0')
end

local function sendNui(data)
    if not nuiReady then
        pendingUpdate = data
        return
    end

    SendNUIMessage(data)
end

local function notify(text)
    TriggerEvent('client:notify', 'info', 3500, tostring(text or ''))
end

local function sanitize(value, fallback)
    local text = tostring(value or '')
    if text == '' or text == 'nil' or text == 'null' then return fallback or '' end
    return text
end

local function getPlayerData(playerId, distance, scale, opacity, sx, sy)
    local serverId = GetPlayerServerId(playerId)
    local state = Player(serverId).state

    return {
        id = serverId,
        x = sx,
        y = sy,
        distance = distance,
        scale = scale,
        opacity = opacity,
        uid = tonumber(state.dz_overhead_uid or serverId) or serverId,
        name = sanitize(state.dz_overhead_name, GetPlayerName(playerId) or ('Player ' .. tostring(serverId))),
        rank = sanitize(state.dz_overhead_rank, Config.DefaultRank.label),
        rankColor = sanitize(state.dz_overhead_rankcolor, Config.DefaultRank.color),
        staff = sanitize(state.dz_overhead_staff, ''),
        aduty = state.dz_overhead_aduty == true,
        isTalking = NetworkIsPlayerTalking(playerId) == 1,
        localPlayer = playerId == PlayerId()
    }
end

local function shouldDraw(playerId, ped, myPed, myCoords)
    if not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) then return false end

    local isSelf = playerId == PlayerId()

    -- IMPORTANT:
    -- showAll/hideAll/toggleAll controleaza DOAR ce vezi la ceilalti.
    -- showPersonal/hidePersonal/togglePersonal controleaza DOAR overhead-ul tau local.
    -- Nu se trimite nimic global, deci daca tu dai hidePersonal, ceilalti inca te vad.
    if isSelf then
        if Config.Performance.hideOwnByDefault then return false end
        if not showSelf then return false end
    else
        if not showOthers then return false end
    end

    local coords = GetEntityCoords(ped)
    local dist = #(myCoords - coords)

    if dist > Config.Distance.max then return false end

    if Config.Performance.useLineOfSight then
        if not isSelf and not HasEntityClearLosToEntity(myPed, ped, 17) then
            return false
        end
    end

    return true, coords, dist
end

local function buildList()
    local myPed = PlayerPedId()
    if not myPed or myPed == 0 then return {} end

    local myCoords = GetEntityCoords(myPed)
    local list = {}
    local maxDistance = Config.Distance.max
    local fullOpacity = Config.Distance.fullOpacity
    local minScale = Config.Distance.minScale
    local maxScale = Config.Distance.maxScale
    local offsetZ = Config.Distance.headOffsetZ

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        local ok, coords, dist = shouldDraw(playerId, ped, myPed, myCoords)

        if ok then
            local drawPos = vector3(coords.x, coords.y, coords.z + offsetZ)
            local onScreen, sx, sy = World3dToScreen2d(drawPos.x, drawPos.y, drawPos.z)

            if onScreen then
                local distanceAlpha = 1.0

                if dist > fullOpacity then
                    distanceAlpha = 1.0 - ((dist - fullOpacity) / math.max(1.0, maxDistance - fullOpacity))
                end

                local opacity = math.max(0.22, math.min(1.0, distanceAlpha))
                local scale = math.max(minScale, math.min(maxScale, maxScale - (dist / maxDistance) * 0.25))

                list[#list + 1] = getPlayerData(playerId, dist, scale, opacity, sx, sy)
            end
        end
    end

    return list
end

local function setOthersVisible(value, silent)
    showOthers = value == true
    saveBool(KVP_OTHERS, showOthers)

    if not showOthers and not showSelf then
        sendNui({ action = 'clear' })
    end

    if not silent then
        notify(showOthers and 'Overhead pentru ceilalti ON.' or 'Overhead pentru ceilalti OFF.')
    end
end

local function setSelfVisible(value, silent)
    showSelf = value == true
    saveBool(KVP_SELF, showSelf)

    if not showOthers and not showSelf then
        sendNui({ action = 'clear' })
    end

    if not silent then
        notify(showSelf and 'Overhead personal ON.' or 'Overhead personal OFF.')
    end
end

-- TRIGGERE MEMORATE PENTRU MAI TARZIU:
-- showAll/hideAll/toggleAll = TU vezi / nu vezi overhead-urile celorlalti.
-- showPersonal/hidePersonal/togglePersonal = TU vezi / nu vezi overhead-ul tau local.
RegisterNetEvent('driftzone_overheadstats:client:showAll', function()
    setOthersVisible(true, false)
end)

RegisterNetEvent('driftzone_overheadstats:client:hideAll', function()
    setOthersVisible(false, false)
end)

RegisterNetEvent('driftzone_overheadstats:client:toggleAll', function()
    setOthersVisible(not showOthers, false)
end)

RegisterNetEvent('driftzone_overheadstats:client:showPersonal', function()
    setSelfVisible(true, false)
end)

RegisterNetEvent('driftzone_overheadstats:client:hidePersonal', function()
    setSelfVisible(false, false)
end)

RegisterNetEvent('driftzone_overheadstats:client:togglePersonal', function()
    setSelfVisible(not showSelf, false)
end)

RegisterNetEvent('driftzone_overheadstats:client:refresh', function()
    TriggerServerEvent('driftzone_overheadstats:server:refresh')
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true

    if pendingUpdate then
        SendNUIMessage(pendingUpdate)
        pendingUpdate = nil
    end

    cb({ ok = true })
end)

exports('ShowAll', function() setOthersVisible(true, false) end)
exports('HideAll', function() setOthersVisible(false, false) end)
exports('ToggleAll', function() setOthersVisible(not showOthers, false) end)
exports('ShowPersonal', function() setSelfVisible(true, false) end)
exports('HidePersonal', function() setSelfVisible(false, false) end)
exports('TogglePersonal', function() setSelfVisible(not showSelf, false) end)

CreateThread(function()
    showOthers = boolFromKvp(KVP_OTHERS, true)
    showSelf = boolFromKvp(KVP_SELF, true)

    -- Update mai rapid la intrare, fara sa schimbam UI-ul.
    Wait(350)
    TriggerServerEvent('driftzone_overheadstats:server:playerReady')
    TriggerServerEvent('driftzone_overheadstats:server:refresh')

    Wait(1200)
    TriggerServerEvent('driftzone_overheadstats:server:refresh')

    print('[DRIFTZONE_OVERHEADSTATS] Client-side loaded. Commands disabled; use triggers/exports only.')
end)

CreateThread(function()
    local waitMs = Config.Performance.updateMs or 80

    while true do
        if showOthers or showSelf then
            sendNui({
                action = 'update',
                players = buildList()
            })

            Wait(waitMs)
        else
            Wait(700)
        end
    end
end)
