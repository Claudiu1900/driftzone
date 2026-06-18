-- DriftZone Inventory - SQL doar pentru sistemul de haine din inventar
-- Ruleaza acest SQL peste baza deja existenta. Nu recreeaza inventory_items/inventory.

CREATE TABLE IF NOT EXISTS `clothes_items` (
  `item_id` VARCHAR(64) NOT NULL,
  `item_name` VARCHAR(128) NOT NULL,
  `image` TEXT NULL,
  `category_key` VARCHAR(32) NOT NULL,
  `drawable` INT NOT NULL DEFAULT 0,
  `texture` INT NOT NULL DEFAULT 0,
  `clothes_type` VARCHAR(16) NOT NULL DEFAULT 'component',
  `component_id` INT NOT NULL DEFAULT -1,
  `prop_id` INT NOT NULL DEFAULT -1,
  `tradable` TINYINT NOT NULL DEFAULT 1,
  `stackable` TINYINT NOT NULL DEFAULT 0,
  `usable` TINYINT NOT NULL DEFAULT 1,
  `giveable` TINYINT NOT NULL DEFAULT 1,
  `max_stack` INT NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item_id`),
  KEY `idx_category_key` (`category_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `users_clothes` (
  `uid` INT NOT NULL,
  `jacket` LONGTEXT NULL,
  `top` LONGTEXT NULL,
  `torso` LONGTEXT NULL,
  `mask` LONGTEXT NULL,
  `shoes` LONGTEXT NULL,
  `pants` LONGTEXT NULL,
  `accessories` LONGTEXT NULL,
  `watches` LONGTEXT NULL,
  `bracelets` LONGTEXT NULL,
  `vest` LONGTEXT NULL,
  `bag` LONGTEXT NULL,
  `hat` LONGTEXT NULL,
  `glasses` LONGTEXT NULL,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Compatibilitate daca tabela exista deja dar lipseste vreo coloana.
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `jacket` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `top` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `torso` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `mask` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `shoes` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `pants` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `accessories` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `watches` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `bracelets` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `vest` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `bag` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `hat` LONGTEXT NULL;
ALTER TABLE `users_clothes` ADD COLUMN IF NOT EXISTS `glasses` LONGTEXT NULL;

ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `image` TEXT NULL;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `category_key` VARCHAR(32) NOT NULL DEFAULT 'jacket';
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `drawable` INT NOT NULL DEFAULT 0;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `texture` INT NOT NULL DEFAULT 0;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `clothes_type` VARCHAR(16) NOT NULL DEFAULT 'component';
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `component_id` INT NOT NULL DEFAULT -1;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `prop_id` INT NOT NULL DEFAULT -1;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `tradable` TINYINT NOT NULL DEFAULT 1;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `stackable` TINYINT NOT NULL DEFAULT 0;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `usable` TINYINT NOT NULL DEFAULT 1;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `giveable` TINYINT NOT NULL DEFAULT 1;
ALTER TABLE `clothes_items` ADD COLUMN IF NOT EXISTS `max_stack` INT NOT NULL DEFAULT 1;
