# DriftZone Implements - Clean

## v2.7.0 - Crosshair Fixed

Resource curat si optimizat pentru server.

## Fix nou

- crosshair-ul / reticle-ul apare din nou când ții arma;
- am scos HUD component `14` din lista ascunsă;
- am adăugat `ForceCrosshair = true`;
- crosshair-ul este forțat într-un thread separat la `0ms`, ca să nu fie ascuns de alte UI-uri.

## Face:

- activeaza damage intre playeri;
- poti trage in alti playeri;
- poti da damage cu pumni / melee;
- activeaza friendly fire;
- reseteaza `users.aduty = 0` cand porneste resource-ul/serverul;
- reseteaza `users.aduty = 0` cand intra un player;
- ascunde HUD-ul default GTA, dar NU mai ascunde reticle-ul;
- dezactiveaza weapon wheel-ul;
- dezactiveaza radio/music wheel-ul in masina;
- opreste radio-ul masinii automat;
- blocheaza scosul soferului din masina prin animatia de carjack cand tii F;
- blocheaza trasul din masina / drive-by;
- dezactiveaza stealth mode-ul GTA;
- CTRL pune playerul pe crouch custom;
- dezactiveaza camera AFK / idle cinematic camera.

## Important

Drive-by ramane blocat.
PvP normal pe jos ramane activ.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_implements
```
