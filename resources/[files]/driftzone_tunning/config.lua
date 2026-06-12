Config = {}
Config.CashColumn = 'cash'
Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'

Config.AdminCommand = 'tunning'
Config.AdminMinLevel = 6
Config.AdminDutyRequired = true
Config.LogsTable = 'tunning_logs'

-- Doar tuning-uri reale/valabile. Nu baga optiuni fake si nu include chameleon.
Config.ShowOnlyValidVisualMods = true
Config.ExtraIds = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25 }
Config.ExtraPricePercent = 1



-- Gradient preview colors din driftzone_gradients. Sunt doar PREVIEW in tunning:
-- nu se adauga in cos, nu se cumpara si nu se salveaza in vehicle_tunning.
Config.GradientPreviewColors = {
    { id = 1, label = 'Monochrome', colorId = 223 },
    { id = 2, label = 'Night & Day', colorId = 224 },
    { id = 3, label = 'The Verlierer', colorId = 225 },
    { id = 4, label = 'Sprunk Extreme', colorId = 226 },
    { id = 5, label = 'Vice City', colorId = 227 },
    { id = 6, label = 'Synthwave Nights', colorId = 228 },
    { id = 7, label = 'Four Seasons', colorId = 229 },
    { id = 8, label = 'Maisonette 9 Throwback', colorId = 230 },
    { id = 9, label = 'Bubblegum', colorId = 231 },
    { id = 10, label = 'Full Rainbow', colorId = 232 },
    { id = 11, label = 'Sunset', colorId = 233 },
    { id = 12, label = 'The Seven', colorId = 234 },
    { id = 13, label = 'Kamen Rider', colorId = 235 },
    { id = 14, label = 'Chromatic Aberration', colorId = 236 },
    { id = 15, label = 'Its Christmas!', colorId = 237 },
    { id = 16, label = 'Blue Monochrome', colorId = 238 },
    { id = 17, label = 'Custom Gradient 17', colorId = 239 }
}

Config.PricePercent = {
    primaryColor = 2, secondaryColor = 2, primaryGradientColor = 0, secondaryGradientColor = 0, pearlescentColor = 1, wheelColor = 1,
    windowTint = 1, xenonColor = 2, plateIndex = 1, dashboardColor = 1, interiorColor = 1,
    spoiler = 3, frontBumper = 3, rearBumper = 3, sideSkirt = 2, exhaust = 2, frame = 2,
    grille = 2, hood = 3, fender = 2, rightFender = 2, roof = 3,
    engine = 30, brakes = 18, transmission = 22, suspension = 14, turbo = 18,
    horn = 1, plateHolder = 1, vanityPlates = 1, trim = 2, ornaments = 2, dashboard = 2,
    dial = 1, doorSpeaker = 2, seats = 3, steeringWheel = 2, shifterLeavers = 1,
    plaques = 1, speakers = 2, trunk = 2, hydraulics = 3, engineBlock = 3, airFilter = 2,
    struts = 2, archCover = 2, aerials = 1, trimB = 2, tank = 2, windows = 2, livery = 4,
    wheels_sport = 5, wheels_muscle = 5, wheels_lowrider = 5, wheels_suv = 5, wheels_offroad = 5,
    wheels_tuner = 5, wheels_bike = 5, wheels_highend = 5, wheels_bennys = 6, wheels_bespoke = 6,
    wheels_openwheel = 6, wheels_street = 6, wheels_track = 6
}

