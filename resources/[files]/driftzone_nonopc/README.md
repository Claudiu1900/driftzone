# DriftZone No NPC / No OPC

Resource pentru dezactivarea NPC-urilor si curatarea celor care mai scapa.

## Ce face

- tine densitatea de NPC-uri la 0;
- tine densitatea de vehicule ambient la 0;
- dezactiveaza masinile parcate;
- dezactiveaza random cops;
- dezactiveaza dispatch/politie;
- tine wanted level la 0;
- opreste vehicle generators;
- opreste scenario types de politie/ambulanta/firetruck;
- sterge in loop NPC-uri ambient;
- sterge in loop vehicule ambient fara playeri.

## Important

Nu sterge vehicule cu playeri inauntru.
Nu sterge vehicule cu state bag de owned/server daca au chei ca `ownedVehicleId`, `sqlId`, `vehicle_id`, `vehicle_plate`, etc.
Nu sterge mission/script vehicles daca `SkipMissionVehicles = true`.

## Instalare

In `server.cfg`:

```cfg
ensure driftzone_nonopc
```

Merge si cu triggere vechi `driftzone_nonpc:*`, dar folderul este `driftzone_nonopc`.

## Triggere client

```lua
TriggerEvent('driftzone_nonopc:client:enable')
TriggerEvent('driftzone_nonopc:client:disable')
TriggerEvent('driftzone_nonopc:client:toggle')
```

## Exporturi client

```lua
exports.driftzone_nonopc:EnableNoNpc()
exports.driftzone_nonopc:DisableNoNpc()
local enabled = exports.driftzone_nonopc:IsNoNpcEnabled()
```

## Config important

Daca vrei mai agresiv:
```lua
Config.Cleanup.IntervalMs = 700
Config.Cleanup.VehicleNearPlayerProtection = 0.0
```

Daca sterge vreo masina custom, adauga state key-ul folosit de scriptul tau in:
```lua
Config.SafeVehicleStateKeys
```
