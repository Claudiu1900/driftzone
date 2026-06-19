# driftzone_minimap v2.0.0

HUD standalone FiveM pentru viață, armură, mâncare, apă și stamina.

## Important la actualizare

Șterge complet folderul vechi `driftzone_minimap`, apoi pune folderul nou. Nu copia doar peste fișierele vechi.

În consola serverului rulează:

```cfg
restart driftzone_minimap
```

Interfața v2 folosește un fișier NUI nou, self-contained, pentru a evita fundalul gri și cache-ul versiunii vechi.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_minimap
```

`oxmysql` este opțional. Fără el, statusurile funcționează, dar nu se păstrează după reconectare.

Oprește alte resurse care modifică simultan HUD-ul, stamina, foamea, setea sau poziția minimap-ului.

## Funcționare

- Armura nu apare la 0%.
- Stamina începe la 100% și este ascunsă.
- Stamina apare cu fade când jucătorul începe să alerge, scade și dispare după ce revine la 100%.
- Mâncare: -1% la fiecare 20 secunde.
- Apă: -1% la fiecare 40 secunde.
- Un status la 0: -5% viață la fiecare 30 secunde.
- Ambele la 0: -10% viață la fiecare 40 secunde, fără damage dublu.

## Trigger-e

Din client:

```lua
TriggerServerEvent('driftzone_minimap:addFood', 25)
TriggerServerEvent('driftzone_minimap:addWater', 25)
```

Din server, varianta recomandată:

```lua
TriggerEvent('driftzone_minimap:server:addFood', playerSource, 25)
TriggerEvent('driftzone_minimap:server:addWater', playerSource, 25)
```

Exports server-side:

```lua
exports['driftzone_minimap']:AddFood(playerSource, 25)
exports['driftzone_minimap']:AddWater(playerSource, 25)
```

## Poziția hărții

În `config.lua`:

```lua
Config.Minimap.VerticalOffset = -0.045
```

O valoare mai negativă ridică harta și mai sus, de exemplu `-0.055`.
