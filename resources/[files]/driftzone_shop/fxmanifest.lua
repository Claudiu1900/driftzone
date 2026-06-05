fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Coins Shop'
version '3.0.0'

shared_scripts {
    'html/js/database.js',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/utils/functions.js',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/images/*.jpeg',
    'html/images/*.webp'
}
