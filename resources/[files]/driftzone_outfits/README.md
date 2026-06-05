# DriftZone Outfits Optimized

Resource FiveM pentru outfit-uri globale.

## Comenzi

```txt
/outfit
/outfits
/addoutfit (nume) (link imagine optional)
```

Tasta `O` deschide meniul.

`/addoutfit` este valabil doar pentru admin 7+ cu `aduty = yes`.

## Ce salveaza /addoutfit

Salveaza doar:
- mask
- hat
- jacket
- torso
- top
- pants
- shoes
- insignia
- glasses

Nu salveaza hair.

## Update

- Cardurile sunt acum verticale, cu inaltime mai mare jos-sus.
- Imaginea are spatiu mare pentru poza cu caracterul.
- Butonul `WEAR` nu mai iese din card.
- `WEAR` sta jos in card cu `margin-top: auto`.
- UI-ul foloseste `object-fit: cover` si `object-position: center top`.
- Script JS optimizat: update la cooldown doar cand textul se schimba.
- Server optimizat:
  - cache pentru lista de outfit-uri;
  - cache pentru outfit by id;
  - cache scurt pentru admin data;
  - cache scurt pentru clothes user;
  - curata cache la playerDropped;
  - curata cache outfit cand se adauga outfit nou.

## Instalare

1. Pune folderul `driftzone_outfits` in `resources/[driftzone]/`.
2. Ruleaza `SQL.sql`.
3. In `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_clothes
ensure driftzone_outfits
```

4. Restart:

```cfg
restart driftzone_outfits
```

## Chat custom

Daca folosesti `driftzone_chat`, ruta este:

```lua
exports.driftzone_outfits:RunCommand(src, command, args)
```
