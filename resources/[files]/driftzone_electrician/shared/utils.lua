DriftzoneElectrician = DriftzoneElectrician or {}

function DriftzoneElectrician.GetLevelFromXp(xp)
    xp = math.max(0, tonumber(xp) or 0)
    local selected = 1

    for level = 1, #Config.Levels do
        local data = Config.Levels[level]
        if data and xp >= (tonumber(data.minXp) or 0) then
            selected = level
        end
    end

    return selected, Config.Levels[selected]
end

function DriftzoneElectrician.GetNextLevelXp(level)
    local nextData = Config.Levels[(tonumber(level) or 1) + 1]
    return nextData and tonumber(nextData.minXp) or nil
end

function DriftzoneElectrician.CopyCoords(coords)
    return {
        x = (coords.x or 0.0) + 0.0,
        y = (coords.y or 0.0) + 0.0,
        z = (coords.z or 0.0) + 0.0
    }
end

function DriftzoneElectrician.FormatProfile(data)
    data = data or {}
    local level, levelData = DriftzoneElectrician.GetLevelFromXp(data.xp)

    return {
        employed = data.employed == true,
        xp = math.max(0, tonumber(data.xp) or 0),
        level = level,
        levelName = levelData and levelData.name or 'Electrician I',
        multiplier = levelData and levelData.multiplier or 1.0,
        nextLevelXp = DriftzoneElectrician.GetNextLevelXp(level),
        totalJobs = math.max(0, tonumber(data.totalJobs) or 0),
        totalEarned = math.max(0, tonumber(data.totalEarned) or 0),
        shiftsCompleted = math.max(0, tonumber(data.shiftsCompleted) or 0),
        cleanShifts = math.max(0, tonumber(data.cleanShifts) or 0),
        pendingPay = math.max(0, tonumber(data.pendingPay) or 0)
    }
end
