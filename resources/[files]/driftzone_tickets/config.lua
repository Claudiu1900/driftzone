Config = {}

Config.MainColor = '#04c7f7'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminLevelColumn = 'admin_level'
Config.AdminDutyColumn = 'aduty'

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
