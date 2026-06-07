CREATE TABLE IF NOT EXISTS `races` (
  `uid` INT UNSIGNED NOT NULL,
  `name` VARCHAR(64) NOT NULL DEFAULT 'Unknown',
  `losses` INT UNSIGNED NOT NULL DEFAULT 0,
  `wins` INT UNSIGNED NOT NULL DEFAULT 0,
  `cashlost` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `cashwin` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `races` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`uid`),
  KEY `idx_races_wins` (`wins`),
  KEY `idx_races_losses` (`losses`),
  KEY `idx_races_total` (`races`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `users`
  MODIFY COLUMN `cash` BIGINT UNSIGNED NOT NULL DEFAULT 0;
