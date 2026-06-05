# driftzone_tunning optimized

Versiune optimizata fara schimbare de UI.

## Optimizari client
- categoryMap pentru lookup rapid;
- nu mai face loop prin toate categoriile la fiecare preview;
- requestControl mai rar si mai scurt;
- SetVehicleModKit nu mai este apelat inutil de mai multe ori;
- bulk apply/reset foloseste un singur control/modkit;
- preview NUI este throttled usor ca sa nu spameze clientul cand misti color picker-ul;
- cache semnaturi applyVehicle curatat ca sa nu creasca permanent;
- loop-ul principal doarme 350ms cand meniul este inchis.

## Optimizari server
- cache UID 30 secunde;
- cache cash scurt;
- getCash nu mai este facut de doua ori dupa plata;
- SQL identifiers sunt escapate;
- calculatePrice ignora duplicate keys;
- cleanup cache la playerDropped.

## Instalare
Inlocuieste folderul:

```txt
resources/[driftzone]/driftzone_tunning
```

Apoi:

```cfg
restart driftzone_tunning
```
