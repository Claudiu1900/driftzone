# driftzone_racejob

Race job complet pentru DriftZone.

## Functii

- Short Race, Medium Race, Long Race.
- SPECIAL Duo Race cu invite prin ID si accept prin `/jobaccept <id>`.
- Fiecare cursa ruleaza in routing bucket separat.
- La finish/fail masina este stearsa si playerul este teleportat inapoi.
- Daca jucatorul coboara din masina in timpul cursei, pierde cursa.
- Cooldown persistent prin KVP.
- `/rracecd <id>` reseteaza cooldown-ul la curse pentru un jucator.
- Duo Race imparte cash si XP 50/50.

## SQL

Ruleaza `sql.sql`.

## Interactions

Copiaza continutul din `driftzone_interactions_config_add.lua` in `Config.DefaultInteractions` din `driftzone_interactions/config.lua`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_racejob
```
