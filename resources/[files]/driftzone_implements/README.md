# DriftZone Implements - Clean

## v2.3.0

Fix CTRL/stealth:
- Am scos `RegisterKeyMapping` de pe CTRL ca sa nu se bata cu GTA stealth.
- CTRL este prins direct prin `IsDisabledControlJustPressed(36)`.
- Controlul 36 este blocat intr-un thread separat 0ms.
- `SetPedStealthMovement(false)` si `SetPedUsingActionMode(false)` ruleaza constant.
- Cand apesi CTRL, nu mai intra in stealth, ci face toggle la crouch.
- Ai si comanda `/crouch` pentru test.

Stats:
- `users.stats` incarca `health` si `armour`.
- Ai comanda `/loadstats` pentru test manual daca vrei sa verifici rapid.

## users.stats

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
