local sessions = {}
local tableName = Config.DatabaseTable
local databaseReady = false
local databaseInitializing = false

math.randomseed(os.time())

local function nowMs()
    return GetGameTimer()
end

local function distanceBetween(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function notify(source, kind, title, message, duration)
    TriggerClientEvent('driftzone_mechanic:client:notify', source, kind, title, message, duration or 5000)
end

local function getRank(xp)
    xp = tonumber(xp) or 0
    local selectedIndex = 1
    for index, rank in pairs(Config.Ranks) do
        if xp >= rank.minXP and index > selectedIndex then
            selectedIndex = index
        end
    end
    return selectedIndex, Config.Ranks[selectedIndex]
end

local function getNextRankProgress(xp, rankIndex)
    local current = Config.Ranks[rankIndex]
    local nextRank = Config.Ranks[rankIndex + 1]
    if not nextRank then
        return 100, xp, xp, nil
    end

    local span = nextRank.minXP - current.minXP
    local progress = math.floor(((xp - current.minXP) / span) * 100)
    return math.max(0, math.min(100, progress)), xp - current.minXP, span, nextRank.name
end

local requiredColumns = {
    player_name = "VARCHAR(80) NOT NULL DEFAULT 'Necunoscut'",
    employed = 'TINYINT(1) NOT NULL DEFAULT 0',
    xp = 'INT NOT NULL DEFAULT 0',
    total_jobs = 'INT NOT NULL DEFAULT 0',
    total_earnings = 'INT NOT NULL DEFAULT 0',
    internal_wallet = 'INT NOT NULL DEFAULT 0',
    created_at = 'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
    updated_at = 'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'
}

local function ensureDatabase()
    if databaseReady then return true end

    if databaseInitializing then
        local timeout = GetGameTimer() + 10000
        while databaseInitializing and GetGameTimer() < timeout do
            Wait(50)
        end
        return databaseReady
    end

    databaseInitializing = true
    local ok, err = pcall(function()
        if type(tableName) ~= 'string' or not tableName:match('^[%w_]+$') then
            error('Config.DatabaseTable conține un nume invalid.')
        end

        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS `%s` (
                `identifier` VARCHAR(80) NOT NULL,
                `player_name` VARCHAR(80) NOT NULL DEFAULT 'Necunoscut',
                `employed` TINYINT(1) NOT NULL DEFAULT 0,
                `xp` INT NOT NULL DEFAULT 0,
                `total_jobs` INT NOT NULL DEFAULT 0,
                `total_earnings` INT NOT NULL DEFAULT 0,
                `internal_wallet` INT NOT NULL DEFAULT 0,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]):format(tableName))

        -- CREATE TABLE IF NOT EXISTS nu repară tabelele vechi. Adăugăm automat
        -- coloanele lipsă, astfel încât angajarea să nu rămână blocată după update-uri.
        local existing = {}
        for _, column in ipairs(MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(tableName)) or {}) do
            existing[column.Field] = true
        end

        for column, definition in pairs(requiredColumns) do
            if not existing[column] then
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, column, definition))
                print(('[driftzone_mechanic] Coloana lipsă `%s` a fost creată.'):format(column))
            end
        end
    end)

    databaseInitializing = false
    databaseReady = ok

    if not ok then
        print(('[driftzone_mechanic] EROARE BAZĂ DE DATE: %s'):format(tostring(err)))
        return false
    end

    print('[driftzone_mechanic] Baza de date este pregătită și verificată.')
    return true
end

