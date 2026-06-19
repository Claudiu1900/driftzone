DZMechanicBridge = {}

local activeFramework = 'internal'
local QBCore, ESX

local function detectFramework()
    local requested = string.lower(Config.Framework or 'auto')

    if (requested == 'auto' or requested == 'qb') and GetResourceState('qb-core') == 'started' then
        local ok, object = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and object then
            QBCore = object
            activeFramework = 'qb'
            return
        end
    end

    if (requested == 'auto' or requested == 'esx') and GetResourceState('es_extended') == 'started' then
        local ok, object = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and object then
            ESX = object
            activeFramework = 'esx'
            return
        end
    end

    activeFramework = 'internal'
end

CreateThread(function()
    Wait(500)
    detectFramework()
    print(('[driftzone_mechanic] Bridge activ: %s'):format(activeFramework))
end)

local function licenseIdentifier(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end
    return ('source:%s'):format(source)
end

function DZMechanicBridge.GetIdentifier(source)
    if activeFramework == 'qb' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        return player and player.PlayerData.citizenid or licenseIdentifier(source)
    end

    if activeFramework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        return player and player.identifier or licenseIdentifier(source)
    end

    return licenseIdentifier(source)
end

function DZMechanicBridge.GetPlayerName(source)
    if activeFramework == 'qb' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if player and player.PlayerData.charinfo then
            return (('%s %s'):format(player.PlayerData.charinfo.firstname or '', player.PlayerData.charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
        end
    elseif activeFramework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        if player and player.getName then
            return player.getName()
        end
    end

    return GetPlayerName(source) or ('Jucător %s'):format(source)
end

-- Pentru un framework custom, modifică doar această funcție.
-- Returnează true când banii au fost adăugați în economia serverului.
function DZMechanicBridge.AddMoney(source, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    if activeFramework == 'qb' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        player.Functions.AddMoney(Config.PaymentAccount or 'cash', amount, reason or 'mechanic-job')
        return true
    end

    if activeFramework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        if not player then return false end
        local account = Config.PaymentAccount or 'money'
        if account == 'cash' then account = 'money' end
        player.addAccountMoney(account, amount, reason or 'mechanic-job')
        return true
    end

    -- Modul internal păstrează plata în coloana internal_wallet din tabela jobului.
    return false
end

function DZMechanicBridge.GetFramework()
    return activeFramework
end
