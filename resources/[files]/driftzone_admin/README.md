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


## Update admin commands

Comenzi adaugate:

```txt
/lockveh sql_id
/unlockveh sql_id
/giveadm uid grad_0_7
/wipe uid
/givecash uid suma
/givedzcoins uid suma
/givevip uid zile
/removevip uid
/resettickets
```

Comenzile pentru masini au fost redenumite:

```txt
/giveveh uid model plate_optional
/takeveh uid id_masina
/transferveh uid_nou id_masina
/addveh
/removeveh id_database
```

Acces:
- `/lockveh`, `/unlockveh`: admin 4+ + aduty yes
- `/giveadm`, `/wipe`, `/removevip`, `/resettickets`: admin 6+ + aduty yes
- `/givecash`, `/givedzcoins`, `/givevip`: admin 7+ + aduty yes

`/nc` a fost refacut ca noclip complet invizibil, fara alpha vizibil pentru playeri.
