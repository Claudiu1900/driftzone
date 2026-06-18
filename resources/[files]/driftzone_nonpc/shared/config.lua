Config = {}

Config.EnabledByDefault = true

-- Ruleaza in fiecare frame. Asa se opresc spawnurile ambient GTA corect.
Config.FrameWaitMs = 0

-- Thread rar pentru wanted/dispatch/radio style services.
Config.ServiceLoopMs = 1000
Config.GeneratorLoopMs = 15000

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
    EmergencyScenarios = true
}

-- IMPORTANT: lasat false ca sa nu mai stearga rapid NPC-uri/vehicule.
-- Daca vrei sa cureti o singura data dupa restart, pui true.
Config.ClearExistingOnStart = false
Config.ClearExistingRadius = 450.0

Config.DispatchServices = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
}

Config.DisabledScenarioTypes = {
    'WORLD_VEHICLE_POLICE_CAR',
    'WORLD_VEHICLE_POLICE_BIKE',
    'WORLD_VEHICLE_POLICE_NEXT_TO_CAR',
    'WORLD_VEHICLE_AMBULANCE',
    'WORLD_VEHICLE_FIRE_TRUCK',
    'WORLD_HUMAN_COP_IDLES',
    'WORLD_HUMAN_GUARD_STAND',
    'WORLD_HUMAN_SECURITY_SHINE_TORCH'
}
