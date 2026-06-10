Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'gradient'
Config.NotifyEvent = 'client:notify'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = 'admin'
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
    zOffset = 2.15,
    size = 0.38,
    r = 4,
    g = 199,
    b = 247,
    a = 230
}

-- Chameleon / Gradient color ids. GTA/FiveM color ids differ by build/modkit;
-- scriptul foloseste id-ul de culoare direct si salveaza id-ul gradientului in DB.
Config.Gradients = {}

local names = {
    'Anodized Red Pearl', 'Anodized Wine Pearl', 'Anodized Purple Pearl', 'Anodized Blue Pearl',
    'Anodized Green Pearl', 'Anodized Lime Pearl', 'Anodized Copper Pearl', 'Anodized Bronze Pearl',
    'Anodized Champagne Pearl', 'Anodized Gold Pearl', 'Green Blue Flip', 'Green Red Flip',
    'Green Brown Flip', 'Green Turquoise Flip', 'Green Purple Flip', 'Teal Purple Flip',
    'Turquoise Red Flip', 'Turquoise Purple Flip', 'Cyan Purple Flip', 'Blue Pink Flip',
    'Blue Green Flip', 'Purple Red Flip', 'Purple Green Flip', 'Magenta Green Flip',
    'Magenta Yellow Flip', 'Burgundy Green Flip', 'Magenta Cyan Flip', 'Copper Purple Flip',
    'Magenta Orange Flip', 'Red Orange Flip', 'Orange Purple Flip', 'Orange Blue Flip',
    'White Purple Flip', 'Red Rainbow Flip', 'Blue Rainbow Flip', 'Dark Green Pearl',
    'Dark Teal Pearl', 'Dark Blue Pearl', 'Dark Purple Pearl', 'Oil Slick Pearl',
    'Light Green Pearl', 'Light Blue Pearl', 'Light Purple Pearl', 'Light Pink Pearl',
    'Off White Pearl', 'Pink Pearl', 'Yellow Pearl', 'Green Pearl',
    'Blue Pearl', 'Cream Pearl', 'White Prismatic', 'Graphite Prismatic',
    'Dark Blue Prismatic', 'Dark Purple Prismatic', 'Hot Pink Prismatic', 'Dark Red Prismatic',
    'Dark Green Prismatic', 'Black Prismatic', 'Black Oil Spill', 'Black Rainbow',
    'Prismatic Blue', 'Prismatic Green', 'Prismatic Orange', 'Prismatic Pink',
    'Prismatic Red', 'Prismatic Yellow', 'Ultra Blue Flip', 'Ultra Green Flip',
    'Ultra Red Flip', 'Ultra Pink Flip', 'Ultra Purple Flip', 'Ultra Cyan Flip',
    'Deep Space', 'Toxic Shift', 'Ocean Shift', 'Carbon Shift',
    'Neon Sky', 'Solar Flare', 'Midnight Wave', 'DriftZone Cyan'
}

for i = 1, #names do
    Config.Gradients[i] = {
        id = i,
        label = names[i],
        colorId = 160 + i
    }
end
