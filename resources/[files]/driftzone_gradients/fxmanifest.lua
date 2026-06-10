fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DriftZone'
description 'DriftZone Gradients - real chameleon paint using chameleonpaint data'
version '1.1.0'

shared_script 'shared/config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'data/carcols_gen9.meta',
    'data/carmodcols_gen9.meta',
    'data/carmodcols.ymt',
    'stream/vehicle_paint_ramps.ytd'
}

data_file 'CARCOLS_GEN9_FILE' 'data/carcols_gen9.meta'
data_file 'CARMODCOLS_GEN9_FILE' 'data/carmodcols_gen9.meta'
data_file 'FIVEM_LOVES_YOU_447B37BE29496FA0' 'data/carmodcols.ymt'
