# driftzone_admin V3

Resource complet pentru admin commands + UI.

## Nou

- `/ah` - admin help UI, admin_level 1+ si aduty yes/1.
- `/ap` - admin panel UI, admin_level 6+ si aduty yes/1.
- `/freeze uid` - blocheaza playerul, admin_level 3+.
- `/unfreeze uid` - deblocheaza playerul, admin_level 3+.
- `/spectate uid` - spectate toggle, admin_level 5+.
- `/mark` - salveaza pozitia adminului local, admin_level 1+.
- `/gotomark` - teleport la pozitia salvata, admin_level 1+.

## Admin Panel

Categoriile sunt configurabile in `config.lua`:

- System
- Teleport
- Punish
- Tools
- Vehicles
- Give / Economy

Panelul arata doar comenzile la care gradul tau are acces si permite rularea lor direct din UI.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_admin
```

Ruleaza o data:

```sql
SQL.sql
```

Apoi:

```cfg
restart driftzone_admin
```

## Note

- Toate comenzile importante verifica `admin_level` si `aduty` pe server.
- `/aduty` si `/staff` merg fara sa fii deja aduty.
- UI-ul nu foloseste `backdrop-filter` si este facut light pentru NUI.
- Daca unele coloane optionale nu exista, scriptul evita update-ul unde poate si anunta in notify.

## Update chat commands

- `/mute uid minute motiv` - admin_level 2+ si aduty yes/1.
- `/unmute uid` - admin_level 3+ si aduty yes/1.
- `/lockchat` - admin_level 5+ si aduty yes/1.
- `/unlockchat` - admin_level 6+ si aduty yes/1.
- `/lockveh` si `/unlockveh` trimit live state catre `driftzone_vehicleconfig`.
- `/ah` si `/ap` au fix de pozitionare pe mijlocul ecranului.

Ordine recomandata in server.cfg:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_chat
ensure driftzone_vehicleconfig
ensure driftzone_admin
```

## Chat mute

`/mute` si `/unmute` folosesc exporturile din `driftzone_chat`; mute-ul este salvat in `users.mute`.


## Fix chat commands

`/mute`, `/unmute`, `/lockchat`, `/unlockchat` folosesc exporturile din `driftzone_chat`. Pune `ensure driftzone_chat` inainte de `ensure driftzone_admin`.
