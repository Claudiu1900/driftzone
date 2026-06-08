fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Garage - forced tuning + spawn cooldown + optimized'
version '1.0.3'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

shared_scripts {
    'config/config.lua',
    'config/config_settings.js',
    'data/events.js'
}
