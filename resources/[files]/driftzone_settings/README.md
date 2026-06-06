# driftzone_settings

Fullscreen futuristic settings UI pentru DriftZone.

## Comanda

```txt
/settings
```

## Toggle-uri incluse

- HUD
- Minimap
- Tickets Counter
- Turometru / Speedometer
- Vehicle Stats
- Voice UI
- Overhead Stats
- Overhead Names
- Overhead IDs
- Overhead Admin Badge
- Overhead Health / Armor
- Notifications

## Cum functioneaza

Setarile sunt salvate local cu KVP pe fiecare client.

Resource-ul trimite eventuri/exports catre sistemele deja existente:

```lua
driftzone_hud
driftzone_overheadstats
driftzone_turometru
driftzone_vs
driftzone_voicechat
driftzone_tickets
driftzone_notifications
```

Pentru integrare extra, alte resource-uri pot asculta:

```lua
AddEventHandler('driftzone_settings:client:changed', function(id, value)
    -- id = toggle id
    -- value = true/false
end)
```

Sau pot citi state bag:

```lua
LocalPlayer.state['settings:hud']
LocalPlayer.state['settings:overhead']
```

## server.cfg

```cfg
ensure driftzone_settings
```

Recomandat dupa HUD/voice/overhead:

```cfg
ensure driftzone_hud
ensure driftzone_overheadstats
ensure driftzone_voicechat
ensure driftzone_turometru
ensure driftzone_vs
ensure driftzone_tickets
ensure driftzone_settings
```

## Pentru driftzone_chat custom

Daca din F8 merge, dar din chat nu merge:

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
git commit -m "Add fullscreen settings menu"
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
ensure driftzone_settings
```

sau:

```txt
restart driftzone_settings
```
