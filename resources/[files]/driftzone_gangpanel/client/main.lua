local uiReady = false
local panelOpen = false
local pendingOpen = nil
local cursorVisible = false
local tabletObj = nil
local tabletPlaying = false
local lastTabletEnsure = 0
local withdrawalBlip = nil
local selectorOpen = false
local selectorPayload = nil
local selectorTarget = nil
local selectorTargetPed = nil
local cursorX, cursorY = 0.5, 0.5
local markerRotation = 0.0
local activeWithdrawal = nil
local claimHintVisible = false

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or Config.NotifyDuration or 4500, tostring(msg or ''))
end

local function sendNui(data)
    if not uiReady then return false end
    SendNUIMessage(data)
    return true
end

local function setFocus(state)
    cursorVisible = state == true
    SetNuiFocus(cursorVisible, cursorVisible)
    SetNuiFocusKeepInput(false)
    sendNui({ action = 'focus', enabled = cursorVisible })
end


local function removeWithdrawalBlip()
    if withdrawalBlip and DoesBlipExist(withdrawalBlip) then
        RemoveBlip(withdrawalBlip)
    end
    withdrawalBlip = nil
end

local function createWithdrawalBlip(data)
    removeWithdrawalBlip()
    if type(data) ~= 'table' or not data.x then return end

    local cfg = Config.Withdrawal or {}
    local bcfg = cfg.CustomBlip or {}
    local blip = AddBlipForCoord(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    SetBlipSprite(blip, tonumber(bcfg.Sprite or cfg.BlipSprite or 500) or 500)
    SetBlipColour(blip, tonumber(bcfg.Color or cfg.BlipColor or 3) or 3)
    SetBlipScale(blip, tonumber(bcfg.Scale or cfg.BlipScale or 0.82) or 0.82)
    SetBlipAsShortRange(blip, bcfg.ShortRange == true)
    SetBlipHighDetail(blip, true)

    if bcfg.Route == true or cfg.BlipRoute == true then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, tonumber(bcfg.RouteColor or cfg.BlipRouteColor or 3) or 3)
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(tostring(bcfg.Name or cfg.BlipName or 'Ridicare pachet'))
    EndTextCommandSetBlipName(blip)

    withdrawalBlip = blip
end

local function addWithdrawalInteraction(data)
    if type(data) ~= 'table' or not data.x then return end
    local wid = tonumber(data.id or data.withdrawalId or 0) or 0
    if wid <= 0 then return end

    activeWithdrawal = {
        id = wid,
        amount = tonumber(data.amount or 0) or 0,
        x = data.x + 0.0,
        y = data.y + 0.0,
        z = data.z + 0.0
    }
    claimHintVisible = false
    sendNui({ action = 'claimHint', visible = false })

    -- Nu folosim waypoint clasic si nu chemam resurse externe.
    -- Blipul este local, albastru si apare doar jucatorului care trebuie sa ridice pachetul.
    createWithdrawalBlip(activeWithdrawal)
end

local function removeWithdrawalInteraction(_)
    removeWithdrawalBlip()
end

local function loadAnimDict(dict, timeout)
    dict = tostring(dict or '')
    if dict == '' then return false end
    RequestAnimDict(dict)
    local untilTime = GetGameTimer() + (timeout or 1800)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
        if GetGameTimer() > untilTime then return false end
    end
    return true
end

local function loadModel(model, timeout)
    local hash = type(model) == 'number' and model or GetHashKey(tostring(model or ''))
    if not hash or hash == 0 then return nil end
    RequestModel(hash)
    local untilTime = GetGameTimer() + (timeout or 1800)
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > untilTime then return nil end
    end
    return hash
end

