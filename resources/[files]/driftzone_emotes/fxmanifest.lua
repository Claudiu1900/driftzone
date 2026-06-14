fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'driftzone_emotes'
author 'DriftZone'
description 'DriftZone Emotes - 0r style UI, standalone/custom framework'
version '1.1.0'

ui_page 'html/index.html'

shared_scripts {
    'shared/cores.lua',
    'shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'shared/config.lua',
    'shared/animation-list.lua'
}

client_scripts {
    'client/core.lua',
    'client/text-ui.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/index.js',
    'html/style.css',
    'html/style-vw.css',
    'html/files/*.*',
    'html/sounds/*.*',
    'html/assets/images/*.*',
    'html/assets/sounds/*.*',
    'assets/*.png',
    'stream/**/*',
    'stream/*.ytyp',
    'stream/*/*.ytyp',
    'stream/**/*.ytyp'
}

-- Pentru props/custom emotes puse manual in stream.
data_file 'DLC_ITYP_REQUEST' 'stream/*.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/*/*.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'

dependency 'oxmysql'
