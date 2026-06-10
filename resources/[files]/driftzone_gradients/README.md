# driftzone_gradients

Sistem DriftZone pentru chameleon paint real pe vehicule.

## Ce este schimbat

Aceasta versiune include fisierele din `chameleonpaint-main`:

- `data/carcols_gen9.meta`
- `data/carmodcols_gen9.meta`
- `data/carmodcols.ymt`
- `stream/vehicle_paint_ramps.ytd`

Fara aceste fisiere, culorile chameleon apar negru/gri sau culoare simpla.

## Important server.cfg

Pentru chameleon trebuie game build nou:

```cfg
sv_enforceGameBuild 2699
```

Dupa modificare fa restart complet la server, nu doar restart la resource.

## Folosire admin

```txt
/gradient id
```

Necesita admin 6+ si aduty yes. Adminul poate aplica pe orice masina.

## Folosire din item

Item pentru gradient ID 5:

```txt
5_gradient
```

Trigger client:

```lua
TriggerEvent('driftzone_gradients:client:useGradient', 5)
```

Server export:

```lua
exports.driftzone_gradients:OpenGradient(source, 5)
```

La item/trigger masina trebuie sa fie personala si itemul se sterge doar dupa aplicare reusita.

## Gradiente reale incluse

ID 1-16 sunt chameleon paint reale din chameleonpaint:

1 Monochrome, 2 Night & Day, 3 The Verlierer, 4 Sprunk Extreme, 5 Vice City, 6 Synthwave Nights, 7 Four Seasons, 8 Maisonette 9 Throwback, 9 Bubblegum, 10 Full Rainbow, 11 Sunset, 12 The Seven, 13 Kamen Rider, 14 Chromatic Aberration, 15 Its Christmas!, 16 Temperature.

## SQL

Ruleaza `SQL.sql`.
