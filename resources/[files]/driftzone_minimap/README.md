# driftzone_minimap v3.0.0

HUD FiveM optimizat pentru viață, armură, mâncare, apă și stamina.

## Salvarea în baza de date

Versiunea 3.0.0 nu mai folosește tabela separată `driftzone_status`.
Toate statisticile sunt salvate direct în:

```text
users.stats
```

Valoarea este JSON:

```json
{
  "health": 100,
  "armour": 0,
  "food": 100,
  "water": 100
}
```

Resursa păstrează celelalte chei care există deja în `users.stats`. Modifică doar:

- `health`
- `armour`
- `food`
- `water`

## Când se salvează

Statisticile se salvează:

- automat la fiecare 30 de secunde, numai dacă s-a schimbat ceva;
- când jucătorul iese de pe server;
- când resursa este oprită sau restartată;
- după schimbări la mâncare, apă, viață sau armură.

Viața și armura sunt trimise către server doar când se schimbă, cu un heartbeat rar pentru siguranță.

## Când se încarcă

La conectare, resursa citește `users.stats` și aplică:

- viața salvată;
- armura salvată;
- mâncarea salvată;
- apa salvată.

Viața salvată la `0` este încărcată la minimum `1%`, pentru a evita ca jucătorul să rămână blocat mort la fiecare reconnect. Poți schimba asta în `config.lua`:

```lua
Config.MinimumLoadedHealth = 1
```

## Identificarea jucătorului

Resursa detectează automat structurile uzuale:

- `vrp_user_ids.identifier -> users.id`
- `user_ids.identifier -> users.id`
- `users.license`
- `users.identifier`
- `users.steam`
- `users.discord`
- user ID din state bag

Setările principale sunt în `config.lua`:

```lua
Config.Database = {
    UsersTable = 'users',
    StatsColumn = 'stats',
    UserIdColumn = 'id',
    MappingTables = {
        'vrp_user_ids',
        'user_ids'
    },
    AutoCreateStatsColumn = true
}
```

Dacă serverul tău folosește un sistem custom, poți trimite direct `users.id` dintr-un script server-side:

```lua
exports['driftzone_minimap']:LoadForUserId(playerSource, userId)
```

## Instalare

În `server.cfg`, `oxmysql` trebuie pornit înainte:

```cfg
ensure oxmysql
ensure driftzone_minimap
```

Șterge complet versiunea veche a folderului înainte să pui versiunea nouă.

Resursa creează automat coloana `users.stats` dacă lipsește. Alternativ, poți rula manual fișierul:

```text
sql/users_stats.sql
```

Nu rula acel `ALTER TABLE` dacă `users.stats` există deja.

## Trigger-e mâncare și apă

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

Poți citi toate statisticile astfel:

```lua
local stats = exports['driftzone_minimap']:GetStatus(playerSource)

-- stats.health
-- stats.armour
-- stats.food
-- stats.water
```

## Funcționarea HUD-ului

- Armura nu apare la `0%`.
- Stamina este ascunsă la `100%`.
- Stamina apare cu fade când jucătorul aleargă și scade spre `0%`.
- Mâncarea scade cu `1%` la fiecare 20 de secunde.
- Apa scade cu `1%` la fiecare 40 de secunde.
- Un singur status la `0%`: `-5%` viață la fiecare 30 de secunde.
- Ambele la `0%`: `-10%` viață la fiecare 40 de secunde, fără damage dublu.

## Poziția hărții

```lua
Config.Minimap.VerticalOffset = -0.045
```

O valoare mai negativă ridică harta mai sus.


## Stamina

Stamina este afișată ca procent rămas: pornește la 100%, scade când jucătorul aleargă, se regenerează când se oprește și cardul este ascuns din nou după revenirea la 100%. Valoarea brută FiveM este inversată pentru afișarea corectă.
