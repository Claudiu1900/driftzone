# driftzone_playerinteract

Varianta finala curata si reparata.

## Fix-uri

- UI-ul de player selectat are acum CSS complet, nu mai apare ca HTML fara stil.
- PAY-ul este pe card premium/frumos.
- Am scos complet crosshair-ul/patratul din mijlocul ecranului.
- La selectie ramane doar cursorul normal.
- Nu exista text de selectie, X, ESC hint sau alte paneluri inutile.
- Butonul PAY este separat de cardul principal, ca sa nu se suprapuna peste nume/ID.
- Inputul de suma nu are sageti plus/minus.
- Dupa confirmare PAY, UI-ul dispare imediat.

## Instalare

Inlocuieste tot folderul `driftzone_playerinteract`, apoi ruleaza:

```cfg
restart driftzone_playerinteract
```

Daca nu exista tabela de loguri, ruleaza `sql.sql`.
