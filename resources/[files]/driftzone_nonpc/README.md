# DriftZone No NPC

Resource curat pentru dezactivarea NPC-urilor/masinilor default GTA fara loop agresiv de delete.

## Ce face

- dezactiveaza spawn-ul de NPC-uri;
- dezactiveaza scenario peds;
- dezactiveaza trafic random;
- dezactiveaza masini parcate;
- dezactiveaza garbage trucks;
- dezactiveaza random boats;
- dezactiveaza random cops;
- dezactiveaza dispatch/politie;
- tine wanted level la 0;
- opreste vehicle generators;
- nu mai foloseste ClearArea in loop.

## Instalare

In `server.cfg`:

```cfg
ensure driftzone_nonpc
```

Daca inainte aveai `driftzone_nonopc`, inlocuieste cu `driftzone_nonpc`.

## Triggere client

```lua
TriggerEvent('driftzone_nonpc:client:enable')
TriggerEvent('driftzone_nonpc:client:disable')
TriggerEvent('driftzone_nonpc:client:toggle')
```

Are si alias pentru numele vechi:

```lua
TriggerEvent('driftzone_nonopc:client:enable')
TriggerEvent('driftzone_nonopc:client:disable')
TriggerEvent('driftzone_nonopc:client:toggle')
```

## Exporturi client

```lua
exports.driftzone_nonpc:EnableNoNpc()
exports.driftzone_nonpc:DisableNoNpc()
local enabled = exports.driftzone_nonpc:IsNoNpcEnabled()
```

## Important

`Config.ClearExistingOnStart = false` ca sa nu stearga vehicule/NPC-uri in loop. Daca vezi NPC-uri deja spawnate dupa restart, ele dispar natural dupa ce jocul nu mai primeste densitate/spawnuri noi.
