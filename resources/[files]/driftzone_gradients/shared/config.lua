Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'gradient'
Config.NotifyEvent = 'client:notify'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = nil -- nu selecteaza coloana `admin` daca nu exista
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

-- Fiecare gradient are ID-ul lui clar.
-- Item-ul din inventar pentru gradient ID 25 trebuie sa fie: 25_gradient
-- colorId este ID-ul de culoare aplicat pe masina prin native FiveM.
Config.Gradients = {
    [1] = { id = 1, label = 'Anodized Red Pearl', colorId = 161, type = 'chameleon' },
    [2] = { id = 2, label = 'Anodized Wine Pearl', colorId = 162, type = 'chameleon' },
    [3] = { id = 3, label = 'Anodized Purple Pearl', colorId = 163, type = 'chameleon' },
    [4] = { id = 4, label = 'Anodized Blue Pearl', colorId = 164, type = 'chameleon' },
    [5] = { id = 5, label = 'Anodized Green Pearl', colorId = 165, type = 'chameleon' },
    [6] = { id = 6, label = 'Anodized Lime Pearl', colorId = 166, type = 'chameleon' },
    [7] = { id = 7, label = 'Anodized Copper Pearl', colorId = 167, type = 'chameleon' },
    [8] = { id = 8, label = 'Anodized Bronze Pearl', colorId = 168, type = 'chameleon' },
    [9] = { id = 9, label = 'Anodized Champagne Pearl', colorId = 169, type = 'chameleon' },
    [10] = { id = 10, label = 'Anodized Gold Pearl', colorId = 170, type = 'chameleon' },
    [11] = { id = 11, label = 'Green Blue Flip', colorId = 171, type = 'chameleon' },
    [12] = { id = 12, label = 'Green Red Flip', colorId = 172, type = 'chameleon' },
    [13] = { id = 13, label = 'Green Brown Flip', colorId = 173, type = 'chameleon' },
    [14] = { id = 14, label = 'Green Turquoise Flip', colorId = 174, type = 'chameleon' },
    [15] = { id = 15, label = 'Green Purple Flip', colorId = 175, type = 'chameleon' },
    [16] = { id = 16, label = 'Teal Purple Flip', colorId = 176, type = 'chameleon' },
    [17] = { id = 17, label = 'Turquoise Red Flip', colorId = 177, type = 'chameleon' },
    [18] = { id = 18, label = 'Turquoise Purple Flip', colorId = 178, type = 'chameleon' },
    [19] = { id = 19, label = 'Cyan Purple Flip', colorId = 179, type = 'chameleon' },
    [20] = { id = 20, label = 'Blue Pink Flip', colorId = 180, type = 'chameleon' },
    [21] = { id = 21, label = 'Blue Green Flip', colorId = 181, type = 'chameleon' },
    [22] = { id = 22, label = 'Purple Red Flip', colorId = 182, type = 'chameleon' },
    [23] = { id = 23, label = 'Purple Green Flip', colorId = 183, type = 'chameleon' },
    [24] = { id = 24, label = 'Magenta Green Flip', colorId = 184, type = 'chameleon' },
    [25] = { id = 25, label = 'Magenta Yellow Flip', colorId = 185, type = 'chameleon' },
    [26] = { id = 26, label = 'Burgundy Green Flip', colorId = 186, type = 'chameleon' },
    [27] = { id = 27, label = 'Magenta Cyan Flip', colorId = 187, type = 'chameleon' },
    [28] = { id = 28, label = 'Copper Purple Flip', colorId = 188, type = 'chameleon' },
    [29] = { id = 29, label = 'Magenta Orange Flip', colorId = 189, type = 'chameleon' },
    [30] = { id = 30, label = 'Red Orange Flip', colorId = 190, type = 'chameleon' },
    [31] = { id = 31, label = 'Orange Purple Flip', colorId = 191, type = 'chameleon' },
    [32] = { id = 32, label = 'Orange Blue Flip', colorId = 192, type = 'chameleon' },
    [33] = { id = 33, label = 'White Purple Flip', colorId = 193, type = 'chameleon' },
    [34] = { id = 34, label = 'Red Rainbow Flip', colorId = 194, type = 'chameleon' },
    [35] = { id = 35, label = 'Blue Rainbow Flip', colorId = 195, type = 'chameleon' },
    [36] = { id = 36, label = 'Dark Green Pearl', colorId = 196, type = 'chameleon' },
    [37] = { id = 37, label = 'Dark Teal Pearl', colorId = 197, type = 'chameleon' },
    [38] = { id = 38, label = 'Dark Blue Pearl', colorId = 198, type = 'chameleon' },
    [39] = { id = 39, label = 'Dark Purple Pearl', colorId = 199, type = 'chameleon' },
    [40] = { id = 40, label = 'Oil Slick Pearl', colorId = 200, type = 'chameleon' },
    [41] = { id = 41, label = 'Light Green Pearl', colorId = 201, type = 'chameleon' },
    [42] = { id = 42, label = 'Light Blue Pearl', colorId = 202, type = 'chameleon' },
    [43] = { id = 43, label = 'Light Purple Pearl', colorId = 203, type = 'chameleon' },
    [44] = { id = 44, label = 'Light Pink Pearl', colorId = 204, type = 'chameleon' },
    [45] = { id = 45, label = 'Off White Pearl', colorId = 205, type = 'chameleon' },
    [46] = { id = 46, label = 'Pink Pearl', colorId = 206, type = 'chameleon' },
    [47] = { id = 47, label = 'Yellow Pearl', colorId = 207, type = 'chameleon' },
    [48] = { id = 48, label = 'Green Pearl', colorId = 208, type = 'chameleon' },
    [49] = { id = 49, label = 'Blue Pearl', colorId = 209, type = 'chameleon' },
    [50] = { id = 50, label = 'Cream Pearl', colorId = 210, type = 'chameleon' },
    [51] = { id = 51, label = 'White Prismatic', colorId = 211, type = 'chameleon' },
    [52] = { id = 52, label = 'Graphite Prismatic', colorId = 212, type = 'chameleon' },
    [53] = { id = 53, label = 'Dark Blue Prismatic', colorId = 213, type = 'chameleon' },
    [54] = { id = 54, label = 'Dark Purple Prismatic', colorId = 214, type = 'chameleon' },
    [55] = { id = 55, label = 'Hot Pink Prismatic', colorId = 215, type = 'chameleon' },
    [56] = { id = 56, label = 'Dark Red Prismatic', colorId = 216, type = 'chameleon' },
    [57] = { id = 57, label = 'Dark Green Prismatic', colorId = 217, type = 'chameleon' },
    [58] = { id = 58, label = 'Black Prismatic', colorId = 218, type = 'chameleon' },
    [59] = { id = 59, label = 'Black Oil Spill', colorId = 219, type = 'chameleon' },
    [60] = { id = 60, label = 'Black Rainbow', colorId = 220, type = 'chameleon' },
    [61] = { id = 61, label = 'Prismatic Blue', colorId = 221, type = 'chameleon' },
    [62] = { id = 62, label = 'Prismatic Green', colorId = 222, type = 'chameleon' },
    [63] = { id = 63, label = 'Prismatic Orange', colorId = 223, type = 'chameleon' },
    [64] = { id = 64, label = 'Prismatic Pink', colorId = 224, type = 'chameleon' },
    [65] = { id = 65, label = 'Prismatic Red', colorId = 225, type = 'chameleon' },
    [66] = { id = 66, label = 'Prismatic Yellow', colorId = 226, type = 'chameleon' },
    [67] = { id = 67, label = 'Ultra Blue Flip', colorId = 227, type = 'chameleon' },
    [68] = { id = 68, label = 'Ultra Green Flip', colorId = 228, type = 'chameleon' },
    [69] = { id = 69, label = 'Ultra Red Flip', colorId = 229, type = 'chameleon' },
    [70] = { id = 70, label = 'Ultra Pink Flip', colorId = 230, type = 'chameleon' },
    [71] = { id = 71, label = 'Ultra Purple Flip', colorId = 231, type = 'chameleon' },
    [72] = { id = 72, label = 'Ultra Cyan Flip', colorId = 232, type = 'chameleon' },
    [73] = { id = 73, label = 'Deep Space', colorId = 233, type = 'chameleon' },
    [74] = { id = 74, label = 'Toxic Shift', colorId = 234, type = 'chameleon' },
    [75] = { id = 75, label = 'Ocean Shift', colorId = 235, type = 'chameleon' },
    [76] = { id = 76, label = 'Carbon Shift', colorId = 236, type = 'chameleon' },
    [77] = { id = 77, label = 'Neon Sky', colorId = 237, type = 'chameleon' },
    [78] = { id = 78, label = 'Solar Flare', colorId = 238, type = 'chameleon' },
    [79] = { id = 79, label = 'Midnight Wave', colorId = 239, type = 'chameleon' },
    [80] = { id = 80, label = 'DriftZone Cyan', colorId = 240, type = 'chameleon' },
    [81] = { id = 81, label = 'Monochrome Black', colorId = 0, type = 'monochrome' },
    [82] = { id = 82, label = 'Monochrome Carbon Black', colorId = 147, type = 'monochrome' },
    [83] = { id = 83, label = 'Monochrome Graphite', colorId = 1, type = 'monochrome' },
    [84] = { id = 84, label = 'Monochrome Black Steel', colorId = 2, type = 'monochrome' },
    [85] = { id = 85, label = 'Monochrome Dark Steel', colorId = 3, type = 'monochrome' },
    [86] = { id = 86, label = 'Monochrome Silver', colorId = 4, type = 'monochrome' },
    [87] = { id = 87, label = 'Monochrome Bluish Silver', colorId = 5, type = 'monochrome' },
    [88] = { id = 88, label = 'Monochrome Rolled Steel', colorId = 6, type = 'monochrome' },
    [89] = { id = 89, label = 'Monochrome Shadow Silver', colorId = 7, type = 'monochrome' },
    [90] = { id = 90, label = 'Monochrome Stone Silver', colorId = 8, type = 'monochrome' },
    [91] = { id = 91, label = 'Monochrome Midnight Silver', colorId = 9, type = 'monochrome' },
    [92] = { id = 92, label = 'Monochrome Cast Iron Silver', colorId = 10, type = 'monochrome' },
    [93] = { id = 93, label = 'Monochrome Ice White', colorId = 111, type = 'monochrome' },
    [94] = { id = 94, label = 'Monochrome Frost White', colorId = 112, type = 'monochrome' },
    [95] = { id = 95, label = 'Monochrome Cream', colorId = 107, type = 'monochrome' },
    [96] = { id = 96, label = 'Monochrome Pure Gold', colorId = 158, type = 'monochrome' },
    [97] = { id = 97, label = 'Monochrome Brushed Gold', colorId = 159, type = 'monochrome' },
    [98] = { id = 98, label = 'Monochrome Chrome', colorId = 120, type = 'monochrome' },
    [99] = { id = 99, label = 'Monochrome Brushed Steel', colorId = 117, type = 'monochrome' },
    [100] = { id = 100, label = 'Monochrome Brushed Black Steel', colorId = 118, type = 'monochrome' },
    [101] = { id = 101, label = 'Monochrome Brushed Aluminium', colorId = 119, type = 'monochrome' },
}
