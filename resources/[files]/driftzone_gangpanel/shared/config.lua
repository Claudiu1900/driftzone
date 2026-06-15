Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'gang'
Config.NotifyEvent = 'client:notify'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.UsernameColumn = 'username'
Config.SyndicateColumn = 'sindicate'

Config.GangsTable = 'gangs'
Config.MembersTable = 'gang_members'
Config.LogsTable = 'gang_logs'
Config.TaxesTable = 'gang_taxes'

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
    'Neo',
    'Oficiala'
}

Config.MaxMembersPerGang = 120
Config.CreateDefaultRole = 'Lider'
Config.RefreshCooldownMs = 600
Config.ActionCooldownMs = 450
Config.UpdateLastSeenEveryMs = 60000

Config.AllowLeaderPromoteCoLeader = true
Config.AllowCoLeaderKickMembers = true
Config.AllowCoLeaderInviteMembers = true

Config.Emote = {
    enabled = true,
    name = 'tablet2',
    playEvent = 'driftzone_emotes:client:play',
    stopEvent = 'driftzone_emotes:client:stop',
    fallbackCancelCommand = 'e c'
}

Config.Hooks = {}

-- Exemple:
-- Config.Hooks.AfterCreateGang = function(src, gangId, data) end
-- Config.Hooks.AfterAddMember = function(src, gangId, targetUid, role) end
-- Config.Hooks.AfterKickMember = function(src, gangId, targetUid) end
-- Config.Hooks.AfterUpdateGang = function(src, gangId, data) end
-- Config.Hooks.AfterDeleteGang = function(src, gangId) end
