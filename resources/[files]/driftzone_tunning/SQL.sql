ALTER TABLE `vehiclenames`
ADD COLUMN IF NOT EXISTS `tunable` TINYINT NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS `tunning_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `action` VARCHAR(64) NOT NULL,
  `uid` INT NOT NULL DEFAULT 0,
  `player_name` VARCHAR(64) DEFAULT NULL,
  `vehicle_id` INT NOT NULL DEFAULT 0,
  `vehicle_model` VARCHAR(80) DEFAULT NULL,
  `vehicle_plate` VARCHAR(32) DEFAULT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `details` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`uid`),
  KEY `idx_vehicle_id` (`vehicle_id`),
  KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
