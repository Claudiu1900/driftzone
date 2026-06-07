# driftzone_races

Multiplayer race lobby pentru DriftZone.

## Comenzi

```txt
/draces - test open menu
```

Normal se deschide prin `driftzone_interactions`.

## driftzone_interactions config

Adauga in `Config.DefaultInteractions`:

```lua
{
    id = 'driftzone_races_main',
    coords = vector3(-1336.180176, -3044.254882, 14.890136),
    range = 2.8,
    key = 'E',
    text = 'Apasa E pentru Race Lobby',
    subText = 'DriftZone Races',
    marker = true,
    event = 'driftzone_races:client:openFromInteraction',
    blip = { sprite = 315, color = 3, scale = 0.85, name = 'DriftZone Races' }
},
```

## SQL

Ruleaza `sql.sql`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_races
```

## Note

- Masinile apar dupa `ownedvehicles.owner_id = users.uid`.
- Pentru Drift Race apar doar masinile din `vehiclenames.type = 'drift'`.
- Race-ul ruleaza in routing bucket privat.
- Playerii au ghost/no-collision intre vehicule in cursa.
- Potul este entryFee x players minus 10%.
