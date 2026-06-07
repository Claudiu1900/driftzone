# driftzone_racejob

Race Job standalone pentru DriftZone.

## Include

- Short Race, Medium Race, Long Race.
- Doar checkpoint-ul de finish.
- Route/blip doar catre finish.
- Dimensiune privata/routing bucket pentru fiecare jucator in cursa.
- Cooldown per cursa configurabil in `config.lua`.
- Timer pe UI in format `m:ss`.
- Countdown mare pe ecran: `3`, `2`, `1`, `START`.
- Masini luate din `ownedvehicles` dupa `owner_id = uid`.
- Spawn cu tuning din `ownedvehicles.vehicle_tunning`.
- La final/fail: DV la masina, teleport inapoi si bucket 0.
- La success: cash + `users.races = users.races + 1`.

## SQL

Ruleaza `sql.sql`:

```sql
ALTER TABLE `users`
  MODIFY COLUMN `cash` BIGINT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `races` INT UNSIGNED NOT NULL DEFAULT 0;
```

## Interaction

Adauga continutul din `driftzone_interactions_config_add.lua` in `Config.DefaultInteractions` din `driftzone_interactions/config.lua`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_garage
ensure driftzone_racejob
```

## Test

```txt
/racejob
```
