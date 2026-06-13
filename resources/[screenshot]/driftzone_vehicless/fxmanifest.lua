fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Vehicless - vehicle photo studio, no hard screenshot-basic dependency, bundled with built screenshot-basic support'
version '7.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_script 'shared/config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'

