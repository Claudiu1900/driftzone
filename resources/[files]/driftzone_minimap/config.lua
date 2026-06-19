Config = {}

-- Valori inițiale pentru jucătorii fără statistici salvate.
Config.DefaultHealth = 100
Config.DefaultArmour = 0
Config.DefaultFood = 100
Config.DefaultWater = 100

-- Evită ca un jucător salvat mort să intre blocat la 0 HP.
-- Valoarea 1 păstrează jucătorul în viață la reconnect.
Config.MinimumLoadedHealth = 1

-- Scăderea statusurilor.
Config.FoodLossAmount = 1
Config.FoodLossInterval = 20 * 1000
Config.WaterLossAmount = 1
Config.WaterLossInterval = 40 * 1000

-- Damage când un status sau ambele sunt la 0.
-- Când ambele sunt 0 se aplică doar regula BothZero.
Config.SingleZeroDamagePercent = 5
Config.SingleZeroDamageInterval = 30 * 1000
Config.BothZeroDamagePercent = 10
Config.BothZeroDamageInterval = 40 * 1000

-- Intervale optimizate.
Config.ServerTickInterval = 1000
Config.DatabaseSaveInterval = 30 * 1000
Config.ClientHudUpdateInterval = 150
Config.VitalsReportInterval = 2000
Config.VitalsHeartbeatInterval = 15000
Config.VitalsApplyDelay = 900

-- Stamina custom: pornește la 100%, scade la sprint și se regenerează după oprire.
-- Nu folosește procentul nativ FiveM, deci afișarea nu poate fi inversată.
Config.Stamina = {
    DrainPerSecond = 3.0,
    RegenPerSecond = 7.0,
    RegenDelay = 850,
    HideDelay = 650,
    ResumeSprintAt = 18.0,
    MinimumMoveSpeed = 1.35,
    ActiveTick = 50,
    IdleTick = 150
}

-- Toate valorile sunt salvate ca JSON în users.stats.
Config.Database = {
    UsersTable = 'users',
    StatsColumn = 'stats',

    -- Coloana principală din users. Resursa încearcă automat și alte variante.
    UserIdColumn = 'id',

    -- Tabele uzuale care leagă license/identifier de users.id.
    MappingTables = {
        'vrp_user_ids',
        'user_ids'
    },

    -- Creează automat users.stats dacă nu există.
    AutoCreateStatsColumn = true
}

-- Trigger-ele client-side cerute.
Config.AllowClientAddTriggers = true
Config.MaxAddPerTrigger = 100
Config.ClientTriggerCooldown = 500

Config.Minimap = {
    Enabled = true,
    HideWithHud = true,
    HideDefaultHealthArmour = true,

    -- Valoare negativă = harta urcă.
    VerticalOffset = -0.045,

    Components = {
        minimap = {
            alignX = 'L', alignY = 'B',
            x = -0.0045, y = -0.0220,
            width = 0.1500, height = 0.188888
        },
        minimap_mask = {
            alignX = 'L', alignY = 'B',
            x = 0.0200, y = -0.0220,
            width = 0.1110, height = 0.1590
        },
        minimap_blur = {
            alignX = 'L', alignY = 'B',
            x = -0.0300, y = 0.0000,
            width = 0.2660, height = 0.2370
        }
    }
}

-- Trigger extern pentru HUD:
-- TriggerEvent('driftzone_minimap:client:setVisible', true/false)
