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
Config.EntryFeeMin = 10000
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
        xp = { winner = 1000, loser = 300 },
        description = 'Cursa de drift pe munte cu checkpoint-uri directionale si lobby privat/public.',
        maxPlayers = 4,
        minPlayers = 2,
        startPositions = {
            vector4(261.639556, 1160.927490, 222.878418, 11.34),
            vector4(269.934082, 1163.169190, 222.844726, 5.67),
            vector4(256.681336, 1159.542846, 222.777344, 8.50),
            vector4(273.600006, 1164.000000, 222.726684, 8.50)
        },
        checkpoints = {
    { coords = vector3(243.995606, 1318.153808, 236.088624), direction = 'left' },
    { coords = vector3(114.487916, 1392.290162, 256.392700), direction = 'straight' },
    { coords = vector3(-37.279122, 1479.876954, 275.770020), direction = 'straight' },
    { coords = vector3(-168.276916, 1504.575806, 287.918702), direction = 'straight' },
    { coords = vector3(-449.881318, 1387.437378, 296.293090), direction = 'right' },
    { coords = vector3(-647.525268, 1348.272584, 289.687866), direction = 'straight' },
    { coords = vector3(-719.393432, 1168.351684, 262.846192), direction = 'left' },
    { coords = vector3(-704.729676, 918.210998, 231.690796), direction = 'straight' },
    { coords = vector3(-938.716492, 790.496704, 180.433716), direction = 'straight' },
    { coords = vector3(-1023.626404, 792.118652, 168.773682), direction = 'left' },
    { coords = vector3(-875.208802, 707.314270, 148.654908), direction = 'straight' },
    { coords = vector3(-681.560424, 685.872558, 152.580932), direction = 'right' },
    { coords = vector3(-538.496704, 665.235168, 141.847656), direction = 'right' },
    { coords = vector3(-549.428588, 524.980224, 106.749512), direction = 'straight' },
    { coords = vector3(-530.175842, 353.578034, 82.064454), direction = 'right' },
    { coords = vector3(-608.215394, 339.745056, 84.103272), direction = 'finish' }
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
            vector4(245.947250, -2083.147216, 16.400756, 229.61),
            vector4(242.202194, -2086.958252, 16.434448, 229.61),
            vector4(249.323074, -2079.177978, 16.316528, 226.77),
            vector4(238.641754, -2090.571534, 16.417602, 226.77),
            vector4(239.617584, -2077.239502, 16.653442, 226.77),
            vector4(235.595612, -2081.024170, 16.703980, 226.77),
            vector4(243.296708, -2073.560546, 16.552368, 226.77),
            vector4(232.232972, -2084.584716, 16.670288, 226.77)
        },
        checkpoints = {
    { coords = vector3(342.540650, -2158.127442, 12.980224), direction = 'left' },
    { coords = vector3(593.063720, -2057.419678, 28.313598), direction = 'straight' },
    { coords = vector3(921.863708, -2087.235108, 29.391968), direction = 'straight' },
    { coords = vector3(1208.980224, -2071.701172, 43.107666), direction = 'right' },
    { coords = vector3(1324.536254, -2324.162598, 51.583130), direction = 'straight' },
    { coords = vector3(1100.281372, -2564.848388, 30.824218), direction = 'straight' },
    { coords = vector3(621.151672, -2649.731934, 44.691528), direction = 'straight' },
    { coords = vector3(159.481324, -2650.786866, 17.799316), direction = 'straight' },
    { coords = vector3(-214.997802, -2455.542968, 54.228516), direction = 'straight' },
    { coords = vector3(-758.914306, -2075.393310, 32.964112), direction = 'straight' },
    { coords = vector3(-910.483520, -1870.061524, 30.958984), direction = 'straight' },
    { coords = vector3(-637.819764, -1732.048340, 36.485718), direction = 'straight' },
    { coords = vector3(-414.567016, -1554.949462, 37.294556), direction = 'straight' },
    { coords = vector3(-395.907684, -1031.221924, 36.216064), direction = 'straight' },
    { coords = vector3(-408.487916, -512.189026, 32.795654), direction = 'left' },
    { coords = vector3(-730.773620, -494.624176, 24.168458), direction = 'straight' },
    { coords = vector3(-1145.459350, -642.843934, 10.486450), direction = 'straight' },
    { coords = vector3(-1704.580200, -673.964844, 10.166260), direction = 'straight' },
    { coords = vector3(-1985.063720, -446.650544, 10.789794), direction = 'straight' },
    { coords = vector3(-2226.276856, -337.529664, 12.407348), direction = 'straight' },
    { coords = vector3(-2564.333984, -166.180222, 19.585328), direction = 'straight' },
    { coords = vector3(-2979.956054, 115.767036, 13.266724), direction = 'straight' },
    { coords = vector3(-2987.841796, 549.507690, 16.080566), direction = 'straight' },
    { coords = vector3(-3155.327392, 951.586792, 13.654174), direction = 'straight' },
    { coords = vector3(-2995.991210, 1479.415406, 26.780274), direction = 'straight' },
    { coords = vector3(-2986.865966, 2016.316528, 33.098876), direction = 'straight' },
    { coords = vector3(-2717.762696, 2293.489990, 17.647584), direction = 'straight' },
    { coords = vector3(-2608.035156, 2966.123046, 15.659302), direction = 'straight' },
    { coords = vector3(-2421.916504, 3852.197754, 22.854248), direction = 'straight' },
    { coords = vector3(-2189.775878, 4372.246094, 52.796386), direction = 'straight' },
    { coords = vector3(-1719.243896, 4786.206542, 57.581666), direction = 'straight' },
    { coords = vector3(-1228.892334, 5259.837402, 49.207276), direction = 'straight' },
    { coords = vector3(-807.494506, 5470.812988, 32.896728), direction = 'left' },
    { coords = vector3(-785.591186, 5524.536132, 33.250610), direction = 'right' },
    { coords = vector3(-775.041748, 5582.307618, 32.475464), direction = 'finish' }
}
    }
}

Config.Debug = false
