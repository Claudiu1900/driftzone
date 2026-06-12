Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'gradient'
Config.NotifyEvent = 'client:notify'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = nil
Config.AdutyColumn = 'aduty'

Config.OwnedVehiclesTable = 'ownedvehicles'
Config.OwnedVehiclesIdColumn = 'id'
Config.OwnedVehiclesOwnerColumn = 'owner_id'
Config.OwnedVehiclesPlateColumn = 'vehicle_plate'
Config.OwnedVehiclesGradientColumn = 'gradient'

Config.InventoryResource = 'driftzone_inventory'
Config.InventoryItemSuffix = '_gradient'
Config.RequireOwnerForTrigger = true
Config.AdminLevel = 6
Config.SelectionDistance = 10.0
Config.VehicleScreenRadius = 0.085
Config.VehicleScreenPaddingX = 0.055
Config.VehicleScreenPaddingY = 0.075

Config.Marker = {
    enabled = true,
    type = 2,
    zOffset = 0.65,
    size = 0.38,
    r = 4,
    g = 199,
    b = 247,
    a = 230
}

-- Gradiente chameleon reale.
-- Aceste ID-uri folosesc fisierele data/stream din chameleonpaint-main.
-- Item pentru gradient ID 5 = 5_gradient.
-- colorId este ID-ul real folosit de SetVehicleColours.
-- originalRamp este ramp-ul din carcols_gen9.meta, doar informativ.
Config.Gradients = {
    [1] = { id = 1, label = 'Monochrome', type = 'chameleon', colorId = 223, originalRamp = 161 },
    [2] = { id = 2, label = 'Night & Day', type = 'chameleon', colorId = 224, originalRamp = 162 },
    [3] = { id = 3, label = 'The Verlierer', type = 'chameleon', colorId = 225, originalRamp = 163 },
    [4] = { id = 4, label = 'Sprunk Extreme', type = 'chameleon', colorId = 226, originalRamp = 164 },
    [5] = { id = 5, label = 'Vice City', type = 'chameleon', colorId = 227, originalRamp = 165 },
    [6] = { id = 6, label = 'Synthwave Nights', type = 'chameleon', colorId = 228, originalRamp = 166 },
    [7] = { id = 7, label = 'Four Seasons', type = 'chameleon', colorId = 229, originalRamp = 167 },
    [8] = { id = 8, label = 'Maisonette 9 Throwback', type = 'chameleon', colorId = 230, originalRamp = 168 },
    [9] = { id = 9, label = 'Bubblegum', type = 'chameleon', colorId = 231, originalRamp = 169 },
    [10] = { id = 10, label = 'Full Rainbow', type = 'chameleon', colorId = 232, originalRamp = 170 },
    [11] = { id = 11, label = 'Sunset', type = 'chameleon', colorId = 233, originalRamp = 171 },
    [12] = { id = 12, label = 'The Seven', type = 'chameleon', colorId = 234, originalRamp = 172 },
    [13] = { id = 13, label = 'Kamen Rider', type = 'chameleon', colorId = 235, originalRamp = 173 },
    [14] = { id = 14, label = 'Chromatic Aberration', type = 'chameleon', colorId = 236, originalRamp = 174 },
    [15] = { id = 15, label = 'Its Christmas!', type = 'chameleon', colorId = 237, originalRamp = 175 },
    [16] = { id = 16, label = 'Blue Monochrome', type = 'chameleon', colorId = 238, originalRamp = 176, rampTexture = 'vehicle_paint_ramps_16' },
    [17] = { id = 17, label = 'Purple Monochrome', type = 'chameleon', colorId = 239, originalRamp = 177, rampTexture = 'vehicle_paint_ramps_17' },
}

-- Item/comanda pentru scoaterea gradientului.
Config.TakeGradientCommand = 'takegradient'
Config.TakeGradientItem = 'takegradient'

-- Culoare fallback cand scoti gradientul si nu exista culoarea veche salvata.
Config.RemoveDefaultPrimaryColor = 0
Config.RemoveDefaultSecondaryColor = 0
