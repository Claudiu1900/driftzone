fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Cycle - Romania real time + fixed admin local overrides'
version '1.1.2'

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