local function stopTablet()
    local ped = PlayerPedId()
    local anim = Config.TabletAnimation or {}

    tabletPlaying = false
    lastTabletEnsure = 0

    if ped and ped ~= 0 then
        if anim.dict and anim.anim then
            StopAnimTask(ped, anim.dict, anim.anim, 2.0)
            Wait(0)
            StopAnimTask(ped, anim.dict, anim.anim, 2.0)
        end
        ClearPedSecondaryTask(ped)
    end

    if tabletObj and DoesEntityExist(tabletObj) then
        DetachEntity(tabletObj, true, true)
        DeleteEntity(tabletObj)
    end
    tabletObj = nil
end

local function ensureTablet(force)
    local anim = Config.TabletAnimation or {}
    if anim.enabled == false then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 or IsPedDeadOrDying(ped, true) then return end

    local now = GetGameTimer()
    if not force and now - lastTabletEnsure < 1200 then return end
    lastTabletEnsure = now

    local dict = tostring(anim.dict or '')
    local name = tostring(anim.anim or '')
    if dict ~= '' and name ~= '' then
        if not IsEntityPlayingAnim(ped, dict, name, 3) then
            if loadAnimDict(dict, tonumber(anim.timeout or 1800) or 1800) then
                TaskPlayAnim(ped, dict, name, 3.0, -3.0, -1, tonumber(anim.flag or 49) or 49, 0.0, false, false, false)
                tabletPlaying = true
            end
        else
            tabletPlaying = true
        end
    end

    if anim.prop and (not tabletObj or not DoesEntityExist(tabletObj)) then
        local hash = loadModel(anim.prop, tonumber(anim.modelTimeout or 1800) or 1800)
        if hash then
            local coords = GetEntityCoords(ped)
            tabletObj = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
            SetEntityCollision(tabletObj, false, false)
            local p = anim.placement or {}
            AttachEntityToEntity(
                tabletObj,
                ped,
                GetPedBoneIndex(ped, tonumber(anim.bone or 28422) or 28422),
                p.x or 0.03, p.y or -0.05, p.z or 0.0,
                p.rx or 0.0, p.ry or 0.0, p.rz or 0.0,
                true, true, false, true, 1, true
            )
            SetModelAsNoLongerNeeded(hash)
        end
    end
end

local function playTablet()
    ensureTablet(true)
end

local function openPanel(data)
    panelOpen = true
    selectorOpen = false
    selectorPayload = nil
    playTablet()
    setFocus(true)
    sendNui({ action = 'open', data = data or {} })
    if data and data.withdrawal then
        addWithdrawalInteraction(data.withdrawal)
    end
end

local function closePanel()
    panelOpen = false
    selectorOpen = false
    selectorPayload = nil
    selectorTarget = nil
    selectorTargetPed = nil
    stopTablet()
    setFocus(false)
    sendNui({ action = 'close' })
    TriggerServerEvent('driftzone_gangpanel:server:closed')
end

RegisterCommand(Config.Command or 'gang', function()
    TriggerServerEvent('driftzone_gangpanel:server:requestOpen')
end, false)

RegisterNetEvent('driftzone_gangpanel:client:open', function(data)
    if not uiReady then pendingOpen = data or {} return end
    openPanel(data or {})
end)

RegisterNetEvent('driftzone_gangpanel:client:deny', function()
    closePanel()
end)

RegisterNetEvent('driftzone_gangpanel:client:update', function(data)
    if panelOpen then sendNui({ action = 'update', data = data or {} }) end
    if data and data.withdrawal then
        addWithdrawalInteraction(data.withdrawal)
    end
end)

RegisterNetEvent('driftzone_gangpanel:client:gangDetails', function(data)
    sendNui({ action = 'gangDetails', data = data or {} })
end)

RegisterNetEvent('driftzone_gangpanel:client:incomingTax', function(data)
    sendNui({ action = 'incomingTax', data = data or {} })
    setFocus(true)
end)

RegisterNetEvent('driftzone_gangpanel:client:clearIncomingTax', function(requestId)
    sendNui({ action = 'clearIncomingTax', requestId = requestId })
end)

