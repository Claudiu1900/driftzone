# driftzone_tickets - FIX aduty 1/0

## Regula reparata

```txt
users.aduty = 1 -> admin ON DUTY -> /ticket deschide meniul de admin
users.aduty = 0 -> admin OFF DUTY -> /ticket deschide meniul normal de player
```

## Ce am reparat

- `/ticket` verifica baza de date live de fiecare data.
- `aduty = 0` nu mai blocheaza comanda.
- Adminii OFF DUTY sunt tratati ca player normal cand folosesc `/ticket`.
- Accept/Delete/Teleport raman permise doar pentru staff ON DUTY.
- Scriptul cauta automat coloana de admin: `admin_level`, `admin`, `adminLvl`, `adminLevel`.
- Scriptul cauta automat coloana duty: `aduty`, `onduty`, `onDuty`.

## Config important

In `config.lua` poti lasa asa:

```lua
Config.UsersTable = 'users'
Config.UsersIdColumn = 'uid'
Config.AdminLevelColumn = 'admin_level'
Config.AdminLevelFallbackColumns = { 'admin', 'adminLvl', 'adminLevel', 'admin_level' }
Config.AdminDutyColumn = 'aduty'
Config.RequireAduty = true
```

Daca baza ta are `users.admin`, scriptul il detecteaza automat.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_tickets
```

Dupa inlocuire:

```cfg
restart driftzone_tickets
```

## Comenzi

```txt
/ticket
/tickets
/tikcet
/cancelticket
```

## Pentru driftzone_chat custom

```lua
ticket = 'driftzone_tickets',
tickets = 'driftzone_tickets',
tikcet = 'driftzone_tickets',
cancelticket = 'driftzone_tickets',
```

sau:

```lua
exports.driftzone_tickets:RunCommand(src, command)
```
