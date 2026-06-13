# driftzone_vehicless v9

Fix pentru screenshot:
- fara requestClientScreenshot pe server;
- fara HTTP upload din screenshot-basic;
- foloseste `exports['screenshot-basic']:requestScreenshot` pe client;
- upload pe server in chunk-uri mici, cu delay, ca sa nu dea `Reliable network event size overflow`.

## server.cfg

```cfg
ensure screenshot-basic
ensure driftzone_vehicless
```

Nu porni `yarn` si `webpack`; screenshot-basic din pachet este client-only si are dist-ul inclus.

## Salvare poze

```txt
driftzone_vehicless/screenshots/model_name.jpg
```

## Comanda

```txt
/vehss s15
```
