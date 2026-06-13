# driftzone_vehicless v4

Fix pentru crash-ul:

```txt
Reliable network event size overflow:
driftzone_vehicless:server:screenshotChunk
```

Resource-ul NU mai trimite poza prin event-uri net pe bucati. Asta era cauza crash-ului.

## Instalare

1. Sterge folderul vechi `driftzone_vehicless`.
2. Pune folderul nou `driftzone_vehicless`.
3. In `server.cfg` pune exact in ordinea asta:

```cfg
ensure screenshot-basic
ensure driftzone_vehicless
```

Nu pune `yarn`, `webpack` sau alte build-uri pentru acest resource.

## Comanda

```txt
/vehss model_name
```

Exemplu:

```txt
/vehss s15
```

Close fortat daca se blocheaza UI-ul:

```txt
/vehssclose
```

## Screenshot-uri

Pozele se salveaza pe server in:

```txt
driftzone_vehicless/screenshots/
```

Numele fisierului este modelul masinii:

```txt
s15.png
rmodm4.png
supra.png
```

Daca vrei sa nu suprascrie aceeasi masina, modifica in `shared/config.lua`:

```lua
Config.Screenshot.overwriteSameModel = false
```

## Alte fix-uri

- masina spawneaza primary alb si secondary alb;
- camera ramane fixa;
- se roteste doar masina;
- playerul revine la pozitia lui dupa close;
- nu mai exista event `screenshotChunk`;
- nu mai exista salvare prin NUI base64, deci nu mai apare network event overflow.
