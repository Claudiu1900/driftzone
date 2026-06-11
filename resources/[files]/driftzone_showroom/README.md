# driftzone_showroom FINAL

Showroom FiveM pentru DriftZone, optimizat si refacut pe categorii noi.

## Ce are nou

- Preview-ul masinii este fortat pe stock tuning:
  - primary color alb;
  - secondary color alb;
  - toate modurile vizuale sunt pe stock `-1`;
  - livery pe stock;
  - extra-urile masinii sunt puse pe varianta stock/enabled.
- Cand cumperi masina, `ownedvehicles.vehicle_tunning` primeste tuning stock cu ambele culori.
- Pret cu cash sau cu DriftZone Coins.
- Daca `vehiclenames.dzcoins_price` este peste `0`, masina se cumpara cu `users.dzcoins`.
- Daca `dzcoins_price = 0`, masina se cumpara cu `users.cash`.
- Categorii noi:
  - `DRIFT`: ALL, Starter, Drifter, JDM Legends
  - `HS`: ALL, Starter, Racer, Legend
  - `PREMIUM`: ALL, Drift, HS
  - `CUSTOM`: ALL
- Cache server-side pentru lista de masini.
- UI-ul nu re-randeaza inutil preview-ul daca selectezi acelasi model.

## Coloane noi in vehiclenames

Ruleaza `SQL.sql`.

```sql
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `showroom_section` VARCHAR(24) NOT NULL DEFAULT 'DRIFT';
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `showroom_subcategory` VARCHAR(32) NOT NULL DEFAULT 'starter';
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `dzcoins_price` INT NOT NULL DEFAULT 0;
ALTER TABLE `vehiclenames` ADD COLUMN IF NOT EXISTS `apear` TINYINT NOT NULL DEFAULT 1;
```

## Exemple categorii

```sql
UPDATE vehiclenames SET showroom_section='DRIFT', showroom_subcategory='starter' WHERE vehicle_model='sultan';
UPDATE vehiclenames SET showroom_section='DRIFT', showroom_subcategory='drifter' WHERE vehicle_model='elegy';
UPDATE vehiclenames SET showroom_section='DRIFT', showroom_subcategory='jdm_legends' WHERE vehicle_model='skyline';

UPDATE vehiclenames SET showroom_section='HS', showroom_subcategory='starter' WHERE vehicle_model='comet2';
UPDATE vehiclenames SET showroom_section='HS', showroom_subcategory='racer' WHERE vehicle_model='italigto';
UPDATE vehiclenames SET showroom_section='HS', showroom_subcategory='legend' WHERE vehicle_model='zentorno';

UPDATE vehiclenames SET showroom_section='PREMIUM', showroom_subcategory='drift', dzcoins_price=2500 WHERE vehicle_model='vipdrift';
UPDATE vehiclenames SET showroom_section='PREMIUM', showroom_subcategory='hs', dzcoins_price=3500 WHERE vehicle_model='viphs';

UPDATE vehiclenames SET showroom_section='CUSTOM', showroom_subcategory='all' WHERE vehicle_model='customcar';
```

## Server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_garage
ensure driftzone_showroom
```

## Restart

```cfg
restart driftzone_showroom
```
