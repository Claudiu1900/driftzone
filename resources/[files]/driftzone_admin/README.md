# DriftZone Admin - cleanup fix + addcar

## Comenzi noi

```txt
/cleanup 10 s
/cleanup 10 m
/cancelcleanup
/addcar
/removecar id
```

## Acces

- `/cleanup` si `/cancelcleanup`: admin_level 3 + aduty yes
- `/addcar` si `/removecar`: admin_level 6 + aduty yes

## Fix cleanup

Cleanup-ul sterge acum masinile fara sofer prin doua metode:

1. client-side, pentru vehiculele controlate de jucatori/client;
2. server-side fallback, pentru vehiculele ramase pe server.

Asta rezolva problema cand `/cleanup 5 s` anunta corect, dar masinile abandonate nu primeau delete.

## Instalare

Pune folderul:

```txt
resources/driftzone_admin
```

Ruleaza `SQL.sql`, apoi:

```cfg
restart driftzone_admin
```


## Update tradeble

- `/addcar` are camp nou `tradeble` optional: `1` = masina poate fi folosita la trade, `0` = nu poate fi folosita la trade.
- SQL adauga automat coloana `vehiclenames.tradeble` cu default `1`.
