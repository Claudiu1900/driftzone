# DriftZone Cycle - Final Admin Fix

## Ce s-a reparat

Versiunea asta NU mai foloseste `SHOW COLUMNS`.
Foloseste direct coloanele tale:

```txt
users.uid
users.admin_level
users.aduty
```

Asta repara eroarea falsa cu `nu exista users.admin_level`.

## Comenzi admin locale

Necesita:

```txt
users.admin_level >= 6
users.aduty = yes / true / 1
```

```txt
/time 20:23
/weather EXTRASUNNY
/resetcycle
/resetcylce
```

Override-ul este doar pentru adminul care foloseste comanda. Restul serverului ramane in cycle normal.

## Pentru driftzone_chat custom

Daca din F8 merge dar din chat nu merge, adauga ruta:

```lua
time = 'driftzone_cycle',
weather = 'driftzone_cycle',
resetcycle = 'driftzone_cycle',
resetcylce = 'driftzone_cycle',
```

sau:

```lua
exports.driftzone_cycle:RunCommand(src, command, args)
```

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_cycle
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_cycle
git commit -m "Fix cycle admin direct columns"
git pull --rebase origin main
git push origin main
```

Pe VPS:

```bash
cd ~/server-data
git pull --rebase origin main
```

txAdmin:

```txt
restart driftzone_cycle
```
