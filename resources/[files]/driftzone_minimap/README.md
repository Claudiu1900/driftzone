# driftzone_minimap

HUD standalone pentru FiveM cu:

- viață, armură, mâncare, apă și stamina;
- minimap repoziționat mai sus;
- barele GTA de viață/armură ascunse;
- armura ascunsă automat la 0%;
- stamina afișată doar când jucătorul aleargă sau se reîncarcă;
- mâncare: -1% la fiecare 20 secunde;
- apă: -1% la fiecare 40 secunde;
- un singur status la 0: -5% viață la fiecare 30 secunde;
- ambele statusuri la 0: -10% viață la fiecare 40 secunde;
- persistare automată cu oxmysql și fallback în memorie.

## Instalare

1. Pune folderul `driftzone_minimap` în `resources`.
2. Dacă folosești oxmysql, pornește-l înaintea HUD-ului:

```cfg
ensure oxmysql
ensure driftzone_minimap
```

Tabela SQL este creată automat. Poți importa și `sql/driftzone_status.sql` manual.

Oprește orice alt HUD/status script care modifică foamea, setea, viața sau poziția minimap-ului, altfel sistemele se vor suprapune.

## Trigger-ele cerute

Dintr-un client script:

```lua
TriggerServerEvent('driftzone_minimap:addFood', 25)
TriggerServerEvent('driftzone_minimap:addWater', 25)
```

Acestea funcționează când `Config.AllowClientAddTriggers = true`.

### Variantă recomandată și mai sigură, din server-side

```lua
TriggerEvent('driftzone_minimap:server:addFood', playerSource, 25)
TriggerEvent('driftzone_minimap:server:addWater', playerSource, 25)
```

Sau prin exports:

```lua
exports['driftzone_minimap']:AddFood(playerSource, 25)
exports['driftzone_minimap']:AddWater(playerSource, 25)
```

## Ascundere/afișare HUD

Din client:

```lua
TriggerEvent('driftzone_minimap:client:setVisible', false)
TriggerEvent('driftzone_minimap:client:setVisible', true)
```

Sau:

```lua
exports['driftzone_minimap']:SetHudVisible(false)
exports['driftzone_minimap']:SetHudVisible(true)
```

## Ajustarea poziției

În `config.lua`:

```lua
Config.Minimap.VerticalOffset = 0.055
```

Mărește valoarea pentru a ridica minimap-ul. Poziția HUD-ului de sub hartă se modifică în `html/style.css`, la clasa `.hud`.
