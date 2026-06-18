# DriftZone Chat Optimized

## Ce face

- Ruleaza comenzile din chat ca in F8, prin `ExecuteCommand` pe client.
- Nu mai trebuie sa pui fiecare comanda manual in config pentru comenzile client-side.
- Mute-ul este salvat direct in `users.mute`, nu intr-un tabel separat.
- Motivul si adminul care a dat mute sunt salvate in `users.mute_reason`, `users.mute_by`, `users.mute_by_name`, `users.mute_at`.
- `/lockchat` si `/unlockchat` sunt controlate din `driftzone_admin`.

## SQL

Ruleaza o data:

```sql
ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `mute` DATETIME NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `mute_reason` VARCHAR(255) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS `mute_by` INT NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `mute_by_name` VARCHAR(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS `mute_at` DATETIME NULL DEFAULT NULL;

ALTER TABLE `users`
  MODIFY COLUMN `mute` DATETIME NULL DEFAULT NULL;
```

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_chat
```
