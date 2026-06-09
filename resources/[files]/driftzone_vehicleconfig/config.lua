Config = {}

Config.LockCommand = 'vehiclelock'
Config.EngineCommand = 'engine'

Config.LockDistance = 5.0
Config.SearchRadius = 7.5

Config.EngineOffOnDriverEnter = false -- lasa false; foloseste trigger-ul de la garaj cand scoti masina

Config.NotifyEvent = 'client:notify'

Config.LockedSound = true
Config.Debug = false

-- Chei Entity(vehicle).state folosite de garajele tale pentru SQL ID.
Config.SqlIdStateKeys = {
    'dz_garage_db_id',
    'vehicleDbId',
    'ownedVehicleId',
    'dz_vs_sql_id',
    'sqlId',
    'vehicle_id'
}

Config.PlateStateKeys = {
    'dz_garage_plate',
    'dz_vs_plate',
    'vehicle_plate',
    'plate'
}

Config.EngineOffTriggers = {
    -- Poti folosi aceste eventuri dupa spawn din garaj:
    client = 'driftzone_vehicleconfig:client:setEngineOff',
    server = 'driftzone_vehicleconfig:server:setEngineOff'
}
