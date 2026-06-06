Config = {}

Config.MainColor = '#04c7f7'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'

-- Pentru DriftZone, coloana principala este de obicei users.admin.
-- Scriptul verifica automat si fallback-urile de mai jos daca numele difera.
Config.AdminLevelColumn = 'admin'
Config.AdminLevelFallbackColumns = { 'admin', 'adminLvl', 'adminLevel', 'admin_level' }

-- Regula ceruta:
-- users.aduty = 1 -> admin ON DUTY -> /ticket deschide staff panel
-- users.aduty = 0 -> admin OFF DUTY -> /ticket deschide ticket normal de player
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
