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
Config.ChameleonIdOffset = 0 -- daca pe build-ul tau 161 iese negru, incearca 62 dupa restart complet

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
-- Chameleon real: foloseste colorId-uri GTA/FiveM, nu RGB.
-- Item-ul pentru gradient ID 25 trebuie sa fie: 25_gradient
-- Daca vezi negru/gri, serverul trebuie sa ruleze game build 2699+ si sa dai full restart.
Config.Gradients = {
    [1] = { id = 1, label = 'Anodized Red Pearl', type = 'chameleon', colorId = 161 },
    [2] = { id = 2, label = 'Anodized Wine Pearl', type = 'chameleon', colorId = 162 },
    [3] = { id = 3, label = 'Anodized Purple Pearl', type = 'chameleon', colorId = 163 },
    [4] = { id = 4, label = 'Anodized Blue Pearl', type = 'chameleon', colorId = 164 },
    [5] = { id = 5, label = 'Anodized Green Pearl', type = 'chameleon', colorId = 165 },
    [6] = { id = 6, label = 'Anodized Lime Pearl', type = 'chameleon', colorId = 166 },
    [7] = { id = 7, label = 'Anodized Copper Pearl', type = 'chameleon', colorId = 167 },
    [8] = { id = 8, label = 'Anodized Bronze Pearl', type = 'chameleon', colorId = 168 },
    [9] = { id = 9, label = 'Anodized Champagne Pearl', type = 'chameleon', colorId = 169 },
    [10] = { id = 10, label = 'Anodized Gold Pearl', type = 'chameleon', colorId = 170 },
    [11] = { id = 11, label = 'Green Blue Flip', type = 'chameleon', colorId = 171 },
    [12] = { id = 12, label = 'Green Red Flip', type = 'chameleon', colorId = 172 },
    [13] = { id = 13, label = 'Green Brown Flip', type = 'chameleon', colorId = 173 },
    [14] = { id = 14, label = 'Green Turquoise Flip', type = 'chameleon', colorId = 174 },
    [15] = { id = 15, label = 'Green Purple Flip', type = 'chameleon', colorId = 175 },
    [16] = { id = 16, label = 'Teal Purple Flip', type = 'chameleon', colorId = 176 },
    [17] = { id = 17, label = 'Turquoise Red Flip', type = 'chameleon', colorId = 177 },
    [18] = { id = 18, label = 'Turquoise Purple Flip', type = 'chameleon', colorId = 178 },
    [19] = { id = 19, label = 'Cyan Purple Flip', type = 'chameleon', colorId = 179 },
    [20] = { id = 20, label = 'Blue Pink Flip', type = 'chameleon', colorId = 180 },
    [21] = { id = 21, label = 'Blue Green Flip', type = 'chameleon', colorId = 181 },
    [22] = { id = 22, label = 'Purple Red Flip', type = 'chameleon', colorId = 182 },
    [23] = { id = 23, label = 'Purple Green Flip', type = 'chameleon', colorId = 183 },
    [24] = { id = 24, label = 'Magenta Green Flip', type = 'chameleon', colorId = 184 },
    [25] = { id = 25, label = 'Magenta Yellow Flip', type = 'chameleon', colorId = 185 },
    [26] = { id = 26, label = 'Burgundy Green Flip', type = 'chameleon', colorId = 186 },
    [27] = { id = 27, label = 'Magenta Cyan Flip', type = 'chameleon', colorId = 187 },
    [28] = { id = 28, label = 'Copper Purple Flip', type = 'chameleon', colorId = 188 },
    [29] = { id = 29, label = 'Magenta Orange Flip', type = 'chameleon', colorId = 189 },
    [30] = { id = 30, label = 'Red Orange Flip', type = 'chameleon', colorId = 190 },
    [31] = { id = 31, label = 'Orange Purple Flip', type = 'chameleon', colorId = 191 },
    [32] = { id = 32, label = 'Orange Blue Flip', type = 'chameleon', colorId = 192 },
    [33] = { id = 33, label = 'White Purple Flip', type = 'chameleon', colorId = 193 },
    [34] = { id = 34, label = 'Red Rainbow Flip', type = 'chameleon', colorId = 194 },
    [35] = { id = 35, label = 'Blue Rainbow Flip', type = 'chameleon', colorId = 195 },
    [36] = { id = 36, label = 'Dark Green Pearl', type = 'chameleon', colorId = 196 },
    [37] = { id = 37, label = 'Dark Teal Pearl', type = 'chameleon', colorId = 197 },
    [38] = { id = 38, label = 'Dark Blue Pearl', type = 'chameleon', colorId = 198 },
    [39] = { id = 39, label = 'Dark Purple Pearl', type = 'chameleon', colorId = 199 },
    [40] = { id = 40, label = 'Oil Slick Pearl', type = 'chameleon', colorId = 200 },
    [41] = { id = 41, label = 'Light Green Pearl', type = 'chameleon', colorId = 201 },
    [42] = { id = 42, label = 'Light Blue Pearl', type = 'chameleon', colorId = 202 },
    [43] = { id = 43, label = 'Light Purple Pearl', type = 'chameleon', colorId = 203 },
    [44] = { id = 44, label = 'Light Pink Pearl', type = 'chameleon', colorId = 204 },
    [45] = { id = 45, label = 'Off White Prism', type = 'chameleon', colorId = 205 },
    [46] = { id = 46, label = 'Pink Pearl', type = 'chameleon', colorId = 206 },
    [47] = { id = 47, label = 'Yellow Pearl', type = 'chameleon', colorId = 207 },
    [48] = { id = 48, label = 'Green Pearl', type = 'chameleon', colorId = 208 },
    [49] = { id = 49, label = 'Blue Pearl', type = 'chameleon', colorId = 209 },
    [50] = { id = 50, label = 'Cream Pearl', type = 'chameleon', colorId = 210 },
    [51] = { id = 51, label = 'White Prism', type = 'chameleon', colorId = 211 },
    [52] = { id = 52, label = 'Graphite Prism', type = 'chameleon', colorId = 212 },
    [53] = { id = 53, label = 'Dark Blue Prism', type = 'chameleon', colorId = 213 },
    [54] = { id = 54, label = 'Dark Purple Prism', type = 'chameleon', colorId = 214 },
    [55] = { id = 55, label = 'Hot Pink Prism', type = 'chameleon', colorId = 215 },
    [56] = { id = 56, label = 'Red Prism', type = 'chameleon', colorId = 216 },
    [57] = { id = 57, label = 'Green Prism', type = 'chameleon', colorId = 217 },
    [58] = { id = 58, label = 'Black Prism', type = 'chameleon', colorId = 218 },
    [59] = { id = 59, label = 'Oil Slick Prism', type = 'chameleon', colorId = 219 },
    [60] = { id = 60, label = 'Rainbow Prism', type = 'chameleon', colorId = 220 },
    [61] = { id = 61, label = 'Black Holographic', type = 'chameleon', colorId = 221 },
    [62] = { id = 62, label = 'White Holographic', type = 'chameleon', colorId = 222 },
}
