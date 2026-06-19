fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'Job complet de mecanic pentru DriftZone'
version '1.0.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'oxmysql'
