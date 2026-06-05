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

    return nil
end

local function getPlayerNameClean(src)
    local name = GetPlayerName(src) or ('Player ' .. tostring(src))
    return tostring(name):gsub('%^%d', '')
end

local function getDzCoins(uid)
    if not uid then return 0 end

    local q = ('SELECT `%s` FROM `%s` WHERE `%s` = ? LIMIT 1'):format(
        Config.Database.dzCoinsColumn,
        Config.Database.usersTable,
        Config.Database.uidColumn
    )

    local value = MySQL.scalar.await(q, { uid })
    return tonumber(value or 0) or 0
end

RegisterNetEvent('driftzone_escmenu:server:requestData', function()
    local src = source
    local uid = getUid(src)

    TriggerClientEvent('driftzone_escmenu:client:data', src, {
        name = getPlayerNameClean(src),
        uid = uid or 0,
        dzcoins = getDzCoins(uid),
        discordInvite = Config.DiscordInvite,
        cards = Config.Cards,
        images = Config.Images,
        mainColor = Config.MainColor
    })
end)

exports('RunCommand', function(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    TriggerClientEvent('driftzone_escmenu:client:openCommand', src)
end)

RegisterCommand(Config.OpenCommand or 'escmenu', function(src)
    if src == 0 then return end
    TriggerClientEvent('driftzone_escmenu:client:openCommand', src)
end, false)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_ESCMENU] Server-side loaded.')
end)
