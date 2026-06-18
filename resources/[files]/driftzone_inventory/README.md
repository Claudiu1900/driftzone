# driftzone_inventory - Clothes Equipment V2

Resource complet cu inventory, money/dirtymoney, quick slots si sistem de haine pe sloturi.

## Fixuri incluse in versiunea asta

- Fix pentru bugul cand scoteai o haina din slot si ramanea pusa pe caracter.
- Nu mai reaplica acelasi payload de haine de 8-10 ori. Aplicarea se face o singura data, iar payload-urile vechi sunt ignorate prin revision ID.
- Cand slotul de haina ramane gol, se aplica default-ul din `shared/config.lua` -> `Config.EmptyClothingDefaults`.
- `body.svg` are background transparent si foloseste manechinul din poza trimisa.
- UI refacut vizual: glass panels, sloturi rotunjite, efecte mai curate si layout optimizat.
- Cand deschizi inventarul, se face reload din DB pentru inventar + item metadata + clothes metadata.

## Config important

In `shared/config.lua` modifici ce se pune pe player cand scoti o haina:

```lua
Config.EmptyClothingDefaults = {
    jacket = { drawable = 15, texture = 0 },
    top = { drawable = 15, texture = 0 },
    torso = { drawable = 15, texture = 0 },
    hat = { drawable = -1, texture = 0 },
    glasses = { drawable = -1, texture = 0 }
}
```

Pentru props, `drawable = -1` inseamna `ClearPedProp`.

## SQL

Ruleaza `SQL.sql` doar daca nu ai tabelele `clothes_items` si `users_clothes`.

## Comenzi

- `/inventory`
- `/additem` admin 6+ aduty
- `/items` admin 6+ aduty
- `/addclothes` admin 6+ aduty
- `/clothesitems` admin 6+ aduty


## Fix inclus
- Sloturile de haine au fost puse inapoi pe pozitiile vechi.
- Unequip salveaza slotul gol ca `{}` in `users_clothes`, nu NULL/nil, ca sa nu revina itemul dupa o fractiune de secunda.
- Clientul pune lock scurt pe categoria scoasa ca payload-urile vechi sa nu poata reaplica haina.
