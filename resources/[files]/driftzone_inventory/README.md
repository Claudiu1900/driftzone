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


## WEAPON ITEMS

Sistem adaugat pentru arme ca iteme de inventar.

### Comanda admin

`/addweapon` - doar `admin_level >= 6` + `aduty` activ.

Campuri:
- `Item ID` - itemul din inventar, exemplu `pistol`
- `Weapon ID` - arma GTA, exemplu `WEAPON_PISTOL`
- `Weapon Name` - nume afisat, exemplu `Pistol`
- `Bullets Item ID` - itemul pentru gloante, exemplu `pistol_ammo`
- `Image`
- `Tradable`
- `Giveable`

### Cum functioneaza

- Cand playerul da `USE` pe arma, arma este pusa in mana.
- Cand da iar `USE` pe aceeasi arma, arma este scoasa.
- Cand trage, serverul scade `-1` din itemul de gloante setat la arma.
- Daca nu mai are gloante, arma este scoasa din mana.
- Daca arma este data cu GIVE, DROP, TAKEITEM sau WIPE, arma este scoasa automat din mana.
- Daca gloantele sunt scoase din inventar, arma este scoasa automat din mana.

### SQL

Ruleaza `SQL.sql`. Tabela noua:
- `inventory_weapons`

Pentru gloante creezi item normal cu `/additem`, de exemplu:
- item id: `pistol_ammo`
- stackable: `1`
- usable: `0`
- max stack: `999`
