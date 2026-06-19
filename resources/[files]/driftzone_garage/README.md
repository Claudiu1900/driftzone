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


## Update V2.1

- Coordonatele in admin panel se introduc direct intr-un singur camp: `x, y, z`.
- Locurile de parcare se introduc direct intr-un singur camp: `x, y, z, heading`.
- Sign-ul de garaj afiseaza doar simbolul de masina, fara nume/text.
- Markerul si radiusul se deseneaza stabil, fara flicker.
- Masinile spawnate nu mai au godmode.
- Playerul nu mai este teleportat automat in masina dupa spawn.
- Heading-ul locului de parcare este fortat server-side si client-side.


## Update V2.2

- Fix crash: `SetVehicleOnGroundProperly` scos de pe server, ramane doar client-side.
- Daca spawn-ul da eroare dupa ce vehiculul a fost creat, masina este stearsa automat ca sa nu ramana ghost car fara owner.
- UI fara `backdrop-filter`.
- UI cu colturi mai putin rotunjite.


## Update V2.3 - heading final

- Spawn-ul trimite explicit `x, y, z, h` catre client.
- Clientul seteaza masina exact pe coordonate si apoi aplica heading-ul.
- Heading-ul este reaplicat de mai multe ori dupa spawn/tuning, ca GTA sa nu il intoarca singur.
- `SetVehicleOnGroundProperly` se executa inainte de `SetEntityHeading`, ca sa nu mai reseteze directia.
