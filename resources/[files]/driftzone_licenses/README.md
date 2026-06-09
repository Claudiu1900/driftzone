# driftzone_licenses

Sistem FiveM pentru schimbarea numerelor de inmatriculare.

## Functii

- UI premium pentru ales tipul de inmatriculare.
- Normal: trebuie sa inceapa cu `DZ`, minim 3 caractere dupa prefix, maxim 8 total, costa `100000` cash din `users.cash`.
- Premium: orice combinatie alfanumerica, 1-8 caractere, costa `2000` DriftZone Coins din `users.dzcoins`.
- Verifica daca numarul exista deja in `ownedvehicles.vehicle_plate`.
- Verifica daca masina apartine jucatorului.
- Schimba `ownedvehicles.vehicle_plate`.
- Salveaza loguri in `licenses_logs`.
- Cache scurt pentru lista de masini, fara loop greu.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_interactions
ensure driftzone_licenses
```

Ruleaza `SQL.sql`.

## driftzone_interactions

Adauga in config-ul tau de interactiuni:

```lua
{
    id = 'driftzone_licenses',
    coords = vector3(3827.0, 3821.0, 30.0),
    range = 2.6,
    key = 'E',
    text = 'Apasa E pentru inmatriculari',
    subText = 'DriftZone Licenses',
    marker = true,
    event = 'driftzone_licenses:client:openFromInteraction',
    blip = { sprite = 498, color = 3, scale = 0.80, name = 'DriftZone Licenses' }
},
```

Resource-ul are si fallback marker propriu, deci merge si fara interactions.
