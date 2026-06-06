fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Cycle - final admin local time/weather fix'
version '1.1.3'

shared_scripts {
    'client/scripts/testing.js',
    'config.lua'
}

server_scripts {
    'server/lib/app.js',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}
