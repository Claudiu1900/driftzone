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

local function sendChat(src, message)
    TriggerClientEvent('driftzone_chat:client:addMessage', src, {
        type = 'system',
        time = os.date('%H:%M'),
        text = tostring(message or '')
    })
end

local function notify(src, notifyType, message, duration)
    TriggerClientEvent('client:notify', src, notifyType or 'info', duration or 5000, tostring(message or ''))
end

local function getCharacter(uid)
    if not uid then return nil end

    local value = MySQL.scalar.await(
        'SELECT `character` FROM users WHERE uid = ? LIMIT 1',
        { uid }
    )

    if not value or tostring(value) == '' or tostring(value) == 'null' then
        return nil
    end

    local ok, decoded = pcall(json.decode, tostring(value))

    if not ok or type(decoded) ~= 'table' then
        return nil
    end

    return decoded
end

local function getSavedClothes(uid)
    if not uid then return '{}' end

    local value = MySQL.scalar.await(
        'SELECT clothes FROM users WHERE uid = ? LIMIT 1',
        { uid }
    )

    if not value or tostring(value) == '' or tostring(value) == 'null' then
        return '{}'
    end

    return tostring(value)
end

local function saveCharacter(uid, character)
    if not uid then return false end
    if type(character) ~= 'table' then return false end

    MySQL.update.await(
        'UPDATE users SET `character` = ? WHERE uid = ?',
        {
            json.encode(character),
            uid
        }
    )

    return true
end

local function sendClothesApply(src, uid)
    src = tonumber(src)
    uid = tonumber(uid)

    if not src or src <= 0 then return end
    if not uid or uid <= 0 then return end
    if GetPlayerPing(src) <= 0 then return end

    local clothes = getSavedClothes(uid)

    TriggerClientEvent('client:clothes:fix', src, clothes)
    TriggerClientEvent('driftzone_clothes:client:apply', src, clothes)
    TriggerClientEvent('client:clothes:forceUnfreeze', src)
end

local function applyClothesAfterCharacter(src, uid)
    local delays = {
        700,
        1400,
        2500,
        4000,
        6500,
        9000
    }

    for _, delay in ipairs(delays) do
        SetTimeout(delay, function()
            sendClothesApply(src, uid)
        end)
    end
end

local function applyCharacterAndClothes(src, uid, character)
    if not src or src <= 0 then return end
    if not uid then return end
    if type(character) ~= 'table' then return end

    TriggerClientEvent('driftzone_character:client:apply', src, character)

    applyClothesAfterCharacter(src, uid)
end

local function openCharacterCreatorFor(src)
    src = tonumber(src)

    if not src or src <= 0 then return end

    local uid = getUid(src)

    if not uid then
        sendChat(src, 'Trebuie sa fii logat ca sa folosesti /character.')
        return
    end

    local character = getCharacter(uid)

    if character then
        TriggerClientEvent('driftzone_character:client:open', src, character, false)
    else
        TriggerClientEvent('driftzone_character:client:open', src, nil, true)
    end
end

local function fixCharacterFor(src)
    src = tonumber(src)

    if not src or src <= 0 then return end

    local uid = getUid(src)

    if not uid then
        sendChat(src, 'Trebuie sa fii logat ca sa folosesti /fixcharacter.')
        return
    end

    local character = getCharacter(uid)

    if character then
        applyCharacterAndClothes(src, uid, character)
        sendChat(src, 'Caracterul si hainele au fost reincarcate.')
    else
        TriggerClientEvent('driftzone_character:client:open', src, nil, true)
    end
end

RegisterNetEvent('driftzone_character:server:check', function()
    local src = source
    local uid = getUid(src)

    if not uid then return end

    local character = getCharacter(uid)

    if character then
        applyCharacterAndClothes(src, uid, character)
    else
        TriggerClientEvent('driftzone_character:client:open', src, nil, true)
    end
end)

RegisterNetEvent('driftzone_character:server:requestApply', function()
    local src = source

    fixCharacterFor(src)
end)

RegisterNetEvent('driftzone_character:server:save', function(payload)
    local src = source
    local uid = getUid(src)

    if not uid then return end

    local data = payload

    if type(data) == 'string' then
        local ok, decoded = pcall(json.decode, data)

        if not ok or type(decoded) ~= 'table' then
            notify(src, 'warning', 'Date caracter invalide.')
            return
        end

        data = decoded
    end

    if type(data) ~= 'table' then
        notify(src, 'warning', 'Date caracter invalide.')
        return
    end

    data.gender = data.gender == 'female' and 'female' or 'male'
    data.savedAt = os.time()

    local saved = saveCharacter(uid, data)

    if not saved then
        notify(src, 'warning', 'Caracterul nu a putut fi salvat.')
        return
    end

    applyCharacterAndClothes(src, uid, data)

    TriggerClientEvent('driftzone_character:client:saved', src, data)

    notify(src, 'info', 'Caracterul a fost salvat cu succes.')
    sendChat(src, 'Caracterul tau a fost salvat cu succes.')
end)

RegisterNetEvent('driftzone_character:server:openCommand', function()
    openCharacterCreatorFor(source)
end)

RegisterNetEvent('driftzone_character:server:fixCommand', function()
    fixCharacterFor(source)
end)

RegisterCommand('character', function(src)
    if src == 0 then return end

    openCharacterCreatorFor(src)
end, false)

RegisterCommand('fixcharacter', function(src)
    if src == 0 then return end

    fixCharacterFor(src)
end, false)

exports('OpenCharacterCreator', function(src)
    openCharacterCreatorFor(src)
end)

exports('FixCharacter', function(src)
    fixCharacterFor(src)
end)

exports('ApplyCharacterAndClothes', function(src)
    local uid = getUid(src)

    if not uid then return end

    local character = getCharacter(uid)

    if character then
        applyCharacterAndClothes(src, uid, character)
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    print('[DRIFTZONE_CHARACTER] Server-side loaded.')
end)