# driftzone_gradients

Sistem DriftZone pentru aplicarea si scoaterea vopselelor chameleon/gradient reale pe vehicule.

## Nou

- Item/comanda `takegradient` pentru scoaterea gradientului.
- Cand folosesti `takegradient`, selectezi masina exact ca la aplicare.
- Dupa selectare apare UI cu `Scoate gradient`.
- Apar doar partile care au gradient:
  - `Culoare Principala` doar daca primary are gradient;
  - `Culoare Secundara` doar daca secondary are gradient;
  - `Ambele` doar daca exista pe ambele.
- La confirmare:
  - scoate itemul `takegradient` din inventar;
  - sterge gradientul de pe masina;
  - da inapoi itemul gradientului, de exemplu `17_gradient`;
  - actualizeaza `ownedvehicles.gradient`;
  - adauga log in `gradient_logs` cu `mode = remove`.

## Comenzi

```txt
/gradient 17
/takegradient
```

## Trigger / export pentru inventory

Daca vrei sa porneasca direct cand folosesti itemul din inventory:

```lua
TriggerServerEvent('driftzone_gradients:server:useTakeGradient')
```

sau server-side:

```lua
exports.driftzone_gradients:OpenTakeGradient(source)
```

Pentru gradient normal ramane:

```lua
exports.driftzone_gradients:OpenGradient(source, 17)
```

## Instalare

```cfg
sv_enforceGameBuild 2699
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gradients
```

Ruleaza `SQL.sql`, apoi restart la resource.
