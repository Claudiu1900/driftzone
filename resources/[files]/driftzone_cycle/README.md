# DriftZone Cycle

Sincronizeaza ora din joc cu ora reala din Romania si vremea cu Mangalia, Constanta.

## Comenzi globale

```txt
/synctime
```

Forteaza sincronizarea orei si vremii pentru server.

## Comenzi admin locale

Necesita:

```txt
admin_level 6+
aduty yes
```

```txt
/time 20:23
```

Seteaza si ingheata ora doar pentru adminul care foloseste comanda.

```txt
/weather EXTRASUNNY
```

Seteaza si ingheata vremea doar pentru adminul care foloseste comanda.

```txt
/resetcycle
```

Sterge override-ul local si readuce adminul la cycle-ul normal al serverului.

Accepta si typo-ul:

```txt
/resetcylce
```

## Weather acceptat

```txt
EXTRASUNNY
CLEAR
CLOUDS
SMOG
FOGGY
OVERCAST
RAIN
THUNDER
CLEARING
NEUTRAL
SNOW
BLIZZARD
SNOWLIGHT
XMAS
HALLOWEEN
```

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

## Instalare

Pune folderul in:

```txt
resources/[files]/driftzone_cycle
```

In `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_cycle
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_cycle
git commit -m "Add admin local time and weather overrides"
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
