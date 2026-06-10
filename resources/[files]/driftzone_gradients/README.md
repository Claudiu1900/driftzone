# driftzone_gradients

Sistem DriftZone pentru chameleon/gradient paint.

## Important

Chameleon real nu este RGB. Scriptul foloseste `SetVehicleColours` cu colorId-uri chameleon GTA/FiveM, de la `161` la `222`.

Daca apare negru/gri, nu este bug de UI: serverul trebuie sa ruleze game build compatibil. Pune in `server.cfg`:

```cfg
sv_enforceGameBuild 2699
```

Dupa asta trebuie restart complet la server, nu doar restart la resource.

## Comanda admin

```txt
/gradient id
```

Valabil admin 6+ cu aduty yes.

## Iteme inventory

Itemul pentru gradient ID 25 trebuie sa fie:

```txt
25_gradient
```

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gradients
```

Ruleaza `SQL.sql`, apoi:

```cfg
restart driftzone_gradients
```
