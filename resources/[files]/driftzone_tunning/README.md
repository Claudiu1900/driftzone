# driftzone_tunning rebuild

Versiune refacuta pentru DriftZone.

## Ce e nou

- UI complet refacut, mai curat si mai premium.
- Nu contine culori chameleon.
- Afiseaza doar tuning-urile reale detectate pe masina curenta.
- Extra-urile sunt detectate automat `0-25` si apar doar daca exista pe vehicul.
- Roțile sunt separate pe tipuri: Sport, Muscle, Lowrider, SUV, Offroad, Tuner, Bike, High End, Benny's, Street, Track.
- Bug reparat: schimbarea la wheels seteaza intai `SetVehicleWheelType`, apoi `SetVehicleMod(23, ...)`, iar pentru motociclete seteaza si `modType 24`.
- Include mai multe categorii pentru add-on-uri: Trim B, Dashboard/Interior color, Plate Style, Livery, Engine Bay, Interior etc.
- Armor este scos.
- Optimizat: categorie map, preview throttled, fara optiuni fake.

## Instalare

Inlocuieste folderul:

```txt
resources/driftzone_tunning
```

Ruleaza SQL daca nu l-ai rulat deja:

```txt
driftzone_tunning/SQL.sql
```

Restart:

```cfg
restart driftzone_tunning
```

Daca o masina add-on nu afiseaza o piesa, inseamna ca masina nu expune acea piesa corect in `carcols.meta` / `carvariations.meta` / modkit. Scriptul nu inventeaza optiuni care nu se pot aplica.


## Update UI vechi

- UI-ul vechi a fost pus inapoi.
- Backend-ul ramane cel optimizat: add-on tuning, extras 0-25, wheels fix cu WheelType, fara chameleon si fara armor.

## Update gradient preview + instant open

- Adaugate categorii noi in tunning:
  - `Primary Gradient Color`
  - `Secondary Gradient Color`
- Gradientele sunt doar preview: nu se adauga in cos, nu se cumpara si nu se salveaza in `ownedvehicles.vehicle_tunning`.
- Daca apesi Pay dupa un preview de gradient, masina revine la tuning-ul cumparat/salvat, fara sa pastreze preview-ul de gradient.
- Meniul se deschide mult mai rapid: scanarea modkit-ului nu mai face request/wait pe fiecare categorie.
- UI vechi pastrat.
- Fixurile pentru add-on tuning, wheels si extras raman active.
