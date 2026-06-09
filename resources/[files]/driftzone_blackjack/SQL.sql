CREATE TABLE IF NOT EXISTS `blackjack_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `uid` INT NOT NULL DEFAULT 0,
  `player_name` VARCHAR(64) DEFAULT NULL,
  `bet` INT NOT NULL DEFAULT 0,
  `result` VARCHAR(32) NOT NULL DEFAULT 'unknown',
  `payout` INT NOT NULL DEFAULT 0,
  `player_cards` TEXT DEFAULT NULL,
  `dealer_cards` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`uid`),
  KEY `idx_result` (`result`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
