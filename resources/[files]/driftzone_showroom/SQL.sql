CREATE TABLE IF NOT EXISTS `ownedvehicles` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `owner_id` INT NOT NULL,
    `vehicle_model` VARCHAR(64) NOT NULL,
    `vehicle_plate` VARCHAR(16) NOT NULL,
    `vehicle_tunning` LONGTEXT NULL,
    `vehicle_fuel` FLOAT NOT NULL DEFAULT 100,
    `vehicle_engine` FLOAT NOT NULL DEFAULT 1000,
    `vehicle_body` FLOAT NOT NULL DEFAULT 1000,
    `stored` TINYINT NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `vehicle_plate_unique` (`vehicle_plate`),
    KEY `owner_id_index` (`owner_id`)
);


ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `vip` TINYINT NOT NULL DEFAULT 0;
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `vip` TINYINT NOT NULL DEFAULT 0;
