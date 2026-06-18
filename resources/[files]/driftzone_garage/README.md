# driftzone_garage V2

Garaj refacut cu UI premium, garaje din DB si locuri de parcare.

## Ce e nou

- UI complet refacut, mai curat si mai modern.
- `/garage` merge doar daca playerul este in radiusul unui garaj.
- Spawn-ul nu se mai face langa player, ci pe primul loc liber al garajului.
- Daca toate locurile sunt ocupate: `Nu este niciun loc liber momentan.`
- Garajele sunt in tabela `garages`.
- La coordonatele garajului apare marker albastru de masina + numele garajului.
- Radius vizibil/transparent pe fiecare garaj.
- `/addgarage` admin_level 6+ si aduty yes.
- `/editgarages` admin_level 6+ si aduty yes.
- `/resetgarages` admin_level 6+ si aduty yes, reincarca garajele din DB.
- Integrare `driftzone_vehicleconfig`: dupa spawn trimite trigger pentru SQL ID, lock default real si motor oprit.
- Tuning-ul si gradientul vechi sunt pastrate si reaplicate ca in versiunea anterioara.

## Instalare

Ruleaza o data SQL-ul:

```sql
SQL.sql
```

Apoi in server.cfg:

```cfg
ensure oxmysql
ensure driftzone_vehicleconfig
ensure driftzone_garage
```

## Comenzi

```txt
/garage
/garaj
/park
/addgarage
/editgarages
/resetgarages
```

## Tabela garages

`parking_spots` este JSON:

```json
[
  { "x": 229.70, "y": -800.12, "z": 30.57, "h": 158.0 }
]
```

ID-ul garajului este AUTO_INCREMENT si incepe de la 1.
