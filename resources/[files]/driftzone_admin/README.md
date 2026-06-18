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


## Fix lockveh / unlockveh

- `/lockveh sql_id` si `/unlockveh sql_id` verifica daca masina exista in `ownedvehicles`.
- Actualizeaza `ownedvehicles.locked` daca exista coloana.
- Trimite state-ul live catre `driftzone_vehicleconfig` prin export/event `SetVehicleLockBySqlId`.
- Daca masina este spawnata, se aplica imediat pe vehicul.
- Daca masina este offline, state-ul ramane in DB si in cache-ul `driftzone_vehicleconfig`.
- Pentru integrare corecta pune in `server.cfg`:

```cfg
ensure driftzone_vehicleconfig
ensure driftzone_admin
```
