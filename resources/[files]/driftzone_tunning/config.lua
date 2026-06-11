Config = {}
Config.CashColumn = 'cash'
Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'

Config.AdminCommand = 'tunning'
Config.AdminMinLevel = 6
Config.AdminDutyRequired = true
Config.LogsTable = 'tunning_logs'

-- Nu forta optiuni vizuale fake. Vizualele apar doar daca exista in modkit/carcols.
Config.ShowOnlyValidVisualMods = true


Config.PricePercent = {
    primaryColor = 2, secondaryColor = 2, pearlescentColor = 1, wheelColor = 1, windowTint = 1, xenonColor = 2,
    spoiler = 3, frontBumper = 3, rearBumper = 3, sideSkirt = 2, exhaust = 2, frame = 2, grille = 2, hood = 3, fender = 2, rightFender = 2, roof = 3,
    engine = 30, brakes = 18, transmission = 22, suspension = 14, turbo = 18,
    wheels = 5, horn = 1, plateHolder = 1, vanityPlates = 1, trim = 2, ornaments = 2, dashboard = 2, dial = 1, doorSpeaker = 2, seats = 3, steeringWheel = 2, shifterLeavers = 1, plaques = 1, speakers = 2, trunk = 2, hydraulics = 3, engineBlock = 3, airFilter = 2, struts = 2, archCover = 2, aerials = 1, tank = 2, windows = 2, livery = 4
}


-- Extra-uri: se vor afisa automat doar extra-urile care exista pe masina curenta.
-- Nu sunt fake; daca DoesExtraExist intoarce true, apar in meniu si se pot aplica.
Config.ExtraIds = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }
Config.ExtraPricePercent = 1

Config.Categories = {
    { key = 'primaryColor', label = 'Primary Color', type = 'color' },
    { key = 'secondaryColor', label = 'Secondary Color', type = 'color' },
    { key = 'pearlescentColor', label = 'Pearlescent', type = 'classicColor' },
    { key = 'wheelColor', label = 'Wheel Color', type = 'classicColor' },
    { key = 'windowTint', label = 'Window Tint', type = 'windowTint' },
    { key = 'xenonColor', label = 'Xenon Color', type = 'xenonColor' },
    { key = 'spoiler', label = 'Spoiler', type = 'mod', modType = 0 },
    { key = 'frontBumper', label = 'Front Bumper', type = 'mod', modType = 1 },
    { key = 'rearBumper', label = 'Rear Bumper', type = 'mod', modType = 2 },
    { key = 'sideSkirt', label = 'Side Skirt', type = 'mod', modType = 3 },
    { key = 'exhaust', label = 'Exhaust', type = 'mod', modType = 4 },
    { key = 'frame', label = 'Frame', type = 'mod', modType = 5 },
    { key = 'grille', label = 'Grille', type = 'mod', modType = 6 },
    { key = 'hood', label = 'Hood', type = 'mod', modType = 7 },
    { key = 'fender', label = 'Left Fender', type = 'mod', modType = 8 },
    { key = 'rightFender', label = 'Right Fender', type = 'mod', modType = 9 },
    { key = 'roof', label = 'Roof', type = 'mod', modType = 10 },
    { key = 'engine', label = 'Engine', type = 'mod', modType = 11, forceCount = 4, performance = true },
    { key = 'brakes', label = 'Brakes', type = 'mod', modType = 12, forceCount = 3, performance = true },
    { key = 'transmission', label = 'Transmission', type = 'mod', modType = 13, forceCount = 3, performance = true },
    { key = 'horn', label = 'Horn', type = 'mod', modType = 14 },
    { key = 'suspension', label = 'Suspension', type = 'mod', modType = 15, forceCount = 4, performance = true },
    { key = 'turbo', label = 'Turbo', type = 'toggle', modType = 18 },
    { key = 'wheels', label = 'Wheels', type = 'mod', modType = 23 },
    { key = 'plateHolder', label = 'Plate Holder', type = 'mod', modType = 25 },
    { key = 'vanityPlates', label = 'Vanity Plates', type = 'mod', modType = 26 },
    { key = 'trim', label = 'Trim Design', type = 'mod', modType = 27 },
    { key = 'ornaments', label = 'Ornaments', type = 'mod', modType = 28 },
    { key = 'dashboard', label = 'Dashboard', type = 'mod', modType = 29 },
    { key = 'dial', label = 'Dial', type = 'mod', modType = 30 },
    { key = 'doorSpeaker', label = 'Door Speakers', type = 'mod', modType = 31 },
    { key = 'seats', label = 'Seats', type = 'mod', modType = 32 },
    { key = 'steeringWheel', label = 'Steering Wheel', type = 'mod', modType = 33 },
    { key = 'shifterLeavers', label = 'Shifter', type = 'mod', modType = 34 },
    { key = 'plaques', label = 'Plaques', type = 'mod', modType = 35 },
    { key = 'speakers', label = 'Speakers', type = 'mod', modType = 36 },
    { key = 'trunk', label = 'Trunk', type = 'mod', modType = 37 },
    { key = 'hydraulics', label = 'Hydraulics', type = 'mod', modType = 38 },
    { key = 'engineBlock', label = 'Engine Block', type = 'mod', modType = 39 },
    { key = 'airFilter', label = 'Air Filter', type = 'mod', modType = 40 },
    { key = 'struts', label = 'Struts', type = 'mod', modType = 41 },
    { key = 'archCover', label = 'Arch Cover', type = 'mod', modType = 42 },
    { key = 'aerials', label = 'Aerials', type = 'mod', modType = 43 },
    { key = 'tank', label = 'Tank', type = 'mod', modType = 45 },
    { key = 'windows', label = 'Windows', type = 'mod', modType = 46 },
    { key = 'livery', label = 'Livery', type = 'mod', modType = 48, nativeLivery = true }
}
