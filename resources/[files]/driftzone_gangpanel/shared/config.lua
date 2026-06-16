Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'gang'

-- Sistemul tau de notificari. Format folosit: TriggerClientEvent(event, src, type, duration, message)
Config.NotifyEvent = 'client:notify'
Config.NotifyDuration = 4500

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
    'Mafie Neoficiala',
    'Mafie Oficiala'
}

Config.MaxMembersPerGang = 120
Config.CreateDefaultRole = 'Lider'
Config.RefreshCooldownMs = 600
Config.ActionCooldownMs = 450
Config.UpdateLastSeenEveryMs = 60000

Config.AllowLeaderPromoteCoLeader = true
Config.AllowCoLeaderKickMembers = true
Config.AllowCoLeaderInviteMembers = true

-- Animatie locala, fara sa depinda de permisiunile din driftzone_emotes.
-- Sta pornita cat timp /gang este deschis si se opreste curat la iesire.
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

-- Exemple:
-- Config.Hooks.AfterCreateGang = function(src, gangId, data) end
-- Config.Hooks.AfterAddMember = function(src, gangId, targetUid, role) end
-- Config.Hooks.AfterKickMember = function(src, gangId, targetUid) end
-- Config.Hooks.AfterUpdateGang = function(src, gangId, data) end
-- Config.Hooks.AfterDeleteGang = function(src, gangId) end
