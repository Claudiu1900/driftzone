# driftzone_gradients

Sistem DriftZone pentru aplicarea si scoaterea vopselelor chameleon/gradient reale pe vehicule.

## Update nou

- `takegradient` nu mai intreaba primary / secondary / ambele.
- Cand folosesti itemul/comanda `takegradient`, selectezi masina si apare un singur buton: `Scoate gradient`.
- Scoate automat gradientul complet de pe masina, adica primary + secondary.
- Daca masina are acelasi gradient pe ambele culori, primesti inapoi un singur item, de exemplu `17_gradient`.
- Daca masina are gradient diferit pe primary si secondary, primesti inapoi ambele iteme.
- Sageata/markerul de selectie este coborat mai aproape de masina.
- Scoate itemul `takegradient` doar dupa confirmare si dupa ce masina are gradient valid.
- Actualizeaza `ownedvehicles.gradient` si adauga log in `gradient_logs` cu `mode = remove`.

## Comenzi

```txt
/gradient 17
/takegradient
```

## Trigger / export pentru inventory

```lua
TriggerServerEvent('driftzone_gradients:server:useTakeGradient')
```

sau server-side:

```lua
exports.driftzone_gradients:OpenTakeGradient(source)
```

Pentru gradient normal:

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
