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
    zOffset = 2.15,
    size = 0.38,
    r = 4,
    g = 199,
    b = 247,
    a = 230
}

-- Fiecare gradient are ID-ul lui clar.
-- Item-ul pentru gradient ID 25 trebuie sa fie: 25_gradient
-- IMPORTANT: nu mai foloseste colorId-uri chameleon care pe unele build-uri FiveM ies negre/gri.
-- Fiecare gradient foloseste custom RGB: startColor + endColor + pearlColor.
-- Pe masina se aplica vizibil prin primary/secondary custom color + pearl.
Config.Gradients = {
    [1] = { id = 1, label = 'Red Blue Shift', type = 'gradient', startColor = { r = 255, g = 0, b = 60 }, endColor = { r = 0, g = 110, b = 255 }, pearlColor = { r = 255, g = 74, b = 0 } },
    [2] = { id = 2, label = 'Purple Cyan Shift', type = 'gradient', startColor = { r = 138, g = 0, b = 255 }, endColor = { r = 0, g = 234, b = 255 }, pearlColor = { r = 255, g = 0, b = 168 } },
    [3] = { id = 3, label = 'Green Purple Shift', type = 'gradient', startColor = { r = 0, g = 255, b = 106 }, endColor = { r = 155, g = 0, b = 255 }, pearlColor = { r = 0, g = 200, b = 255 } },
    [4] = { id = 4, label = 'Orange Blue Shift', type = 'gradient', startColor = { r = 255, g = 123, b = 0 }, endColor = { r = 0, g = 76, b = 255 }, pearlColor = { r = 255, g = 225, b = 0 } },
    [5] = { id = 5, label = 'Pink Green Shift', type = 'gradient', startColor = { r = 255, g = 20, b = 147 }, endColor = { r = 0, g = 255, b = 123 }, pearlColor = { r = 125, g = 0, b = 255 } },
    [6] = { id = 6, label = 'Gold Cyan Shift', type = 'gradient', startColor = { r = 255, g = 191, b = 0 }, endColor = { r = 0, g = 217, b = 255 }, pearlColor = { r = 255, g = 115, b = 0 } },
    [7] = { id = 7, label = 'Toxic Lime Shift', type = 'gradient', startColor = { r = 191, g = 255, b = 0 }, endColor = { r = 0, g = 255, b = 204 }, pearlColor = { r = 17, g = 17, b = 17 } },
    [8] = { id = 8, label = 'Ocean Violet Shift', type = 'gradient', startColor = { r = 0, g = 76, b = 255 }, endColor = { r = 138, g = 43, b = 226 }, pearlColor = { r = 0, g = 234, b = 255 } },
    [9] = { id = 9, label = 'Blood Gold Shift', type = 'gradient', startColor = { r = 176, g = 0, b = 32 }, endColor = { r = 255, g = 191, b = 0 }, pearlColor = { r = 255, g = 0, b = 93 } },
    [10] = { id = 10, label = 'Emerald Red Shift', type = 'gradient', startColor = { r = 0, g = 166, b = 81 }, endColor = { r = 255, g = 0, b = 60 }, pearlColor = { r = 4, g = 199, b = 247 } },
    [11] = { id = 11, label = 'Teal Magenta Flip', type = 'gradient', startColor = { r = 0, g = 255, b = 213 }, endColor = { r = 255, g = 0, b = 212 }, pearlColor = { r = 0, g = 110, b = 255 } },
    [12] = { id = 12, label = 'Ice Fire Flip', type = 'gradient', startColor = { r = 168, g = 248, b = 255 }, endColor = { r = 255, g = 59, b = 0 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [13] = { id = 13, label = 'Deep Space Flip', type = 'gradient', startColor = { r = 7, g = 0, b = 31 }, endColor = { r = 93, g = 0, b = 255 }, pearlColor = { r = 0, g = 200, b = 255 } },
    [14] = { id = 14, label = 'Solar Flare Flip', type = 'gradient', startColor = { r = 255, g = 234, b = 0 }, endColor = { r = 255, g = 0, b = 93 }, pearlColor = { r = 255, g = 123, b = 0 } },
    [15] = { id = 15, label = 'Mint Rose Flip', type = 'gradient', startColor = { r = 0, g = 255, b = 179 }, endColor = { r = 255, g = 106, b = 213 }, pearlColor = { r = 191, g = 255, b = 0 } },
    [16] = { id = 16, label = 'Copper Cyan Flip', type = 'gradient', startColor = { r = 184, g = 115, b = 51 }, endColor = { r = 0, g = 234, b = 255 }, pearlColor = { r = 255, g = 191, b = 0 } },
    [17] = { id = 17, label = 'Blue Pink Flip', type = 'gradient', startColor = { r = 0, g = 110, b = 255 }, endColor = { r = 255, g = 20, b = 147 }, pearlColor = { r = 0, g = 217, b = 255 } },
    [18] = { id = 18, label = 'Purple Gold Flip', type = 'gradient', startColor = { r = 125, g = 0, b = 255 }, endColor = { r = 212, g = 175, b = 55 }, pearlColor = { r = 255, g = 0, b = 212 } },
    [19] = { id = 19, label = 'Green Blue Flip', type = 'gradient', startColor = { r = 0, g = 255, b = 106 }, endColor = { r = 0, g = 85, b = 255 }, pearlColor = { r = 0, g = 255, b = 255 } },
    [20] = { id = 20, label = 'Red Orange Flip', type = 'gradient', startColor = { r = 255, g = 0, b = 0 }, endColor = { r = 255, g = 140, b = 0 }, pearlColor = { r = 255, g = 191, b = 0 } },
    [21] = { id = 21, label = 'Carbon Rainbow', type = 'gradient', startColor = { r = 11, g = 15, b = 23 }, endColor = { r = 4, g = 199, b = 247 }, pearlColor = { r = 255, g = 0, b = 212 } },
    [22] = { id = 22, label = 'Black Oil Slick', type = 'gradient', startColor = { r = 5, g = 5, b = 5 }, endColor = { r = 82, g = 45, b = 128 }, pearlColor = { r = 0, g = 255, b = 138 } },
    [23] = { id = 23, label = 'White Prism', type = 'gradient', startColor = { r = 255, g = 255, b = 255 }, endColor = { r = 4, g = 199, b = 247 }, pearlColor = { r = 255, g = 102, b = 204 } },
    [24] = { id = 24, label = 'Graphite Prism', type = 'gradient', startColor = { r = 27, g = 31, b = 39 }, endColor = { r = 122, g = 167, b = 255 }, pearlColor = { r = 255, g = 76, b = 207 } },
    [25] = { id = 25, label = 'Midnight Cyan', type = 'gradient', startColor = { r = 0, g = 17, b = 31 }, endColor = { r = 0, g = 217, b = 255 }, pearlColor = { r = 0, g = 110, b = 255 } },
    [26] = { id = 26, label = 'Midnight Purple', type = 'gradient', startColor = { r = 11, g = 0, b = 26 }, endColor = { r = 166, g = 0, b = 255 }, pearlColor = { r = 255, g = 0, b = 168 } },
    [27] = { id = 27, label = 'Neon Sky', type = 'gradient', startColor = { r = 4, g = 199, b = 247 }, endColor = { r = 142, g = 241, b = 255 }, pearlColor = { r = 0, g = 110, b = 255 } },
    [28] = { id = 28, label = 'Toxic Shift', type = 'gradient', startColor = { r = 16, g = 21, b = 0 }, endColor = { r = 191, g = 255, b = 0 }, pearlColor = { r = 0, g = 255, b = 106 } },
    [29] = { id = 29, label = 'Ocean Shift', type = 'gradient', startColor = { r = 0, g = 31, b = 46 }, endColor = { r = 0, g = 170, b = 255 }, pearlColor = { r = 0, g = 255, b = 204 } },
    [30] = { id = 30, label = 'Carbon Shift', type = 'gradient', startColor = { r = 17, g = 17, b = 17 }, endColor = { r = 48, g = 59, b = 74 }, pearlColor = { r = 4, g = 199, b = 247 } },
    [31] = { id = 31, label = 'DriftZone Cyan', type = 'gradient', startColor = { r = 4, g = 199, b = 247 }, endColor = { r = 0, g = 110, b = 255 }, pearlColor = { r = 142, g = 241, b = 255 } },
    [32] = { id = 32, label = 'Inferno Purple', type = 'gradient', startColor = { r = 255, g = 59, b = 0 }, endColor = { r = 125, g = 0, b = 255 }, pearlColor = { r = 255, g = 20, b = 147 } },
    [33] = { id = 33, label = 'Acid Pink', type = 'gradient', startColor = { r = 255, g = 0, b = 168 }, endColor = { r = 191, g = 255, b = 0 }, pearlColor = { r = 0, g = 255, b = 213 } },
    [34] = { id = 34, label = 'Royal Mint', type = 'gradient', startColor = { r = 75, g = 0, b = 130 }, endColor = { r = 0, g = 255, b = 179 }, pearlColor = { r = 212, g = 175, b = 55 } },
    [35] = { id = 35, label = 'Lava Cyan', type = 'gradient', startColor = { r = 255, g = 69, b = 0 }, endColor = { r = 0, g = 255, b = 255 }, pearlColor = { r = 255, g = 191, b = 0 } },
    [36] = { id = 36, label = 'Ghost Blue', type = 'gradient', startColor = { r = 207, g = 239, b = 255 }, endColor = { r = 0, g = 110, b = 255 }, pearlColor = { r = 138, g = 43, b = 226 } },
    [37] = { id = 37, label = 'Venom Purple', type = 'gradient', startColor = { r = 17, g = 17, b = 17 }, endColor = { r = 155, g = 0, b = 255 }, pearlColor = { r = 0, g = 255, b = 106 } },
    [38] = { id = 38, label = 'Rose Gold Flip', type = 'gradient', startColor = { r = 183, g = 110, b = 121 }, endColor = { r = 212, g = 175, b = 55 }, pearlColor = { r = 255, g = 102, b = 204 } },
    [39] = { id = 39, label = 'Electric Lime', type = 'gradient', startColor = { r = 4, g = 199, b = 247 }, endColor = { r = 191, g = 255, b = 0 }, pearlColor = { r = 0, g = 255, b = 106 } },
    [40] = { id = 40, label = 'Ruby Sapphire', type = 'gradient', startColor = { r = 224, g = 17, b = 95 }, endColor = { r = 15, g = 82, b = 186 }, pearlColor = { r = 125, g = 0, b = 255 } },
    [41] = { id = 41, label = 'Jade Amber', type = 'gradient', startColor = { r = 0, g = 168, b = 107 }, endColor = { r = 255, g = 191, b = 0 }, pearlColor = { r = 0, g = 217, b = 255 } },
    [42] = { id = 42, label = 'Plasma Orange', type = 'gradient', startColor = { r = 255, g = 115, b = 0 }, endColor = { r = 255, g = 0, b = 212 }, pearlColor = { r = 138, g = 43, b = 226 } },
    [43] = { id = 43, label = 'Cyber Green', type = 'gradient', startColor = { r = 0, g = 255, b = 106 }, endColor = { r = 4, g = 199, b = 247 }, pearlColor = { r = 17, g = 17, b = 17 } },
    [44] = { id = 44, label = 'Cyber Red', type = 'gradient', startColor = { r = 255, g = 0, b = 60 }, endColor = { r = 4, g = 199, b = 247 }, pearlColor = { r = 17, g = 17, b = 17 } },
    [45] = { id = 45, label = 'Cyber Purple', type = 'gradient', startColor = { r = 125, g = 0, b = 255 }, endColor = { r = 4, g = 199, b = 247 }, pearlColor = { r = 255, g = 0, b = 212 } },
    [46] = { id = 46, label = 'Pearl Aqua', type = 'gradient', startColor = { r = 223, g = 255, b = 255 }, endColor = { r = 0, g = 188, b = 212 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [47] = { id = 47, label = 'Pearl Rose', type = 'gradient', startColor = { r = 255, g = 241, b = 248 }, endColor = { r = 255, g = 102, b = 204 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [48] = { id = 48, label = 'Pearl Gold', type = 'gradient', startColor = { r = 255, g = 244, b = 191 }, endColor = { r = 212, g = 175, b = 55 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [49] = { id = 49, label = 'Night Rainbow', type = 'gradient', startColor = { r = 6, g = 6, b = 6 }, endColor = { r = 255, g = 0, b = 212 }, pearlColor = { r = 0, g = 255, b = 204 } },
    [50] = { id = 50, label = 'Aurora', type = 'gradient', startColor = { r = 0, g = 255, b = 204 }, endColor = { r = 138, g = 43, b = 226 }, pearlColor = { r = 4, g = 199, b = 247 } },
    [51] = { id = 51, label = 'Nebula', type = 'gradient', startColor = { r = 43, g = 0, b = 87 }, endColor = { r = 255, g = 20, b = 147 }, pearlColor = { r = 0, g = 234, b = 255 } },
    [52] = { id = 52, label = 'Dragon Scale', type = 'gradient', startColor = { r = 0, g = 59, b = 31 }, endColor = { r = 255, g = 59, b = 0 }, pearlColor = { r = 191, g = 255, b = 0 } },
    [53] = { id = 53, label = 'Frozen Grape', type = 'gradient', startColor = { r = 142, g = 241, b = 255 }, endColor = { r = 125, g = 0, b = 255 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [54] = { id = 54, label = 'Candy Flip', type = 'gradient', startColor = { r = 255, g = 102, b = 204 }, endColor = { r = 0, g = 217, b = 255 }, pearlColor = { r = 255, g = 234, b = 0 } },
    [55] = { id = 55, label = 'Holographic Blue', type = 'gradient', startColor = { r = 189, g = 239, b = 255 }, endColor = { r = 0, g = 110, b = 255 }, pearlColor = { r = 255, g = 102, b = 204 } },
    [56] = { id = 56, label = 'Holographic Green', type = 'gradient', startColor = { r = 223, g = 255, b = 232 }, endColor = { r = 0, g = 255, b = 106 }, pearlColor = { r = 4, g = 199, b = 247 } },
    [57] = { id = 57, label = 'Holographic Pink', type = 'gradient', startColor = { r = 255, g = 225, b = 243 }, endColor = { r = 255, g = 20, b = 147 }, pearlColor = { r = 0, g = 234, b = 255 } },
    [58] = { id = 58, label = 'Holographic Gold', type = 'gradient', startColor = { r = 255, g = 242, b = 178 }, endColor = { r = 255, g = 191, b = 0 }, pearlColor = { r = 0, g = 217, b = 255 } },
    [59] = { id = 59, label = 'Dark Aqua', type = 'gradient', startColor = { r = 0, g = 31, b = 38 }, endColor = { r = 0, g = 255, b = 213 }, pearlColor = { r = 0, g = 110, b = 255 } },
    [60] = { id = 60, label = 'Dark Cherry', type = 'gradient', startColor = { r = 25, g = 0, b = 9 }, endColor = { r = 255, g = 0, b = 60 }, pearlColor = { r = 255, g = 123, b = 0 } },
    [61] = { id = 61, label = 'Dark Emerald', type = 'gradient', startColor = { r = 0, g = 31, b = 16 }, endColor = { r = 0, g = 255, b = 106 }, pearlColor = { r = 0, g = 217, b = 255 } },
    [62] = { id = 62, label = 'Dark Violet', type = 'gradient', startColor = { r = 16, g = 0, b = 32 }, endColor = { r = 138, g = 43, b = 226 }, pearlColor = { r = 255, g = 0, b = 168 } },
    [63] = { id = 63, label = 'Ultra Blue Flip', type = 'gradient', startColor = { r = 0, g = 26, b = 255 }, endColor = { r = 0, g = 255, b = 255 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [64] = { id = 64, label = 'Ultra Green Flip', type = 'gradient', startColor = { r = 0, g = 179, b = 74 }, endColor = { r = 191, g = 255, b = 0 }, pearlColor = { r = 4, g = 199, b = 247 } },
    [65] = { id = 65, label = 'Ultra Red Flip', type = 'gradient', startColor = { r = 201, g = 0, b = 0 }, endColor = { r = 255, g = 123, b = 0 }, pearlColor = { r = 255, g = 102, b = 204 } },
    [66] = { id = 66, label = 'Ultra Pink Flip', type = 'gradient', startColor = { r = 255, g = 20, b = 147 }, endColor = { r = 138, g = 43, b = 226 }, pearlColor = { r = 0, g = 234, b = 255 } },
    [67] = { id = 67, label = 'Ultra Purple Flip', type = 'gradient', startColor = { r = 125, g = 0, b = 255 }, endColor = { r = 255, g = 0, b = 212 }, pearlColor = { r = 4, g = 199, b = 247 } },
    [68] = { id = 68, label = 'Ultra Cyan Flip', type = 'gradient', startColor = { r = 0, g = 217, b = 255 }, endColor = { r = 0, g = 110, b = 255 }, pearlColor = { r = 191, g = 255, b = 0 } },
    [69] = { id = 69, label = 'Deep Ocean', type = 'gradient', startColor = { r = 0, g = 26, b = 51 }, endColor = { r = 0, g = 119, b = 255 }, pearlColor = { r = 0, g = 255, b = 204 } },
    [70] = { id = 70, label = 'Solar Night', type = 'gradient', startColor = { r = 6, g = 6, b = 6 }, endColor = { r = 255, g = 191, b = 0 }, pearlColor = { r = 255, g = 59, b = 0 } },
    [71] = { id = 71, label = 'Obsidian Silver', type = 'monochrome-gradient', startColor = { r = 2, g = 2, b = 2 }, endColor = { r = 119, g = 119, b = 119 }, pearlColor = { r = 17, g = 17, b = 17 } },
    [72] = { id = 72, label = 'Carbon Ice', type = 'monochrome-gradient', startColor = { r = 16, g = 16, b = 16 }, endColor = { r = 215, g = 215, b = 215 }, pearlColor = { r = 64, g = 64, b = 64 } },
    [73] = { id = 73, label = 'Graphite White', type = 'monochrome-gradient', startColor = { r = 27, g = 27, b = 27 }, endColor = { r = 255, g = 255, b = 255 }, pearlColor = { r = 136, g = 136, b = 136 } },
    [74] = { id = 74, label = 'Black Chrome Fade', type = 'monochrome-gradient', startColor = { r = 0, g = 0, b = 0 }, endColor = { r = 191, g = 194, b = 199 }, pearlColor = { r = 48, g = 48, b = 48 } },
    [75] = { id = 75, label = 'Steel Fade', type = 'monochrome-gradient', startColor = { r = 48, g = 52, b = 59 }, endColor = { r = 217, g = 221, b = 227 }, pearlColor = { r = 112, g = 119, b = 128 } },
    [76] = { id = 76, label = 'Smoke Fade', type = 'monochrome-gradient', startColor = { r = 13, g = 13, b = 13 }, endColor = { r = 139, g = 139, b = 139 }, pearlColor = { r = 34, g = 34, b = 34 } },
    [77] = { id = 77, label = 'Ash Fade', type = 'monochrome-gradient', startColor = { r = 32, g = 32, b = 32 }, endColor = { r = 176, g = 176, b = 176 }, pearlColor = { r = 85, g = 85, b = 85 } },
    [78] = { id = 78, label = 'Frost Fade', type = 'monochrome-gradient', startColor = { r = 207, g = 212, b = 218 }, endColor = { r = 255, g = 255, b = 255 }, pearlColor = { r = 136, g = 136, b = 136 } },
    [79] = { id = 79, label = 'Titanium Fade', type = 'monochrome-gradient', startColor = { r = 59, g = 64, b = 71 }, endColor = { r = 228, g = 231, b = 235 }, pearlColor = { r = 125, g = 131, b = 140 } },
    [80] = { id = 80, label = 'Dark Matter', type = 'monochrome-gradient', startColor = { r = 0, g = 0, b = 0 }, endColor = { r = 68, g = 68, b = 68 }, pearlColor = { r = 17, g = 17, b = 17 } },
    [81] = { id = 81, label = 'Silver Shadow', type = 'monochrome-gradient', startColor = { r = 17, g = 17, b = 17 }, endColor = { r = 192, g = 192, b = 192 }, pearlColor = { r = 90, g = 90, b = 90 } },
    [82] = { id = 82, label = 'Chrome Ghost', type = 'monochrome-gradient', startColor = { r = 242, g = 242, b = 242 }, endColor = { r = 138, g = 138, b = 138 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [83] = { id = 83, label = 'Black Pearl Mono', type = 'monochrome-gradient', startColor = { r = 5, g = 5, b = 5 }, endColor = { r = 160, g = 160, b = 160 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [84] = { id = 84, label = 'White Carbon Mono', type = 'monochrome-gradient', startColor = { r = 255, g = 255, b = 255 }, endColor = { r = 34, g = 34, b = 34 }, pearlColor = { r = 187, g = 187, b = 187 } },
    [85] = { id = 85, label = 'Iron Gradient', type = 'monochrome-gradient', startColor = { r = 31, g = 35, b = 40 }, endColor = { r = 144, g = 153, b = 163 }, pearlColor = { r = 85, g = 92, b = 102 } },
    [86] = { id = 86, label = 'Midnight Mono', type = 'monochrome-gradient', startColor = { r = 3, g = 3, b = 3 }, endColor = { r = 102, g = 111, b = 122 }, pearlColor = { r = 17, g = 17, b = 17 } },
    [87] = { id = 87, label = 'Platinum Mono', type = 'monochrome-gradient', startColor = { r = 229, g = 228, b = 226 }, endColor = { r = 85, g = 85, b = 85 }, pearlColor = { r = 255, g = 255, b = 255 } },
    [88] = { id = 88, label = 'Gunmetal Mono', type = 'monochrome-gradient', startColor = { r = 42, g = 52, b = 57 }, endColor = { r = 185, g = 192, b = 199 }, pearlColor = { r = 102, g = 102, b = 102 } },
    [89] = { id = 89, label = 'Clouded Chrome', type = 'monochrome-gradient', startColor = { r = 191, g = 194, b = 199 }, endColor = { r = 17, g = 17, b = 17 }, pearlColor = { r = 233, g = 233, b = 233 } },
    [90] = { id = 90, label = 'Noir Frost', type = 'monochrome-gradient', startColor = { r = 0, g = 0, b = 0 }, endColor = { r = 238, g = 238, b = 238 }, pearlColor = { r = 119, g = 119, b = 119 } },
}
