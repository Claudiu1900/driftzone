# driftzone_tunning

Versiune optimizata DriftZone.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_tunning
```

Ruleaza SQL-ul doar daca nu ai tabelele create:

```txt
driftzone_tunning/SQL.sql
```

## Update inclus

- UI refacut: mai curat, mai premium, fara elemente suprapuse in bara de jos.
- Bara de jos este mai inalta si optiunile au spatiu corect.
- A fost scoasa caseta cu textul despre ` camera libera si ESC.
- Cand apesi `, meniul ramane vizibil normal, nu se mai face transparent.
- Gradient Preview este strict preview: nu intra in cos, nu se cumpara si nu se salveaza.
- Daca dai Pay dupa un gradient preview, gradientul se curata inainte de cumparare.
- Daca incerci sa cumperi doar gradient preview, masina revine la tuning-ul stabil si nu ramane gradientul.
- Masina primeste freeze cand intri in tuning si revine la starea initiala cand iesi.
- Open Wheel este scos.
- In meniul principal apare doar Wheels, apoi in interior alegi tipul de roti.

## Comenzi

```txt
/tuning
/tune
/tunning
```

`/tunning` este comanda admin configurata in `config.lua`.
