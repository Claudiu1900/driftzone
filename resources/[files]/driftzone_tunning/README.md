# driftzone_tunning

Versiune finală optimizată pentru DriftZone.

## Fixuri importante

- Prețurile sunt calculate server-side ca în prima variantă: `vehiclenames.price` + procentele din `Config.PricePercent`.
- Cash-ul afișat vine din `users.cash` prin server.
- Tuning-ul cumpărat se salvează în `ownedvehicles.vehicle_tunning`.
- Gradientele sunt doar preview: nu intră în coș, nu se cumpără și nu se salvează în DB.
- Dacă ai avut preview de gradient și cumperi alt tuning, gradientul este curățat înainte de cumpărare și după confirmare.
- Mașina primește freeze cât e meniul deschis.
- Open Wheel este scos.
- În meniul principal apare doar `Wheels`, apoi alegi subcategoria.
- UI nou, fără `backdrop-filter`.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_tunning
```

Dacă nu ai rulat SQL-ul:

```txt
driftzone_tunning/SQL.sql
```

## Comenzi

```txt
/tuning
/tune
/tunning
```

`/tunning` este pentru admin conform configului.
