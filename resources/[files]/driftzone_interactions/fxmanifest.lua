fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Interactions - optimized FiveM interaction prompts'
version '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    'data/v2_settings.js',
    'dist/commands.js',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}