RegisterNetEvent('driftzone_gangpanel:client:setWithdrawalPickup', function(data)
    addWithdrawalInteraction(data or {})
end)

RegisterNetEvent('driftzone_gangpanel:client:claimWithdrawalFromInteraction', function(payload)
    payload = type(payload) == 'table' and payload or {}
    local withdrawalId = tonumber(payload.withdrawalId or payload.id or 0) or 0
    if withdrawalId > 0 then
        TriggerServerEvent('driftzone_gangpanel:server:claimWithdrawal', withdrawalId)
    end
end)

RegisterNetEvent('driftzone_gangpanel:client:clearWithdrawalPickup', function()
    if activeWithdrawal then removeWithdrawalInteraction(activeWithdrawal) end
    activeWithdrawal = nil
    claimHintVisible = false
    sendNui({ action = 'claimHint', visible = false })
end)

RegisterNUICallback('ready', function(_, cb)
    uiReady = true
    cb({ ok = true })
    if pendingOpen then
        local data = pendingOpen
        pendingOpen = nil
        Wait(100)
        openPanel(data)
    end
end)

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb({ ok = true })
end)

RegisterNUICallback('toggleFocus', function(_, cb)
    if panelOpen or selectorOpen then setFocus(not cursorVisible) end
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('driftzone_gangpanel:server:refresh')
    cb({ ok = true })
end)

RegisterNUICallback('getGangDetails', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:getGangDetails', data and data.gang_id)
    cb({ ok = true })
end)

