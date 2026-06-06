RegisterCommand(Config.Command or 'settings', function(src)
    if src == 0 then
        print('[DRIFTZONE_SETTINGS] Comanda se foloseste in joc.')
        return
    end

    TriggerClientEvent('driftzone_settings:client:open', src)
end, false)

exports('RunCommand', function(src, command, args)
    command = tostring(command or ''):lower():gsub('^/', '')

    if command == tostring(Config.Command or 'settings'):lower() then
        TriggerClientEvent('driftzone_settings:client:open', src)
        return true
    end

    return false
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_SETTINGS] Server-side loaded. Command: /' .. tostring(Config.Command or 'settings'))
end)
