# driftzone_vehicless

Studio local pentru poze la masini.

## Comanda

```txt
/vehss model_name
```

Acces: `admin_level 6+` si `aduty yes`.

## Ce include

- Spawn local doar pentru adminul care foloseste comanda.
- Coordonate studio: `-75.243958, -818.716492, 326.173584`.
- Masina porneste rotita la `45°`.
- Camera este fixa in fata masinii si nu se mai roteste cand rotesti masina.
- Caracterul este dus sus si ascuns, ca sa nu mai intre in POV/screenshot.
- UI in stanga cu rotate, auto rotate, FOV, zoom, camera height, look height, lights, doors, reset.
- Poti scrie alt model in UI si apesi `LOAD` fara sa inchizi meniul.
- Screenshot prin `screenshot-basic`, cu download in browser.

## Instalare screenshot-basic

Resource-ul este aici:

```txt
https://github.com/citizenfx/screenshot-basic
```

Pe VPS/Linux:

```bash
cd /home/container/resources
mkdir -p "[local]"
cd "[local]"
git clone https://github.com/citizenfx/screenshot-basic.git screenshot-basic
```

In `server.cfg`:

```cfg
ensure screenshot-basic
ensure oxmysql
ensure driftzone_auth
ensure driftzone_vehicless
```

Daca nu ai `git` pe host, descarci ZIP-ul de pe GitHub, il extragi si folderul final trebuie sa fie exact:

```txt
resources/[local]/screenshot-basic
```

## Config util

In `shared/config.lua`:

```lua
Config.Studio.cameraHeading = 45.0 -- camera fixa
Config.Studio.heading = 45.0       -- rotatia initiala a masinii
Config.Studio.hidePlayer = true    -- ascunde playerul din poza
```
