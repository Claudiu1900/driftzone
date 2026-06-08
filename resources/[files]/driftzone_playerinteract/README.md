# driftzone_playerinteract

PAY + TRADE pentru DriftZone.

## Trade
- click TRADE trimite cerere si notificare;
- celalalt trebuie sa dea si el TRADE inapoi in 30 secunde;
- dupa acceptare se deschide UI-ul de trade la amandoi, fara timer;
- fiecare vede doar masinile lui personale;
- cand selectezi masina sau schimbi cash-ul, oferta apare live la celalalt;
- butonul final este CONFIRM TRADE;
- dupa confirmarea ambilor se schimba `ownedvehicles.owner_id` si cash-ul;
- loguri in `trade_logs`.

## Instalare
Ruleaza `sql.sql`, apoi:
```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```
