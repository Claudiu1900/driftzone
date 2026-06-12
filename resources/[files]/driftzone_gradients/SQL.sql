ALTER TABLE `ownedvehicles`
ADD COLUMN IF NOT EXISTS `gradient` LONGTEXT NULL;

CREATE TABLE IF NOT EXISTS `gradient_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `uid` INT NOT NULL DEFAULT 0,
    `player_name` VARCHAR(64) NULL,
    `vehicle_id` INT NOT NULL DEFAULT 0,
    `plate` VARCHAR(16) NULL,
    `gradient_id` INT NOT NULL DEFAULT 0,
    `gradient_name` VARCHAR(128) NULL,
    `apply_to` VARCHAR(16) NOT NULL DEFAULT 'both',
    `mode` VARCHAR(16) NOT NULL DEFAULT 'item',
    `item_removed` TINYINT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_uid` (`uid`),
    KEY `idx_vehicle` (`vehicle_id`),
    KEY `idx_gradient` (`gradient_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional: item pentru scoaterea gradientului.
-- Daca folosesti driftzone_inventory-ul meu, ruleaza asta ca sa existe itemul in /additem/lista iteme.
INSERT INTO `inventory_items`
(`item_id`, `item_name`, `image`, `tradable`, `stackable`, `usable`, `giveable`, `max_stack`, `created_at`, `updated_at`)
VALUES
('takegradient', 'Scoate Gradient', '', 1, 1, 1, 1, 10, NOW(), NOW())
ON DUPLICATE KEY UPDATE
`item_name` = VALUES(`item_name`),
`tradable` = 1,
`stackable` = 1,
`usable` = 1,
`giveable` = 1,
`max_stack` = 10,
`updated_at` = NOW();
