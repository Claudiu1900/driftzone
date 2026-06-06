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

local function hasNoSavedClothes(raw)
    if not raw or tostring(raw) == '' or tostring(raw) == 'null' then
        return true
    end

    local text = tostring(raw):gsub('%s+', '')

    if text == '' or text == '{}' or text == '[]' then
        return true
    end

    local ok, decoded = pcall(json.decode, tostring(raw))

    if not ok or type(decoded) ~= 'table' then
        return true
    end

    return next(decoded) == nil
end

local function reloadClothesSilent(src)
    src = tonumber(src or 0) or 0
    if src <= 0 or GetPlayerPing(src) <= 0 then return end

    pcall(function()
        exports.driftzone_clothes:ReloadClothes(src)
    end)

    TriggerClientEvent('driftzone_clothes:client:reloadSaved', src)
    TriggerClientEvent('driftzone_clothes:client:forceUnfreeze', src)
end

local function reloadClothesAfterSave(src)
    local delays = Config.ClothesReloadDelays or { 300, 900, 1800, 3500 }

    for _, delay in ipairs(delays) do
        SetTimeout(tonumber(delay or 0) or 0, function()
            reloadClothesSilent(src)
        end)
    end
end

local function ensureDefaultOutfitIfNoClothes(src, uid, gender)
    local currentClothes = getSavedClothes(uid)

    if not hasNoSavedClothes(currentClothes) then
        return false
    end

    local outfitConfig = Config.DefaultSavedOutfits or {}
    local outfitId = gender == 'female' and tonumber(outfitConfig.female or 0) or tonumber(outfitConfig.male or 0)

    if not outfitId or outfitId <= 0 then
        return false
    end

    local ok, result = pcall(function()
        return exports.driftzone_outfits:SetOutfitSilent(src, outfitId)
    end)

    if not ok then
        print(('[DRIFTZONE_CHARACTER] Failed default outfit %s for uid %s: %s'):format(outfitId, uid, tostring(result)))
        return false
    end

    return true
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

    reloadClothesSilent(src)
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

    -- Daca users.clothes este gol / {}, seteaza outfit default silent:
    -- male -> Config.DefaultSavedOutfits.male, female -> Config.DefaultSavedOutfits.female.
    ensureDefaultOutfitIfNoClothes(src, uid, data.gender)

    applyCharacterAndClothes(src, uid, data)
    reloadClothesAfterSave(src)

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

    print('[DRIFTZONE_CHARACTER] Server-side loaded. Creator clothes + default outfit fix enabled.')
end)
exports('EnsureDefaultOutfitIfNoClothes', function(src)
    local uid = getUid(src)
    if not uid then return false end

    local character = getCharacter(uid)
    local gender = character and character.gender or 'male'

    return ensureDefaultOutfitIfNoClothes(src, uid, gender)
end)
