# driftzone_settings - Voice Volume UI Toggle

Settings fullscreen pentru:
- driftzone_hud
- radar/minimap
- driftzone_overheadstats
- driftzone_turometru
- voice chat volume UI

## Toggle nou

```txt
Voice Volume UI
```

Cand este ON:

```lua
TriggerEvent('driftzone_voicechat:client:showVolumeUi')
exports['driftzone_voicechat']:ShowVolumeUi()
```

Cand este OFF:

```lua
TriggerEvent('driftzone_voicechat:client:hideVolumeUi')
exports['driftzone_voicechat']:HideVolumeUi()
```

## server.cfg recomandat

```cfg
ensure driftzone_hud
ensure driftzone_overheadstats
ensure driftzone_turometru
ensure driftzone_voicechat
ensure driftzone_settings
```

## Comanda

```txt
/settings
```
