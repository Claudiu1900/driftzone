fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'Optimized minimap HUD with persistent health, armour, food and water in users.stats.'
version '3.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependency 'oxmysql'

ui_page 'html/hud_v21.html'

files {
    'html/hud_v21.html'
}
