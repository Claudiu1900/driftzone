# DriftZone Outfits - Trigger Only + Sex Filter

## Ce s-a schimbat

- Nu mai exista keybind intern pe `O`.
- Nu mai exista comanda client `/outfit` sau `/outfits`.
- Meniul se deschide doar prin trigger/export.
- `/addoutfit` ramane activ pentru admin 7+ cu `aduty = yes`.
- Cand creezi outfit cu `/addoutfit`, sistemul detecteaza ped-ul:
  - `mp_m_freemode_01` => `sex = 'm'`
  - `mp_f_freemode_01` => `sex = 'f'`
- In DB se adauga `outfits.sex`.
- La deschidere, jucatorul vede doar outfit-urile pentru sexul caracterului lui.
- La wear, serverul verifica iar sexul ca sa nu poata echipa outfit gresit.

## Trigger pentru deschidere

Din client:

```lua
TriggerEvent('driftzone_outfits:client:requestOpen')
```

Sau export client:

```lua
exports.driftzone_outfits:Open()
```

Din server, daca ai src:

```lua
exports.driftzone_outfits:Open(src, 'm')
exports.driftzone_outfits:Open(src, 'f')
```

## Pentru driftzone_keybinds

La keybind-ul setat de tine, pune client-side:

```lua
TriggerEvent('driftzone_outfits:client:requestOpen')
```

Astfel se deschide doar pe tasta setata in sistemul tau de keybinds, nu pe O.

## SQL

Ruleaza `SQL.sql` sau lasa resource-ul sa faca automat:

```sql
ALTER TABLE `outfits` ADD COLUMN IF NOT EXISTS `sex` ENUM('m','f') NOT NULL DEFAULT 'm' AFTER `image`;
```

## Instalare

In `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_clothes
ensure driftzone_outfits
```
