-- Adauga acest item in Config.DefaultInteractions din driftzone_interactions/config.lua

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
