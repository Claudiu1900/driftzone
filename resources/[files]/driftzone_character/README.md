# DriftZone Character - Gender Outfit + Chat Commands Fix

## Fixuri noi

- Daca jucatorul intra in `/character` si schimba sexul:
  - male -> female: seteaza outfit-ul default de female;
  - female -> male: seteaza outfit-ul default de male.
- Setarea outfit-ului este silent, prin:
  - `exports.driftzone_outfits:SetOutfitSilent(...)`
  - `exports.driftzone_clothes:ReloadClothes(...)`
- Daca `users.clothes` este gol / `{}` si sexul nu s-a schimbat:
  - male primeste outfit ID din `Config.DefaultSavedOutfits.male`;
  - female primeste outfit ID din `Config.DefaultSavedOutfits.female`.
- `/character` si `/fixcharacter` raman RegisterCommand native.
- Adaugat `exports.driftzone_character:RunCommand(src, command, args)` pentru driftzone_chat custom.

## Config

In `config.lua`:

```lua
Config.DefaultSavedOutfits = {
    male = 1,
    female = 4
}
```

## Pentru driftzone_chat

Daca din F8 merg comenzile, dar din chat nu merg, chat-ul tau intercepteaza comenzile.
Adauga ruta in driftzone_chat:

```lua
character = 'driftzone_character',
fixcharacter = 'driftzone_character',
```

sau unde procesezi comenzile:

```lua
exports.driftzone_character:RunCommand(src, command, args)
```

## server.cfg order

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_clothes
ensure driftzone_outfits
ensure driftzone_character
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_character
git commit -m "Fix character gender outfits and chat commands"
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
restart driftzone_clothes
restart driftzone_character
```

Daca folosesti driftzone_chat custom, dupa ce adaugi ruta:

```txt
restart driftzone_chat
```
