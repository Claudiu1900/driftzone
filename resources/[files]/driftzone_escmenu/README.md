# DriftZone ESC Menu

## Fix MAP / SETTINGS

- MAP si SETTINGS inchid NUI-ul si deschid automat meniul default GTA.
- Deschiderea foloseste `ActivateFrontendMenu` + `SetPauseMenuActive`, cu retry.
- Cat timp meniul default GTA este activ, ESC nu este blocat.
- Daca apesi ESC in meniul default, se inchide doar meniul default.
- Dupa ce iesi din meniul default, urmatorul ESC deschide iar ESC UI normal.
- Imaginile sunt `cover`, nu stretch.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_escmenu
```

## Imagini

```txt
logo.png              256x256 px
card_map.png          1200x520 px
card_garage.png       1200x520 px
card_ticket.png       1200x520 px
card_settings.png     1200x520 px
card_ui_settings.png  1200x520 px
card_shop.png         1200x520 px
card_keybinds.png     1200x520 px
card_discord.png      760x900 px
```
