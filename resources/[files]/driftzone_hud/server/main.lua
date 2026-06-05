local function getOnlinePlayers()
    return #GetPlayers()
end

local function getUid(src)
    local state = Player(src).state

    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then
        return tonumber(state.dz_uid)
    end

    local ok, uid = pcall(function()
        return exports.driftzone_auth:GetUID(src)
    end)

    if ok and tonumber(uid) and tonumber(uid) > 0 then
        return tonumber(uid)
    end

    return 0
end

local function getCashByUid(uid)
    uid = tonumber(uid)

    if not uid or uid <= 0 then
        return 0
    end

    local result = MySQL.scalar.await(
        'SELECT cash FROM users WHERE uid = @uid LIMIT 1',
        {
            ['@uid'] = uid
        }
    )

    return tonumber(result) or 0
end

local function sendHudData(src)
    local uid = getUid(src)
    local cash = getCashByUid(uid)

    TriggerClientEvent('driftzone_hud:client:updateData', src, {
        id = uid,
        online = getOnlinePlayers(),
        cash = cash
    })
end

RegisterNetEvent('driftzone_hud:server:requestData', function()
    local src = source
    sendHudData(src)
end)

RegisterNetEvent('driftzone_hud:server:refreshMoney', function()
    local src = source
    sendHudData(src)
end)

AddEventHandler('playerJoining', function()
    Wait(1000)

    for _, id in ipairs(GetPlayers()) do
        sendHudData(tonumber(id))
    end
end)

AddEventHandler('playerDropped', function()
    Wait(1000)

    for _, id in ipairs(GetPlayers()) do
        sendHudData(tonumber(id))
    end
end)

CreateThread(function()
    while true do
        Wait(Config.UpdateInterval or 3000)

        for _, id in ipairs(GetPlayers()) do
            sendHudData(tonumber(id))
        end
    end
end)

exports('RefreshPlayer', function(src)
    sendHudData(tonumber(src))
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    print('[DRIFTZONE_HUD] Server-side loaded.')
end)