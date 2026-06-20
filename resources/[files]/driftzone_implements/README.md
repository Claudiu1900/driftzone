# DriftZone Implements - Clean

## v2.4.0 Final

Resource curat si optimizat pentru server.

## Face:

- reseteaza `users.aduty = 0` cand porneste resource-ul/serverul;
- reseteaza `users.aduty = 0` cand intra un player;
- ascunde HUD-ul default GTA;
- dezactiveaza weapon wheel-ul;
- dezactiveaza radio/music wheel-ul in masina;
- opreste radio-ul masinii automat;
- blocheaza scosul soferului din masina prin animatia de carjack cand tii F;
- blocheaza trasul din masina / drive-by;
- dezactiveaza stealth mode-ul GTA;
- CTRL este prins direct si pune playerul pe crouch custom;
- stealth/action mode este fortat OFF constant;
- dezactiveaza camera AFK / idle cinematic camera;
- cand intra un player, incarca `health` si `armour` din `users.stats`.

## users.stats

Exemplu:

```json
{"health": 100, "armour": 0, "food": 61, "water": 81}
```

Resource-ul citeste doar:
- `health`
- `armour`

`health = 100` inseamna full HP in GTA.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_implements
```

Nu are NUI, nu are comenzi de test, nu are `runtime_module.js`, nu are godmode, nu are no-ragdoll, nu are infinite stamina, nu are hat lock.
