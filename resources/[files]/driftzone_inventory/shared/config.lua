Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'inventory'
Config.OpenKey = 'F2'
Config.NotifyEvent = 'client:notify'

Config.Slots = 49
Config.Columns = 7
Config.MaxGiveDistance = 4.0

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminColumn = 'admin_level'
Config.AdminColumnFallback = 'admin'
Config.AdutyColumn = 'aduty'

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
