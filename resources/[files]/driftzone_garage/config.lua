Config = {}

Config.MainColor = '#04c7f7'

Config.OpenKey = 'M'
Config.OpenKeyControl = 244 -- M
Config.UseKeybind = true
Config.UseCommand = true
Config.Command = 'garage'
Config.ParkCommand = 'park'

Config.SpawnDistance = 5.5
Config.DeleteDistance = 8.0
Config.BlipSprite = 225
Config.BlipColor = 2
Config.BlipScale = 0.82

Config.DefaultFuel = 100.0
Config.DefaultEngineHealth = 1000.0
Config.DefaultBodyHealth = 1000.0

Config.Garages = {
    {
        id = 'pillbox_garage',
        coords = vector3(215.15, -809.95, 30.73),
        spawn = vector4(229.70, -800.12, 30.57, 158.0),
        range = 3.0,
        marker = true,
        text = 'Apasa tasta E pentru a deschide garajul',
        subText = 'DriftZone Garage'
    },
    {
        id = 'showroom_garage',
        coords = vector3(-39.139870, -1110.605835, 26.438608),
        spawn = vector4(-43.50, -1102.72, 26.42, 70.0),
        range = 3.0,
        marker = true,
        text = 'Apasa tasta E pentru a deschide garajul',
        subText = 'Showroom Garage'
    }
}
