Config = {}

Config.NotifyEvent = 'client:notify'
Config.Debug = false

-- TAB = 37, F3 = 170
Config.Keys = {
    Engine = 37,
    Lock = 170
}

Config.Commands = {
    Engine = 'engine',
    Lock = 'vehiclelock'
}

Config.SearchRadius = 7.5
Config.LockDistance = 6.0

-- Cooldown lock/unlock in ms. Nu trimite notificare cand e pe cooldown.
Config.LockCooldownMs = 3000

-- Daca garajul nu seteaza SQL ID pe masina, serverul cauta masina in ownedvehicles dupa placuta.
Config.AllowPlateFallback = true

-- Cand intri ca sofer, motorul ramane oprit pana apesi TAB.
Config.ForceEngineOffUntilStarted = true
Config.DriverEngineLoopMs = 350
Config.StateRefreshMs = 1000

-- Reaplica lock-ul de cateva ori dupa spawn, ca GTA uneori il reseteaza.
Config.SpawnLockApplyRepeats = 8
Config.SpawnLockApplyIntervalMs = 250

-- Entity(vehicle).state keys unde poate exista ownedvehicles.id.
Config.SqlIdStateKeys = {
    'ownedVehicleId',
    'owned_vehicle_id',
    'dz_owned_vehicle_id',
    'dz_garage_db_id',
    'vehicleDbId',
    'dz_vs_sql_id',
    'sqlId',
    'vehicle_id'
}

-- Entity(vehicle).state keys unde poate exista placuta.
Config.PlateStateKeys = {
    'vehicle_plate',
    'plate',
    'dz_garage_plate',
    'dz_vs_plate'
}

-- Structura DB existenta.
Config.Database = {
    ownedVehiclesTable = 'ownedvehicles',
    ownedVehicleIdColumn = 'id',
    ownerUidColumn = 'owner_id',
    plateColumn = 'vehicle_plate'
}

Config.LockedSound = true
