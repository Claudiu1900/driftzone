local inventoryOpen = false
local addItemOpen = false
local currentMode = 'normal'
local currentTarget = nil

local function notify(typ, msg, duration)
    TriggerEvent(Config.NotifyEvent or 'client:notify', typ or 'info', duration or 4500, tostring(msg or ''))
end

local function setFocus(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function sendNui(data)
    SendNUIMessage(data)
end

local function openInventory(data)
    inventoryOpen = true
    addItemOpen = false
    currentMode = data and data.mode or 'normal'
    currentTarget = data and data.target or nil
    setFocus(true)
    sendNui({ action = 'openInventory', data = data or {} })
end

local function closeAll()
    inventoryOpen = false
    addItemOpen = false
    currentMode = 'normal'
    currentTarget = nil
    setFocus(false)
    sendNui({ action = 'closeAll' })
end

RegisterCommand(Config.Command or 'inventory', function()
    TriggerServerEvent('driftzone_inventory:server:requestOpen')
end, false)

RegisterKeyMapping(Config.Command or 'inventory', 'Open DriftZone Inventory', 'keyboard', Config.OpenKey or 'F2')

RegisterNetEvent('driftzone_inventory:client:open', function(data)
    openInventory(data or {})
end)

RegisterNetEvent('driftzone_inventory:client:addItemPanel', function(data)
    inventoryOpen = false
    addItemOpen = true
    setFocus(true)
    sendNui({ action = 'openAddItem', data = data or {} })
end)

RegisterNetEvent('driftzone_inventory:client:addItemResult', function(ok, message)
    sendNui({ action = 'addItemResult', ok = ok == true, message = tostring(message or '') })
end)

RegisterNetEvent('driftzone_inventory:client:itemUsed', function(itemId)
    notify('info', ('Ai folosit %s.'):format(tostring(itemId or 'item')))
end)

-- Trigger pentru driftzone_playerinteract: dupa ce selectezi un player, apelezi acest event cu serverId-ul lui.
RegisterNetEvent('driftzone_inventory:client:openGiveToPlayer', function(targetServerId)
    TriggerServerEvent('driftzone_inventory:server:startGiveToPlayer', tonumber(targetServerId or 0) or 0)
end)

-- Comanda de test: /giveinv id
RegisterCommand('giveinv', function(_, args)
    local target = tonumber(args[1] or 0) or 0
    if target <= 0 then
        notify('warning', 'Folosire: /giveinv id')
        return
    end
    TriggerServerEvent('driftzone_inventory:server:startGiveToPlayer', target)
end, false)

RegisterNUICallback('close', function(_, cb)
    closeAll()
    cb({ ok = true })
end)

RegisterNUICallback('move', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:move', data and data.from, data and data.to)
    cb({ ok = true })
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:useItem', data and data.slot)
    cb({ ok = true })
end)

RegisterNUICallback('giveItem', function(data, cb)
    if not currentTarget or not currentTarget.serverId then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('driftzone_inventory:server:giveSelected', currentTarget.serverId, data and data.slot, data and data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('submitAddItem', function(data, cb)
    TriggerServerEvent('driftzone_inventory:server:addItemSubmit', data or {})
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if inventoryOpen or addItemOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
                closeAll()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
