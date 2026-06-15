Config = {}

Config.Command = 'phone'
Config.MainColor = '#04c7f7'

Config.AuthResource = 'driftzone_auth'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.PhoneColumn = 'phonenumber'
Config.PhoneColumns = { 'phonenumber', 'phone_number', 'phone', 'number' }

Config.CallTimeoutMs = 30000
Config.PhoneNumberMinLength = 1
Config.PhoneNumberMaxLength = 32

-- Telefonul nu mai trimite notificari externe. Apelurile se vad doar in UI-ul telefonului.
Config.UseExternalNotifications = false

-- Cand primesti apel si telefonul este inchis, apare telefonul partial in dreapta cu butoane.
Config.ShowPeekOnIncoming = true

Config.Debug = false
