# DriftZone Implements

Resource FiveM client-side pentru:

- ascundere HUD GTA default inutil;
- ascunde barele default de viata/armura de sub harta, dar lasa minimap-ul;
- dezactivare weapon wheel;
- dezactivare radio/music wheel cand esti in masina;
- godmode/no ragdoll/infinite stamina;
- palaria/casca ramane mereu pe cap si este reaplicata daca GTA o scoate la vehicul/impact/animatii.

## Instalare

Pune folderul in:

```txt
resources/[driftzone]/driftzone_implements
```

In `server.cfg`:

```cfg
ensure driftzone_implements
```

## Ce a fost adaugat

- Disable la meniul de muzica/radio din masina.
- Blocheaza controlurile:
  - 85 radio wheel;
  - 81/82 radio next/prev;
  - 83/84 radio track next/prev.
- Forteaza radio OFF in masina.
- Ascunde HUD-ul default de viata/armura de sub harta unde build-ul permite, fara sa ascunda minimap-ul.
- Optimizare:
  - safeCall redus in loop-ul principal;
  - godmode/stamina flags grele sunt reaplicate throttled;
  - stamina ramane refacuta constant;
  - hat system ramane separat la intervalul lui.

## Export-uri client-side

```lua
exports.driftzone_implements:RefreshHat()
exports.driftzone_implements:SetHatLock(true)
exports.driftzone_implements:SetGodMode(true)
exports.driftzone_implements:SetHudClean(true)
exports.driftzone_implements:SetWeaponWheelDisabled(true)
exports.driftzone_implements:SetVehicleMusicWheelDisabled(true)
exports.driftzone_implements:SetHealthArmorHudHidden(true)
```

## Event-uri client-side

```lua
TriggerEvent('driftzone_implements:client:refreshHat')
TriggerEvent('driftzone_implements:client:setHatLock', true)
TriggerEvent('driftzone_implements:client:setVehicleMusicWheelDisabled', true)
TriggerEvent('driftzone_implements:client:setHealthArmorHudHidden', true)
```

Dupa ce schimbi palaria prin clothes/outfits, poti chema:

```lua
TriggerEvent('driftzone_implements:client:refreshHat')
```

ca sistemul sa memoreze noua palarie/casca.
