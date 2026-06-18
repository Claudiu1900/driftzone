CREATE TABLE IF NOT EXISTS `garages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(96) NOT NULL DEFAULT 'Garage',
  `x` DOUBLE NOT NULL DEFAULT 0,
  `y` DOUBLE NOT NULL DEFAULT 0,
  `z` DOUBLE NOT NULL DEFAULT 0,
  `radius` DOUBLE NOT NULL DEFAULT 4,
  `visible_radius` TINYINT(1) NOT NULL DEFAULT 1,
  `parking_spots` LONGTEXT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_garages_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `vip` VARCHAR(64) NULL DEFAULT NULL;
ALTER TABLE `ownedvehicles` ADD COLUMN IF NOT EXISTS `vip` TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE `ownedvehicles` ADD COLUMN IF NOT EXISTS `gradient` LONGTEXT NULL;

CREATE INDEX IF NOT EXISTS `idx_ownedvehicles_owner_vip` ON `ownedvehicles` (`owner_id`, `vip`);
CREATE INDEX IF NOT EXISTS `idx_ownedvehicles_owner_id` ON `ownedvehicles` (`owner_id`, `id`);
CREATE INDEX IF NOT EXISTS `idx_vehiclenames_model` ON `vehiclenames` (`vehicle_model`);
