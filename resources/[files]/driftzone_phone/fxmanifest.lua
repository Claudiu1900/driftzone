fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Phone - calls, contacts, messages, garage app'
version '1.2.0-full-garage'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/icons/*.svg',
    'html/assets/sounds/ring.mp3',
    'html/assets/sounds/ring2.mp3',
    'html/assets/sounds/decline.mp3',
    'html/assets/sounds/message.mp3'
}

shared_scripts {
    'shared/config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}
