fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Implements - optimized HUD cleanup, music wheel disable, controls, stamina, godmode, persistent hat/helmet, auto aduty reset'
version '1.2.0'

shared_scripts {
    'vendor/runtime_module.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}
