-- DriftZone Clothes SQL
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `clothes` LONGTEXT NULL;

CREATE TABLE IF NOT EXISTS `unallowed_clothes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `category_key` VARCHAR(32) NOT NULL,
  `drawable` INT NOT NULL,
  `reason` VARCHAR(255) NOT NULL DEFAULT '',
  `active` TINYINT NOT NULL DEFAULT 1,
  `created_by` VARCHAR(64) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_clothes_blacklist` (`category_key`, `drawable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `clothes_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL DEFAULT 0,
  `player_name` VARCHAR(64) NOT NULL DEFAULT '',
  `action` VARCHAR(32) NOT NULL DEFAULT '',
  `clothes` LONGTEXT NULL,
  `admin_name` VARCHAR(64) NOT NULL DEFAULT '',
  `admin_uid` INT NOT NULL DEFAULT 0,
  `target_name` VARCHAR(64) NOT NULL DEFAULT '',
  `target_uid` INT NOT NULL DEFAULT 0,
  `category_key` VARCHAR(32) NOT NULL DEFAULT '',
  `drawable` INT NOT NULL DEFAULT 0,
  `reason` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
