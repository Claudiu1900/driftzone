# driftzone_hud

HUD DriftZone cu sistem normal show/hide si sistem hard hide.

## Triggere normale

```lua
TriggerEvent('driftzone_hud:client:show')
TriggerEvent('driftzone_hud:client:hide')
TriggerEvent('driftzone_hud:client:toggle')
TriggerEvent('driftzone_hud:visible', true)
TriggerEvent('driftzone_hud:visible', false)
```

## Hard hide

Cand hard hide este activ, orice trigger normal de show nu mai poate afisa HUD-ul.

```lua
TriggerEvent('driftzone_hud:client:lockHide')
TriggerEvent('driftzone_hud:client:unlockHide')
```

Compatibil:

```lua
TriggerEvent('driftzone_hud:client:forceHide')
TriggerEvent('driftzone_hud:client:forceShow')
TriggerEvent('driftzone_hud:client:hardHide')
TriggerEvent('driftzone_hud:client:hardShow')
TriggerEvent('driftzone_hud:client:setHardHidden', true)
TriggerEvent('driftzone_hud:client:setHardHidden', false)
```

## Exports

```lua
exports['driftzone_hud']:LockHide()
exports['driftzone_hud']:UnlockHide()
exports['driftzone_hud']:SetHardHidden(true)
exports['driftzone_hud']:SetHardHidden(false)
```
