# driftzone_playerinteract

Sistem FiveM pentru interactiune directa cu playerii.

## Comanda

```txt
/playerinteract
```

## Functii

- Selectezi player cu mouse-ul.
- Meniu transparent cu cardul principal + actiuni PAY si TRADE.
- PAY trimite cash si inchide UI-ul rapid dupa confirmare.
- TRADE functioneaza cu cerere reciproca in 30 secunde.
- In trade fiecare vede doar masinile lui personale.
- Se pot selecta mai multe masini.
- Oferta celuilalt apare doar cand selecteaza masini sau bani.
- Banii au placeholder `0`, fara valoare pusa automat.
- Daca cineva schimba oferta, confirmurile se reseteaza si pot fi apasate din nou.
- Trade-ul se finalizeaza doar dupa ce amandoi apasa `CONFIRM TRADE`.
- Masinile se transfera prin `ownedvehicles.owner_id`.
- Logurile se salveaza in `trade_logs`.

## SQL

Ruleaza `sql.sql` daca nu ai tabelele.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```


## Pozitii action cards

PAY si TRADE sunt separate complet in CSS:

```css
.pay-card-action { left: 72%; }
.trade-card-action { left: 28%; }
```

Schimbi una fara sa afectezi cealalta.
