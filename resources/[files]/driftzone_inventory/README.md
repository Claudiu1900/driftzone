# driftzone_inventory - Clothes Equipment FINAL

Resource complet cu inventar, money/dirtymoney, quick slots si sistem de haine echipabile.

## Update in aceasta versiune

- Manechinul din stanga este refacut dupa poza de referinta: fundal alb + outline negru curat.
- Cardul de haine este mai mare si nu mai are textul `CLOTHES`.
- Cand scoti o haina din slotul de echipare, haina este scoasa si de pe caracter.
- Cand un slot de haine este gol, clientul aplica drawable/texture default din `shared/config.lua`.
- Default-urile se modifica din `Config.EmptyClothingDefaults`. Pentru prop-uri, `drawable = -1` inseamna `ClearPedProp`.
- La join/spawn se reaplica hainele si default-urile de mai multe ori, ca sa nu ramana playerul cu skin gresit dupa spawn.

## Config important

In `shared/config.lua` ai:

```lua
Config.EmptyClothingDefaults = {
    jacket = { drawable = 15, texture = 0 },
    hat = { drawable = -1, texture = 0 }
}
```

Schimbi aici ID-ul de drawable/texture pentru fiecare categorie atunci cand slotul este gol.

## SQL

Ruleaza `SQL.sql` doar daca nu ai rulat deja tabelele pentru haine. Nu recreeaza inventarul vechi.
