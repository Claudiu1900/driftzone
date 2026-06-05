fx_version '1.2.0'
game 'gta5'
lua54 'yes'
author 'DriftZone'
description 'DriftZone Outfits - trigger only + sex filtered outfits'
version '1.2.0'
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/script.js' }
server_scripts {
    'server/lib/webpack_bundle.js', '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
