Config = {}

Config.MainColor = '#04c7f7'
Config.Key = 38 -- E
Config.CheckInterval = 180
Config.DrawDistance = 35.0
Config.DefaultRange = 2.5

Config.Marker = {
    enabled = true,
    type = 1,
    zOffset = -1.0,
    sizeMultiplier = 1.2,
    height = 0.35,
    color = { r = 4, g = 199, b = 247, a = 110 }
}

Config.DefaultInteractions = {
    {
        id = 'driftzone_showroom_main',
        coords = vector3(-36.083958, -1102.284546, 26.422356),
        range = 2.6,
        key = 'E',
        text = 'Apasa E pentru showroom',
        subText = 'DriftZone Vehicle Showroom',
        marker = true,
        event = 'driftzone_showroom:client:openFromInteraction',
        blip = { sprite = 225, color = 3, scale = 0.85, name = 'DriftZone Showroom' }
    },

   {
    id = 'driftzone_racejob_main',
    coords = vector3(-116.835160, -604.720886, 36.272584),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Job',
    subText = 'DriftZone Race Job',
    marker = true,
    event = 'driftzone_racejob:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Race Job' }
},

{
    id = 'driftzone_races_main',
    coords = vector3(-1336.180176, -3044.254882, 14.890136),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Lobby',
    subText = 'DriftZone Races',
    marker = true,
    event = 'driftzone_races:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Races' }
},

    { id = 'tuning_lsc_city', coords = vector3(-337.23, -136.80, 39.01), range = 3.0, key = 'E', text = 'Apasa E pentru tuning', subText = 'Los Santos Customs', marker = true, event = 'driftzone_tunning:client:openFromInteraction', requireVehicle = true, blip = { sprite = 72, color = 3, scale = 0.8, name = 'DriftZone Tuning' } },
    { id = 'tuning_airport', coords = vector3(-1155.42, -2007.98, 13.18), range = 3.0, key = 'E', text = 'Apasa E pentru tuning', subText = 'Airport Tuning', marker = true, event = 'driftzone_tunning:client:openFromInteraction', requireVehicle = true, blip = { sprite = 72, color = 3, scale = 0.8, name = 'DriftZone Tuning' } },
    { id = 'tuning_route68', coords = vector3(1174.76, 2640.21, 37.75), range = 3.0, key = 'E', text = 'Apasa E pentru tuning', subText = 'Route 68 Customs', marker = true, event = 'driftzone_tunning:client:openFromInteraction', requireVehicle = true, blip = { sprite = 72, color = 3, scale = 0.8, name = 'DriftZone Tuning' } },
    { id = 'tuning_paleto', coords = vector3(110.90, 6626.46, 31.78), range = 3.0, key = 'E', text = 'Apasa E pentru tuning', subText = 'Paleto Customs', marker = true, event = 'driftzone_tunning:client:openFromInteraction', requireVehicle = true, blip = { sprite = 72, color = 3, scale = 0.8, name = 'DriftZone Tuning' } },
    { id = 'tuning_bennys', coords = vector3(-211.93, -1324.42, 30.89), range = 3.0, key = 'E', text = 'Apasa E pentru tuning', subText = "Benny's Motorworks", marker = true, event = 'driftzone_tunning:client:openFromInteraction', requireVehicle = true, blip = { sprite = 72, color = 3, scale = 0.8, name = 'DriftZone Tuning' } }
}
