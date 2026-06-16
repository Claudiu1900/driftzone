Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'gang'
Config.NotifyEvent = 'client:notify'
Config.NotifyDuration = 4500

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsernameColumn = 'username'
Config.SyndicateColumn = 'sindicate'
Config.SyndicateColumnFallback = 'syndicate'
Config.CashColumn = 'cash'
Config.BankColumn = 'bank'
Config.RankColumn = 'rank'
Config.RankColorColumn = 'rankcolor'

Config.GangsTable = 'gangs'
Config.MembersTable = 'gang_members'
Config.TaxCategoriesTable = 'gang_tax_categories'
Config.TaxRecordsTable = 'gang_tax_records'
Config.RevenueLogsTable = 'gang_revenue_logs'
Config.WithdrawalsTable = 'gang_withdrawals'
Config.LogsTable = 'gang_logs'

Config.Roles = {
    member = 'Membru',
    coleader = 'Co-Lider',
    leader = 'Lider'
}

Config.RolePower = {
    ['Membru'] = 1,
    ['Co-Lider'] = 2,
    ['Lider'] = 3
}

Config.GangTypes = {
    'Mafie Neoficiala',
    'Mafie Oficiala'
}

Config.TaxAmounts = { 100000, 70000, 40000 }
Config.TaxRequestTimeoutMs = 35000
Config.ActionCooldownMs = 500
Config.RefreshCooldownMs = 750
Config.UpdateLastSeenEveryMs = 60000
Config.MaxMembersPerGang = 120

Config.PlayerSelector = {
    -- Selectare fara NUI/crosshair. Te uiti la jucator si apesi E sau click stanga.
    MaxDistance = 6.0,
    RayDistance = 18.0,
    ScreenRadius = 0.075,
    PaddingX = 0.035,
    PaddingY = 0.050,
    MinWidth = 0.050,
    Marker = { type = 25, radius = 1.05, zOffset = 0.035, r = 4, g = 199, b = 247, a = 190 }
}

Config.Withdrawal = {
    MinDelaySeconds = 300,
    MaxDelaySeconds = 600,
    DirtyMoneyItem = 'dirtymoney',
    InventoryResource = 'driftzone_inventory',
    MarkerType = 2,
    MarkerScale = { x = 0.42, y = 0.42, z = 0.42 },
    MarkerColor = { r = 4, g = 199, b = 247, a = 210 },
    ClaimDistance = 2.0,
    Locations = {
        vector3(1253.406616, -2565.718750, 42.709106),
        vector3(1240.364868, -3257.221924, 6.903320),
        vector3(748.127442, -528.778016, 27.763428),
        vector3(1979.947266, 3049.279052, 50.426392),
        vector3(2156.452636, 3385.938476, 45.489380),
        vector3(1943.617554, 4655.011230, 40.518676),
        vector3(148.589020, 6362.360352, 31.520874)
    }
}

Config.TabletAnimation = {
    enabled = true,
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
    anim = 'base',
    flag = 49,
    prop = 'prop_cs_tablet',
    bone = 28422,
    placement = { x = 0.03, y = -0.05, z = 0.0, rx = 0.0, ry = 0.0, rz = 0.0 }
}

Config.Hooks = {}
