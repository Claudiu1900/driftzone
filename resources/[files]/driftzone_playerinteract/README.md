# driftzone_playerinteract

Sistem de interactiune cu playeri pentru FiveM.

## Comenzi

```txt
/playerinteract
```

Dupa comanda:
- apare mouse/camera select mode;
- cand pui cursorul pe un player apropiat apare cerc albastru la picioare;
- click pe player deschide meniul;
- momentan exista functia PAY.

## SQL

Ruleaza `sql.sql`.

## Server cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```

## Tabele folosite

- `users.uid`
- `users.cash`
- `pay_logs`

## Config

Schimbi tabele, coloane, limite pay si distanta in `config.lua`.
