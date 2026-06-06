# driftzone_tickets - Futuristic optimized UI

## Fix inclus

- Dupa ce un admin apasa **Accept**, meniul se inchide automat.
- Adminul este teleportat la player, ticket-ul este sters din queue si counter-ul se actualizeaza.
- Regula aduty ramane:
  - `users.aduty = 1` -> `/ticket` deschide staff panel
  - `users.aduty = 0` -> `/ticket` deschide ticket normal de player

## UI

- UI refacut complet, fullscreen, modern/futuristic.
- Admin panel cu search rapid dupa ID, UID, nume, titlu sau subiect.
- Player panel pentru creare ticket.
- Counter de tickets activ doar cand exista tickete pentru staff ON DUTY.
- JS optimizat: nu face loop-uri inutile, randeaza doar cand se primesc date sau cand cauti.

## Comenzi

```txt
/ticket
/tickets
/tikcet
/cancelticket
```

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_tickets
```

## driftzone_chat custom

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

## Instalare

1. Inlocuieste folderul vechi `driftzone_tickets` cu acesta.
2. Ruleaza:

```cfg
restart driftzone_tickets
```
