Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'playerinteract'
Config.CancelKey = 177 -- BACKSPACE / ESC-like close
Config.MaxSelectDistance = 6.0
Config.RayDistance = 18.0
Config.SelectionScreenRadius = 0.075 -- fallback langa corp, nu doar cap
Config.BodySelectionPaddingX = 0.035
Config.BodySelectionPaddingY = 0.050
Config.BodySelectionMinWidth = 0.050
Config.TargetCircleDistance = 7.5

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsersNameColumn = 'username'
Config.UsersCashColumn = 'cash'

Config.PayLogsTable = 'pay_logs'
Config.NotifyEvent = 'client:notify'
Config.SafeCashMax = 2147483647

Config.Pay = {
    enabled = true,
    min = 1,
    max = 500000000,
    cooldownMs = 1500
}

Config.Marker = {
    enabled = true,
    type = 25,
    radius = 1.05,
    height = 0.035,
    zOffset = 0.035,
    r = 4,
    g = 199,
    b = 247,
    a = 190
}

Config.Debug = false


Config.OwnedVehiclesTable = 'ownedvehicles'
Config.OwnedVehiclesIdColumn = 'id'
Config.OwnedVehiclesOwnerColumn = 'owner_id'
Config.OwnedVehiclesModelColumn = 'vehicle_model'
Config.OwnedVehiclesPlateColumn = 'vehicle_plate'

Config.VehicleNamesTable = 'vehiclenames'
Config.VehicleNamesModelColumn = 'vehicle_model'
Config.VehicleNamesNameColumn = 'vehicle_name'

Config.TradeLogsTable = 'trade_logs'

Config.Trade = {
    enabled = true,
    timeoutSeconds = 30,
    maxMoney = 500000000,
    maxVehicles = 80
}
