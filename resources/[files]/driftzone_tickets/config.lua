Config = {}

Config.MainColor = '#04c7f7'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'

-- Scriptul incearca automat si coloanele astea, in ordine.
-- Daca la tine coloana de admin este "admin", merge.
-- Daca este "admin_level" sau "adminLvl", merge la fel.
Config.AdminLevelColumn = 'admin_level'
Config.AdminLevelFallbackColumns = { 'admin', 'adminLvl', 'adminLevel', 'admin_level' }

-- ON DUTY = users.aduty = 1
-- OFF DUTY = users.aduty = 0
Config.AdminDutyColumn = 'aduty'
Config.AdminDutyFallbackColumns = { 'aduty', 'onduty', 'onDuty' }

Config.MinAdminLevel = 1
Config.RequireAduty = true

Config.MaxTitleLength = 80
Config.MaxSubjectLength = 500

Config.CounterRefreshMs = 5000

Config.AdminRanks = {
    [1] = 'Trial Helper',
    [2] = 'Helper',
    [3] = 'Moderator',
    [4] = 'Admin',
    [5] = 'Manager',
    [6] = 'Co-Owner',
    [7] = 'Owner'
}
