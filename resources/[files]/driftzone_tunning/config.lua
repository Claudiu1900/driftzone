Config = {}
Config.CashColumn = 'cash'
Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'

Config.AdminCommand = 'tunning'
Config.AdminMinLevel = 6
Config.AdminDutyRequired = true
Config.LogsTable = 'tunning_logs'

-- Pentru masini add-on care au modkituri prost citite de FiveM, meniul arata si categoriile vizibile fortat.
-- Daca masina are moduri reale, foloseste count-ul real. Daca native-ul returneaza 0, foloseste fallback-ul de mai jos.
Config.ShowAddonVisualModsEvenIfCountZero = true
Config.DefaultAddonVisualCount = 25
Config.DefaultWheelCount = 80
Config.DefaultHornCount = 60
Config.DefaultLiveryCount = 30


Config.PricePercent = {
    primaryColor = 2, secondaryColor = 2, pearlescentColor = 1, wheelColor = 1, windowTint = 1, xenonColor = 2,
    spoiler = 3, frontBumper = 3, rearBumper = 3, sideSkirt = 2, exhaust = 2, frame = 2, grille = 2, hood = 3, fender = 2, rightFender = 2, roof = 3,
    engine = 30, brakes = 18, transmission = 22, suspension = 14, armor = 20, turbo = 18,
    wheels = 5, horn = 1, plateHolder = 1, vanityPlates = 1, trim = 2, ornaments = 2, dashboard = 2, dial = 1, doorSpeaker = 2, seats = 3, steeringWheel = 2, shifterLeavers = 1, plaques = 1, speakers = 2, trunk = 2, hydraulics = 3, engineBlock = 3, airFilter = 2, struts = 2, archCover = 2, aerials = 1, tank = 2, windows = 2, livery = 4
}

Config.Categories = {
    { key = 'primaryColor', label = 'Primary Color', type = 'color' },
    { key = 'secondaryColor', label = 'Secondary Color', type = 'color' },
    { key = 'pearlescentColor', label = 'Pearlescent', type = 'classicColor' },
    { key = 'wheelColor', label = 'Wheel Color', type = 'classicColor' },
    { key = 'windowTint', label = 'Window Tint', type = 'windowTint' },
    { key = 'xenonColor', label = 'Xenon Color', type = 'xenonColor' },
    { key = 'spoiler', label = 'Spoiler', type = 'mod', modType = 0, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'frontBumper', label = 'Front Bumper', type = 'mod', modType = 1, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'rearBumper', label = 'Rear Bumper', type = 'mod', modType = 2, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'sideSkirt', label = 'Side Skirt', type = 'mod', modType = 3, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'exhaust', label = 'Exhaust', type = 'mod', modType = 4, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'frame', label = 'Frame', type = 'mod', modType = 5, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'grille', label = 'Grille', type = 'mod', modType = 6, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'hood', label = 'Hood', type = 'mod', modType = 7, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'fender', label = 'Left Fender', type = 'mod', modType = 8, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'rightFender', label = 'Right Fender', type = 'mod', modType = 9, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'roof', label = 'Roof', type = 'mod', modType = 10, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'engine', label = 'Engine', type = 'mod', modType = 11, forceCount = 4 },
    { key = 'brakes', label = 'Brakes', type = 'mod', modType = 12, forceCount = 3 },
    { key = 'transmission', label = 'Transmission', type = 'mod', modType = 13, forceCount = 3 },
    { key = 'horn', label = 'Horn', type = 'mod', modType = 14, forceAddon = true, fallbackCount = Config.DefaultHornCount },
    { key = 'suspension', label = 'Suspension', type = 'mod', modType = 15, forceCount = 4 },
    { key = 'armor', label = 'Armor', type = 'mod', modType = 16, forceCount = 5 },
    { key = 'turbo', label = 'Turbo', type = 'toggle', modType = 18 },
    { key = 'wheels', label = 'Wheels', type = 'mod', modType = 23, forceAddon = true, fallbackCount = Config.DefaultWheelCount },
    { key = 'plateHolder', label = 'Plate Holder', type = 'mod', modType = 25, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'vanityPlates', label = 'Vanity Plates', type = 'mod', modType = 26, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'trim', label = 'Trim Design', type = 'mod', modType = 27, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'ornaments', label = 'Ornaments', type = 'mod', modType = 28, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'dashboard', label = 'Dashboard', type = 'mod', modType = 29, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'dial', label = 'Dial', type = 'mod', modType = 30, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'doorSpeaker', label = 'Door Speakers', type = 'mod', modType = 31, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'seats', label = 'Seats', type = 'mod', modType = 32, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'steeringWheel', label = 'Steering Wheel', type = 'mod', modType = 33, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'shifterLeavers', label = 'Shifter', type = 'mod', modType = 34, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'plaques', label = 'Plaques', type = 'mod', modType = 35, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'speakers', label = 'Speakers', type = 'mod', modType = 36, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'trunk', label = 'Trunk', type = 'mod', modType = 37, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'hydraulics', label = 'Hydraulics', type = 'mod', modType = 38, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'engineBlock', label = 'Engine Block', type = 'mod', modType = 39, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'airFilter', label = 'Air Filter', type = 'mod', modType = 40, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'struts', label = 'Struts', type = 'mod', modType = 41, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'archCover', label = 'Arch Cover', type = 'mod', modType = 42, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'aerials', label = 'Aerials', type = 'mod', modType = 43, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'tank', label = 'Tank', type = 'mod', modType = 45, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'windows', label = 'Windows', type = 'mod', modType = 46, forceAddon = true, fallbackCount = Config.DefaultAddonVisualCount },
    { key = 'livery', label = 'Livery', type = 'mod', modType = 48, forceAddon = true, fallbackCount = Config.DefaultLiveryCount, nativeLivery = true }
}
