Core = nil
CoreName = 'driftzone'
CoreReady = true

function GetPlayerData()
    return {
        source = GetPlayerServerId(PlayerId()),
        id = GetPlayerServerId(PlayerId()),
        name = GetPlayerName(PlayerId()) or 'Player'
    }
end

function Notify(text, length, type)
    local notifyEvent = (Config and Config.NotifyEvent) or 'client:notify'
    TriggerEvent(notifyEvent, type or 'info', length or 5000, tostring(text or ''))
end

function Create3DTextUIOnPlayer(name, data)
    if create3DTextUIOnPlayers then create3DTextUIOnPlayers(name, data) end
end

function Delete3DTextUIOnPlayer(name)
    if delete3DTextUIOnPlayers then delete3DTextUIOnPlayers(name) end
end

function ShowTextUI(name, key)
    if displayTextUI then displayTextUI(name, key) end
end

function HideTextUI()
    if hideTextUI then hideTextUI() end
end
