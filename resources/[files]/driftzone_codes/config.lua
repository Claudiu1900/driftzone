Config = {}

Config.MainColor = '#04c7f7'

Config.Database = {
    usersTable = 'users',
    uidColumn = 'uid',
    dzCoinsColumn = 'dzcoins'
}

Config.Admin = {
    minLevel = 6,
    requireAduty = true,

    -- Prima data incearca Player state + exports driftzone_auth.
    -- Daca nu gaseste acolo, foloseste baza de date.
    useDatabaseFallback = true,

    -- La tine este users.admin_level
    adminLevelColumn = 'admin_level',

    -- Daca la tine coloana are alt nume, schimba aici.
    adutyColumn = 'aduty'
}

Config.Code = {
    generatedLength = 12,
    maxCodeLength = 64,
    redeemCooldownMs = 1800,
    listLimit = 30
}

Config.RewardAliases = {
    dz = 'dzcoins',
    dzcoin = 'dzcoins',
    dzcoins = 'dzcoins',

    c = 'money',
    cash = 'money',
    money = 'money',
    coin = 'money',
    coins = 'money'
}

Config.Rewards = {
    dzcoins = {
        label = 'DriftZone Coins',
        columns = { 'dzcoins' }
    },

    money = {
        label = 'Money',
        -- Scriptul foloseste prima coloana care exista in users.
        -- Daca banii tai sunt in alta coloana, pune aici numele.
        columns = { 'money', 'cash' }
    }
}

Config.Chat = {
    enabled = true,
    prefix = 'DriftZone',
    color = { 4, 199, 247 }
}

Config.Notifications = {
    enabled = true,
    successType = 'info',
    warningType = 'warning',
    errorType = 'error'
}
