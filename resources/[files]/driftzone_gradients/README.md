# driftzone_gradients

Sistem DriftZone pentru aplicarea vopselelor chameleon/gradient reale pe vehicule.

## Fix inclus

- /gradient functioneaza din nou.
- A fost reparat client/main.lua, unde ramasese cod vechi RGB dupa functia chameleon si putea strica incarcarea clientului.
- Foloseste doar `users.admin_level`, nu `users.admin`.
- Include fisierele din chameleonpaint: `carcols_gen9.meta`, `carmodcols_gen9.meta`, `carmodcols.ymt`, `vehicle_paint_ramps.ytd`.
- Salveaza in `ownedvehicles.gradient`.
- Loguri in `gradient_logs`.

## Instalare

```cfg
sv_enforceGameBuild 2699
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gradients
```

Ruleaza `SQL.sql`, apoi restart complet la server daca ai schimbat game build-ul.

## Comanda admin

```txt
/gradient 1
/gradient 10
/gradient 16
```

Comanda este pentru admin 6+ cu aduty yes.

## Item inventory

Itemele raman de forma:

```txt
1_gradient
2_gradient
16_gradient
```

Trigger client:

```lua
TriggerEvent('driftzone_gradients:client:useGradient', 1)
```

Export server:

```lua
exports.driftzone_gradients:OpenGradient(source, 1)
```


## Custom Blue Monochrome / Gradient 17
- Gradient ID 16 foloseste `vehicle_paint_ramps_16` si label `Blue Monochrome`.
- Gradient ID 17 foloseste `vehicle_paint_ramps_17`.
- Daca ai editat `.ytd` local, pastreaza `stream/vehicle_paint_ramps.ytd` cu texturile `vehicle_paint_ramps_16` si `vehicle_paint_ramps_17`.
- Comenzi test: `/gradient 16` si `/gradient 17`.
