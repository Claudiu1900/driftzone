ALTER TABLE `vehiclenames`
ADD COLUMN IF NOT EXISTS `tunable` TINYINT NOT NULL DEFAULT 1;

-- Exemple:
-- UPDATE `vehiclenames` SET `tunable` = 1 WHERE `vehicle_model` = 's15';
-- UPDATE `vehiclenames` SET `tunable` = 0 WHERE `vehicle_model` = 'vipcar';


CREATE TABLE IF NOT EXISTS `tunning_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `uid` INT NOT NULL DEFAULT 0,
    `player_name` VARCHAR(64) DEFAULT NULL,
    `vehicle_id` INT NOT NULL DEFAULT 0,
    `vehicle_model` VARCHAR(80) DEFAULT NULL,
    `vehicle_plate` VARCHAR(16) DEFAULT NULL,
    `paid` INT NOT NULL DEFAULT 0,
    `remaining_cash` INT NOT NULL DEFAULT 0,
    `changes` LONGTEXT DEFAULT NULL,
    `tuning` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_uid` (`uid`),
    KEY `idx_vehicle_id` (`vehicle_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
