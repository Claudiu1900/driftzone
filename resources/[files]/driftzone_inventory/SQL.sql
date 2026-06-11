CREATE TABLE IF NOT EXISTS `inventory_items` (
  `item_id` VARCHAR(64) NOT NULL,
  `item_name` VARCHAR(128) NOT NULL,
  `image` TEXT NULL,
  `tradable` TINYINT NOT NULL DEFAULT 1,
  `stackable` TINYINT NOT NULL DEFAULT 1,
  `usable` TINYINT NOT NULL DEFAULT 0,
  `giveable` TINYINT NOT NULL DEFAULT 1,
  `max_stack` INT NOT NULL DEFAULT 100,
  `is_gradient` TINYINT NOT NULL DEFAULT 0,
  `gradient_id` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `inventory` (
  `uid` INT NOT NULL,
  `inventory_json` LONGTEXT NULL,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `inventory_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `action` VARCHAR(64) NOT NULL,
  `admin_uid` INT NOT NULL DEFAULT 0,
  `target_uid` INT NOT NULL DEFAULT 0,
  `item_id` VARCHAR(64) NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_target_uid` (`target_uid`),
  KEY `idx_action` (`action`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `inventory_items` ADD COLUMN IF NOT EXISTS `is_gradient` TINYINT NOT NULL DEFAULT 0;
ALTER TABLE `inventory_items` ADD COLUMN IF NOT EXISTS `gradient_id` INT NOT NULL DEFAULT 0;

INSERT INTO `inventory_items` (`item_id`, `item_name`, `image`, `tradable`, `stackable`, `usable`, `giveable`, `max_stack`, `is_gradient`, `gradient_id`)
VALUES
('water', 'Apă', '', 1, 1, 1, 1, 20, 0, 0),
('repairkit', 'Repair Kit', '', 1, 1, 1, 1, 10, 0, 0),
('1_gradient', 'Gradient 1', '', 1, 1, 1, 1, 1, 1, 1)
ON DUPLICATE KEY UPDATE `item_name` = VALUES(`item_name`);
