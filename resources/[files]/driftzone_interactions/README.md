# driftzone_implements

Sistem optimizat de interacțiuni locale pentru DriftZone.

## Ce face

- prompt modern jos pe ecran;
- marker/blip local;
- waypoint personal doar pentru jucătorul care primește eventul;
- compatibil cu eventurile vechi `driftzone_interactions:*`;
- compatibil și cu `driftzone_implements:*`;
- fără fișiere obfuscate `v2_settings.js` / `commands.js` în manifest.

## Event local / client

```lua
TriggerEvent('driftzone_interactions:client:addPersonalWaypoint', {
    id = 'test_location',
    coords = { x = 0.0, y = 0.0, z = 72.0 },
    text = 'Apasă E',
    subText = 'Test local',
    event = 'my_resource:client:event',
    data = { hello = true },
    setWaypoint = true,
    marker = true
})
```

Dacă îl trimiți de pe server cu `TriggerClientEvent` către un singur player, se vede doar la acel player.

## server.cfg

```cfg
ensure driftzone_implements
```
