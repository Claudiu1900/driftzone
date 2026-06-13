# driftzone_vehicless - fixed FiveM

Resource FiveM pentru studio local de poze la masini.

## Comenzi

```txt
/vehss model_name
/vehssclose
```

Exemplu:

```txt
/vehss s15
```

Acces implicit: `admin_level >= 6` sau `admin >= 6` si `aduty = yes` in tabela `users`.

## Ce s-a reparat in versiunea asta

- Screenshot-ul NU se mai bazeaza pe download-ul browserului CEF, pentru ca poate afisa succes dar sa nu salveze nimic local.
- Poza este salvata server-side in `driftzone_vehicless/screenshots/`.
- NUI trimite poza pe bucati mici catre client/server, ca sa nu crape de la payload mare.
- Resource-ul nu mai are dependency pe `screenshot-basic`.
- Resource-ul nu mai are dependency pe `yarn`, `webpack`, `dist/screenshot.js` sau TypeScript build.
- Comanda `/vehss` este inregistrata si client-side si server-side.
- Daca `oxmysql` sau `driftzone_auth` nu sunt pornite, resource-ul nu mai crapa; doar iti da mesaj ca nu ai acces/logare.
- Camera ramane fixa cand rotesti masina.
- Se roteste doar masina.
- Playerul este mutat temporar in studio pentru loading, dar la inchidere revine la pozitia initiala.
- UI-ul are buton de close si exista `/vehssclose` daca se blocheaza focusul.

## Instalare

1. Opreste serverul.
2. Sterge folderul vechi `driftzone_vehicless` complet.
3. Pune folderul nou `driftzone_vehicless` in `resources/[driftzone]/` sau unde tii tu resursele.
4. In `server.cfg` pune:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_vehicless
```

Daca nu folosesti `driftzone_auth`, seteaza in `shared/config.lua`:

```lua
Config.RequireLogin = false
```

Daca ai coloana admin numita doar `admin`, lasa asa: config-ul are fallback automat.

## Unde se salveaza pozele

Se salveaza pe server aici:

```txt
resources/[driftzone]/driftzone_vehicless/screenshots/
```

Exemplu nume fisier:

```txt
driftzone_s15_1789654321.png
```

In consola serverului apare si linia:

```txt
[DRIFTZONE_VEHICLESS] Screenshot saved: .../driftzone_vehicless/screenshots/...
```

## Important

Folderul `screenshots` trebuie sa ramana in resource. L-am pus deja in zip cu `.keep`.

Daca nu se salveaza, verifica:

- consola serverului pentru `[DRIFTZONE_VEHICLESS] Screenshot saved` sau eroare;
- sa ai folderul `screenshots` in resource;
- sa fi sters complet versiunea veche;
- sa nu mai ai `ensure screenshot-basic`, `ensure yarn`, `ensure webpack` pentru acest resource.

## Structura

```txt
driftzone_vehicless/
  fxmanifest.lua
  shared/config.lua
  server/main.lua
  client/main.lua
  html/index.html
  html/style.css
  html/script.js
  screenshots/.keep
```
