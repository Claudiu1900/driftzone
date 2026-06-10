# driftzone_inventory

Inventory DriftZone optimizat.

## Funcții

- 49 sloturi, 7x7.
- Sloturi pătrate.
- Drag & drop între sloturi.
- Imaginea itemului umple tot slotul.
- Fără header, fără DZ, fără X, fără numere pe sloturi.
- Click dreapta pe item: nume item + USE / GIVE / DROP.
- Numele nu mai apare la hover.
- GIVE: închide inventarul, apare selectorul de player, verifică sloturile țintei și trimite itemul.
- DROP: aruncă itemul la locația playerului.
- Drop-urile în radius 4m se combină într-un singur punct.
- Dropped items apar în dreapta când ești în radius 4m.
- Itemele din Dropped Items se pot trage în inventar.
- Marker albastru spre pământ la locația drop-ului.
- Admin UI `/additem`.
- Comenzi admin: `/giveitem`, `/takeitem`, `/wipeinventory`.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
```

Rulează:

```txt
driftzone_inventory/SQL.sql
```

Restart:

```cfg
restart driftzone_inventory
```
