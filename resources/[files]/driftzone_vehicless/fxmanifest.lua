fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Vehicless - clean vehicle studio, screenshot removed'
version '13.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_script 'shared/config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'
