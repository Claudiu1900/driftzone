# driftzone_vehicless v5

Resource FiveM pentru studio poze masini.

## Ce a fost reparat in v5

- Am scos `dependency 'screenshot-basic'` din `fxmanifest.lua`, deci `driftzone_vehicless` porneste chiar daca `screenshot-basic` nu porneste.
- Nu mai exista `screenshotChunk`, deci nu mai iei kick/crash de la `Reliable network event size overflow`.
- Daca `screenshot-basic` este pornit corect, pozele se salveaza server-side in `screenshots/model.png`.
- Daca `screenshot-basic` lipseste sau nu porneste, comanda `/vehss` merge, UI-ul merge, masina se spawneaza, dar butonul de screenshot iti spune exact ce lipseste.
- Masina se spawneaza alb/alb.
- Screenshot-ul se numeste dupa model: `s15.png`, `rmodm4.png`, etc.

## Instalare minima

```cfg
ensure driftzone_vehicless
```

Cu asta porneste comanda si studioul, fara sa mai blocheze serverul din cauza la `yarn`.

## Pentru screenshot functional

Ai nevoie de `screenshot-basic` pornit corect. Daca iti apare:

```txt
Could not find dependency yarn for resource screenshot-basic
```

nu este problema din `driftzone_vehicless`, este problema din `screenshot-basic`: ai pus doar source-ul, dar lipsesc builder-ele `yarn` si `webpack`.

Server.cfg corect cand ai `screenshot-basic` reparat:

```cfg
ensure yarn
ensure webpack
ensure screenshot-basic
ensure driftzone_vehicless
```

Pe artifacts noi, `yarn` si `webpack` pot fi deja in system_resources. Daca tot iti zice ca lipsesc, ai artifact/server-data incomplet.

## Comenzi

```txt
/vehss model
/vehssclose
```

Exemplu:

```txt
/vehss s15
```

## Unde se salveaza pozele

```txt
resources/.../driftzone_vehicless/screenshots/model.png
```

## Config

In `shared/config.lua`:

```lua
Config.Screenshot.overwriteSameModel = true -- model.png mereu
Config.Screenshot.overwriteSameModel = false -- model.png, model_2.png, model_3.png
```
