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
- Screenshot integrat direct in resource, cu download in browser. Cursorul revine automat daca apare o eroare.

## Screenshot integrat

Nu mai ai nevoie de `screenshot-basic`. Sistemul de screenshot este inclus in `driftzone_vehicless`, foloseste helper-ul intern bazat pe CfxTexture si descarca poza prin browser in Downloads / folderul ales de client.

Resource-ul foloseste `yarn` si `webpack` pentru bundle-ul intern de screenshot. Acestea sunt resurse standard din cfx-server-data; nu trebuie sa mai pornesti `screenshot-basic`.

## Config util

In `shared/config.lua`:

```lua
Config.Studio.cameraHeading = 45.0 -- camera fixa
Config.Studio.heading = 45.0       -- rotatia initiala a masinii
Config.Studio.hidePlayer = true    -- ascunde playerul din poza
```


## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_vehicless
```

Daca ai avut `screenshot-basic`, il poti sterge sau scoate din `server.cfg`.

## Fix screenshot

- Nu mai ramane cursorul blocat/disparut daca screenshot-ul da eroare.
- UI-ul se ascunde doar cat se face poza, apoi revine singur.
- Poza se descarca local, de obicei in `C:\Users\Nume\Downloads`.