RegisterNUICallback('createGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:createGang', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('updateGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:updateGang', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('deleteGang', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:deleteGang', data and data.gang_id)
    cb({ ok = true })
end)

RegisterNUICallback('addMember', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:addMember', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('kickMember', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:kickMember', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('changeRole', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:changeRole', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('createTaxCategory', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:createTaxCategory', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('deleteTaxCategory', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:deleteTaxCategory', data and data.category_id)
    cb({ ok = true })
end)

RegisterNUICallback('startTaxSelector', function(data, cb)
    selectorPayload = data or {}
    selectorOpen = true
    selectorTarget = nil
    selectorTargetPed = nil
    cursorX, cursorY = 0.5, 0.5

    -- Inchide complet panoul ca selectarea sa se faca natural, fara UI/crosshair.
    panelOpen = false
    stopTablet()
    setFocus(false)
    sendNui({ action = 'close' })
    TriggerServerEvent('driftzone_gangpanel:server:closed')

    notify('info', 'Uita-te spre persoana si apasa E sau click stanga pentru a oferi taxa.')
    cb({ ok = true })
end)

RegisterNUICallback('payTax', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:payTax', data and data.requestId)
    cb({ ok = true })
end)

RegisterNUICallback('refuseTax', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:refuseTax', data and data.requestId)
    cb({ ok = true })
end)

RegisterNUICallback('adjustRevenue', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:adjustRevenue', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('requestWithdrawal', function(data, cb)
    TriggerServerEvent('driftzone_gangpanel:server:requestWithdrawal', data and data.gang_id)
    cb({ ok = true })
end)

RegisterNUICallback('getCoords', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    cb({ ok = true, x = tonumber(string.format('%.6f', coords.x)), y = tonumber(string.format('%.6f', coords.y)), z = tonumber(string.format('%.6f', coords.z)) })
end)

local findPlayerFromCursor

local function rotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function raycastFromCamera(distance)
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local destination = camCoord + direction * (distance or 18.0)
    local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, destination.x, destination.y, destination.z, 12, PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    return hit == 1, endCoords, entityHit
end

local function getPlayerFromEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil, nil end
    if not IsEntityAPed(entity) or not IsPedAPlayer(entity) then return nil, nil end
    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
    if playerIndex == -1 or playerIndex == PlayerId() then return nil, nil end
    local ped = GetPlayerPed(playerIndex)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil, nil end
    local myPed = PlayerPedId()
    local maxDist = tonumber((Config.PlayerSelector or {}).MaxDistance or 6.0) or 6.0
    if #(GetEntityCoords(myPed) - GetEntityCoords(ped)) > maxDist then return nil, nil end
    return GetPlayerServerId(playerIndex), ped
end

local function findPlayerFromAim()
    local hit, _, entityHit = raycastFromCamera(tonumber((Config.PlayerSelector or {}).RayDistance or 18.0) or 18.0)
    if hit then
        local sid, ped = getPlayerFromEntity(entityHit)
        if sid then return sid, ped end
    end

    -- Fallback: alege cel mai apropiat de centrul ecranului, fara UI/crosshair.
    cursorX, cursorY = 0.5, 0.5
    return findPlayerFromCursor()
end

local function projectWorldPoint(coords)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then return sx, sy end
    return nil, nil
end

local function getPedScreenBox(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    local points = {}
    local offsets = {
        { x = 0.00, y = 0.00, z = 0.95 },
        { x = 0.00, y = 0.00, z = 0.72 },
        { x = 0.00, y = 0.00, z = 0.48 },
        { x = 0.00, y = 0.00, z = 0.22 },
        { x = 0.00, y = 0.00, z = -0.10 }
    }
    for _, off in ipairs(offsets) do
        local point = vector3(coords.x + off.x, coords.y + off.y, coords.z + off.z)
        local sx, sy = projectWorldPoint(point)
        if sx and sy then points[#points + 1] = { x = sx, y = sy } end
    end
    local bones = { 31086, 24818, 11816, 58271, 63931 }
    for _, bone in ipairs(bones) do
        local bc = GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
        local sx, sy = projectWorldPoint(bc)
        if sx and sy then points[#points + 1] = { x = sx, y = sy } end
    end
    if #points <= 0 then return nil end
    local minX, maxX, minY, maxY = 1.0, 0.0, 1.0, 0.0
    for _, p in ipairs(points) do
        if p.x < minX then minX = p.x end
        if p.x > maxX then maxX = p.x end
        if p.y < minY then minY = p.y end
        if p.y > maxY then maxY = p.y end
    end
    local cfg = Config.PlayerSelector or {}
    local width = math.max(maxX - minX, tonumber(cfg.MinWidth or 0.050) or 0.050)
    local centerX = (minX + maxX) / 2.0
    minX = centerX - (width / 2.0)
    maxX = centerX + (width / 2.0)
    return {
        minX = minX - (cfg.PaddingX or 0.035), maxX = maxX + (cfg.PaddingX or 0.035),
        minY = minY - (cfg.PaddingY or 0.050), maxY = maxY + (cfg.PaddingY or 0.050),
        centerX = centerX, centerY = (minY + maxY) / 2.0
    }
end

findPlayerFromCursor = function()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local bestTarget, bestPed, bestScore = nil, nil, 999999.0
    local cfg = Config.PlayerSelector or {}
    local radius = tonumber(cfg.ScreenRadius or 0.075) or 0.075
    local maxDist = tonumber(cfg.MaxDistance or 6.0) or 6.0
    for _, playerIndex in ipairs(GetActivePlayers()) do
        if playerIndex ~= PlayerId() then
            local ped = GetPlayerPed(playerIndex)
            if ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
                local coords = GetEntityCoords(ped)
                local dist = #(myCoords - coords)
                if dist <= maxDist then
                    local box = getPedScreenBox(ped)
                    if box then
                        local insideBox = cursorX >= box.minX and cursorX <= box.maxX and cursorY >= box.minY and cursorY <= box.maxY
                        local dx, dy = cursorX - box.centerX, cursorY - box.centerY
                        local screenDist = math.sqrt(dx * dx + dy * dy)
                        if insideBox or screenDist <= radius then
                            local score = screenDist + (dist * 0.002)
                            if score < bestScore then
                                bestScore = score
                                bestTarget = GetPlayerServerId(playerIndex)
                                bestPed = ped
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget, bestPed
end

RegisterNUICallback('selectorMove', function(data, cb)
    cursorX = tonumber(data and data.x or 0.5) or 0.5
    cursorY = tonumber(data and data.y or 0.5) or 0.5
    selectorTarget, selectorTargetPed = findPlayerFromCursor()
    cb({ ok = true, target = selectorTarget })
end)

RegisterNUICallback('selectorClick', function(_, cb)
    if selectorOpen and selectorPayload and selectorTarget then
        selectorPayload.target = selectorTarget
        TriggerServerEvent('driftzone_gangpanel:server:offerTaxToPlayer', selectorPayload)
        selectorOpen = false
        selectorPayload = nil
        selectorTarget = nil
        selectorTargetPed = nil
        sendNui({ action = 'closeSelector' })
        setFocus(false)
        TriggerServerEvent('driftzone_gangpanel:server:requestOpen')
    else
        notify('warning', 'Selecteaza o persoana apropiata.')
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if selectorOpen then
            selectorTarget, selectorTargetPed = findPlayerFromAim()

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 202, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) then
                selectorOpen = false
                selectorPayload = nil
                selectorTarget = nil
                selectorTargetPed = nil
                setFocus(false)
                notify('info', 'Selectarea a fost anulata.')
            elseif IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 24) then
                if selectorPayload and selectorTarget then
                    selectorPayload.target = selectorTarget
                    TriggerServerEvent('driftzone_gangpanel:server:offerTaxToPlayer', selectorPayload)
                    selectorOpen = false
                    selectorPayload = nil
                    selectorTarget = nil
                    selectorTargetPed = nil
                    setFocus(false)
                    TriggerServerEvent('driftzone_gangpanel:server:requestOpen')
                else
                    notify('warning', 'Nu ai selectat nicio persoana apropiata.')
                end
            end

            Wait(0)
        else
            Wait(220)
        end
    end
end)

CreateThread(function()
    while true do
        if panelOpen then
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustPressed(0, 200) then closePanel() end
            if IsControlJustPressed(0, 243) or IsDisabledControlJustPressed(0, 243) then setFocus(not cursorVisible) end
            ensureTablet(false)
            Wait(0)
        else
            Wait(350)
        end
    end
end)

CreateThread(function()
    while true do
        if activeWithdrawal and activeWithdrawal.x then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local target = vector3(activeWithdrawal.x + 0.0, activeWithdrawal.y + 0.0, activeWithdrawal.z + 0.0)
            local dist = #(coords - target)
            if dist < 35.0 then
                local c = Config.Withdrawal.MarkerColor or {}
                local s = Config.Withdrawal.MarkerScale or {}
                DrawMarker(Config.Withdrawal.MarkerType or 2, target.x, target.y, target.z + 0.45, 0.0, 0.0, 0.0, 180.0, 0.0, markerRotation, s.x or 0.42, s.y or 0.42, s.z or 0.42, c.r or 4, c.g or 199, c.b or 247, c.a or 210, false, true, 2, false, nil, nil, false)
                if dist <= (Config.Withdrawal.ClaimDistance or 2.0) then
                    if not claimHintVisible then
                        claimHintVisible = true
                        sendNui({ action = 'claimHint', visible = true, amount = activeWithdrawal.amount })
                    end
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('driftzone_gangpanel:server:claimWithdrawal', activeWithdrawal.id)
                    end
                elseif claimHintVisible then
                    claimHintVisible = false
                    sendNui({ action = 'claimHint', visible = false })
                end
                markerRotation = markerRotation + 2.0
                if markerRotation >= 360.0 then markerRotation = 0.0 end
                Wait(0)
            else
                if claimHintVisible then
                    claimHintVisible = false
                    sendNui({ action = 'claimHint', visible = false })
                end
                Wait(850)
            end
        else
            Wait(1200)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopTablet()
    removeWithdrawalBlip()
    SetNuiFocus(false, false)
end)
