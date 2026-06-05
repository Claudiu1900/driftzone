Config = {}

Config.MainColor = '#04c7f7'

Config.Database = {
    usersTable = 'users',
    uidColumn = 'uid',
    dzCoinsColumn = 'dzcoins',
    cashColumn = 'cash',
    garageSlotsColumn = 'garageslots',
    outsideVehiclesColumn = 'outsidevehicles'
}

-- Shop-ul are categorii in stanga.
-- CASH este prima categorie.
Config.Categories = {
    {
        id = 'cash',
        label = 'CASH',
        subtitle = 'Cumpără bani cu DZ Coins',
        icon = 'cash'
    },
    {
        id = 'vehicles',
        label = 'VEHICLES',
        subtitle = 'Garaj, sloturi si vehicule',
        icon = 'vehicle'
    }
}

-- image = fisier din html/images/
-- purchasable = false -> apare in shop dar nu are pret activ si nu poate fi cumparat.
--
-- type:
-- cash             -> users.cash + amount
-- garage_slots     -> users.garageslots + amount
-- outside_vehicles -> users.outsidevehicles + amount
-- none             -> indisponibil
Config.Items = {
    {
        id = 'cash_50000',
        category = 'cash',
        title = '$50,000 Cash',
        tag = 'CASH PACK',
        short = '50K server cash',
        description = 'Primești instant $50,000 cash în contul tău de pe server.',
        price = 300,
        currency = 'DriftZone Coins',
        purchasable = true,
        type = 'cash',
        amount = 50000,
        image = 'cash_50000.png'
    },
    {
        id = 'cash_100000',
        category = 'cash',
        title = '$100,000 Cash',
        tag = 'CASH PACK',
        short = '100K server cash',
        description = 'Primești instant $100,000 cash în contul tău de pe server.',
        price = 500,
        currency = 'DriftZone Coins',
        purchasable = true,
        type = 'cash',
        amount = 100000,
        image = 'cash_100000.png'
    },
    {
        id = 'cash_250000',
        category = 'cash',
        title = '$250,000 Cash',
        tag = 'CASH PACK',
        short = '250K server cash',
        description = 'Primești instant $250,000 cash în contul tău de pe server.',
        price = 1000,
        currency = 'DriftZone Coins',
        purchasable = true,
        type = 'cash',
        amount = 250000,
        image = 'cash_250000.png'
    },
    {
        id = 'cash_500000',
        category = 'cash',
        title = '$500,000 Cash',
        tag = 'CASH PACK',
        short = '500K server cash',
        description = 'Primești instant $500,000 cash în contul tău de pe server.',
        price = 1750,
        currency = 'DriftZone Coins',
        purchasable = true,
        type = 'cash',
        amount = 500000,
        image = 'cash_500000.png'
    },
    {
        id = 'cash_1000000',
        category = 'cash',
        title = '$1,000,000 Cash',
        tag = 'CASH PACK',
        short = '1M server cash',
        description = 'Primești instant $1,000,000 cash în contul tău de pe server.',
        price = 3000,
        currency = 'DriftZone Coins',
        purchasable = true,
        type = 'cash',
        amount = 1000000,
        image = 'cash_1000000.png'
    },

    {
        id = 'garage_slots_1',
        category = 'vehicles',
        title = 'Garage Slots',
        tag = 'VEHICLE SLOT',
        short = 'Extra storage',
        description = 'Adauga un slot permanent in garajul tau. Vei putea detine cu 1 masina mai mult.',
        price = 1000,
        currency = 'DriftZone Coins',
        purchasable = true,
        type = 'garage_slots',
        amount = 1,
        image = 'garage_slots.png'
    },
    {
        id = 'outside_vehicles_1',
        category = 'vehicles',
        title = 'Outside Vehicles',
        tag = 'PARKING SLOT',
        short = 'More spawned cars',
        description = 'Mareste limita de masini pe care le poti avea scoase simultan din garaj cu +1.',
        price = 1000,
        currency = 'DriftZone Coins',
        purchasable = true,
        type = 'outside_vehicles',
        amount = 1,
        image = 'outside_vehicles.png'
    },
    {
        id = 'test_item',
        category = 'vehicles',
        title = 'Test Item',
        tag = 'COMING SOON',
        short = 'Experimental',
        description = 'Acesta este un item de test pentru produse viitoare. Momentan nu poate fi cumparat.',
        price = 0,
        currency = 'DriftZone Coins',
        purchasable = false,
        type = 'none',
        amount = 0,
        image = 'test_item.png'
    }
}

Config.Notifications = {
    enabled = true,
    successType = 'info',
    warningType = 'warning',
    errorType = 'error'
}
