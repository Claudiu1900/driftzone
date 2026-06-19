CREATE TABLE IF NOT EXISTS `contacts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner_uid` int(11) NOT NULL,
  `contact_name` varchar(64) NOT NULL,
  `phone_number` varchar(32) NOT NULL,
  `blocked` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_owner_phone` (`owner_uid`, `phone_number`),
  KEY `idx_owner_uid` (`owner_uid`),
  KEY `idx_phone_number` (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `call_history` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner_uid` int(11) NOT NULL,
  `other_number` varchar(32) NOT NULL,
  `other_name` varchar(64) DEFAULT NULL,
  `direction` varchar(16) NOT NULL,
  `status` varchar(16) NOT NULL,
  `duration` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_owner_uid` (`owner_uid`),
  KEY `idx_other_number` (`other_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `message_history` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sender_uid` int(11) NOT NULL,
  `receiver_uid` int(11) NOT NULL,
  `sender_number` varchar(32) NOT NULL,
  `receiver_number` varchar(32) NOT NULL,
  `message` text NOT NULL,
  `message_type` varchar(16) NOT NULL DEFAULT 'text',
  `location_json` longtext DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sender_uid` (`sender_uid`),
  KEY `idx_receiver_uid` (`receiver_uid`),
  KEY `idx_sender_receiver` (`sender_uid`, `receiver_uid`),
  KEY `idx_numbers` (`sender_number`, `receiver_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =========================
-- PHONE GARAGE APP
-- =========================
CREATE TABLE IF NOT EXISTS `garages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(96) NOT NULL DEFAULT 'Garage',
  `x` DOUBLE NOT NULL DEFAULT 0,
  `y` DOUBLE NOT NULL DEFAULT 0,
  `z` DOUBLE NOT NULL DEFAULT 0,
  `radius` DOUBLE NOT NULL DEFAULT 4,
  `park_radius` DOUBLE NOT NULL DEFAULT 12,
  `visible_radius` TINYINT(1) NOT NULL DEFAULT 1,
  `parking_spots` LONGTEXT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_garages_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `ownedvehicles` ADD COLUMN IF NOT EXISTS `garage` INT NOT NULL DEFAULT 1;
ALTER TABLE `ownedvehicles` ADD COLUMN IF NOT EXISTS `vip` TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE `ownedvehicles` ADD COLUMN IF NOT EXISTS `gradient` LONGTEXT NULL;
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `outsidevehicles` INT NOT NULL DEFAULT 1;

-- Daca ai masini vechi cu garage = 0 dar vrei sa le bagi initial in garajul 1:
-- UPDATE `ownedvehicles` SET `garage` = 1 WHERE `garage` IS NULL OR `garage` = 0;


-- Optional: daca vrei sa bagi toate masinile vechi in garajul 1 manual:
-- UPDATE `ownedvehicles` SET `garage` = 1 WHERE `garage` IS NULL OR `garage` = 0;
