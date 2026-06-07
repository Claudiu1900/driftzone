# driftzone_races

Race lobby pentru DriftZone.

## Update

- Dupa terminarea cursei, toti jucatorii sunt trimisi la `-1338.316528, -3047.960450, 13.929688, 331.65` si revin in bucket-ul normal.
- Dupa Create Race se inchide flow-ul de create si se deschide direct meniul de party.
- Dupa Join Race se inchide flow-ul de join si se deschide direct meniul de party.
- ESC in party inchide UI-ul si te pune READY automat, dar ramai in party.
- UI refacut complet, glass/futuristic, fara backdrop-filter/filter.
- Race-ul ramane in virtual world, cu ghost/no collision intre masini.

## Interactions

Adauga in `Config.DefaultInteractions` din `driftzone_interactions/config.lua`:

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

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_races
```

## SQL

Ruleaza `sql.sql`.
