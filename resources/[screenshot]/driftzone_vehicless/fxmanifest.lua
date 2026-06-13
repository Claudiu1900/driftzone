fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Vehicless - local FiveM vehicle photo studio'
version '2.0.0-fixed'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
