DriftzoneElectricianStorage = {
    ready = false
}

local RESOURCE = GetCurrentResourceName()

local function normalise(row, uid)
    row = row or {}
    return {
        uid = tonumber(uid or row.uid or 0) or 0,
        employed = row.employed == true or tonumber(row.employed) == 1,
        xp = math.max(0, tonumber(row.xp) or 0),
        totalJobs = math.max(0, tonumber(row.total_jobs or row.totalJobs) or 0),
        totalEarned = math.max(0, tonumber(row.total_earned or row.totalEarned) or 0),
        shiftsCompleted = math.max(0, tonumber(row.shifts_completed or row.shiftsCompleted) or 0),
        cleanShifts = math.max(0, tonumber(row.clean_shifts or row.cleanShifts) or 0),
        pendingPay = math.max(0, tonumber(row.pending_pay or row.pendingPay) or 0)
    }
end

function DriftzoneElectricianStorage.Init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `driftzone_electrician_players` (
            `uid` BIGINT UNSIGNED NOT NULL,
            `employed` TINYINT(1) NOT NULL DEFAULT 0,
            `xp` INT UNSIGNED NOT NULL DEFAULT 0,
            `total_jobs` INT UNSIGNED NOT NULL DEFAULT 0,
            `total_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `shifts_completed` INT UNSIGNED NOT NULL DEFAULT 0,
            `clean_shifts` INT UNSIGNED NOT NULL DEFAULT 0,
            `pending_pay` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`uid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    DriftzoneElectricianStorage.ready = true
    print(('^2[%s] Tabelul de progres este pregatit.^7'):format(RESOURCE))
end

function DriftzoneElectricianStorage.Get(uid)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return nil end

    local row = MySQL.single.await([[
        SELECT uid, employed, xp, total_jobs, total_earned, shifts_completed, clean_shifts, pending_pay
        FROM driftzone_electrician_players
        WHERE uid = ?
        LIMIT 1
    ]], { uid })

    return normalise(row, uid)
end

function DriftzoneElectricianStorage.Save(profile)
    profile = normalise(profile, profile and profile.uid)
    if profile.uid <= 0 then return false end

    MySQL.query.await([[
        INSERT INTO driftzone_electrician_players
            (uid, employed, xp, total_jobs, total_earned, shifts_completed, clean_shifts, pending_pay)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            employed = VALUES(employed),
            xp = VALUES(xp),
            total_jobs = VALUES(total_jobs),
            total_earned = VALUES(total_earned),
            shifts_completed = VALUES(shifts_completed),
            clean_shifts = VALUES(clean_shifts),
            pending_pay = VALUES(pending_pay)
    ]], {
        profile.uid,
        profile.employed and 1 or 0,
        profile.xp,
        profile.totalJobs,
        profile.totalEarned,
        profile.shiftsCompleted,
        profile.cleanShifts,
        profile.pendingPay
    })

    return true
end
