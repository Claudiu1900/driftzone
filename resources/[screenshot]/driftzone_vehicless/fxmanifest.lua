fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Vehicless - vehicle photo studio with safe client screenshot upload'
version '9.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_script 'shared/config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'
