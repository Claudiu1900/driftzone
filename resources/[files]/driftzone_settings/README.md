# driftzone_settings v2

Settings fullscreen doar pentru:
- driftzone_hud
- driftzone_overheadstats
- radar/minimap

## Toggle-uri

```txt
DriftZone HUD
Radar / Minimap
Overhead Players
Overhead Personal
```

## Overhead corect

Conform `driftzone_overheadstats`:

```lua
TriggerEvent('driftzone_overheadstats:client:showAll')
TriggerEvent('driftzone_overheadstats:client:hideAll')

TriggerEvent('driftzone_overheadstats:client:showPersonal')
TriggerEvent('driftzone_overheadstats:client:hidePersonal')
```

## Radar/minimap

Cand radarul este OFF, resource-ul ruleaza loop si forteaza:

```lua
DisplayRadar(false)
SetRadarBigmapEnabled(false, false)
```

ca sa nu reapara cand intri in masina.

## server.cfg

```cfg
ensure driftzone_hud
ensure driftzone_overheadstats
ensure driftzone_settings
```

## Chat custom

Daca din F8 merge dar din chat nu:

```lua
settings = 'driftzone_settings',
```

sau:

```lua
exports.driftzone_settings:RunCommand(src, command, args)
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_settings
git commit -m "Fix settings toggles for hud overhead radar"
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
restart driftzone_settings
```
