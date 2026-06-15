Config = {}

Config.Command = 'phone'
Config.MainColor = '#04c7f7'
Config.NotifyEvent = 'client:notify'

Config.AuthResource = 'driftzone_auth'

Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'

-- Coloana principala. Scriptul verifica si PhoneColumns ca fallback.
Config.PhoneColumn = 'phonenumber'
Config.PhoneColumns = { 'phonenumber', 'phone_number', 'phone', 'number' }

Config.CallTimeoutMs = 30000

-- Nu bloca numere scurte. Daca exista in DB, il poti suna.
Config.PhoneNumberMinLength = 1
Config.PhoneNumberMaxLength = 32

-- Cand true, telefonul se deschide singur la apel primit.
-- Cand false, primesti notificare si raspunzi cand deschizi /phone.
Config.AutoOpenOnIncoming = false

-- Debug util daca mai ai probleme cu UID/numere.
Config.Debug = false
