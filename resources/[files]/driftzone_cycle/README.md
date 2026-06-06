# DriftZone Cycle - Admin Access Fix Final

## Fix

Versiunea asta foloseste explicit:

```txt
users.admin_level
users.aduty
```

si are fallback-uri mai bune pentru UID:

```txt
Player state: dz_uid, uid, user_id, userId
exports driftzone_auth: GetUID/GetUid/getUID/getUid/GetUserId/getUserId
identifiers: license/discord/steam/fivem/username daca exista coloane in users
```

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

sau apeleaza:

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
git commit -m "Fix cycle admin uid access"
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
