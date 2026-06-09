# driftzone_blackjack

Sistem Blackjack pentru FiveM / DriftZone.

## Instalare

Pune folderul in:

```txt
resources/driftzone_blackjack
```

In `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_blackjack
```

Ruleaza:

```txt
SQL.sql
```

Apoi:

```cfg
restart driftzone_blackjack
```

## Comanda

```txt
/blackjack
```

## Functii

- UI NUI premium.
- Input miza in stanga.
- Bet minim/maxim configurabil.
- Max bet default: $1,000,000.
- Cash din `users.cash`.
- Joc server-side, nu se poate modifica din NUI.
- HIT / STAND / DOUBLE / SURRENDER.
- Blackjack payout 3:2.
- Dealer stand la 17.
- Logs in `blackjack_logs`.
- Daca inchide masa cu mana activa, pierde pariul.

## Config

In `config.lua` poti modifica:

```lua
Config.MinBet = 1000
Config.MaxBet = 1000000
Config.BlackjackPayout = 1.5
Config.WinPayout = 1.0
```
