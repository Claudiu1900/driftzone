# DriftZone No NPC

Scoate NPC-urile default GTA, traficul default, masinile parcate, politia random si dispatch services.

## Instalare

In `server.cfg`:

```cfg
ensure driftzone_nonopc
```

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

Nu sterge vehiculele/jucatorii create de server, doar ambient/default GTA.
