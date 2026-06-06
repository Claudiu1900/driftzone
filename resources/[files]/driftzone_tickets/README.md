# driftzone_tickets

## Inclus

- /ticket deschide staff panel doar cand adminul are `users.aduty = 1`.
- /ticket deschide player ticket panel cand adminul are `users.aduty = 0`.
- Dupa Accept, meniul se inchide automat.
- Cardul/stanga "DriftZone Ticket Matrix" este scos complet.
- Formularul Create Ticket este intins pe toata latimea panelului.
- Loguri SQL in `ticket_logs` pentru create / accept / delete / cancel / delete_offline.
- La fiecare ticket acceptat, adminul primeste `users.tickets = users.tickets + 1`.

## SQL

Ruleaza fisierul:

```sql
source sql.sql;
```

sau copiaza continutul din `sql.sql` in consola MySQL/phpMyAdmin/HeidiSQL.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_tickets
```

## Comenzi

```txt
/ticket
/tickets
/tikcet
/cancelticket
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

## Log actions

```txt
created
accepted
deleted
cancelled
deleted_offline
```
