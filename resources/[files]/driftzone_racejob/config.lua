Config = {}

Config.MainColor = '#04c7f7'

Config.OpenEvent = 'driftzone_racejob:client:openFromInteraction'

Config.Reward = {
    min = 2000,
    max = 5000
}

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsersCashColumn = 'cash'

Config.OwnedVehiclesTable = 'ownedvehicles'
Config.VehicleNamesTable = 'vehiclenames'

Config.SpawnDeleteExisting = true
Config.FinishRadius = 8.0
Config.CheckpointRadius = 8.0

Config.Races = {
    short = {
        id = 'short',
        title = 'Short Race',
        description = 'Cursa scurta prin oras. Reward: $2.000 - $5.000',
        enabled = true,

        start = vector4(-490.958252, -751.094482, 32.144288, 170.08),

        checkpoints = {
            vector3(-509.617584, -831.573608, 30.476196),
            vector3(-626.914306, -830.505494, 25.151612),
            vector3(-737.076904, -829.542846, 22.843262),
            vector3(-743.235168, -657.520874, 30.324584),
            vector3(-832.681336, -641.643982, 27.695922),
            vector3(-926.703308, -489.072540, 36.676880),
        },

        finish = vector3(-850.378052, -453.323060, 36.626342)
    },

    medium = {
        id = 'medium',
        title = 'Medium Race',
        description = 'In curand.',
        enabled = false
    },

    long = {
        id = 'long',
        title = 'Long Race',
        description = 'In curand.',
        enabled = false
    }
}

Config.InteractionConfig = [[
-- Adauga acest item in Config.DefaultInteractions din driftzone_interactions/config.lua

{
    id = 'driftzone_racejob_main',
    coords = vector3(-116.835160, -604.720886, 36.272584),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Job',
    subText = 'DriftZone Race Job',
    marker = true,
    event = 'driftzone_racejob:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Race Job' }
},
]]