local function ensureProfile(source)
    if not ensureDatabase() then
        return nil, 'Baza de date nu este disponibilă.'
    end

    local identifier = DZMechanicBridge.GetIdentifier(source)
    if not identifier or identifier == '' then
        return nil, 'Identificatorul jucătorului nu a putut fi obținut.'
    end

    local ok, rowOrError = pcall(function()
        local playerName = DZMechanicBridge.GetPlayerName(source)
        MySQL.query.await(([[
            INSERT INTO `%s` (`identifier`, `player_name`)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE
                `player_name` = VALUES(`player_name`),
                `updated_at` = CURRENT_TIMESTAMP
        ]]):format(tableName), { identifier, playerName })

        return MySQL.single.await(([[
            SELECT * FROM `%s` WHERE `identifier` = ? LIMIT 1
        ]]):format(tableName), { identifier })
    end)

    if not ok then
        print(('[driftzone_mechanic] Eroare profil pentru ID %s: %s'):format(source, tostring(rowOrError)))
        return nil, 'Profilul de mecanic nu a putut fi încărcat.'
    end

    if not rowOrError then
        return nil, 'Profilul de mecanic nu a fost găsit după creare.'
    end

    return rowOrError
end

local function buildProfile(source)
    local row, profileError = ensureProfile(source)
    if not row then return nil, profileError end

    local xp = tonumber(row.xp) or 0
    local rankIndex, rank = getRank(xp)
    local progress, currentXP, neededXP, nextRank = getNextRankProgress(xp, rankIndex)
    local session = sessions[source]
    local employed = row.employed == true or tonumber(row.employed) == 1

    return {
        employed = employed,
        xp = xp,
        rankIndex = rankIndex,
        rankName = rank.name,
        xpProgress = progress,
        currentRankXP = currentXP,
        neededRankXP = neededXP,
        nextRankName = nextRank,
        totalJobs = tonumber(row.total_jobs) or 0,
        totalEarnings = tonumber(row.total_earnings) or 0,
        internalWallet = tonumber(row.internal_wallet) or 0,
        framework = DZMechanicBridge.GetFramework(),
        onDuty = session and session.onDuty or false,
        shiftJobs = session and session.completions or 0,
        shiftMistakes = session and session.mistakes or 0
    }
end

local function sendProfile(source)
    local profile, profileError = buildProfile(source)
    if not profile then
        notify(source, 'error', 'Atelier', profileError or 'Profilul nu a putut fi încărcat.', 7000)
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return false
    end

    TriggerClientEvent('driftzone_mechanic:client:openMenu', source, profile)
    return true
end

local function validPlayerDistance(source, target, maximum)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    local coords = GetEntityCoords(ped)
    return distanceBetween(coords, target) <= maximum
end

local function payPlayer(source, amount, reason)
    local added = DZMechanicBridge.AddMoney(source, amount, reason)
    if added then return end

    local identifier = DZMechanicBridge.GetIdentifier(source)
    MySQL.update.await(([[
        UPDATE `%s` SET `internal_wallet` = `internal_wallet` + ?
        WHERE `identifier` = ?
    ]]):format(tableName), { amount, identifier })
end

local function updateProgress(source, money, xp, jobs)
    local identifier = DZMechanicBridge.GetIdentifier(source)
    MySQL.update.await(([[
        UPDATE `%s`
        SET `xp` = `xp` + ?,
            `total_jobs` = `total_jobs` + ?,
            `total_earnings` = `total_earnings` + ?,
            `updated_at` = CURRENT_TIMESTAMP
        WHERE `identifier` = ?
    ]]):format(tableName), { xp, jobs or 0, money, identifier })
end

