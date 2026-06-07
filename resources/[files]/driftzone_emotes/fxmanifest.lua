fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DriftZone'
description 'DriftZone Emotes - custom NUI card emote menu'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'stream/*'
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

-- Daca folderul tau stream contine fisiere .ytyp pentru props custom,
-- adauga aici manual fiecare .ytyp, de exemplu:
-- data_file 'DLC_ITYP_REQUEST' 'stream/rpemotesreborn_props.ytyp'
-- data_file 'DLC_ITYP_REQUEST' 'stream/brummie_props.ytyp'
