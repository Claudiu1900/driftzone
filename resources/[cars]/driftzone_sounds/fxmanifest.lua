fx_version 'cerulean'
game 'gta5'

author 'DriftZone'
description 'DriftZone Custom Engine Sounds'
version '1.0.0'

files {
    'audioconfig/*.dat151.rel',
    'audioconfig/*.dat54.rel',
    'sfx/**/*.awc'
}

-- Game data files: de obicei sunt *_game.dat151.rel
data_file 'AUDIO_GAMEDATA' 'audioconfig/*_game.dat'

-- Sound data files: de obicei sunt *_sounds.dat54.rel
data_file 'AUDIO_SOUNDDATA' 'audioconfig/*_sounds.dat'

-- Wavepack folders din sfx
data_file 'AUDIO_WAVEPACK' 'sfx/dlc_*'