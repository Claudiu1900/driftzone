Config = {}

Config.MainColor = '#2aaeff'

Config.CreatorCoords = {
    x = -811.15,
    y = 175.22,
    z = 76.75,
    h = 112.0
}

Config.CreatorCamera = {
    x = -813.10,
    y = 174.10,
    z = 77.55,
    lookX = -811.15,
    lookY = 175.22,
    lookZ = 77.15,
    fov = 34.0
}

Config.SpawnAfterCreator = {
    x = -460.0,
    y = 6000.0,
    z = 40.0,
    h = 0.0
}

Config.DefaultCreatorClothes = {
    -- Haine foarte simple/nude pentru editor, ca sa vezi corpul/fata fara haine peste caracter.
    -- component IDs:
    -- 1 mask, 3 arms, 4 pants, 5 bag, 6 shoes, 7 accessory, 8 undershirt, 9 armor, 10 decals, 11 top
    male = {
        mask = { component = 1, drawable = 0, texture = 0 },
        arms = { component = 3, drawable = 15, texture = 0 },
        pants = { component = 4, drawable = 21, texture = 0 },
        bag = { component = 5, drawable = 0, texture = 0 },
        shoes = { component = 6, drawable = 34, texture = 0 },
        accessory = { component = 7, drawable = 0, texture = 0 },
        tshirt = { component = 8, drawable = 15, texture = 0 },
        armor = { component = 9, drawable = 0, texture = 0 },
        decals = { component = 10, drawable = 0, texture = 0 },
        torso = { component = 11, drawable = 15, texture = 0 }
    },

    female = {
        mask = { component = 1, drawable = 0, texture = 0 },
        arms = { component = 3, drawable = 15, texture = 0 },
        pants = { component = 4, drawable = 15, texture = 0 },
        bag = { component = 5, drawable = 0, texture = 0 },
        shoes = { component = 6, drawable = 35, texture = 0 },
        accessory = { component = 7, drawable = 0, texture = 0 },
        tshirt = { component = 8, drawable = 15, texture = 0 },
        armor = { component = 9, drawable = 0, texture = 0 },
        decals = { component = 10, drawable = 0, texture = 0 },
        torso = { component = 11, drawable = 15, texture = 0 }
    }
}

-- Dupa ce caracterul este salvat, daca users.clothes este gol / {}:
-- male primeste outfit ID 1, female primeste outfit ID 4.
Config.DefaultSavedOutfits = {
    male = 1,
    female = 2
}

-- Delay-uri pentru reload silent dupa salvare caracter/default outfit.
Config.ClothesReloadDelays = { 300, 900, 1800, 3500 }
