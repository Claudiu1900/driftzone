# DriftZone Stats

Sistem FiveM + oxmysql pentru meniul de statistici. Varianta old-style, fara keybind F7.

## Instalare

1. Pune folderul `driftzone_stats` in `resources/[driftzone]/`.
2. Pune `logo.png` in `driftzone_stats/html/logo.png`.
3. Ruleaza `SQL.sql` in baza `driftzone`.
4. Adauga in `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_stats
```

## Comenzi

```txt
/stats
/statistici
/stats (id)        - admin 6+ si aduty yes
/statistici (id)   - admin 6+ si aduty yes
```

`id` poate fi server ID sau UID.

## Chat custom

Daca `driftzone_chat` inghite comenzile, adauga `stats` si `statistici` catre export:

```lua
exports.driftzone_stats:RunCommand(src, command, args or {})
```

## Database

Foloseste coloanele din `users`:

- `Rank`
- `rankcolor`
- `xp`
- `playtime`
- `created_at`
- `cash`
- `dzcoins`
- `admin_level`
- `aduty`

Playtime este in minute si creste automat cu +1 la fiecare minut pentru jucatorii logati.
