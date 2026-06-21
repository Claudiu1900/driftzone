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
    -- IMPORTANT: ramane true. Nu mai setam ownedvehicles.garage = 0 la spawn.
    -- Statusul AFARA este tinut runtime in GarageVehicles, ca sa nu strice masinile din DB.
    KeepGarageColumnOnSpawn = true,
    GaragesTable = 'garages',
    OwnedVehiclesTable = 'ownedvehicles',
    VehicleNamesTable = 'vehiclenames',
    GarageColumn = 'garage',
    TowPrice = 5000,
    DefaultGarageId = 1,
    SpawnCooldownMs = 3000,
    ParkingSpotClearRadius = 3.2,
    OutsideVehiclesColumn = 'outsidevehicles',

    -- Verifica periodic daca masinile spawnate inca exista.
    -- Daca o masina este stearsa de alt script/admin/restart, nu mai apare ca scoasa.
    GarageVehicleCleanupIntervalMs = 5000,

    -- Tuning/VS integration.
    ApplyTuningRetries = { 150, 450, 900, 1600, 2800 },
    RegisterVehicleConfig = true,

    -- Blip-uri garaje pe harta.
    GarageBlipEnabled = true,
    GarageBlipSprite = 357,
    GarageBlipColor = 38,
    GarageBlipScale = 0.78,
    GarageBlipShortRange = true,
    GarageBlipName = 'Garaj',

    -- Despawn/parcare robusta.
    GarageDeleteRetries = 12,
    GarageDeleteRetryMs = 250
}


Config.Admin = {
    minLevelGarage = 6,
    adutyColumn = 'aduty',
    adminColumn = 'admin_level'
}


-- =========================
-- PHONE VOICE
-- =========================
Config.Voice = {
    Enabled = true,
    System = 'pma-voice' -- pma-voice / saltychat custom fallback events
}
