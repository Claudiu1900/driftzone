-- =========================================================
-- DriftZone GangPanel V3 - FINAL SQL / MIGRATION FIXED
-- Ruleaza TOT fisierul acesta, apoi restart driftzone_gangpanel.
-- Repara eroarea: Unknown column 'g.type' in SELECT.
-- Compatibil MySQL/MariaDB prin INFORMATION_SCHEMA.
-- =========================================================

SET @OLD_SQL_MODE = @@SQL_MODE;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =========================================================
-- Helper: adauga coloana doar daca nu exista
-- =========================================================
DROP PROCEDURE IF EXISTS dz_add_column;
DELIMITER $$
CREATE PROCEDURE dz_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition TEXT)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = p_table
          AND COLUMN_NAME = p_column
    ) THEN
        SET @sql = CONCAT('ALTER TABLE `', REPLACE(p_table, '`', ''), '` ADD COLUMN `', REPLACE(p_column, '`', ''), '` ', p_definition);
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$
DELIMITER ;

-- =========================================================
-- USERS columns
-- =========================================================
CALL dz_add_column('users', 'sindicate', 'TINYINT(1) NOT NULL DEFAULT 0');
CALL dz_add_column('users', 'rank', 'VARCHAR(64) NOT NULL DEFAULT ''''');
CALL dz_add_column('users', 'rankcolor', 'VARCHAR(16) NOT NULL DEFAULT ''''');
CALL dz_add_column('users', 'cash', 'BIGINT NOT NULL DEFAULT 0');
CALL dz_add_column('users', 'bank', 'BIGINT NOT NULL DEFAULT 0');

-- =========================================================
-- GANGS
-- =========================================================
CREATE TABLE IF NOT EXISTS `gangs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(64) NOT NULL DEFAULT 'Mafie Neoficiala',
  `name` VARCHAR(96) NOT NULL DEFAULT '',
  `shortcut` VARCHAR(16) NOT NULL DEFAULT '',
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
  KEY `idx_active` (`active`),
  KEY `idx_leader` (`leader_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('gangs', 'type', 'VARCHAR(64) NOT NULL DEFAULT ''Mafie Neoficiala''');
CALL dz_add_column('gangs', 'name', 'VARCHAR(96) NOT NULL DEFAULT ''''');
CALL dz_add_column('gangs', 'shortcut', 'VARCHAR(16) NOT NULL DEFAULT ''''');
CALL dz_add_column('gangs', 'color', 'VARCHAR(16) NOT NULL DEFAULT ''#04C7F7''');
CALL dz_add_column('gangs', 'leader_uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gangs', 'garage_x', 'DOUBLE NULL');
CALL dz_add_column('gangs', 'garage_y', 'DOUBLE NULL');
CALL dz_add_column('gangs', 'garage_z', 'DOUBLE NULL');
CALL dz_add_column('gangs', 'storage_x', 'DOUBLE NULL');
CALL dz_add_column('gangs', 'storage_y', 'DOUBLE NULL');
CALL dz_add_column('gangs', 'storage_z', 'DOUBLE NULL');
CALL dz_add_column('gangs', 'revenue', 'BIGINT NOT NULL DEFAULT 0');
CALL dz_add_column('gangs', 'active', 'TINYINT(1) NOT NULL DEFAULT 1');
CALL dz_add_column('gangs', 'created_by', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gangs', 'created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');
CALL dz_add_column('gangs', 'updated_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

UPDATE `gangs` SET `type` = 'Mafie Neoficiala' WHERE `type` = 'Neo' OR `type` = '' OR `type` IS NULL;
UPDATE `gangs` SET `type` = 'Mafie Oficiala' WHERE `type` = 'Oficiala';
UPDATE `gangs` SET `color` = '#04C7F7' WHERE `color` = '' OR `color` IS NULL;
UPDATE `gangs` SET `revenue` = 0 WHERE `revenue` IS NULL;
UPDATE `gangs` SET `active` = 1 WHERE `active` IS NULL;

-- =========================================================
-- GANG MEMBERS
-- =========================================================
CREATE TABLE IF NOT EXISTS `gang_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL DEFAULT 0,
  `uid` INT NOT NULL DEFAULT 0,
  `role` VARCHAR(32) NOT NULL DEFAULT 'Membru',
  `added_by` INT NOT NULL DEFAULT 0,
  `added_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_gang` (`gang_id`),
  KEY `idx_uid` (`uid`),
  KEY `idx_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('gang_members', 'gang_id', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_members', 'uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_members', 'role', 'VARCHAR(32) NOT NULL DEFAULT ''Membru''');
CALL dz_add_column('gang_members', 'added_by', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_members', 'added_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');
CALL dz_add_column('gang_members', 'last_seen', 'TIMESTAMP NULL DEFAULT NULL');

UPDATE `gang_members` SET `role` = 'Membru' WHERE `role` = '' OR `role` IS NULL;
UPDATE `gang_members` SET `role` = 'Co-Lider' WHERE LOWER(`role`) IN ('coleader', 'co lider', 'co-lider');
UPDATE `gang_members` SET `role` = 'Lider' WHERE LOWER(`role`) IN ('leader', 'lider');

-- =========================================================
-- TAX CATEGORIES
-- =========================================================
CREATE TABLE IF NOT EXISTS `gang_tax_categories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(96) NOT NULL DEFAULT '',
  `description` VARCHAR(255) NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('gang_tax_categories', 'name', 'VARCHAR(96) NOT NULL DEFAULT ''''');
CALL dz_add_column('gang_tax_categories', 'description', 'VARCHAR(255) NULL');
CALL dz_add_column('gang_tax_categories', 'active', 'TINYINT(1) NOT NULL DEFAULT 1');
CALL dz_add_column('gang_tax_categories', 'created_by', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_tax_categories', 'created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');

INSERT INTO `gang_tax_categories` (`name`, `description`, `active`, `created_by`)
SELECT 'Protectie', 'Taxa de protectie pentru afaceri sau persoane.', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM `gang_tax_categories` WHERE `name` = 'Protectie' OR `name` = 'Protecție');

INSERT INTO `gang_tax_categories` (`name`, `description`, `active`, `created_by`)
SELECT 'Teritoriu', 'Taxa pentru activitate intr-o zona controlata.', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM `gang_tax_categories` WHERE `name` = 'Teritoriu');

INSERT INTO `gang_tax_categories` (`name`, `description`, `active`, `created_by`)
SELECT 'Servicii', 'Taxa pentru servicii sau intelegeri.', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM `gang_tax_categories` WHERE `name` = 'Servicii');

