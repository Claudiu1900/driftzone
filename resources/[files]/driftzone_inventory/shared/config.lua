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
-- money vine direct din users.cash, nu din inventory_items / inventory_json.
Config.MoneyItemId = 'money'
Config.DirtyMoneyItemId = 'dirtymoney'
Config.MoneyItemName = 'Money'
Config.DirtyMoneyItemName = 'Dirty Money'
Config.MoneyImage = ''
Config.DirtyMoneyImage = ''
Config.CurrencyMaxStack = 2147483647

Config.InventoryTable = 'inventory'
Config.ItemsTable = 'inventory_items'
Config.LogsTable = 'inventory_logs'

Config.Admin = {
    additem = 6,
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

