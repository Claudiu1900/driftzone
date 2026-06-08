ALTER TABLE `vehiclenames`
ADD COLUMN IF NOT EXISTS `tunable` TINYINT NOT NULL DEFAULT 1;

-- Exemple:
-- UPDATE `vehiclenames` SET `tunable` = 1 WHERE `vehicle_model` = 's15';
-- UPDATE `vehiclenames` SET `tunable` = 0 WHERE `vehicle_model` = 'vipcar';
