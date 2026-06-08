# driftzone_showroom

FiveM showroom pentru DriftZone.

## Server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_interactions
ensure driftzone_garage
ensure driftzone_showroom
```

## Comenzi

```txt
/showroom
/sr
```

## Interacțiune

Apare pe hartă la coordonatele din `config.lua` și se deschide cu `E` prin `driftzone_interactions`.

## Rotire mașină preview

În showroom, ține click în zona mașinii și mișcă mouse-ul stânga/dreapta.

## Bază de date

Folosește `users.cash`, nu `money`.

Showroom-ul citește mașinile din `vehiclenames`.
Acceptă coloane:

- `vehicle_model`
- `vehicle_name`
- `price` sau `vehicle_price`
- `image` sau `vehicle_image`
- `category`
- `selling`

Când cumperi, inserează în `ownedvehicles`.


FIX inclus: showroom-ul citeste pretul corect din `vehiclenames.price` daca `vehicle_price` este 0, sau din `vehicle_price` daca acela este folosit. Preview/test drive seteaza primary si secondary pe alb.


## Update optimizare preview

- Fix pentru bugul în care prima mașină rămânea în showroom după schimbarea selecției.
- Preview-ul are `request id`, deci dacă schimbi rapid mașinile, modelul vechi nu mai poate apărea după modelul nou.
- La închidere se șterge forțat mașina de preview și camera.
- UI-ul nu mai re-randează toată lista la fiecare click; schimbă doar cardul activ.
- Rotirea mașinii este throttled prin `requestAnimationFrame`, deci trimite mai puține NUI callbacks.
- Serverul cache-uiește lista de mașini 30 secunde ca să reducă query-urile MySQL.


## Update VIP

- Adaugă coloana `vehiclenames.vip`.
- `0` = mașină normală.
- `1` = mașină VIP.
- Mașinile VIP apar și în categoria lor normală, dar au badge `VIP`.
- Categoria `VIP` este penultima și listează toate mașinile VIP.
- La cumpărare verifică `users.vip`; dacă nu este `1`, jucătorul primește mesaj că are nevoie de VIP.

## Fix extra preview vehicle

Preview-ul nu se mai creează și din client și din UI în același timp. Acum UI-ul trimite un singur `preview`, iar clientul curăță toate preview-urile locale înainte să creeze mașina nouă.


## Update apear showroom

Am adaugat filtrul `vehiclenames.apear`:

- `apear = 1` masina apare in showroom;
- `apear = 0` masina nu apare deloc in showroom si nu poate fi cumparata prin request direct;
- daca vechea tabela nu are coloana, ruleaza `SQL.sql`.

Exemplu:

```sql
UPDATE vehiclenames SET apear = 0 WHERE vehicle_model = 'modelul_masinii';
UPDATE vehiclenames SET apear = 1 WHERE vehicle_model = 'modelul_masinii';
```
