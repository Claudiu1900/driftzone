# driftzone_admin

## Nou

- `/addveh` deschide UI-ul nou pentru adăugat mașini în `vehiclenames`.
- `/configveh` admin_level 6 + aduty yes: listă cu toate mașinile din `vehiclenames`, edit + delete.
- `/vehs uid` admin_level 6 + aduty yes: listă cu toate mașinile deținute de UID, merge și dacă playerul este offline.
- În `/vehs` apar: poza, plate, SQL ID, vehicle name, model, gradient ID, status spawned, Net ID și VS ID dacă există.
- Butoane `/vehs`: TAKE cu confirmare, TRANSFER cu UID nou, SPAWN, GO TO, BRING.
- Dacă mașina este deja spawnată și apeși SPAWN, o aduce la admin în loc să creeze dublură.

## Instalare

Rulează o dată:

```sql
-- driftzone_admin/SQL.sql
```

Apoi:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_admin
```

Restart:

```cfg
restart driftzone_admin
```
