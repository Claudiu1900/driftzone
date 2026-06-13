fx_version 'cerulean'
game 'gta5'

-- DriftZone build: client-only screenshot-basic.
-- No yarn/webpack dependency. dist/ui.html and dist/client.js are already built.

client_script 'dist/client.js'

files {
    'dist/ui.html'
}

ui_page 'dist/ui.html'
