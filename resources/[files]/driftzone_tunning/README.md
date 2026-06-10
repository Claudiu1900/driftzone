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

## Update addon full tuning

- Categoriile vizibile pentru masini add-on sunt afisate fortat cand FiveM returneaza `0` la `GetNumVehicleMods`.
- Daca masina are modkit real, se foloseste count-ul real.
- Daca native-ul returneaza 0, se foloseste fallback optimizat din `config.lua`.
- Livery are suport dublu: `SetVehicleMod(48, ...)` si `SetVehicleLivery(...)`.
- Comanda admin: `/tunning`, admin 6+ si aduty yes.
- Loguri in `tunning_logs` pentru cumparari si folosire admin.

Important: daca un addon nu are deloc modkit/carcols pentru piesele vizibile, meniul le poate afisa fortat, dar piesa respectiva nu are ce sa aplice in joc. Pentru addon-uri facute corect, piesele apar si se aplica.
