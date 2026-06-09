# driftzone_playerinteract

Sistem FiveM pentru interactiune directa cu playerii.

## Comanda

```txt
/playerinteract
```

## Actiuni

- `01` TRADE - schimb de masini/cash.
- `02` PAY - transfer cash.
- `03` BARBUT - duel cu zaruri pe cash.

## BARBUT

Flow:
1. Selectezi playerul.
2. Apesi `BARBUT`.
3. Daca nu ai cerere primita de la acel player, se deschide UI pentru suma si `INVITE`.
4. Celalalt player primeste notificare si accepta selectandu-te pe tine + `BARBUT`.
5. Se deschide UI cu zaruri la ambii.
6. Ambii apasa `READY`, zarurile ruleaza, serverul calculeaza castigatorul.
7. Castigatorul primeste potul minus 10% taxa.
8. `CLOSE` inchide la ambii. `RETRY` trebuie apasat de ambii.

## SQL

Ruleaza `sql.sql`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```
