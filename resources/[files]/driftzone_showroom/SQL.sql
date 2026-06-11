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
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `dzcoins` INT NOT NULL DEFAULT 0;

-- 1 = apare in showroom, 0 = nu apare.
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `apear` TINYINT NOT NULL DEFAULT 1;

-- Pret cu DriftZone Coins. Daca este peste 0, masina se cumpara cu DZC in loc de cash.
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `dzcoins_price` INT NOT NULL DEFAULT 0;

-- Noile categorii showroom.
-- showroom_section: DRIFT / HS / PREMIUM / CUSTOM
-- showroom_subcategory:
--   DRIFT: starter / drifter / jdm_legends
--   HS: starter / racer / legend
--   PREMIUM: drift / hs
--   CUSTOM: all
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `showroom_section` VARCHAR(24) NOT NULL DEFAULT 'DRIFT';
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `showroom_subcategory` VARCHAR(32) NOT NULL DEFAULT 'starter';

-- Exemple:
-- UPDATE vehiclenames SET showroom_section='DRIFT', showroom_subcategory='jdm_legends' WHERE vehicle_model='skyline';
-- UPDATE vehiclenames SET showroom_section='HS', showroom_subcategory='legend' WHERE vehicle_model='bugatti';
-- UPDATE vehiclenames SET showroom_section='PREMIUM', showroom_subcategory='drift', dzcoins_price=2500 WHERE vehicle_model='vipcar';
-- UPDATE vehiclenames SET showroom_section='CUSTOM', showroom_subcategory='all' WHERE vehicle_model='customcar';
