# driftzone_tickets

Sistem de tickete pentru FiveM + oxmysql.

## Comenzi

- `/ticket` - playerii creează ticket, adminii ON DUTY văd lista.
- `/tickets` - alias pentru admin panel.
- `/cancelticket` - playerul își anulează ticketul activ.

## Permisiuni

Verifică în `users`:

- `uid`
- `admin_level`
- `aduty`

Setările se pot schimba în `config.lua`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_tickets
```

Dacă folosești chat custom și comenzile nu ajung, trimite comenzile `ticket`, `tickets`, `cancelticket` către exportul:

```lua
exports.driftzone_tickets:RunCommand(src, command)
```
