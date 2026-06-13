fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- DriftZone fixed screenshot-basic
-- Nu foloseste yarn/webpack si nu foloseste export JS.
-- Exporturile requestScreenshot/requestScreenshotUpload sunt facute in Lua, deci FiveM le vede sigur.

client_script 'client.lua'

files {
    'dist/ui.html'
}

ui_page 'dist/ui.html'
