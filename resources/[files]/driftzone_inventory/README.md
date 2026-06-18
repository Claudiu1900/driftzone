# driftzone_inventory - Money, Quick Slots, Items Panel, Clothes Equipment

Resource complet DriftZone Inventory cu:

- sloturi speciale `money` / `dirtymoney`;
- `money` sincronizat cu `users.cash`;
- 5 quick-use slots cu tastele 1-5;
- `/items` pentru editarea itemelor din `inventory_items`;
- sistem de haine direct in inventar;
- sloturi de haine pe corp in partea stanga a inventarului;
- `/addclothes` pentru adaugare haine in `clothes_items`;
- `/clothesitems` pentru listare/editare haine din `clothes_items`;
- tabela `users_clothes` pentru hainele echipate pe fiecare categorie;
- auto-load fortat la haine dupa join/spawn, cu retry-uri.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
```

Ruleaza `SQL.sql`. Acest SQL contine doar partea noua de haine: `clothes_items` si `users_clothes`.

## Comenzi admin

Toate cer `admin_level >= 6` si `aduty` activ (`1`, `yes`, `true` sau `on`).

```txt
/addclothes
/clothesitems
/items
/additem
/giveitem uid item_id amount
/takeitem uid item_id amount
/wipeinventory uid
```

## Categorii haine suportate

- `jacket` - component 11
- `top` - component 8
- `torso` - component 3
- `mask` - component 1
- `shoes` - component 6
- `pants` - component 4
- `accessories` - component 7
- `watches` - prop 6
- `bracelets` - prop 7
- `vest` - component 9
- `bag` - component 5
- `hat` - prop 0
- `glasses` - prop 1

Aliasuri acceptate in config: `jaket`, `jacheta`, `acecessories`, `accesorii`, `bratari`, `palarie`, etc.

## Cum functioneaza hainele

1. Adminul creeaza item de haina cu `/addclothes`.
2. Itemul este salvat in `clothes_items`.
3. Itemul poate fi dat cu `/giveitem uid item_id amount`.
4. Jucatorul trage itemul in slotul corect de pe corp.
5. Resource-ul aplica haina pe ped si salveaza in `users_clothes`.
6. La spawn/join, hainele din `users_clothes` sunt reaplicate automat de mai multe ori.

## Note

- Itemele de haine nu sunt salvate in `inventory_items`; sunt citite direct din `clothes_items`.
- `money` ramane item logic, dar valoarea reala este `users.cash`.
- Quick slots raman salvate in `inventory_json`.
