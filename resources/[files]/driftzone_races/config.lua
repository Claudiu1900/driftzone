Config = {}

Config.MainColor = '#04c7f7'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsersNameColumn = 'username'
Config.UsersCashColumn = 'cash'

Config.OwnedVehiclesTable = 'ownedvehicles'
Config.OwnedVehicleIdColumn = 'id'
Config.OwnedVehicleOwnerColumn = 'owner_id'
Config.OwnedVehicleModelColumn = 'vehicle_model'
Config.OwnedVehiclePlateColumn = 'vehicle_plate'
Config.OwnedVehicleTuningColumn = 'vehicle_tunning'

Config.VehicleNamesTable = 'vehiclenames'
Config.VehicleNamesModelColumn = 'vehicle_model'
Config.VehicleNamesNameColumn = 'vehicle_name'
Config.VehicleNamesImageColumn = 'vehicle_image'
Config.VehicleNamesTypeColumn = 'type'

Config.StatsTable = 'races'

Config.NotifyEvent = 'client:notify'
Config.InteractionEvent = 'driftzone_races:client:openFromInteraction'

Config.MinPlayers = 2
Config.LobbyStartAfterNoJoinSeconds = 60
Config.CountdownSeconds = 3
Config.RaceBucketBase = 73000
Config.ReturnBucket = 0
Config.FinishRadius = 9.0
Config.CheckpointRadius = 12.0
Config.EntryFeeMin = 1
Config.EntryFeeMax = 500000000
Config.HouseTaxPercent = 10

Config.Vehicle = {
    spawnZOffset = 0.55,
    freezeDuringCountdown = true,
    protectVehicle = true,
    cleanupAfterRace = true,
    spawnTimeoutMs = 15000,
    ghostPlayers = true,
    tuningApplyDelays = { 100, 350, 750, 1400, 2400, 3600 }
}

Config.Interaction = {
    id = 'driftzone_races_main',
    coords = vector3(-1336.180176, -3044.254882, 14.890136),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Lobby',
    subText = 'DriftZone Races',
    marker = true,
    event = 'driftzone_races:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Races' }
}

Config.RaceTypes = {
    drift_mountain = {
        id = 'drift_mountain',
        label = 'Drift Race',
        type = 'drift',
        description = 'Cursa de drift pe munte cu checkpoint-uri directionale si lobby privat/public.',
        maxPlayers = 4,
        minPlayers = 2,
        startPositions = {
            vector4(261.639556, 1160.927490, 223.878418, 11.34),
            vector4(269.934082, 1163.169190, 223.844726, 5.67),
            vector4(256.681336, 1159.542846, 223.777344, 8.50),
            vector4(273.600006, 1164.000000, 223.726684, 8.50)
        },
        checkpoints = {
            { coords = vector3(243.995606, 1318.153808, 237.088624), direction = 'left' },
            { coords = vector3(114.487916, 1392.290162, 257.392700), direction = 'straight' },
            { coords = vector3(-37.279122, 1479.876954, 276.770020), direction = 'straight' },
            { coords = vector3(-168.276916, 1504.575806, 288.918702), direction = 'straight' },
            { coords = vector3(-449.881318, 1387.437378, 297.293090), direction = 'right' },
            { coords = vector3(-647.525268, 1348.272584, 290.687866), direction = 'straight' },
            { coords = vector3(-719.393432, 1168.351684, 263.846192), direction = 'left' },
            { coords = vector3(-704.729676, 918.210998, 232.690796), direction = 'straight' },
            { coords = vector3(-938.716492, 790.496704, 181.433716), direction = 'straight' },
            { coords = vector3(-1023.626404, 792.118652, 169.773682), direction = 'left' },
            { coords = vector3(-875.208802, 707.314270, 149.654908), direction = 'straight' },
            { coords = vector3(-681.560424, 685.872558, 153.580932), direction = 'right' },
            { coords = vector3(-538.496704, 665.235168, 142.847656), direction = 'right' },
            { coords = vector3(-549.428588, 524.980224, 107.749512), direction = 'straight' },
            { coords = vector3(-530.175842, 353.578034, 83.064454), direction = 'right' },
            { coords = vector3(-608.215394, 339.745056, 85.103272), direction = 'finish' }
        }
    }
}

Config.Debug = false
