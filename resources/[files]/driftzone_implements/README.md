# DriftZone Implements - Clean

## v2.8.0 - Crosshair Aim Only

Resource curat si optimizat pentru server.

## Fix nou

- crosshair-ul apare doar cand playerul tine arma indreptata / apasa aim;
- nu mai apare doar pentru ca arma este in mana;
- `ForceCrosshair = true`;
- `CrosshairOnlyWhileAiming = true`;
- HUD component `14` nu mai este ascuns din config.

## Face:

- activeaza damage intre playeri;
- poti trage in alti playeri;
- poti da damage cu pumni / melee;
- activeaza friendly fire;
- reseteaza `users.aduty = 0` cand porneste resource-ul/serverul;
- reseteaza `users.aduty = 0` cand intra un player;
- ascunde HUD-ul default GTA, dar nu omoara crosshair-ul;
- dezactiveaza weapon wheel-ul;
- dezactiveaza radio/music wheel-ul in masina;
- opreste radio-ul masinii automat;
- blocheaza scosul soferului din masina prin animatia de carjack cand tii F;
- blocheaza trasul din masina / drive-by;
- dezactiveaza stealth mode-ul GTA;
- CTRL pune playerul pe crouch custom;
- dezactiveaza camera AFK / idle cinematic camera.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_implements
```
