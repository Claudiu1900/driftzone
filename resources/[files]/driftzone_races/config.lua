Config = {}

Config.MainColor = '#04c7f7'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsersNameColumn = 'username'
Config.UsersCashColumn = 'cash'
Config.UsersXpColumn = 'xp'

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
Config.ReturnPosition = vector4(-1338.316528, -3047.960450, 13.929688, 331.65)
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
        xp = { winner = 500, loser = 150 },
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
    },
    highspeed_city_to_paleto = {
        id = 'highspeed_city_to_paleto',
        label = 'Highspeed Race',
        type = 'hs',
        xp = { winner = 1200, loser = 350 },
        description = 'Cursa highspeed pentru masini rapide. Traseu lung cu maxim 8 jucatori.',
        maxPlayers = 8,
        minPlayers = 2,
        startPositions = {
            vector4(245.947250, -2083.147216, 17.400756, 229.61),
            vector4(242.202194, -2086.958252, 17.434448, 229.61),
            vector4(249.323074, -2079.177978, 17.316528, 226.77),
            vector4(238.641754, -2090.571534, 17.417602, 226.77),
            vector4(239.617584, -2077.239502, 17.653442, 226.77),
            vector4(235.595612, -2081.024170, 17.703980, 226.77),
            vector4(243.296708, -2073.560546, 17.552368, 226.77),
            vector4(232.232972, -2084.584716, 17.670288, 226.77)
        },
        checkpoints = {
            { coords = vector3(342.540650, -2158.127442, 13.980224), direction = 'left' },
            { coords = vector3(593.063720, -2057.419678, 29.313598), direction = 'straight' },
            { coords = vector3(921.863708, -2087.235108, 30.391968), direction = 'straight' },
            { coords = vector3(1208.980224, -2071.701172, 44.107666), direction = 'right' },
            { coords = vector3(1324.536254, -2324.162598, 52.583130), direction = 'straight' },
            { coords = vector3(1100.281372, -2564.848388, 31.824218), direction = 'straight' },
            { coords = vector3(621.151672, -2649.731934, 45.691528), direction = 'straight' },
            { coords = vector3(159.481324, -2650.786866, 18.799316), direction = 'straight' },
            { coords = vector3(-214.997802, -2455.542968, 55.228516), direction = 'straight' },
            { coords = vector3(-758.914306, -2075.393310, 33.964112), direction = 'straight' },
            { coords = vector3(-910.483520, -1870.061524, 31.958984), direction = 'straight' },
            { coords = vector3(-637.819764, -1732.048340, 37.485718), direction = 'straight' },
            { coords = vector3(-414.567016, -1554.949462, 38.294556), direction = 'straight' },
            { coords = vector3(-395.907684, -1031.221924, 37.216064), direction = 'straight' },
            { coords = vector3(-408.487916, -512.189026, 33.795654), direction = 'left' },
            { coords = vector3(-730.773620, -494.624176, 25.168458), direction = 'straight' },
            { coords = vector3(-1145.459350, -642.843934, 11.486450), direction = 'straight' },
            { coords = vector3(-1704.580200, -673.964844, 11.166260), direction = 'straight' },
            { coords = vector3(-1985.063720, -446.650544, 11.789794), direction = 'straight' },
            { coords = vector3(-2226.276856, -337.529664, 13.407348), direction = 'straight' },
            { coords = vector3(-2564.333984, -166.180222, 20.585328), direction = 'straight' },
            { coords = vector3(-2979.956054, 115.767036, 14.266724), direction = 'straight' },
            { coords = vector3(-2987.841796, 549.507690, 17.080566), direction = 'straight' },
            { coords = vector3(-3155.327392, 951.586792, 14.654174), direction = 'straight' },
            { coords = vector3(-2995.991210, 1479.415406, 27.780274), direction = 'straight' },
            { coords = vector3(-2986.865966, 2016.316528, 34.098876), direction = 'straight' },
            { coords = vector3(-2717.762696, 2293.489990, 18.647584), direction = 'straight' },
            { coords = vector3(-2608.035156, 2966.123046, 16.659302), direction = 'straight' },
            { coords = vector3(-2421.916504, 3852.197754, 23.854248), direction = 'straight' },
            { coords = vector3(-2189.775878, 4372.246094, 53.796386), direction = 'straight' },
            { coords = vector3(-1719.243896, 4786.206542, 58.581666), direction = 'straight' },
            { coords = vector3(-1228.892334, 5259.837402, 50.207276), direction = 'straight' },
            { coords = vector3(-807.494506, 5470.812988, 33.896728), direction = 'left' },
            { coords = vector3(-785.591186, 5524.536132, 34.250610), direction = 'right' },
            { coords = vector3(-775.041748, 5582.307618, 33.475464), direction = 'finish' }
        }
    }
}

Config.Debug = false
