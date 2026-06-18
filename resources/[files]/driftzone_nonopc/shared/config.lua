Config = {}

Config.EnabledByDefault = true

-- Densitatile trebuie puse in fiecare frame.
Config.FrameWaitMs = 0

-- Wanted/dispatch/police checks.
Config.ServiceLoopMs = 1000

-- Vehicle generators si scenario types.
Config.GeneratorLoopMs = 10000

Config.Disable = {
    Peds = true,
    ScenarioPeds = true,
    Vehicles = true,
    RandomVehicles = true,
    ParkedVehicles = true,
    GarbageTrucks = true,
    RandomBoats = true,
    RandomCops = true,
    Dispatch = true,
    WantedLevel = true,
    VehicleGenerators = true,
    EmergencyScenarios = true,
    DistantCars = true
}

-- Curata o data cand porneste resource-ul.
Config.ClearExistingOnStart = true
Config.ClearExistingRadius = 550.0

-- Loop safe de delete pentru ce mai scapa.
Config.Cleanup = {
    Enabled = true,

    -- Cat de des sa scaneze entitatile.
    IntervalMs = 1200,

    -- Raza in jurul playerului.
    Radius = 420.0,

    -- Limite per tick ca sa nu faca lag.
    MaxPedsPerTick = 45,
    MaxVehiclesPerTick = 35,

    -- Sterge peds non-player.
    DeletePeds = true,

    -- Sterge vehicule ambient fara playeri.
    DeleteVehicles = true,

    -- Nu sterge vehicule cu player inauntru.
    SkipVehiclesWithPlayers = true,

    -- Nu sterge vehicule de tip mission entity / probabil spawnate de scripturi.
    SkipMissionVehicles = true,

    -- Nu sterge vehicule care au state bag cu SQL/owned/net custom.
    SkipStateBagVehicles = true,

    -- Nu sterge vehicule conduse de NPC daca sunt foarte aproape de player,
    -- ca sa nu dispara fix in fata ta. Seteaza 0 daca vrei agresiv.
    VehicleNearPlayerProtection = 12.0
}

-- Keys de state folosite des de garaje/vehicle system. Daca un vehicul are una din astea, nu il stergem.
Config.SafeVehicleStateKeys = {
    'dz_garage_db_id',
    'vehicleDbId',
    'ownedVehicleId',
    'dz_vs_sql_id',
    'sqlId',
    'vehicle_id',
    'dz_owner',
    'owner',
    'owner_id',
    'vehicle_plate',
    'dz_garage_plate',
    'dz_vs_plate',
    'isOwned',
    'spawnedByScript',
    'driftzone_vehicle'
}

Config.DispatchServices = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
}

Config.DisabledScenarioTypes = {
    'WORLD_VEHICLE_POLICE_CAR',
    'WORLD_VEHICLE_POLICE_BIKE',
    'WORLD_VEHICLE_POLICE_NEXT_TO_CAR',
    'WORLD_VEHICLE_AMBULANCE',
    'WORLD_VEHICLE_FIRE_TRUCK',
    'WORLD_VEHICLE_DRIVE_SOLO',
    'WORLD_VEHICLE_DRIVE_PASSENGERS',
    'WORLD_VEHICLE_PARK_PARALLEL',
    'WORLD_VEHICLE_PARK_PERPENDICULAR_NOSE_IN',
    'WORLD_VEHICLE_BICYCLE_BMX',
    'WORLD_VEHICLE_BIKE_OFF_ROAD_RACE',
    'WORLD_VEHICLE_MILITARY_PLANES_SMALL',
    'WORLD_VEHICLE_MILITARY_PLANES_BIG',
    'WORLD_VEHICLE_EMPTY',
    'WORLD_HUMAN_COP_IDLES',
    'WORLD_HUMAN_GUARD_STAND',
    'WORLD_HUMAN_SECURITY_SHINE_TORCH'
}

Config.Debug = false
