# driftzone_racejob

Race Job FiveM standalone pentru DriftZone.

## Ce face

- se deschide prin `driftzone_interactions`;
- citeste masinile jucatorului din `ownedvehicles`, dupa `owner_id = uid`;
- meniul are Short Race, Medium Race, Long Race;
- momentan doar Short Race este activa;
- jucatorul selecteaza masina si apasa START;
- daca masina este deja spawnata prin `driftzone_garage`, resource-ul incearca sa o stearga;
- spawneaza masina la start;
- pune waypoint pe harta pentru fiecare checkpoint;
- checkpointurile sunt albastre;
- la finish adauga in `users.cash` intre 2000 si 5000.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_garage
ensure driftzone_racejob
```

## Config pentru driftzone_interactions

Adauga in `Config.DefaultInteractions` din `driftzone_interactions/config.lua`:

```lua
{
    id = 'driftzone_racejob_main',
    coords = vector3(-116.835160, -604.720886, 36.272584),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Job',
    subText = 'DriftZone Race Job',
    marker = true,
    event = 'driftzone_racejob:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Race Job' }
},
```

## Comanda test

```txt
/racejob
```


## Fix 1.0.1

- Reparat eroarea `SetVehicleEngineOn` nil server-side.
- Motorul, reparatia si dirt-ul masinii se aplica client-side dupa spawn, unde native-ul exista sigur.
