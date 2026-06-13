local function targetId(value)
    local id = tonumber(value)
    if id and GetPlayerName(id) then return id end
    return nil
end

RegisterNetEvent('driftzone_emotes:sendAnimRequest:server', function(data)
    if type(data) ~= 'table' then return end
    local id = targetId(data.id)
    if id then TriggerClientEvent('driftzone_emotes:receiveAnimRequest:client', id, data) end
end)

RegisterNetEvent('driftzone_emotes:playAnimTogetherSender:server', function(data)
    if type(data) ~= 'table' then return end
    local id = data.target or (data.data and data.data.target)
    id = targetId(id)
    if id then TriggerClientEvent('driftzone_emotes:playAnimTogetherSender:client', id, data) end
end)

RegisterNetEvent('driftzone_emotes:playAnimTogetherSender2:server', function(data)
    if type(data) ~= 'table' then return end
    local id = data.target or (data.data and data.data.target)
    id = targetId(id)
    if id then TriggerClientEvent('driftzone_emotes:playAnimTogetherSender2:client', id, data) end
end)

RegisterNetEvent('driftzone_emotes:requstCanelledNotif:server', function(target)
    local id = targetId(target)
    if id then TriggerClientEvent('driftzone_emotes:requstCanelledNotif:client', id) end
end)

RegisterNetEvent('driftzone_emotes:cancelEmote:server', function(target)
    local id = targetId(target)
    if id then TriggerClientEvent('driftzone_emotes:cancelEmote:client', id) end
end)

RegisterNetEvent('driftzone_emotes:animDictLoaded:server', function(target)
    local id = targetId(target)
    if id then TriggerClientEvent('driftzone_emotes:animDictLoaded:client', id) end
end)

RegisterNetEvent('driftzone_emotes:attachPeds:server', function(targetIdValue, myId, data)
    local id = targetId(targetIdValue)
    if id then TriggerClientEvent('driftzone_emotes:attachPeds:client', id, myId, data) end
end)

RegisterNetEvent('driftzone_emotes:ptfxSync:server', function(asset, name, offset, rot, bone, scale, color)
    if type(asset) ~= 'string' or type(name) ~= 'string' then return end
    local state = Player(source).state
    state:set('ptfxAsset', asset, true)
    state:set('ptfxName', name, true)
    state:set('ptfxOffset', offset, true)
    state:set('ptfxRot', rot, true)
    state:set('ptfxBone', bone, true)
    state:set('ptfxScale', scale, true)
    state:set('ptfxColor', color, true)
    state:set('ptfxPropNet', false, true)
    state:set('ptfx', false, true)
end)

RegisterNetEvent('driftzone_emotes:ptfxSyncProp:server', function(propNet)
    local state = Player(source).state
    if propNet then
        local tries = 0
        while tries <= 100 and not DoesEntityExist(NetworkGetEntityFromNetworkId(propNet)) do
            Wait(10)
            tries = tries + 1
        end
        if tries < 100 then
            state:set('ptfxPropNet', propNet, true)
            return
        end
    end
    state:set('ptfxPropNet', false, true)
end)

RegisterNetEvent('driftzone_emotes:setPedAlpha:server', function(id, alpha)
    TriggerClientEvent('driftzone_emotes:setPedAlpha:server', -1, id, alpha)
end)

-- Server-side helper triggers for your custom framework scripts.
-- Usage: TriggerEvent('driftzone_emotes:server:playForSource', source, 'sit')
RegisterNetEvent('driftzone_emotes:server:playForSource', function(target, emote)
    local id = targetId(target)
    if id and type(emote) == 'string' then
        TriggerClientEvent('driftzone_emotes:client:play', id, emote)
    end
end)

RegisterNetEvent('driftzone_emotes:server:playLockedForSource', function(target, emote)
    local id = targetId(target)
    if id and type(emote) == 'string' then
        TriggerClientEvent('driftzone_emotes:client:playLocked', id, emote)
    end
end)

RegisterNetEvent('driftzone_emotes:server:forceStopForSource', function(target)
    local id = targetId(target)
    if id then TriggerClientEvent('driftzone_emotes:client:forceStop', id) end
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        print('^2[driftzone_emotes]^7 started standalone/custom framework mode.')
    end
end)