Config.Categories = {
    { key = 'primaryColor', label = 'Primary Color', type = 'color', group = 'Colors' },
    { key = 'secondaryColor', label = 'Secondary Color', type = 'color', group = 'Colors' },
    { key = 'primaryGradientColor', label = 'Primary Gradient Color', type = 'gradientPreview', applyTo = 'primary', previewOnly = true, group = 'Gradient Preview' },
    { key = 'secondaryGradientColor', label = 'Secondary Gradient Color', type = 'gradientPreview', applyTo = 'secondary', previewOnly = true, group = 'Gradient Preview' },
    { key = 'pearlescentColor', label = 'Pearlescent', type = 'classicColor', group = 'Colors' },
    { key = 'wheelColor', label = 'Wheel Color', type = 'classicColor', group = 'Colors' },
    { key = 'dashboardColor', label = 'Dashboard Color', type = 'vehicleColor', target = 'dashboard', group = 'Colors' },
    { key = 'interiorColor', label = 'Interior Color', type = 'vehicleColor', target = 'interior', group = 'Colors' },
    { key = 'windowTint', label = 'Window Tint', type = 'windowTint', group = 'Visual' },
    { key = 'xenonColor', label = 'Xenon Color', type = 'xenonColor', group = 'Lights' },
    { key = 'plateIndex', label = 'Plate Style', type = 'plateIndex', group = 'Visual' },

    { key = 'spoiler', label = 'Spoiler', type = 'mod', modType = 0, group = 'Body' },
    { key = 'frontBumper', label = 'Front Bumper', type = 'mod', modType = 1, group = 'Body' },
    { key = 'rearBumper', label = 'Rear Bumper', type = 'mod', modType = 2, group = 'Body' },
    { key = 'sideSkirt', label = 'Side Skirt', type = 'mod', modType = 3, group = 'Body' },
    { key = 'exhaust', label = 'Exhaust', type = 'mod', modType = 4, group = 'Body' },
    { key = 'frame', label = 'Frame / Cage', type = 'mod', modType = 5, group = 'Body' },
    { key = 'grille', label = 'Grille', type = 'mod', modType = 6, group = 'Body' },
    { key = 'hood', label = 'Hood', type = 'mod', modType = 7, group = 'Body' },
    { key = 'fender', label = 'Left Fender', type = 'mod', modType = 8, group = 'Body' },
    { key = 'rightFender', label = 'Right Fender', type = 'mod', modType = 9, group = 'Body' },
    { key = 'roof', label = 'Roof', type = 'mod', modType = 10, group = 'Body' },

    { key = 'engine', label = 'Engine', type = 'mod', modType = 11, forceCount = 4, performance = true, group = 'Performance' },
    { key = 'brakes', label = 'Brakes', type = 'mod', modType = 12, forceCount = 3, performance = true, group = 'Performance' },
    { key = 'transmission', label = 'Transmission', type = 'mod', modType = 13, forceCount = 3, performance = true, group = 'Performance' },
    { key = 'suspension', label = 'Suspension', type = 'mod', modType = 15, forceCount = 4, performance = true, group = 'Performance' },
    { key = 'turbo', label = 'Turbo', type = 'toggle', modType = 18, group = 'Performance' },

    { key = 'horn', label = 'Horn', type = 'mod', modType = 14, group = 'Interior' },
    { key = 'plateHolder', label = 'Plate Holder', type = 'mod', modType = 25, group = 'Visual' },
    { key = 'vanityPlates', label = 'Vanity Plates', type = 'mod', modType = 26, group = 'Visual' },
    { key = 'trim', label = 'Trim A', type = 'mod', modType = 27, group = 'Interior' },
    { key = 'ornaments', label = 'Ornaments', type = 'mod', modType = 28, group = 'Interior' },
    { key = 'dashboard', label = 'Dashboard', type = 'mod', modType = 29, group = 'Interior' },
    { key = 'dial', label = 'Dial', type = 'mod', modType = 30, group = 'Interior' },
    { key = 'doorSpeaker', label = 'Door Speakers', type = 'mod', modType = 31, group = 'Interior' },
    { key = 'seats', label = 'Seats', type = 'mod', modType = 32, group = 'Interior' },
    { key = 'steeringWheel', label = 'Steering Wheel', type = 'mod', modType = 33, group = 'Interior' },
    { key = 'shifterLeavers', label = 'Shifter', type = 'mod', modType = 34, group = 'Interior' },
    { key = 'plaques', label = 'Plaques', type = 'mod', modType = 35, group = 'Interior' },
    { key = 'speakers', label = 'Speakers', type = 'mod', modType = 36, group = 'Interior' },
    { key = 'trunk', label = 'Trunk', type = 'mod', modType = 37, group = 'Body' },
    { key = 'hydraulics', label = 'Hydraulics', type = 'mod', modType = 38, group = 'Visual' },
    { key = 'engineBlock', label = 'Engine Block', type = 'mod', modType = 39, group = 'Engine Bay' },
    { key = 'airFilter', label = 'Air Filter', type = 'mod', modType = 40, group = 'Engine Bay' },
    { key = 'struts', label = 'Struts', type = 'mod', modType = 41, group = 'Engine Bay' },
    { key = 'archCover', label = 'Arch Cover', type = 'mod', modType = 42, group = 'Body' },
    { key = 'aerials', label = 'Aerials', type = 'mod', modType = 43, group = 'Visual' },
    { key = 'trimB', label = 'Trim B', type = 'mod', modType = 44, group = 'Interior' },
    { key = 'tank', label = 'Tank', type = 'mod', modType = 45, group = 'Body' },
    { key = 'windows', label = 'Windows', type = 'mod', modType = 46, group = 'Visual' },
    { key = 'livery', label = 'Livery', type = 'mod', modType = 48, nativeLivery = true, group = 'Visual' },

    -- Roțile sunt separate pe wheel type. Asta repară bugul când schimbi wheels și nu se întâmplă nimic.
    { key = 'wheels_sport', label = 'Wheels Sport', type = 'wheel', modType = 23, wheelType = 0, group = 'Wheels' },
    { key = 'wheels_muscle', label = 'Wheels Muscle', type = 'wheel', modType = 23, wheelType = 1, group = 'Wheels' },
    { key = 'wheels_lowrider', label = 'Wheels Lowrider', type = 'wheel', modType = 23, wheelType = 2, group = 'Wheels' },
    { key = 'wheels_suv', label = 'Wheels SUV', type = 'wheel', modType = 23, wheelType = 3, group = 'Wheels' },
    { key = 'wheels_offroad', label = 'Wheels Offroad', type = 'wheel', modType = 23, wheelType = 4, group = 'Wheels' },
    { key = 'wheels_tuner', label = 'Wheels Tuner', type = 'wheel', modType = 23, wheelType = 5, group = 'Wheels' },
    { key = 'wheels_bike', label = 'Bike Wheels', type = 'wheel', modType = 23, wheelType = 6, group = 'Wheels' },
    { key = 'wheels_highend', label = 'Wheels High End', type = 'wheel', modType = 23, wheelType = 7, group = 'Wheels' },
    { key = 'wheels_bennys', label = 'Benny\'s Original', type = 'wheel', modType = 23, wheelType = 8, group = 'Wheels' },
    { key = 'wheels_bespoke', label = 'Benny\'s Bespoke', type = 'wheel', modType = 23, wheelType = 9, group = 'Wheels' },
    { key = 'wheels_openwheel', label = 'Open Wheel', type = 'wheel', modType = 23, wheelType = 10, group = 'Wheels' },
    { key = 'wheels_street', label = 'Street Wheels', type = 'wheel', modType = 23, wheelType = 11, group = 'Wheels' },
    { key = 'wheels_track', label = 'Track Wheels', type = 'wheel', modType = 23, wheelType = 12, group = 'Wheels' }
}
