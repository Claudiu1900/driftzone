fx_version 'bodacious'
game 'common'

-- Built version for servers without the yarn/webpack builder resources.
-- The original source files are kept in this folder, but this manifest runs dist directly.

client_script 'dist/client.js'
server_script 'dist/server.js'

files {
    'dist/ui.html'
}

ui_page 'dist/ui.html'
