# DriftZone OverheadStats

Sistem optimizat pentru overhead UI fara comenzi.

## Triggere client-side

```lua
TriggerEvent('driftzone_overheadstats:client:showAll')
TriggerEvent('driftzone_overheadstats:client:hideAll')
TriggerEvent('driftzone_overheadstats:client:toggleAll')

TriggerEvent('driftzone_overheadstats:client:showPersonal')
TriggerEvent('driftzone_overheadstats:client:hidePersonal')
TriggerEvent('driftzone_overheadstats:client:togglePersonal')
```

## Logica toggle

- `showAll/hideAll/toggleAll` controleaza doar daca TU vezi overhead-urile celorlalti.
- `showPersonal/hidePersonal/togglePersonal` controleaza doar daca TU iti vezi propriul overhead.
- Daca tu dai `hidePersonal`, ceilalti jucatori inca iti vad overhead-ul.
- Daca tu dai `hideAll`, nu ii mai vezi pe ceilalti, dar iti vezi overhead-ul tau daca nu ai dat si `hidePersonal`.

## Server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_overheadstats
```


## Update join refresh

- Nu a fost schimbat UI-ul.
- Cand un player intra pe server, serverul ii face refresh la metadata aproape imediat.
- Clientul nou trimite `playerReady` rapid, ca overhead-ul sa se actualizeze mai repede.
- Serverul repune statebag-urile pentru toti jucatorii, ca playerul nou sa vada datele corecte.
