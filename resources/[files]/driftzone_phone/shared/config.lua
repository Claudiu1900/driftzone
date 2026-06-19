Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'phone'
Config.Debug = false

Config.AuthResource = 'driftzone_auth'
Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.PhoneColumn = 'phonenumber'
Config.PhoneColumns = { 'phonenumber', 'phone_number', 'phone', 'number' }

Config.ContactsTable = 'contacts'
Config.CallHistoryTable = 'call_history'
Config.MessageHistoryTable = 'message_history'

Config.PhoneNumberMinLength = 1
Config.PhoneNumberMaxLength = 32
Config.CallTimeoutMs = 30000
Config.StateRefreshMs = 8000
Config.MessageLimit = 250
Config.HistoryLimit = 80
Config.ContactsLimit = 300


-- =========================
-- GARAGE PHONE APP
-- =========================
Config.Garage = {
    Enabled = true,
    GaragesTable = 'garages',
    OwnedVehiclesTable = 'ownedvehicles',
    VehicleNamesTable = 'vehiclenames',
    GarageColumn = 'garage',
    TowPrice = 5000,
    DefaultGarageId = 1,
    SpawnCooldownMs = 3000,
    ParkingSpotClearRadius = 3.2,
    OutsideVehiclesColumn = 'outsidevehicles'
}


Config.Admin = {
    minLevelGarage = 6,
    adutyColumn = 'aduty',
    adminColumn = 'admin_level'
}
