# DriftZone Outfits - Set Outfit Trigger

## Ce este varianta asta

Este varianta cu:
- `/outfit`
- `/outfits`
- keybinds pe command `outfits`
- sex filter normal
- `/addoutfit` salveaza `sex = m/f`
- trigger/export ca sa setezi un outfit la cineva si sa salveze in `users.clothes`

## Trigger server-side

Din orice script server-side:

```lua
TriggerEvent('driftzone_outfits:server:setOutfit', targetSourceSauUid, outfitId)
```

Exemplu:

```lua
TriggerEvent('driftzone_outfits:server:setOutfit', 1, 3)
```

Asta seteaza outfit ID 3 la jucatorul source/UID 1, il aplica daca este online si salveaza in `users.clothes`.

## Export server-side

Recomandat:

```lua
local ok, result = exports.driftzone_outfits:SetOutfit(targetSourceSauUid, outfitId)
```

Silent, fara notificare la target:

```lua
local ok, result = exports.driftzone_outfits:SetOutfitSilent(targetSourceSauUid, outfitId)
```

## Trigger client admin-protected

Din client, doar admin 7+ aduty yes:

```lua
TriggerServerEvent('driftzone_outfits:server:adminSetOutfit', targetSourceSauUid, outfitId)
```

## Comanda admin

```txt
/setoutfit (id/uid) (outfitId)
```

Necesita admin 7+ si aduty yes.

## Keybinds config

In `driftzone_keybinds/config.lua`:

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

Nu folosi `O`, pentru ca la tine `O = nil`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_clothes
ensure driftzone_outfits
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_outfits
git commit -m "Add set outfit trigger"
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
```
