Config = {}

Config.Command = 'phone'
Config.MainColor = '#04c7f7'
Config.NotifyEvent = 'client:notify'

Config.AuthResource = 'driftzone_auth'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.PhoneColumn = 'phonenumber'

Config.CallTimeoutMs = 30000
Config.PhoneNumberMinLength = 3
Config.PhoneNumberMaxLength = 16

-- Cand true, telefonul se deschide singur la apel primit.
-- Cand false, primesti doar notificare si il deschizi cu /phone.
Config.AutoOpenOnIncoming = false

Config.Debug = false
