# driftzone_playerinteract

Varianta curata cu UI-ul original premium pentru player selectat si PAY, dar fara background, fara selector text, fara crosshair, fara X si fara hint ESC.

## Instalare

Pune folderul `driftzone_playerinteract` in `resources` si ruleaza:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```

Dupa update:

```cfg
restart driftzone_playerinteract
```

## SQL

Ruleaza `sql.sql` daca nu ai tabela pentru `pay_logs`.
