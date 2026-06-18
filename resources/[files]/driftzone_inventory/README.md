# driftzone_inventory - Inventory Position Editor

Resource complet cu inventory, money/dirtymoney, quick slots, clothes equipment si editor pentru pozitia sloturilor de haine.

## Nou in versiunea asta

- Adaugata tabela `inventory_position`.
- Adaugata comanda `/inventorypos` pentru `admin_level >= 6` + `aduty` activ.
- `/inventorypos` deschide inventarul in mod de editare pozitie.
- Sloturile de haine se pot muta cu drag & drop direct pe manechin.
- Butonul `SAVE` salveaza pozitiile in `inventory_position`.
- Cand orice player deschide inventarul, pozitiile sunt incarcate din DB.
- Daca nu exista pozitie salvata in DB, foloseste fallback-ul din `shared/config.lua` -> `Config.ClothingSlotPositions`.
- UI-ul ramane optimizat, fara `backdrop-filter`.

## SQL

Ruleaza `SQL.sql`. Acesta adauga doar tabelele/coloanele necesare pentru haine si pozitiile sloturilor.

Tabela noua:

```sql
inventory_position
```

Coloane importante:

- `category_key`
- `left_pct`
- `top_pct`
- `slot_size`
- `updated_by`
- `updated_at`

## Comenzi

- `/inventory`
- `/additem` admin 6+ aduty
- `/items` admin 6+ aduty
- `/addclothes` admin 6+ aduty
- `/clothesitems` admin 6+ aduty
- `/inventorypos` admin 6+ aduty

## Config

Pozitiile default sunt in:

```lua
Config.ClothingSlotPositions = {}
```

Pozitiile salvate de admin in DB au prioritate peste config.
