fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Clothes - fixed load on join and reload trigger'
version '1.0.2'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/icons/*.svg'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

shared_scripts {
    'utils/queue_handler.js',
    'client/lib/jest_mock.js'
}
