fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Vehicle Config - owned-only locks, engine, temporary keys'
version '2.1.0'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
