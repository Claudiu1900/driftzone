# driftzone_vehicless v14

Comenzi:

```txt
/vehss
/vehss model
/vehssclean
/vehssclose
```

## Ce s-a reparat

- `/vehss` fara model deschide meniul corect.
- In meniu poti scrie modelul masinii si apesi `LOAD` sau `Enter`.
- `/vehss s15` inca deschide direct cu modelul incarcat.
- Daca modelul este invalid, meniul ramane deschis si poti scrie alt model.
- Playerul nu mai este mutat in studio pana cand modelul este valid.
- Daca nu exista masina incarcata, controalele nu mai dau bug.
- Screenshot-basic/yarn/webpack raman scoase complet.

## Clean mode

- Tasta ` ascunde/arata UI-ul, radarul/minimap-ul si HUD-ul.
- Daca tasta nu merge, foloseste `/vehssclean`.

## server.cfg

```cfg
ensure driftzone_vehicless
```
