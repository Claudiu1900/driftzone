CREATE TABLE IF NOT EXISTS `outfits` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  `image` TEXT NULL,
  `sex` ENUM('m','f') NOT NULL DEFAULT 'm',
  `clothes` LONGTEXT NOT NULL,
  `created_by_uid` INT NOT NULL DEFAULT 0,
  `created_by_name` VARCHAR(64) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by_uid_idx` (`created_by_uid`),
  KEY `sex_idx` (`sex`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `outfits` ADD COLUMN IF NOT EXISTS `sex` ENUM('m','f') NOT NULL DEFAULT 'm' AFTER `image`;
UPDATE `outfits` SET `sex` = 'm' WHERE `sex` IS NULL OR `sex` = '';

ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `clothes` LONGTEXT NULL;
