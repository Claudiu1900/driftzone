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


## Update V2.4 - spawn refacut client-side

- Masina nu mai este creata server-side.
- Serverul doar valideaza ownerul, garajul si locul liber.
- Clientul creeaza masina direct la `x, y, z, heading`, deci heading-ul este exact cel din parking spot.
- Nu se mai foloseste `SetVehicleOnGroundProperly`, pentru ca poate roti masina dupa strada.
- Dupa ce clientul creeaza masina, serverul primeste `netId`, seteaza owner/state si o inregistreaza.

- Toate apelurile `SetVehicleOnGroundProperly` au fost scoase din spawn ca heading-ul sa nu mai fie resetat.


## Update V2.5 - spawn pe sol

- Clientul calculeaza ground Z cu `GetGroundZFor_3dCoord` inainte sa creeze masina.
- Masina se creeaza direct pe sol, nu la Z-ul din DB daca acela este prea sus.
- `SetVehicleOnGroundProperly` este folosit doar client-side, apoi se aplica heading-ul.
- Am scos fortarea agresiva de heading/pozitie; acum doar aseaza masina pe sol si lasa heading-ul normal.


## Update V2.6 - no retry / no flicker

- Scos retry-ul/reaplicarea de pozitie dupa spawn.
- Scos `forceSpawnTransform` dupa spawn.
- Scos delayed `forceTuning` care putea face masina sa para ca dispare/apare.
- Masina se creeaza o singura data, se aseaza pe sol si serverul doar confirma owner/state.


## Update V2.7 - confirm spawn fix

- Fix pentru bug-ul in care masina se spawna, apoi era stearsa imediat.
- Serverul nu mai considera masina nou creata de client ca duplicat.
- Verificarea de duplicate ignora exact entitatea/netId-ul care confirma spawn-ul.
- Timeout-ul nu mai sterge masina daca ea a fost deja inregistrata in `ActiveVehicles`.


## Update V2.8 - outsidevehicles + park radius

- Scos textul `garage id` din UI.
- Scos butonul de despawn din meniul garajului.
- Limita de masini spawnate simultan se ia din `users.outsidevehicles`.
  - Exemplu: `outsidevehicles = 2` => playerul poate avea maxim 2 masini spawnate.
- Adaugat `park_radius` separat de radiusul pentru deschiderea garajului.
- Masina se poate parca/despawna doar in zona de park.
- Cand esti cu masina ta in zona de park apare jos: `Apasa E pentru a parca vehiculul.`
- `/park` functioneaza doar daca esti in zona de park.


## Update V2.9 - spawn nil fix

- Fix eroare server: `getServerVehiclesSafe nil`.
- `vehicleExists`, `getServerVehiclesSafe` si `getGarageVehicleIdFromEntity` sunt forward-declared corect.
- `getOutsideVehicleCount` este safe si nu mai poate opri spawn-ul daca o functie lipseste.
- Spawn-ul nu mai este blocat din cauza erorii de limitare `outsidevehicles`.


## Update V2.10 - park prompt UI

- Promptul `Apasa E pentru a parca vehiculul` a fost refacut.
- Stil minimalist jos central.
- Tasta `E` are box separat cu accent albastru.
- Fundal discret, fara UI incarcat.
