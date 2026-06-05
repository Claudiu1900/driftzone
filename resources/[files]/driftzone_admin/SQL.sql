ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `warns` INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `admin_command_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `admin_uid` INT NULL DEFAULT NULL,
    `admin_name` VARCHAR(64) NOT NULL DEFAULT '',
    `admin_level` INT NOT NULL DEFAULT 0,
    `command` VARCHAR(64) NOT NULL DEFAULT '',
    `args` TEXT NULL,
    `status` VARCHAR(32) NOT NULL DEFAULT 'unknown',
    `target_uid` INT NULL DEFAULT NULL,
    `target_name` VARCHAR(64) NULL DEFAULT NULL,
    `message` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_admin_uid` (`admin_uid`),
    KEY `idx_command` (`command`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
