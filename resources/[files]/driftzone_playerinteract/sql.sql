CREATE TABLE IF NOT EXISTS `pay_logs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from_uid` INT UNSIGNED NOT NULL,
  `from_name` VARCHAR(64) NOT NULL DEFAULT 'Unknown',
  `to_uid` INT UNSIGNED NOT NULL,
  `to_name` VARCHAR(64) NOT NULL DEFAULT 'Unknown',
  `amount` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `x` DOUBLE NOT NULL DEFAULT 0,
  `y` DOUBLE NOT NULL DEFAULT 0,
  `z` DOUBLE NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pay_logs_from_uid` (`from_uid`),
  KEY `idx_pay_logs_to_uid` (`to_uid`),
  KEY `idx_pay_logs_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `users`
  MODIFY COLUMN `cash` BIGINT UNSIGNED NOT NULL DEFAULT 0;

-- Trade logs pentru request_sent / request_expired / request_cancelled / cancelled / confirmed
CREATE TABLE IF NOT EXISTS `trade_logs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id` VARCHAR(64) NOT NULL,
  `from_uid` INT UNSIGNED NOT NULL,
  `from_name` VARCHAR(64) NOT NULL DEFAULT 'Unknown',
  `to_uid` INT UNSIGNED NOT NULL,
  `to_name` VARCHAR(64) NOT NULL DEFAULT 'Unknown',
  `from_vehicle_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `to_vehicle_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `from_money` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `to_money` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `accepted` TINYINT(1) NOT NULL DEFAULT 0,
  `reason` VARCHAR(128) NOT NULL DEFAULT '',
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_trade_logs_request_id` (`request_id`),
  KEY `idx_trade_logs_from_uid` (`from_uid`),
  KEY `idx_trade_logs_to_uid` (`to_uid`),
  KEY `idx_trade_logs_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