local function availableTaskTypes(rankIndex)
    local result = {}
    for taskType, data in pairs(Config.TaskTypes) do
        if rankIndex >= data.minRank then
            result[#result + 1] = taskType
        end
    end
    return result
end

local function createTask(source)
    local session = sessions[source]
    if not session or not session.onDuty or not session.hasTools or session.task then return end

    local profile = buildProfile(source)
    if not profile then
        notify(source, 'error', 'Dispecerat', 'Profilul nu a putut fi încărcat. Încearcă din nou.')
        return
    end
    local allowed = availableTaskTypes(profile.rankIndex)
    if #allowed == 0 then return end

    local taskType = allowed[math.random(1, #allowed)]
    local locationIndex
    repeat
        locationIndex = math.random(1, #Config.TaskLocations)
    until #Config.TaskLocations == 1 or locationIndex ~= session.lastLocation

    session.lastLocation = locationIndex
    local location = Config.TaskLocations[locationIndex]
    local taskConfig = Config.TaskTypes[taskType]
    local urgent = math.random() <= Config.UrgentCallChance

    local task = {
        id = ('%s:%s:%s'):format(source, os.time(), math.random(100000, 999999)),
        type = taskType,
        label = taskConfig.label,
        description = taskConfig.description,
        difficulty = taskConfig.difficulty,
        coords = { x = location.x, y = location.y, z = location.z, w = location.w },
        vehicleModel = Config.TaskVehicleModels[math.random(1, #Config.TaskVehicleModels)],
        urgent = urgent,
        estimatedMin = math.floor(taskConfig.pay[1] * (urgent and Config.UrgentPayMultiplier or 1)),
        estimatedMax = math.floor(taskConfig.pay[2] * (urgent and Config.UrgentPayMultiplier or 1)),
        assignedAt = nowMs(),
        gameStartedAt = nil
    }

    session.task = task
    TriggerClientEvent('driftzone_mechanic:client:taskAssigned', source, task)
end

local function finishShift(source, aborted)
    local session = sessions[source]
    if not session then return end

    local bonusMoney, bonusXP = 0, 0
    if not aborted and session.completions >= Config.FlawlessBonus.minimumJobs and session.mistakes == 0 then
        bonusMoney = Config.FlawlessBonus.money
        bonusXP = Config.FlawlessBonus.xp
        payPlayer(source, bonusMoney, 'mechanic-flawless-bonus')
        updateProgress(source, bonusMoney, bonusXP, 0)
    end

    sessions[source] = nil
    TriggerClientEvent('driftzone_mechanic:client:shiftEnded', source, {
        aborted = aborted == true,
        bonusMoney = bonusMoney,
        bonusXP = bonusXP
    })
end

CreateThread(function()
    Wait(0)
    ensureDatabase()
end)

RegisterNetEvent('driftzone_mechanic:server:requestMenu', function()
    local source = source
    sendProfile(source)
end)

RegisterNetEvent('driftzone_mechanic:server:hire', function()
    local source = source
    local row, profileError = ensureProfile(source)
    if not row then
        notify(source, 'error', 'Atelier', profileError or 'Angajarea nu a putut fi procesată.', 7000)
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end

    if row.employed == true or tonumber(row.employed) == 1 then
        notify(source, 'info', 'Atelier', 'Ești deja angajat ca mecanic.')
        sendProfile(source)
        return
    end

    local identifier = DZMechanicBridge.GetIdentifier(source)
    local ok, verificationOrError = pcall(function()
        MySQL.update.await(([[
            UPDATE `%s`
            SET `employed` = 1, `updated_at` = CURRENT_TIMESTAMP
            WHERE `identifier` = ?
        ]]):format(tableName), { identifier })

        return MySQL.single.await(([[
            SELECT `employed` FROM `%s` WHERE `identifier` = ? LIMIT 1
        ]]):format(tableName), { identifier })
    end)

    if not ok then
        print(('[driftzone_mechanic] Angajare eșuată pentru ID %s: %s'):format(source, tostring(verificationOrError)))
        notify(source, 'error', 'Atelier', 'A apărut o eroare la salvarea angajării. Verifică consola serverului.', 7000)
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end

    local verification = verificationOrError
    if not verification or not (verification.employed == true or tonumber(verification.employed) == 1) then
        notify(source, 'error', 'Atelier', 'Angajarea nu a fost confirmată de baza de date.', 7000)
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end

    notify(source, 'success', 'Atelier', 'Ai fost angajat ca Mecanic I. Acum poți începe tura.')
    sendProfile(source)
end)

RegisterNetEvent('driftzone_mechanic:server:resign', function()
    local source = source
    if sessions[source] and sessions[source].onDuty then
        notify(source, 'error', 'Atelier', 'Încheie tura înainte de a demisiona.')
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end

    local row, profileError = ensureProfile(source)
    if not row then
        notify(source, 'error', 'Atelier', profileError or 'Demisia nu a putut fi procesată.', 7000)
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end

    local identifier = DZMechanicBridge.GetIdentifier(source)
    local ok, updateError = pcall(function()
        MySQL.update.await(([[
            UPDATE `%s`
            SET `employed` = 0, `updated_at` = CURRENT_TIMESTAMP
            WHERE `identifier` = ?
        ]]):format(tableName), { identifier })
    end)

    if not ok then
        print(('[driftzone_mechanic] Demisie eșuată pentru ID %s: %s'):format(source, tostring(updateError)))
        notify(source, 'error', 'Atelier', 'Demisia nu a putut fi salvată.', 7000)
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end

    notify(source, 'info', 'Atelier', 'Ai demisionat. Progresul tău a fost păstrat.')
    sendProfile(source)
end)

RegisterNetEvent('driftzone_mechanic:server:startShift', function()
    local source = source
    if sessions[source] and sessions[source].onDuty then
        sendProfile(source)
        return
    end

    local profile, profileError = buildProfile(source)
    if not profile then
        notify(source, 'error', 'Atelier', profileError or 'Profilul nu a putut fi încărcat.', 7000)
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end
    if not profile.employed then
        notify(source, 'error', 'Atelier', 'Trebuie să te angajezi mai întâi.')
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end

    sessions[source] = {
        onDuty = true,
        hasTools = false,
        serviceNetId = nil,
        task = nil,
        completions = 0,
        mistakes = 0,
        lastLocation = nil,
        lastTaskRequest = 0,
        lastResult = 0
    }

    TriggerClientEvent('driftzone_mechanic:client:shiftStarted', source, profile)
end)

RegisterNetEvent('driftzone_mechanic:server:registerServiceVehicle', function(netId)
    local source = source
    local session = sessions[source]
    if not session or not session.onDuty then return end
    netId = tonumber(netId)
    if not netId then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity > 0 then
        if GetEntityType(entity) ~= 2 then return end
        if GetEntityModel(entity) ~= joaat(Config.ServiceVehicle.model) then return end
        if NetworkGetEntityOwner(entity) ~= source then return end
    end

    session.serviceNetId = netId
end)

RegisterNetEvent('driftzone_mechanic:server:abortShift', function()
    finishShift(source, true)
end)

RegisterNetEvent('driftzone_mechanic:server:collectTools', function()
    local source = source
    local session = sessions[source]
    if not session or not session.onDuty then return end
    if not validPlayerDistance(source, Config.ToolDepot, 5.0) then return end

    session.hasTools = true
    TriggerClientEvent('driftzone_mechanic:client:toolsCollected', source)
    createTask(source)
end)

RegisterNetEvent('driftzone_mechanic:server:requestTask', function()
    local source = source
    local session = sessions[source]
    if not session or not session.onDuty or session.task then return end

    local current = nowMs()
    if current - session.lastTaskRequest < Config.Security.taskRequestCooldownMs then return end
    session.lastTaskRequest = current
    createTask(source)
end)

RegisterNetEvent('driftzone_mechanic:server:startTask', function(taskId)
    local source = source
    local session = sessions[source]
    if not session or not session.task or session.task.id ~= taskId then return end
    if session.task.gameStartedAt then return end

    local coords = session.task.coords
    if not validPlayerDistance(source, vector3(coords.x, coords.y, coords.z), Config.Security.maximumTaskDistance) then
        return
    end

    if not session.serviceNetId then return end
    local serviceVehicle = NetworkGetEntityFromNetworkId(session.serviceNetId)
    if not serviceVehicle or serviceVehicle <= 0 or GetEntityType(serviceVehicle) ~= 2 then return end
    if GetEntityModel(serviceVehicle) ~= joaat(Config.ServiceVehicle.model) then return end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local serviceCoords = GetEntityCoords(serviceVehicle)
    if distanceBetween(playerCoords, serviceCoords) > (Config.ServiceVehicleMaxDistance + 12.0) then
        notify(source, 'error', 'Intervenție', Config.Text.noServiceVehicle)
        return
    end

    session.task.gameStartedAt = nowMs()
    TriggerClientEvent('driftzone_mechanic:client:beginMinigame', source, session.task)
end)

RegisterNetEvent('driftzone_mechanic:server:taskResult', function(taskId, success)
    local source = source
    local session = sessions[source]
    if not session or not session.task or session.task.id ~= taskId then return end
    if not session.task.gameStartedAt then return end

    local current = nowMs()
    if current - session.lastResult < Config.Security.resultCooldownMs then return end
    session.lastResult = current

    local elapsed = current - session.task.gameStartedAt
    if success and elapsed < Config.Security.minimumGameTimeMs then
        print(('[driftzone_mechanic] Rezultat prea rapid blocat pentru %s (%sms)'):format(source, elapsed))
        session.task.gameStartedAt = nil
        session.mistakes = session.mistakes + 1
        TriggerClientEvent('driftzone_mechanic:client:taskFailed', source, session.task.id)
        return
    end

    local coords = session.task.coords
    if not validPlayerDistance(source, vector3(coords.x, coords.y, coords.z), Config.Security.maximumTaskDistance) then
        return
    end

    if not success then
        session.mistakes = session.mistakes + 1
        session.task.gameStartedAt = nil
        TriggerClientEvent('driftzone_mechanic:client:taskFailed', source, session.task.id)
        return
    end

    local profileBefore = buildProfile(source)
    if not profileBefore then
        notify(source, 'error', 'Intervenție', 'Profilul nu a putut fi încărcat. Plata nu a fost procesată.')
        session.task.gameStartedAt = nil
        return
    end
    local taskConfig = Config.TaskTypes[session.task.type]
    local rank = Config.Ranks[profileBefore.rankIndex]
    local reward = math.random(taskConfig.pay[1], taskConfig.pay[2])
    local xp = math.random(taskConfig.xp[1], taskConfig.xp[2])

    reward = math.floor(reward * rank.multiplier)
    if session.task.urgent then
        reward = math.floor(reward * Config.UrgentPayMultiplier)
        xp = xp + Config.UrgentXPBonus
    end

    payPlayer(source, reward, 'mechanic-intervention')
    updateProgress(source, reward, xp, 1)

    session.completions = session.completions + 1
    local completedTask = session.task
    session.task = nil

    local profileAfter = buildProfile(source) or profileBefore
    local promoted = profileAfter.rankIndex > profileBefore.rankIndex

    TriggerClientEvent('driftzone_mechanic:client:taskCompleted', source, {
        taskId = completedTask.id,
        reward = reward,
        xp = xp,
        completed = session.completions,
        mistakes = session.mistakes,
        promoted = promoted,
        rankName = profileAfter.rankName,
        framework = profileAfter.framework
    })
end)

RegisterNetEvent('driftzone_mechanic:server:endShift', function()
    local source = source
    local session = sessions[source]
    if not session or not session.onDuty then
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end
    if not validPlayerDistance(source, vector3(Config.BossNPC.coords.x, Config.BossNPC.coords.y, Config.BossNPC.coords.z), 7.0) then
        notify(source, 'error', 'Atelier', 'Trebuie să fii lângă șeful atelierului pentru a încheia tura.')
        TriggerClientEvent('driftzone_mechanic:client:menuActionFinished', source, false)
        return
    end
    finishShift(source, false)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)
