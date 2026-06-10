# driftzone_inventory

Inventory FiveM pentru DriftZone.

## Functii

- 49 sloturi: 7 pe rand x 7 randuri.
- Sloturi patrate.
- Drag & drop intre sloturi.
- Stack automat pentru iteme stackable.
- Save in baza de date in tabela `inventory`.
- Itemele sunt definite in `inventory_items`.
- Click dreapta pe item: arata meniul minimal cu nume si actiuni.
- UI curat, fara texte inutile.
- Give catre player prin event pentru `driftzone_playerinteract`.
- Admin panel `/additem` pentru creare iteme.

## Comenzi

```txt
/inventory
/additem
/giveitem uid item_id bucati
/takeitem uid item_id bucati
/wipeinventory uid
```

Comenzile admin cer admin 6+ si aduty yes.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
```

Ruleaza `SQL.sql`, apoi:

```cfg
restart driftzone_inventory
```

## Integrare cu driftzone_playerinteract

Adauga un action card nou in playerinteract, de exemplu `GIVE ITEM`, iar cand este apasat sa trimita serverId-ul targetului la:

```lua
TriggerEvent('driftzone_inventory:client:openGiveToPlayer', targetServerId)
```

Pentru test poti folosi:

```txt
/giveinv id
```

## Exporturi server

```lua
exports.driftzone_inventory:GiveItem(uid, itemId, amount)
exports.driftzone_inventory:TakeItem(uid, itemId, amount)
exports.driftzone_inventory:GetInventory(uid)
exports.driftzone_inventory:HasSpaceForItem(uid, itemId, amount)
```
