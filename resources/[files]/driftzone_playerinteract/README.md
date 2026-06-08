# driftzone_playerinteract

Varianta curata si optimizata.

## Ce s-a schimbat

- scos tot UI-ul de selectie in afara cursorului;
- scos notificarea cand dai `/playerinteract`;
- cand selectezi playerul apare doar patratul cu nume/ID si butonul PAY;
- butonul PAY este mutat mai departe de patratul principal, ca sa nu se suprapuna;
- scos X, text ESC, texte de tutorial si background-uri mari;
- input-ul de suma nu mai are sageti de plus/minus;
- dupa confirmare PAY, UI-ul dispare imediat;
- click gol nu da notificari;
- selectia pe corpul playerului ramane optimizata.

## Instalare

Pune folderul `driftzone_playerinteract` in `resources`, apoi in `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```

Ruleaza `sql.sql` daca nu ai deja tabela `pay_logs`.
