ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `vip` VARCHAR(64) NULL DEFAULT NULL;
ALTER TABLE `ownedvehicles` ADD COLUMN IF NOT EXISTS `vip` TINYINT(1) NOT NULL DEFAULT 0;

-- Optional, dar recomandat pentru performanta garajului.
CREATE INDEX IF NOT EXISTS `idx_ownedvehicles_owner_vip` ON `ownedvehicles` (`owner_id`, `vip`);
CREATE INDEX IF NOT EXISTS `idx_ownedvehicles_owner_id` ON `ownedvehicles` (`owner_id`, `id`);
CREATE INDEX IF NOT EXISTS `idx_vehiclenames_model` ON `vehiclenames` (`vehicle_model`);
