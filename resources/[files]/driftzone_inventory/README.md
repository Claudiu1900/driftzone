# driftzone_inventory - DriftZone Inventory

Inventory DriftZone optimizat pentru framework propriu.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
```

Ruleaza `SQL.sql` daca nu ai tabelele sau daca vrei sa se adauge/actualizeze itemele default.

## Ce include versiunea aceasta

- `money` este item in `inventory_items`, dar suma reala vine din `users.cash`.
- Cand dai GIVE/DROP/PICKUP la `money`, se modifica `users.cash`.
- `dirtymoney` ramane currency special in inventory si are stack practic nelimitat.
- `money` si `dirtymoney` respecta setarile din `inventory_items` pentru `usable`, `giveable`, nume si imagine.
- Currency sloturile sunt intr-un card separat de inventarul normal.
- Inventarul normal ramane 7x7.
- Sub inventar exista 5 quick-use sloturi intr-un card separat.
- In quick sloturi poti pune doar iteme cu `usable = 1`.
- Daca un item este mutat dintr-un quick slot in alt quick slot, dispare automat din quick slotul vechi.
- Tastele `1`, `2`, `3`, `4`, `5` folosesc itemul pus in quick slotul respectiv.
- Comanda `/items` deschide lista completa din `inventory_items` si permite editarea itemelor.
- `/items` este doar pentru admin `admin_level >= 6` si `aduty` activ (`yes`, `true` sau `1`).
- `/additem` ramane separat si functioneaza ca inainte.

## Comenzi

```txt
/inventory
/additem
/items
/giveitem uid item_id amount
/takeitem uid item_id amount
/wipeinventory uid
```

## Note

- La `/items`, `item_id` este blocat la editare ca sa nu se strice itemele deja existente in inventarele jucatorilor.
- Quick sloturile sunt salvate in `inventory_json`, fara tabel nou.
- `money` nu este salvat in `inventory_json`; valoarea lui este citita din `users.cash`.
