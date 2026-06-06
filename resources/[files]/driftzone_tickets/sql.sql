CREATE TABLE IF NOT EXISTS `ticket_logs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` INT UNSIGNED NOT NULL,
  `action` VARCHAR(32) NOT NULL DEFAULT 'unknown',
  `player_uid` INT UNSIGNED NOT NULL DEFAULT 0,
  `player_name` VARCHAR(64) NULL DEFAULT NULL,
  `admin_uid` INT UNSIGNED NULL DEFAULT NULL,
  `admin_name` VARCHAR(64) NULL DEFAULT NULL,
  `admin_level` INT NULL DEFAULT NULL,
  `title` VARCHAR(80) NULL DEFAULT NULL,
  `subject` VARCHAR(500) NULL DEFAULT NULL,
  `ticket_created_at` VARCHAR(32) NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ticket_logs_ticket_id` (`ticket_id`),
  KEY `idx_ticket_logs_player_uid` (`player_uid`),
  KEY `idx_ticket_logs_admin_uid` (`admin_uid`),
  KEY `idx_ticket_logs_action` (`action`),
  KEY `idx_ticket_logs_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `tickets` INT UNSIGNED NOT NULL DEFAULT 0;
