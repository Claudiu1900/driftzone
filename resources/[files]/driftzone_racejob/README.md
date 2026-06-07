# driftzone_racejob

Race Job standalone pentru DriftZone.

## Fixuri in aceasta versiune

- Masina nu mai este spawnata server-side, ci client-side dupa ce playerul intra in bucket privat. Asta rezolva bug-ul `Masina cursei nu a fost gasita`.
- Cooldown-ul este persistent prin KVP server-side si sincronizat in localStorage in UI.
- Comanda `/rracecd <id>` reseteaza cooldown-ul la race pentru playerul respectiv.
- Tuning-ul din `ownedvehicles.vehicle_tunning` se aplica de mai multe ori dupa spawn.
- Doar checkpoint-ul de finish este creat.
- Playerul ruleaza cursa in dimensiune privata.

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

## Comenzi

```txt
/racejob
/rracecd <id>
```
