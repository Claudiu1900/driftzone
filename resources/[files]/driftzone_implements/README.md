# DriftZone Implements - Clean

Resource curat si optimizat pentru server.

## Face doar:

- reseteaza `users.aduty = 0` cand porneste resource-ul/serverul;
- reseteaza `users.aduty = 0` cand intra un player;
- ascunde HUD-ul default GTA;
- dezactiveaza weapon wheel-ul;
- dezactiveaza radio/music wheel-ul in masina;
- opreste radio-ul masinii automat;
- blocheaza scosul soferului din masina prin animatia de carjack cand tii F;
- blocheaza trasul din masina / drive-by.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_implements
```

Nu are NUI, nu are `runtime_module.js`, nu are godmode, nu are no-ragdoll, nu are infinite stamina, nu are hat lock.
