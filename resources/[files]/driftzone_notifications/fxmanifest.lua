fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Notifications'
version '1.0.2'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/info.png',
    'html/warning.png',
    'html/error.png',
    'html/notification.mp3'
}

client_scripts {
    'client/main.lua'
}

shared_scripts {
    'locales/v2_settings.js'
}
