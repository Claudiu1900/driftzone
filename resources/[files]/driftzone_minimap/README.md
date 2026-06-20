# driftzone_minimap v3.3.0

HUD FiveM optimizat pentru viață, armură, mâncare, apă și stamina.

## Ce face

- Încarcă la intrare/spawn `health`, `armour`, `food`, `water` din `users.stats`.
- Aplică pe player viața și armura salvate.
- Salvează periodic în `users.stats`.
- Scade mâncarea și apa automat.
- Când mâncarea sau apa ajung la `0`, scade viața.
- Damage-ul de la foame/sete este acum server-authoritative: scade `health` direct în status și apoi aplică pe client.
- Păstrează celelalte chei din JSON, modifică doar `health`, `armour`, `food`, `water`.

## users.stats

```json
{
  "health": 100,
  "armour": 0,
  "food": 100,
  "water": 100
}
```

## Trigger-e pentru mâncare și apă

Client:

```lua
TriggerServerEvent('driftzone_minimap:addFood', 25)
TriggerServerEvent('driftzone_minimap:addWater', 25)
```

Server:

```lua
TriggerEvent('driftzone_minimap:server:addFood', playerSource, 25)
TriggerEvent('driftzone_minimap:server:addWater', playerSource, 25)
```

Exports:

```lua
exports['driftzone_minimap']:AddFood(playerSource, 25)
exports['driftzone_minimap']:AddWater(playerSource, 25)
exports['driftzone_minimap']:GetStatus(playerSource)
```

## Instalare

```cfg
ensure oxmysql
ensure driftzone_minimap
```

Dacă nu ai coloana `users.stats`, rulează:

```text
sql/users_stats.sql
```

Configul este în `config.lua`.
