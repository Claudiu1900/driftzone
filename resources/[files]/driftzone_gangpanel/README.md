# driftzone_gangpanel V3

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gangpanel
```

Rulează:

```txt
driftzone_gangpanel/SQL.sql
```

## Acces

Acces total:

```sql
UPDATE users SET sindicate = 1 WHERE uid = CNP_UL_TAU;
```

Comandă:

```txt
/gang
```

## Ce include

- Mafii cu ID pornind de la 1.
- Tipuri: Mafie Neoficiala / Mafie Oficiala.
- Când un jucător intră într-o mafie, `users.rank` primește shortcut-ul, iar `users.rankcolor` primește culoarea HEX.
- Logurile nu apar în meniu, dar se salvează în DB.
- Pentru membri apare doar Taxes.
- Pentru Lider / Co-Lider apar Dashboard, Members, Taxes, Venituri.
- Pentru Sindicat apar Gangs + management complet.
- Taxe cu selector de player ca la playerinteract.
- Plata taxei verifică cash, apoi bank.
- Veniturile din taxe merg în gang revenue.
- Liderul poate cere retragere. După 5-10 minute primește waypoint și revendică dirtymoney.
- Sindicat poate adăuga/scădea bani din venituri.
