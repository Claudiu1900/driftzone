fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Races - public/private multiplayer race lobbies'
version '1.0.0'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
