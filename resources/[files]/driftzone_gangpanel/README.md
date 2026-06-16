# driftzone_gangpanel V4 Premium

Sistem pentru mafii / sindicat pe DriftZone.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gangpanel
```

Rulează SQL-ul:

```txt
driftzone_gangpanel/SQL.sql
```

Pentru acces total:

```sql
UPDATE `users` SET `sindicate` = 1 WHERE `uid` = CNP_UL_TAU;
```

## Update V4

- Fix acces `users.sindicate = 1` + fallback `users.syndicate`.
- Tax categories nu mai sunt create automat. Se creează manual din panoul de Sindicat.
- UI refăcut premium, fără `backdrop-filter`.
- Selectorul de jucător pentru taxe închide meniul complet și nu mai afișează crosshair / plus / UI.
- Pentru selectare: te uiți spre jucător și apeși `E` sau click stânga.
- Membrii simpli văd doar Taxe.
- Lider / Co-Lider văd Dashboard, Membri, Taxe, Venituri.
- Sindicat vede Gangs și poate crea/edita mafii, categorii și venituri.
- Când adaugi un membru, se setează automat `users.rank = shortcut` și `users.rankcolor = color`.
- Logurile se salvează doar în database, nu apar în UI.

## Tabele

- `gangs`
- `gang_members`
- `gang_tax_categories`
- `gang_tax_records`
- `gang_revenue_logs`
- `gang_withdrawals`
- `gang_logs`

## Dirty money

La revendicarea veniturilor, liderul primește itemul:

```txt
dirtymoney
```

Resource-ul încearcă exportul `driftzone_inventory:GiveItem`. Dacă nu există, folosește fallback direct pe tabela `inventory`.

## V5 - driftzone_implements + waypoint personal

- Retragerile folosesc acum `driftzone_implements` / eventurile compatibile `driftzone_interactions`.
- Când liderul primește locația, waypointul, markerul și promptul apar doar la liderul respectiv.
- Nu mai trimite promptul locației pentru tot orașul.
- Markerul de ridicare este controlat prin `driftzone_implements`, iar `gangpanel` doar validează revendicarea pe server.

În `server.cfg` pune:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_implements
ensure driftzone_gangpanel
```
