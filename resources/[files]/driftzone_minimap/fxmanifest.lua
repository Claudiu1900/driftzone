fx_version 'cerulean'
game 'gta5'

author 'DriftZone'
description 'Standalone minimap HUD with health, armour, food, water and stamina.'
version '1.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
