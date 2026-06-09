CREATE TABLE IF NOT EXISTS `licenses_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `uid` INT NOT NULL DEFAULT 0,
  `player_name` VARCHAR(64) DEFAULT NULL,
  `vehicle_id` INT NOT NULL DEFAULT 0,
  `vehicle_model` VARCHAR(80) DEFAULT NULL,
  `old_plate` VARCHAR(16) DEFAULT NULL,
  `new_plate` VARCHAR(16) DEFAULT NULL,
  `license_type` VARCHAR(20) DEFAULT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `currency` VARCHAR(20) DEFAULT NULL,
  `status` VARCHAR(20) DEFAULT NULL,
  `message` VARCHAR(255) DEFAULT NULL,
  `details` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`uid`),
  KEY `idx_vehicle_id` (`vehicle_id`),
  KEY `idx_new_plate` (`new_plate`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `users`
ADD COLUMN IF NOT EXISTS `dzcoins` INT NOT NULL DEFAULT 0;

ALTER TABLE `ownedvehicles`
ADD INDEX IF NOT EXISTS `idx_vehicle_plate` (`vehicle_plate`);
