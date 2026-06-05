local function openMenu(src)
    TriggerClientEvent('driftzone_keybinds:client:open', src)
end

local function runCommand(src, command, args)
    command = tostring(command or ''):lower()

    if command == 'keybind' or command == 'keybinds' then
        openMenu(src)
        return true
    end

    return false
end

RegisterCommand('keybind', function(src)
    if src == 0 then return end
    openMenu(src)
end, false)

RegisterCommand('keybinds', function(src)
    if src == 0 then return end
    openMenu(src)
end, false)

RegisterNetEvent('driftzone_keybinds:server:open', function()
    openMenu(source)
end)

exports('RunCommand', function(src, command, args)
    return runCommand(src, command, args or {})
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_KEYBINDS] Server-side loaded.')
end)
