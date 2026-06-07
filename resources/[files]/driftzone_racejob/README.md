# driftzone_racejob

Race Job pentru DriftZone.

## Fixuri incluse

- reward-ul nu mai da crash daca `users.cash` este INT si atinge limita;
- scriptul citeste limita coloanei `cash` si face update safe;
- `sql.sql` modifica `cash` la BIGINT UNSIGNED si adauga `users.races`;
- timer-ul din cursa este mai mic si apare langa minimap, jos;
- countdown-ul 3 / 2 / 1 / START porneste imediat dupa teleport/spawn;
- tuning-ul se aplica instant si apoi se reaplica in background;
- masina cursei se sterge la finish/fail;
- playerul revine in dimensiunea normala dupa finish/fail.

## SQL obligatoriu recomandat

Ruleaza `sql.sql` in baza de date ca sa nu mai ai limita mica la cash.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_garage
ensure driftzone_racejob
```

## Reset cooldown

```txt
/rracecd <id>
```
