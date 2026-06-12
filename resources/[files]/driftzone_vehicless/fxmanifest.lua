fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Vehicless - local vehicle photo studio'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'dist/screenshot.js'
}

shared_scripts {
    'shared/config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/screenshot_client.js',
    'client/main.lua'
}

dependency 'oxmysql'
dependency 'yarn'
dependency 'webpack'

webpack_config 'ui.config.js'
