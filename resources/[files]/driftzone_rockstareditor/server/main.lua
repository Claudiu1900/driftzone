RegisterCommand(Config.Command or 'editor', function(src)
    if src == 0 then
        print('[DRIFTZONE_EDITOR] Comanda este client-side. Foloseste /editor in joc.')
        return
    end

    TriggerClientEvent('driftzone_rockstareditor:client:toggle', src)
end, false)

exports('RunCommand', function(src, command, args)
    command = tostring(command or ''):lower():gsub('^/', '')

    if command == tostring(Config.Command or 'editor'):lower() then
        TriggerClientEvent('driftzone_rockstareditor:client:toggle', src)
        return true
    end

    return false
end)

CreateThread(function()
    Wait(1000)
    print('[DRIFTZONE_EDITOR] Server-side loaded. Command: /' .. tostring(Config.Command or 'editor'))
end)
