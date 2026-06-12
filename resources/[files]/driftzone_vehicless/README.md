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

## Ce s-a reparat

- Resource-ul nu mai are dependency pe `screenshot-basic`.
- Resource-ul nu mai are dependency pe `yarn`, `webpack`, `dist/screenshot.js` sau TypeScript build.
- Comanda `/vehss` este inregistrata si client-side si server-side.
- Daca `oxmysql` sau `driftzone_auth` nu sunt pornite, resource-ul nu mai crapa; doar iti da mesaj ca nu ai acces/logare.
- Camera ramane fixa cand rotesti masina.
- Se roteste doar masina.
- Playerul este mutat temporar in studio pentru loading, dar la inchidere revine la pozitia initiala.
- UI-ul are buton de close si exista `/vehssclose` daca se blocheaza focusul.
- Screenshot-ul se face intern din NUI prin WebGL/Cfx game-view si se descarca local prin browser.

## Instalare

1. Sterge folderul vechi `driftzone_vehicless`.
2. Pune folderul nou in `resources/[driftzone]/driftzone_vehicless` sau unde tii tu resursele.
3. In `server.cfg` pune:

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

## Permisiune ACE optionala

Daca vrei sa testezi fara baza de date, poti da ACE:

```cfg
add_ace group.admin driftzone.vehicless allow
```

sau:

```cfg
add_ace group.admin command.vehss allow
```

## Unde se salveaza pozele

Poza se descarca pe PC-ul jucatorului/adminului care apasa `SCREENSHOT`, de obicei in `Downloads`. FiveM nu poate salva direct in folderul serverului/clientului fara download sau upload extern.

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
```
