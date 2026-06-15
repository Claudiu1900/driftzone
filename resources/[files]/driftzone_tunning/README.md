# driftzone_tunning

Versiune optimizată pentru DriftZone.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_tunning
```

Rulează `SQL.sql` dacă nu ai coloana `vehiclenames.tunable` și tabela `tunning_logs`.

## Ce include

- UI nou, dark, premium, cu colțuri mici.
- SVG-uri locale pentru categorii: Colors, Gradient, Body, Performance, Wheels, Interior, Visual, Lights, Engine Bay, Extras.
- Mașina primește freeze când intri în tuning și revine normal când ieși.
- Preview-ul de gradient este doar preview: nu intră în coș, nu se cumpără, nu rămâne pe mașină când cumperi alt tuning.
- Open Wheel este scos din roți.
- În meniul principal apare o singură categorie `Wheels`; după selectare alegi Sport/Muscle/Tuner/Street/Track etc.
- Fără `vendor/beta_module.js` și fără fișiere obfuscate.
- Optimizări: preview throttled, categorii mapate local, doar tuning-uri reale detectate pe vehicul.

## Comenzi

```txt
/tuning
/tune
/tunning
```

`/tunning` este admin mode și respectă:

```lua
Config.AdminMinLevel = 6
Config.AdminDutyRequired = true
```

## Important

Dacă o piesă nu apare pe o mașină add-on, înseamnă că mașina nu expune piesa corect prin modkit/carcols/carvariations. Scriptul nu inventează tuning-uri fake.
