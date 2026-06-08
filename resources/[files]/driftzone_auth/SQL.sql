-- DriftZone Auth update
-- Starter car tuning support

ALTER TABLE `ownedvehicles`
ADD COLUMN IF NOT EXISTS `vehicle_tunning` LONGTEXT NULL;

-- Recomandat pentru ban-uri auth directe din FiveM connect deferrals.
ALTER TABLE `users`
ADD COLUMN IF NOT EXISTS `ban` VARCHAR(10) NOT NULL DEFAULT 'no',
ADD COLUMN IF NOT EXISTS `banreason` TEXT NULL,
ADD COLUMN IF NOT EXISTS `tempban` DATETIME NULL,
ADD COLUMN IF NOT EXISTS `tempbanreason` TEXT NULL;
