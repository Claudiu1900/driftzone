ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `sindicate` TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `rank` VARCHAR(64) NOT NULL DEFAULT '';
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `rankcolor` VARCHAR(16) NOT NULL DEFAULT '';
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `bank` BIGINT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `gangs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(64) NOT NULL DEFAULT 'Mafie Neoficiala',
  `name` VARCHAR(96) NOT NULL,
  `shortcut` VARCHAR(16) NOT NULL,
  `color` VARCHAR(16) NOT NULL DEFAULT '#04C7F7',
  `leader_uid` INT NOT NULL DEFAULT 0,
  `garage_x` DOUBLE NULL,
  `garage_y` DOUBLE NULL,
  `garage_z` DOUBLE NULL,
  `storage_x` DOUBLE NULL,
  `storage_y` DOUBLE NULL,
  `storage_z` DOUBLE NULL,
  `revenue` BIGINT NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_shortcut` (`shortcut`),
  KEY `idx_active` (`active`),
  KEY `idx_leader` (`leader_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `uid` INT NOT NULL,
  `role` VARCHAR(32) NOT NULL DEFAULT 'Membru',
  `added_by` INT NOT NULL DEFAULT 0,
  `added_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_uid` (`uid`),
  KEY `idx_gang` (`gang_id`),
  KEY `idx_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_tax_categories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(96) NOT NULL,
  `description` VARCHAR(255) NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_active` (`active`),
  UNIQUE KEY `uk_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_tax_records` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `category_id` INT NOT NULL DEFAULT 0,
  `category_name` VARCHAR(96) NOT NULL,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `payer_uid` INT NOT NULL DEFAULT 0,
  `issuer_uid` INT NOT NULL DEFAULT 0,
  `paid_from` VARCHAR(16) NOT NULL DEFAULT '',
  `status` VARCHAR(24) NOT NULL DEFAULT 'paid',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_gang` (`gang_id`),
  KEY `idx_category` (`category_id`),
  KEY `idx_payer` (`payer_uid`),
  KEY `idx_issuer` (`issuer_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_revenue_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `by_uid` INT NOT NULL DEFAULT 0,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang` (`gang_id`),
  KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_withdrawals` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `leader_uid` INT NOT NULL,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'processing',
  `ready_at` TIMESTAMP NULL DEFAULT NULL,
  `claimed_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_leader_status` (`leader_uid`, `status`),
  KEY `idx_gang_status` (`gang_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `action` VARCHAR(64) NOT NULL,
  `by_uid` INT NOT NULL DEFAULT 0,
  `gang_id` INT NOT NULL DEFAULT 0,
  `target_uid` INT NOT NULL DEFAULT 0,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_action` (`action`),
  KEY `idx_gang` (`gang_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `gang_tax_categories` (`name`, `description`, `active`, `created_by`)
VALUES
('Protecție', 'Taxă de protecție pentru afaceri sau persoane.', 1, 0),
('Teritoriu', 'Taxă pentru activitate într-o zonă controlată.', 1, 0),
('Servicii', 'Taxă pentru servicii sau înțelegeri.', 1, 0)
ON DUPLICATE KEY UPDATE `active` = VALUES(`active`);

CREATE TABLE IF NOT EXISTS `inventory_items` (
  `item_id` VARCHAR(64) NOT NULL,
  `item_name` VARCHAR(128) NOT NULL,
  `image` TEXT NULL,
  `tradable` TINYINT NOT NULL DEFAULT 1,
  `stackable` TINYINT NOT NULL DEFAULT 1,
  `usable` TINYINT NOT NULL DEFAULT 0,
  `giveable` TINYINT NOT NULL DEFAULT 1,
  `max_stack` INT NOT NULL DEFAULT 100,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `inventory_items` (`item_id`, `item_name`, `image`, `tradable`, `stackable`, `usable`, `giveable`, `max_stack`, `created_at`, `updated_at`)
VALUES ('dirtymoney', 'Dirty Money', '', 1, 1, 0, 1, 100000000, NOW(), NOW())
ON DUPLICATE KEY UPDATE `item_name` = VALUES(`item_name`), `stackable` = 1, `giveable` = 1, `max_stack` = VALUES(`max_stack`), `updated_at` = NOW();

UPDATE `gangs` SET `type` = 'Mafie Neoficiala' WHERE `type` = 'Neo';
UPDATE `gangs` SET `type` = 'Mafie Oficiala' WHERE `type` = 'Oficiala';
