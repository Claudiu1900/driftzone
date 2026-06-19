fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'driftzone_electrician'
author 'DriftZone'
description 'Job complet de electrician pentru DriftZone: NPC, duba, uniforma, tableta, interventii, XP si bonusuri.'
version '2.1.0'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/storage.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'oxmysql'
