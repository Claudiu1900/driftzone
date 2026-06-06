# DriftZone Character - Fixed Creator + Default Outfit

## Fixuri

- In character creator, caracterul este dezbracat/curatat mai bine pentru editare.
- La slider/update nu mai da `SetPlayerModel` de fiecare data.
  Asta rezolva bug-ul cand caracterul dispare si apare iar.
- Dupa save caracter:
  - verifica `users.clothes`;
  - daca este gol / `{}` / `null`, seteaza outfit default silent:
    - male: `Config.DefaultSavedOutfits.male`
    - female: `Config.DefaultSavedOutfits.female`
  - apoi da reload la haine prin `driftzone_clothes`, fara notificari.
- Foloseste `exports.driftzone_outfits:SetOutfitSilent(...)`.
- Foloseste `exports.driftzone_clothes:ReloadClothes(...)`.

## Config important

In `config.lua`:

```lua
Config.DefaultSavedOutfits = {
    male = 1,
    female = 4
}
```

Poti schimba ID-urile de outfit acolo.

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
git commit -m "Fix character creator and default outfits"
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
restart driftzone_character
```

Recomand dupa update:

```txt
restart driftzone_outfits
restart driftzone_clothes
restart driftzone_character
```
