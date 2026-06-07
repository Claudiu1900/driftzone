fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Emotes - NUI card emote menu'
version '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'stream/*.ycd',
    'stream/*.ydr',
    'stream/*.ytd',
    'stream/*.ytyp'
}

shared_scripts {
    'config.lua',
    'data/emotes.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

data_file 'DLC_ITYP_REQUEST' 'stream/apple_1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/brummie_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_camp_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_murderpack.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/kaykaymods_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/knjgh_pizzas.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/natty_props_lollipops.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pata_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pnwsigns.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pprp_icefishing.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/rpemotesreborn_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/samnick_prop_lighter01.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/scully_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/taymckenzienz_rpemotes.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/ultra_ringcase.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/vedere_props.ytyp'