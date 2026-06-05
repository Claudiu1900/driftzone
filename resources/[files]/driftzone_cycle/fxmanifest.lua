fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Cycle - Romania real time + Mangalia real weather'
version '1.0.0'

shared_scripts {
    'client/scripts/testing.js',
    'config.lua'
}

server_scripts {
    'server/lib/app.js',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}
