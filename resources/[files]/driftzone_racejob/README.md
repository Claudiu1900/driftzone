# driftzone_racejob

Race Job pentru DriftZone.

## Ce include

- Short / Medium / Long Race din `config.lua`.
- Cooldown persistent si reset cu `/rracecd <id>`.
- Meniu NUI pentru selectie cursa + masina.
- Masini luate din `ownedvehicles` dupa `owner_id = uid`.
- Tuning aplicat din `ownedvehicles.vehicle_tunning`.
- Dimensiune privata in timpul cursei.
- Finish checkpoint + route pe harta.
- Timer mic langa minimap.
- Countdown 3 / 2 / 1 / START.
- Daca jucatorul se da jos din masina in timpul cursei, pierde cursa.
- La finish/fail masina este stearsa si jucatorul este teleportat inapoi.
- La finish primeste cash si `users.races + 1`.

## SQL

Ruleaza `sql.sql`.

```sql
ALTER TABLE `users`
  MODIFY COLUMN `cash` BIGINT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `races` INT UNSIGNED NOT NULL DEFAULT 0;
```

## driftzone_interactions

Adauga in `Config.DefaultInteractions`:

```lua
{
    id = 'driftzone_racejob_main',
    coords = vector3(-116.835160, -604.720886, 36.272584),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Job',
    subText = 'DriftZone Race Job',
    marker = true,
    event = 'driftzone_racejob:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Race Job' }
},
```

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_garage
ensure driftzone_racejob
```

Dupa update:

```cfg
restart driftzone_racejob
```
