Config = {}

Config.MainColor = '#04c7f7'
Config.Command = 'phone'
Config.Debug = false

Config.AuthResource = 'driftzone_auth'
Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.PhoneColumn = 'phonenumber'
Config.PhoneColumns = { 'phonenumber', 'phone_number', 'phone', 'number' }

Config.ContactsTable = 'contacts'
Config.CallHistoryTable = 'call_history'
Config.MessageHistoryTable = 'message_history'

Config.PhoneNumberMinLength = 1
Config.PhoneNumberMaxLength = 32
Config.CallTimeoutMs = 30000
Config.StateRefreshMs = 1200
Config.MessageLimit = 250
Config.HistoryLimit = 80
Config.ContactsLimit = 300
