# driftzone_playerinteract

Sistem FiveM pentru interactiune directa cu playerii.

## Comenzi

```txt
/playerinteract
```

## Ce face

- deschide cursorul si modul de selectie;
- selectia merge pe tot corpul playerului, nu doar pe cap;
- cand cursorul este pe player, apare cerc albastru rotativ la picioare;
- click pe player deschide UI radial modern;
- afiseaza doar functiile valide;
- momentan exista functia PAY;
- click in gol nu mai trimite notificare;
- PAY verifica `users.cash`, muta banii si salveaza log in `pay_logs`.

## SQL

Ruleaza `sql.sql`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```
