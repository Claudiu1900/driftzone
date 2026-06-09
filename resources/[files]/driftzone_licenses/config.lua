Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'licenses'
Config.NotifyEvent = 'client:notify'

Config.Location = {
    coords = vector3(3827.0, 3821.0, 30.0),
    range = 2.6,
    marker = true
}

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsersCashColumn = 'cash'
Config.UsersCoinsColumn = 'dzcoins'

Config.OwnedVehiclesTable = 'ownedvehicles'
Config.OwnedVehiclesIdColumn = 'id'
Config.OwnedVehiclesOwnerColumn = 'owner_id'
Config.OwnedVehiclesModelColumn = 'vehicle_model'
Config.OwnedVehiclesPlateColumn = 'vehicle_plate'

Config.VehicleNamesTable = 'vehiclenames'
Config.VehicleNamesModelColumn = 'vehicle_model'
Config.VehicleNamesNameColumn = 'vehicle_name'

Config.LogsTable = 'licenses_logs'

Config.Normal = {
    price = 100000,
    moneyColumn = 'cash',
    prefix = 'DZ',
    minExtra = 3,
    maxLength = 8
}

Config.Premium = {
    price = 2000,
    moneyColumn = 'dzcoins',
    minLength = 1,
    maxLength = 8
}

Config.CacheMs = 1500
Config.MaxVehicles = 120
Config.Debug = false
