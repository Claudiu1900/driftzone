# DriftZone Outfits - Commands + Keybinds + Sex Filter

## Fix

- Meniul se deschide din `/outfit`.
- Meniul se deschide din `/outfits`.
- Keybinds poate folosi `eventType = 'command'` cu `eventName = 'outfits'`.
- Nu exista RegisterKeyMapping intern in `driftzone_outfits`, deci nu mai deschide singur pe O.
- Sex filter ramane activ:
  - `m` pentru `mp_m_freemode_01`
  - `f` pentru `mp_f_freemode_01`
- `/addoutfit` salveaza automat `sex` in tabela `outfits`.

## Comenzi

```txt
/outfit
/outfits
/addoutfit (nume) (link imagine optional)
```

`/addoutfit` necesita admin 7+ si aduty yes.

## Ce pui in driftzone_keybinds/config.lua

Varianta recomandata:

```lua
{
    id = 'outfits',
    name = 'Outfits',
    description = 'Deschide meniul de outfit-uri',
    key = 'K',
    eventType = 'command',
    eventName = 'outfits',
    enabled = true
}
```

Daca vrei pe alta tasta, schimbi doar:

```lua
key = 'K'
```

Nu folosi `O`, pentru ca la tine in `Config.KeyMap` este `O = nil`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_clothes
ensure driftzone_outfits
```

## SQL

Ruleaza `SQL.sql` in baza `driftzone`, sau lasa resource-ul sa faca automat:

```sql
ALTER TABLE `outfits` ADD COLUMN IF NOT EXISTS `sex` ENUM('m','f') NOT NULL DEFAULT 'm' AFTER `image`;
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_outfits
git add -A resources/[files]/driftzone_keybinds
git commit -m "Fix outfits commands and keybind open"
git pull --rebase origin main
git push origin main
```

Pe VPS:

```bash
cd ~/server-data
git pull --rebase origin main
```

txAdmin:

```txt
restart driftzone_outfits
restart driftzone_keybinds
```
