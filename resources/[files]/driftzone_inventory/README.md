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

## Update drag/drop + amounts

- Inventarul se deschide pe tasta `I`.
- Drag & drop este optimizat cu event delegation + requestAnimationFrame.
- Pentru iteme stackable cu mai mult de 1 bucata, DROP si GIVE deschid selector de cantitate cu slider, input, MIN si MAX.


## Update selector give
- GIVE nu mai deschide inventarul la jucatorul care primeste itemul.
- Selectorul de player este curat: fara crosshair, fara UI extra, doar cursor normal si cercul albastru sub player cand treci cu mouse-ul peste el.
- Inputul de cantitate nu mai afiseaza sagetile native + / -.


## Gradient items

In `/additem` ai campuri noi:
- `Gradient Item` = 1 daca itemul trebuie sa deschida meniul de gradient;
- `Gradient ID` = ID-ul gradientului din `driftzone_gradients`.

Cand `Gradient Item = 1`, itemul devine automat:
- item_id: `ID_gradient`, de exemplu `16_gradient`;
- usable: 1;
- giveable: 1;
- stackable: 1.

Cand dai USE pe item, inventarul deschide `driftzone_gradients`. Itemul este sters de `driftzone_gradients` doar dupa ce gradientul a fost aplicat cu succes pe masina.
