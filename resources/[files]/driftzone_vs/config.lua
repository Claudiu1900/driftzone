Config = {}

Config.MainColor = { r = 4, g = 199, b = 247 }

Config.Admin = {
    useDuty = true,

    commands = {
        vs = 1,
        dv = 2,
        gotoveh = 2,
        bringveh = 2,
        fixveh = 2
    }
}

Config.UpdateInterval = 1000
Config.DrawDistance = 45.0

Config.MaxHealth = 1000.0

Config.Label = {
    scale = 0.32,
    minScale = 0.22,
    maxScale = 0.38,
    lineGap = 0.023
}
-- Auto DV pentru masini abandonate in tabela VS.
-- Daca vehiculul nu are niciun jucator inauntru pentru X minute, se sterge singur.
Config.AbandonedAutoDV = {
    enabled = true,
    minutes = 30,
    checkIntervalSeconds = 60,
    printLog = true
}
