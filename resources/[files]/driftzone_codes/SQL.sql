CREATE TABLE IF NOT EXISTS `codes` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    `reward_type` VARCHAR(32) NOT NULL DEFAULT 'dzcoins',
    `reward_amount` INT NOT NULL DEFAULT 0,
    `max_uses` INT NOT NULL DEFAULT 1,
    `used_count` INT NOT NULL DEFAULT 0,
    `expires_at` DATETIME NULL DEFAULT NULL,
    `active` TINYINT NOT NULL DEFAULT 1,
    `created_by` INT NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_code` (`code`),
    KEY `idx_active_expires` (`active`, `expires_at`),
    KEY `idx_code_active` (`code`, `active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `code_redemptions` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `code_id` INT NOT NULL,
    `code` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    `user_id` INT NOT NULL,
    `player_name` VARCHAR(64) NOT NULL DEFAULT '',
    `reward_type` VARCHAR(32) NOT NULL DEFAULT 'dzcoins',
    `reward_amount` INT NOT NULL DEFAULT 0,
    `redeemed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_code_user` (`code_id`, `user_id`),
    KEY `idx_user` (`user_id`),
    KEY `idx_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `dzcoins` INT NOT NULL DEFAULT 0;
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `cash` INT NOT NULL DEFAULT 0;

ALTER TABLE `codes` MODIFY `code` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL;
ALTER TABLE `code_redemptions` MODIFY `code` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL;
