Config = {}

-- Valori inițiale pentru jucătorii fără date salvate.
Config.DefaultFood = 100
Config.DefaultWater = 100

-- Scăderea statusurilor.
Config.FoodLossAmount = 1
Config.FoodLossInterval = 20 * 1000
Config.WaterLossAmount = 1
Config.WaterLossInterval = 40 * 1000

-- Damage când un status sau ambele statusuri sunt la 0.
-- Când ambele sunt 0 se aplică DOAR regula BothZero, nu și SingleZero.
Config.SingleZeroDamagePercent = 5
Config.SingleZeroDamageInterval = 30 * 1000
Config.BothZeroDamagePercent = 10
Config.BothZeroDamageInterval = 40 * 1000

-- Intervale optimizate.
Config.ServerTickInterval = 1000
Config.DatabaseSaveInterval = 60 * 1000
Config.ClientHudUpdateInterval = 150

-- Persistență automată dacă resursa oxmysql este pornită.
Config.UseOxMySQL = true
Config.DatabaseTable = 'driftzone_status'

-- Trigger-ele de client cerute:
-- TriggerServerEvent('driftzone_minimap:addFood', amount)
-- TriggerServerEvent('driftzone_minimap:addWater', amount)
-- Pentru inventare server-side este mai sigur să folosești trigger-ele server-side din README.
Config.AllowClientAddTriggers = true
Config.MaxAddPerTrigger = 100
Config.ClientTriggerCooldown = 500

Config.Minimap = {
    Enabled = true,
    HideWithHud = true,
    HideDefaultHealthArmour = true,

    -- Ridică minimap-ul pentru a lăsa HUD-ul sub el.
    -- Mărește valoarea dacă dorești harta și mai sus.
    VerticalOffset = 0.055,

    -- Pozițiile originale GTA/FiveM; VerticalOffset se adaugă automat pe Y.
    Components = {
        minimap = {
            alignX = 'L', alignY = 'B',
            x = -0.0045, y = 0.0020,
            width = 0.1500, height = 0.188888
        },
        minimap_mask = {
            alignX = 'L', alignY = 'B',
            x = 0.0200, y = 0.0320,
            width = 0.1110, height = 0.1590
        },
        minimap_blur = {
            alignX = 'L', alignY = 'B',
            x = -0.0300, y = 0.0220,
            width = 0.2660, height = 0.2370
        }
    }
}

-- Eveniment extern pentru ascunderea/afișarea HUD-ului:
-- TriggerEvent('driftzone_minimap:client:setVisible', true/false)
