Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'inventory'
Config.NotifyEvent = 'client:notify'

Config.Slots = 49
Config.Columns = 7
Config.MaxGiveDistance = 4.0

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsersCashColumn = 'cash'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = 'admin'
Config.AdutyColumn = 'aduty'

-- Sloturi speciale de bani deasupra inventarului.
-- money este definit in inventory_items pentru nume/imagine/use/give/drop, dar suma reala vine din users.cash.
Config.MoneyItemId = 'money'
Config.DirtyMoneyItemId = 'dirtymoney'
Config.MoneyItemName = 'Money'
Config.DirtyMoneyItemName = 'Dirty Money'
Config.MoneyImage = ''
Config.DirtyMoneyImage = ''
Config.CurrencyMaxStack = 2147483647

Config.QuickSlots = 5

Config.InventoryTable = 'inventory'
Config.ItemsTable = 'inventory_items'
Config.LogsTable = 'inventory_logs'

Config.Admin = {
    additem = 6,
    items = 6,
    addclothes = 6,
    clothesitems = 6,
    giveitem = 6,
    takeitem = 6,
    wipeinventory = 6
}

Config.ItemDefaults = {
    image = '',
    tradable = 1,
    stackable = 1,
    usable = 0,
    giveable = 1,
    max_stack = 100
}

Config.GiveSelectDistance = 6.0
Config.DropMergeRadius = 4.0
Config.DropShowRadius = 4.0
Config.DropPickupRadius = 4.0
Config.DropMarkerRadius = 35.0

Config.GradientResource = 'driftzone_gradients'
Config.GradientItemSuffix = '_gradient'

Config.TakeGradientItemId = 'takegradient'


-- =========================
-- CLOTHES ITEMS / EQUIPMENT
-- =========================
Config.ClothesItemsTable = 'clothes_items'
Config.UsersClothesTable = 'users_clothes'

-- Categoria decide unde se pune haina pe corp si ce native GTA foloseste.
-- componentId = SetPedComponentVariation, propId = SetPedPropIndex/ClearPedProp.
Config.ClothingCategoryOrder = {
    'hat', 'glasses', 'mask', 'accessories', 'jacket', 'top', 'torso',
    'vest', 'bag', 'pants', 'shoes', 'watches', 'bracelets'
}

Config.ClothingAliases = {
    jaket = 'jacket',
    jacheta = 'jacket',
    palarie = 'hat',
    hats = 'hat',
    ochelari = 'glasses',
    masca = 'mask',
    accesorii = 'accessories',
    acecessories = 'accessories',
    accessory = 'accessories',
    ceas = 'watches',
    watch = 'watches',
    bratari = 'bracelets',
    bracelet = 'bracelets',
    pantaloni = 'pants',
    pantofi = 'shoes',
    geanta = 'bag',
    arms = 'torso'
}

Config.ClothingCategories = {
    jacket = { label = 'Jacket', icon = 'jacket.svg', type = 'component', componentId = 11 },
    top = { label = 'Top', icon = 'top.svg', type = 'component', componentId = 8 },
    torso = { label = 'Torso / Arms', icon = 'torso.svg', type = 'component', componentId = 3 },
    mask = { label = 'Mask', icon = 'mask.svg', type = 'component', componentId = 1 },
    shoes = { label = 'Shoes', icon = 'shoes.svg', type = 'component', componentId = 6 },
    pants = { label = 'Pants', icon = 'pants.svg', type = 'component', componentId = 4 },
    accessories = { label = 'Accessories', icon = 'accessories.svg', type = 'component', componentId = 7 },
    watches = { label = 'Watches', icon = 'watches.svg', type = 'prop', propId = 6 },
    bracelets = { label = 'Bracelets', icon = 'bracelets.svg', type = 'prop', propId = 7 },
    vest = { label = 'Vest', icon = 'vest.svg', type = 'component', componentId = 9 },
    bag = { label = 'Bag', icon = 'bag.svg', type = 'component', componentId = 5 },
    hat = { label = 'Hat', icon = 'hat.svg', type = 'prop', propId = 0 },
    glasses = { label = 'Glasses', icon = 'glasses.svg', type = 'prop', propId = 1 }
}

-- Forteaza reincarcarea hainelor salvate dupa login/spawn. Nu poate opri spawn-ul GTA,
-- dar reaplica hainele de mai multe ori ca sa nu ramana playerul cu default skin.
Config.ClothesLoad = {
    Enabled = true,
    RetryCount = 18,
    RetryDelayMs = 850,
    ClientRetryDelays = { 500, 1200, 2200, 3500, 5200, 7500, 10000, 13500, 17000 }
}


-- =========================
-- DRIFTZONE INVENTORY HOOKS
-- =========================
-- Aici modifici usor animatii / triggere fara sa umbli in client/server.
Config.ActionAnimations = {
    Enabled = true,

    -- false = foloseste animatii native GTA, merge pentru toti jucatorii.
    -- true  = incearca intai driftzone_emotes cu numele de mai jos, apoi opreste automat dupa duration.
    UseDriftzoneEmotes = false,
    EmotesResource = 'driftzone_emotes',

    give = {
        emote = 'give2',
        dict = 'mp_common',
        anim = 'givetake1_b',
        duration = 1600,
        flag = 48
    },

    pickup = {
        emote = 'pickup',
        dict = 'pickup_object',
        anim = 'pickup_low',
        duration = 1150,
        flag = 0
    }
}

Config.Drops = {
    -- true = markerul/ sageata drop-urilor se vede pentru tot serverul in radius, nu doar pentru cel care arunca.
    RefreshAlways = true,
    RefreshIntervalMs = 1500,
    RefreshIntervalClosedMs = 2200
}

-- Hook-uri client. Poti adauga aici orice TriggerEvent/export vrei.
-- Exemplu:
-- Config.ClientHooks.OnGiveSuccess = function(data)
--     TriggerEvent('alt_resource:client:ceva', data)
-- end
Config.ClientHooks = {}

Config.ClientHooks.OnInventoryOpen = function(data)
    -- se apeleaza cand inventarul se deschide
end

Config.ClientHooks.OnGiveSuccess = function(data)
    TriggerEvent('driftzone_inventory:client:playActionAnimation', 'give')
end

Config.ClientHooks.OnDropSuccess = function(data)
    TriggerEvent('driftzone_inventory:client:playActionAnimation', 'pickup')
end

Config.ClientHooks.OnPickupSuccess = function(data)
    TriggerEvent('driftzone_inventory:client:playActionAnimation', 'pickup')
end

Config.ClientHooks.OnInventoryClose = function()
end

-- Hook-uri server. Ruleaza dupa actiuni reusite.
Config.ServerHooks = {}

Config.ServerHooks.OnPlayerGiveItem = function(data)
    -- data = { source, target, fromUid, toUid, itemId, amount }
end

Config.ServerHooks.OnPlayerDropItem = function(data)
    -- data = { source, uid, itemId, amount, dropId, coords }
end

Config.ServerHooks.OnPlayerPickupItem = function(data)
    -- data = { source, uid, itemId, amount, dropId }
end