-- =========================================================
-- TAX RECORDS
-- =========================================================
CREATE TABLE IF NOT EXISTS `gang_tax_records` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL DEFAULT 0,
  `category_id` INT NOT NULL DEFAULT 0,
  `category_name` VARCHAR(96) NOT NULL DEFAULT '',
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
  KEY `idx_issuer` (`issuer_uid`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('gang_tax_records', 'gang_id', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_tax_records', 'category_id', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_tax_records', 'category_name', 'VARCHAR(96) NOT NULL DEFAULT ''''');
CALL dz_add_column('gang_tax_records', 'amount', 'BIGINT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_tax_records', 'payer_uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_tax_records', 'issuer_uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_tax_records', 'paid_from', 'VARCHAR(16) NOT NULL DEFAULT ''''');
CALL dz_add_column('gang_tax_records', 'status', 'VARCHAR(24) NOT NULL DEFAULT ''paid''');
CALL dz_add_column('gang_tax_records', 'created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');
CALL dz_add_column('gang_tax_records', 'paid_at', 'TIMESTAMP NULL DEFAULT NULL');

-- =========================================================
-- REVENUE LOGS
-- =========================================================
CREATE TABLE IF NOT EXISTS `gang_revenue_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL DEFAULT 0,
  `action` VARCHAR(64) NOT NULL DEFAULT '',
  `amount` BIGINT NOT NULL DEFAULT 0,
  `by_uid` INT NOT NULL DEFAULT 0,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang` (`gang_id`),
  KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('gang_revenue_logs', 'gang_id', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_revenue_logs', 'action', 'VARCHAR(64) NOT NULL DEFAULT ''''');
CALL dz_add_column('gang_revenue_logs', 'amount', 'BIGINT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_revenue_logs', 'by_uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_revenue_logs', 'details', 'LONGTEXT NULL');
CALL dz_add_column('gang_revenue_logs', 'created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');

-- =========================================================
-- WITHDRAWALS
-- =========================================================
CREATE TABLE IF NOT EXISTS `gang_withdrawals` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL DEFAULT 0,
  `leader_uid` INT NOT NULL DEFAULT 0,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `x` DOUBLE NOT NULL DEFAULT 0,
  `y` DOUBLE NOT NULL DEFAULT 0,
  `z` DOUBLE NOT NULL DEFAULT 0,
  `status` VARCHAR(24) NOT NULL DEFAULT 'processing',
  `ready_at` TIMESTAMP NULL DEFAULT NULL,
  `claimed_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_leader_status` (`leader_uid`, `status`),
  KEY `idx_gang_status` (`gang_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('gang_withdrawals', 'gang_id', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_withdrawals', 'leader_uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_withdrawals', 'amount', 'BIGINT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_withdrawals', 'x', 'DOUBLE NOT NULL DEFAULT 0');
CALL dz_add_column('gang_withdrawals', 'y', 'DOUBLE NOT NULL DEFAULT 0');
CALL dz_add_column('gang_withdrawals', 'z', 'DOUBLE NOT NULL DEFAULT 0');
CALL dz_add_column('gang_withdrawals', 'status', 'VARCHAR(24) NOT NULL DEFAULT ''processing''');
CALL dz_add_column('gang_withdrawals', 'ready_at', 'TIMESTAMP NULL DEFAULT NULL');
CALL dz_add_column('gang_withdrawals', 'claimed_at', 'TIMESTAMP NULL DEFAULT NULL');
CALL dz_add_column('gang_withdrawals', 'created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');

-- =========================================================
-- INTERNAL LOGS - nu apar in meniu, doar DB
-- =========================================================
CREATE TABLE IF NOT EXISTS `gang_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `action` VARCHAR(64) NOT NULL DEFAULT '',
  `by_uid` INT NOT NULL DEFAULT 0,
  `gang_id` INT NOT NULL DEFAULT 0,
  `target_uid` INT NOT NULL DEFAULT 0,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_action` (`action`),
  KEY `idx_gang` (`gang_id`),
  KEY `idx_target` (`target_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('gang_logs', 'action', 'VARCHAR(64) NOT NULL DEFAULT ''''');
CALL dz_add_column('gang_logs', 'by_uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_logs', 'gang_id', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_logs', 'target_uid', 'INT NOT NULL DEFAULT 0');
CALL dz_add_column('gang_logs', 'details', 'LONGTEXT NULL');
CALL dz_add_column('gang_logs', 'created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');

-- =========================================================
-- INVENTORY support pentru dirtymoney fallback
-- =========================================================
CREATE TABLE IF NOT EXISTS `inventory` (
  `uid` INT NOT NULL,
  `inventory_json` LONGTEXT NULL,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL dz_add_column('inventory', 'inventory_json', 'LONGTEXT NULL');
CALL dz_add_column('inventory', 'updated_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

CREATE TABLE IF NOT EXISTS `inventory_items` (
  `item_id` VARCHAR(64) NOT NULL,
  `item_name` VARCHAR(128) NOT NULL DEFAULT '',
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

CALL dz_add_column('inventory_items', 'item_name', 'VARCHAR(128) NOT NULL DEFAULT ''''');
CALL dz_add_column('inventory_items', 'image', 'TEXT NULL');
CALL dz_add_column('inventory_items', 'tradable', 'TINYINT NOT NULL DEFAULT 1');
CALL dz_add_column('inventory_items', 'stackable', 'TINYINT NOT NULL DEFAULT 1');
CALL dz_add_column('inventory_items', 'usable', 'TINYINT NOT NULL DEFAULT 0');
CALL dz_add_column('inventory_items', 'giveable', 'TINYINT NOT NULL DEFAULT 1');
CALL dz_add_column('inventory_items', 'max_stack', 'INT NOT NULL DEFAULT 100');
CALL dz_add_column('inventory_items', 'created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');
CALL dz_add_column('inventory_items', 'updated_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

INSERT INTO `inventory_items` (`item_id`, `item_name`, `image`, `tradable`, `stackable`, `usable`, `giveable`, `max_stack`, `created_at`, `updated_at`)
VALUES ('dirtymoney', 'Dirty Money', '', 1, 1, 0, 1, 100000000, NOW(), NOW())
ON DUPLICATE KEY UPDATE
  `item_name` = VALUES(`item_name`),
  `tradable` = 1,
  `stackable` = 1,
  `usable` = 0,
  `giveable` = 1,
  `max_stack` = VALUES(`max_stack`),
  `updated_at` = NOW();

-- =========================================================
-- Curata helper-ul
-- =========================================================
DROP PROCEDURE IF EXISTS dz_add_column;
SET SQL_MODE = @OLD_SQL_MODE;

-- DONE
