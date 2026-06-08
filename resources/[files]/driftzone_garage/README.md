# driftzone_garage

Garaj FiveM optimizat, cu UI-ul vechi pastrat, sistem VIP, tuning fortat si cooldown la spawn.

## Comenzi

```txt
/garage
/garaj
/park
```

Nu exista keybind pe M.

## VIP

- `users.vip` trebuie sa aiba o valoare valida ca playerul sa fie considerat VIP.
- `ownedvehicles.vip = 1` inseamna masina VIP.
- Masinile VIP apar doar in tab-ul VIP si doar daca playerul are VIP activ.

## Tuning fortat

Bug rezolvat: masina nu mai trebuie sa iasa fara tuning.

La spawn, garajul:
- citeste `ownedvehicles.vehicle_tunning`;
- pune tuning-ul in statebag:
  - `dz_garage_tuning`
  - `vehicleTunning`
  - `dz_vehicle_tunning`
- aplica tuning direct client-side;
- trimite si event catre `driftzone_tunning`;
- reaplica tuning-ul de mai multe ori dupa spawn pentru race conditions de streaming/network control.

## Cooldown

- `Config.SpawnCooldownMs = 3000`
- playerul nu poate spama spawn masini mai repede de 3 secunde.

## Optimizari

- spawn lock server-side pentru spam dublu;
- cooldown server-side + debounce NUI;
- tuning raw normalizat;
- statebag complet pentru masini din garaj;
- protectia masinilor si blip scan raman rarite;
- cleanup complet la `playerDropped` si `onResourceStop`.

## Instalare

Inlocuieste folderul:

```txt
resources/[files]/driftzone_garage
```

sau unde il ai tu in `resources`.

Asigura-te ca in `server.cfg` ai:

```cfg
ensure oxmysql
ensure [files]
```

sau direct:

```cfg
ensure driftzone_garage
```

`oxmysql` trebuie sa fie pornit inainte de `[files]`.

## Git update

Pe PC, dupa ce inlocuiesti folderul:

```bash
git add -A resources/[files]/driftzone_garage
git commit -m "Fix garage forced tuning and spawn cooldown"
git push
```

Pe VPS:

```bash
cd ~/server-data
git pull
```

Din txAdmin sau consola:

```txt
restart driftzone_garage
```

Daca masina are deja tuning salvat in `ownedvehicles.vehicle_tunning`, acum il forteaza la fiecare spawn.


## Block pentru curse

Garajul poate fi blocat temporar din alte scripturi, de exemplu in timpul curselor.
Cat timp este blocat, nu se mai deschide nici din comanda, nici din trigger, nici din interaction.
Jucatorul primeste notificarea: `Garaj indisponibil.`

Server-side:

```lua
exports['driftzone_garage']:SetGarageBlocked(source, true, 'Garaj indisponibil.')
exports['driftzone_garage']:SetGarageBlocked(source, false)
```

Client-side:

```lua
TriggerEvent('driftzone_garage:client:setBlocked', true, 'Garaj indisponibil.')
TriggerEvent('driftzone_garage:client:setBlocked', false)
```

Compatibil:

```lua
TriggerEvent('driftzone_garage:client:block', 'Garaj indisponibil.')
TriggerEvent('driftzone_garage:client:unblock')
```
