# driftzone_vehicless

Studio local pentru poze la masini.

## Comanda

```txt
/vehss model_name
```

Acces: `users.admin_level >= 6` si `users.aduty = yes/1/true`.

## Ce face

- Spawneaza masina doar pentru adminul care a folosit comanda.
- Coordonate studio: `-75.243958, -818.716492, 326.173584`.
- Masina porneste rotita la 45 grade.
- Camera este in fata masinii.
- UI in stanga cu:
  - rotate stanga/dreapta;
  - auto rotate;
  - FOV mic/mare;
  - zoom in/out;
  - camera mai jos/sus;
  - lights on/off;
  - doors on/off;
  - reset view;
  - screenshot.

## Screenshot

Pentru screenshot trebuie pornit resource-ul `screenshot-basic`.

```cfg
ensure screenshot-basic
ensure oxmysql
ensure driftzone_auth
ensure driftzone_vehicless
```

Screenshot-ul este salvat de browser in folderul `Downloads` sau in folderul ales de tine la download. FiveM nu poate scrie direct intr-un folder arbitrar din PC-ul jucatorului fara download/browser permission.

## Instalare

```txt
resources/driftzone_vehicless
```

In `server.cfg`:

```cfg
ensure screenshot-basic
ensure oxmysql
ensure driftzone_auth
ensure driftzone_vehicless
```
