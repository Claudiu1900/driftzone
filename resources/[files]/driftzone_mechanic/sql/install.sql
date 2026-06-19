CREATE TABLE IF NOT EXISTS `driftzone_mechanic_players` (
    `identifier` VARCHAR(80) NOT NULL,
    `player_name` VARCHAR(80) NOT NULL DEFAULT 'Necunoscut',
    `employed` TINYINT(1) NOT NULL DEFAULT 0,
    `xp` INT NOT NULL DEFAULT 0,
    `total_jobs` INT NOT NULL DEFAULT 0,
    `total_earnings` INT NOT NULL DEFAULT 0,
    `internal_wallet` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
