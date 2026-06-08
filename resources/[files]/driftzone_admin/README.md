# DriftZone Admin - cleanup + addcar

## Comenzi adaugate

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

## Ce face

- `/cleanup` porneste timer si anunta tot serverul. La final sterge toate vehiculele fara sofer.
- `/cancelcleanup` anuleaza orice cleanup activ.
- `/addcar` deschide UI si adauga masina in `vehiclenames`.
- `/removecar id` sterge masina din `vehiclenames`.
- Toate comenzile se logheaza in `admin_command_logs`.

## Instalare

Ruleaza `SQL.sql`, apoi pune folderul:

```txt
resources/driftzone_admin
```

Restart:

```cfg
restart driftzone_admin
```
