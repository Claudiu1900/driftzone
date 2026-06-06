# driftzone_hud

HUD DriftZone cu suport pentru normal hide/show si HARD HIDE.

## Triggere normale
Acestea functioneaza doar daca HUD-ul nu este blocat cu hard hide:

```lua
TriggerEvent('driftzone_hud:client:show')
TriggerEvent('driftzone_hud:client:hide')
TriggerEvent('driftzone_hud:client:toggle')
TriggerEvent('driftzone_hud:visible', true)
TriggerEvent('driftzone_hud:visible', false)
```

## Hard hide
Cand hard hide este activ, niciun trigger vechi de show nu mai poate afisa HUD-ul.

```lua
TriggerEvent('driftzone_hud:client:lockHide')
TriggerEvent('driftzone_hud:client:setHardHidden', true)
```

Pentru deblocare:

```lua
TriggerEvent('driftzone_hud:client:unlockHide')
TriggerEvent('driftzone_hud:client:setHardHidden', false)
```

## Exporturi

```lua
exports['driftzone_hud']:LockHide()
exports['driftzone_hud']:UnlockHide()
exports['driftzone_hud']:SetHardHidden(true)
exports['driftzone_hud']:SetHardHidden(false)
```

## Important
Hard hide se salveaza in KVP, deci ramane activ si dupa restart resource pana cand este dezactivat din settings sau cu `unlockHide`.
