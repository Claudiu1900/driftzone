-- DriftZone GangPanel SQL
-- Ruleaza acest fisier o singura data in baza ta de date.

-- Daca nu ai coloana, ruleaza manual linia de mai jos:
-- ALTER TABLE `users` ADD COLUMN `sindicate` TINYINT(1) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `gangs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_type` VARCHAR(20) NOT NULL DEFAULT 'Neo',
  `name` VARCHAR(64) NOT NULL,
  `shortcut` VARCHAR(16) NOT NULL,
  `color` VARCHAR(9) NOT NULL DEFAULT '#04C7F7',
  `leader_uid` INT DEFAULT NULL,
  `garage_x` DOUBLE DEFAULT NULL,
  `garage_y` DOUBLE DEFAULT NULL,
  `garage_z` DOUBLE DEFAULT NULL,
  `storage_x` DOUBLE DEFAULT NULL,
  `storage_y` DOUBLE DEFAULT NULL,
  `storage_z` DOUBLE DEFAULT NULL,
  `created_by_uid` INT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_gangs_shortcut_active` (`shortcut`, `active`),
  KEY `idx_gangs_leader_uid` (`leader_uid`),
  KEY `idx_gangs_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `uid` INT NOT NULL,
  `role` VARCHAR(24) NOT NULL DEFAULT 'Membru',
  `added_by_uid` INT DEFAULT NULL,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_gang_member_uid` (`uid`),
  KEY `idx_gang_members_gang_id` (`gang_id`),
  KEY `idx_gang_members_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL DEFAULT 0,
  `action` VARCHAR(64) NOT NULL,
  `actor_uid` INT NOT NULL DEFAULT 0,
  `target_uid` INT NOT NULL DEFAULT 0,
  `details` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_logs_gang_id` (`gang_id`),
  KEY `idx_gang_logs_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gang_taxes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `uid` INT NOT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `reason` VARCHAR(120) DEFAULT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_gang_taxes_gang_uid` (`gang_id`, `uid`),
  KEY `idx_gang_taxes_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
