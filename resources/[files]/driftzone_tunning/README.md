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

## Update tunable

- Adaugă coloana `vehiclenames.tunable`.
- `1` = masina poate intra in tunning.
- `0` = masina nu poate intra in tunning.
- Dacă este `0`, jucătorul primește mesajul: `Aceasta masina nu se poate modifica!`.
- Verificarea este server-side și se face și la deschidere, și la plata modificărilor.

SQL:

```sql
ALTER TABLE `vehiclenames`
ADD COLUMN IF NOT EXISTS `tunable` TINYINT NOT NULL DEFAULT 1;
```


## Update add-on tuning + logs

- Masinile add-on primesc acum si categorii native `Extra 1` - `Extra 14`, daca acele extra-uri exista pe vehicul.
- `Livery` foloseste fallback pe `GetVehicleLiveryCount` / `SetVehicleLivery` pentru masinile care nu folosesc modkit clasic la livery.
- Categoriile apar doar daca vehiculul chiar are acele optiuni, ca sa nu incarce UI inutil.
- Fiecare plata de tuning este salvata in `tunning_logs` cu UID, masina, suma, schimbari si tuning JSON.
