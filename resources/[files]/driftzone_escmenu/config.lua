Config = {}

Config.DiscordInvite = 'https://discord.gg/346s8S2Ha6'

Config.MainColor = '#04c7f7'
Config.OpenCommand = 'escmenu'
Config.DisableDefaultPause = true

Config.Images = {
    logo = 'images/logo.png',
    map = 'images/card_map.png',
    garage = 'images/card_garage.png',
    ticket = 'images/card_ticket.png',
    discord = 'images/card_discord.png',
    settings = 'images/card_settings.png',
    ui_settings = 'images/card_ui_settings.png',
    shop = 'images/card_shop.png',
    keybinds = 'images/card_keybinds.png'
}

Config.Cards = {
    {
        id = 'map',
        title = 'MAP',
        subtitle = 'Deschide meniul default GTA',
        image = 'map',
        action = { type = 'default_pause' }
    },
    {
        id = 'garage',
        title = 'GARAGE',
        subtitle = 'Vehiculele tale personale',
        image = 'garage',
        action = { type = 'command', value = 'garage' }
    },
    {
        id = 'ticket',
        title = 'TICKET',
        subtitle = 'Creeaza un ticket pentru admini',
        image = 'ticket',
        action = { type = 'command', value = 'ticket' }
    },
    {
        id = 'discord',
        title = 'DISCORD',
        subtitle = 'Copiaza invitatia comunitatii',
        image = 'discord',
        action = { type = 'copy_discord' }
    },
    {
        id = 'settings',
        title = 'SETTINGS',
        subtitle = 'Deschide meniul default GTA',
        image = 'settings',
        action = { type = 'default_pause' }
    },
    {
        id = 'ui_settings',
        title = 'UI SETTINGS',
        subtitle = 'Coming soon',
        image = 'ui_settings',
        action = { type = 'command', value = 'settings' }
    },
    {
        id = 'keybinds',
        title = 'KEYBINDS',
        subtitle = 'Modifica tastele meniurilor',
        image = 'keybinds',
        action = { type = 'command', value = 'keybinds' }
    },
    {
    id = 'shop',
    title = 'SHOP',
    subtitle = 'Deschide DriftZone Shop',
    image = 'shop',
    action = {
        type = 'client_event',
        value = 'driftzone_shop:client:show'}
    }
}

Config.Database = {
    usersTable = 'users',
    uidColumn = 'uid',
    dzCoinsColumn = 'dzcoins'
}

Config.Pause = {
    frontendHash = 'FE_MENU_VERSION_MP_PAUSE',

    -- cat asteapta dupa inchiderea NUI inainte sa deschida meniul default
    openDelayMs = 260,

    -- cate incercari face pana cand pause menu devine activ
    openAttempts = 25,

    -- delay intre incercari
    attemptDelayMs = 60,

    -- dupa ce iesi din pause menu, nu redeschide ESC UI instant
    cooldownAfterCloseMs = 550
}
