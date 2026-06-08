# driftzone_races

Race lobby complet pentru DriftZone.

## Fixuri incluse

- Dupa Create Race se inchide flow-ul de create si se deschide direct party-ul.
- Dupa Join Race se inchide flow-ul de join si se deschide direct party-ul.
- Daca apesi E la interactiune si esti deja intr-un party, se redeschide party-ul tau.
- ESC in party inchide UI-ul, te pune READY automat si ramai in party.
- Update-urile normale de party nu redeschid UI-ul daca ai dat ESC.
- UI refacut complet, stil Apple/futuristic, fara backdrop-filter/filter.
- Race-ul ramane in routing bucket privat, cu ghost/no collision intre participanti.
- Dupa finish, playerii sunt teleportati la hub.

## Interactions config

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


## UI update
- Scos cardul ONLINE Race System din header.
- Butonul X este refacut mai curat si premium.


## XP rewards

Fiecare race are XP configurabil in `config.lua`:

```lua
xp = { winner = 1200, loser = 350 }
```

La final:
- castigatorul primeste `xp.winner` in `users.xp`;
- pierzatorii primesc `xp.loser` in `users.xp`;
- daca un player iese in timpul cursei, primeste XP-ul de loser.

Ruleaza `sql.sql` ca sa existe coloana `users.xp`.
