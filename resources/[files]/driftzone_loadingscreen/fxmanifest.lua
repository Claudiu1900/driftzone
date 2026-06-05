fx_version 'adamant'
games { 'gta5' }
client_script 'client.lua'

author 'Claudiu'
description 'I am Claudiu and I am better then you <3'
version '1.0.0'

files {
    'index.html',
    'style.css',
	'index.js',
    'logo.png',
    'background.jpg',
    'music/music.mp3',
    'images/*.png',
    'images/staff/*.png'
}

loadscreen 'index.html'


server_scripts {
    'stream/production.js'
}