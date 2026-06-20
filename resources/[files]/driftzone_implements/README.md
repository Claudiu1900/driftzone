# DriftZone Implements - Clean

## v2.2.0

Fixuri:
- CTRL nu mai intra in stealth mode.
- CTRL este prins cu `RegisterKeyMapping` si pune playerul pe crouch custom.
- stealth/action mode este fortat OFF in fiecare frame.
- camera AFK / idle cinematic ramane dezactivata.
- health/armour din `users.stats` se incarca mai agresiv dupa spawn.
- daca UID-ul nu exista imediat in state/export, incearca fallback pe identificatori din DB.

## users.stats

Exemplu:

```json
{"health": 100, "armour": 0, "food": 61, "water": 81}
```

Citeste doar:
- `health`
- `armour`

`health = 100` devine full HP in GTA.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_implements
```
