# driftzone_minimap v3.4.0

Fix pentru load la viață și armură.

## Reparat

- `health` și `armour` se încarcă mai sigur din `users.stats`;
- reparată problema de ordine Lua unde funcțiile locale erau apelate înainte să fie definite;
- `sendHudUpdate` este forward-declared corect pe client;
- `scheduleJoinLoad` este forward-declared corect pe server;
- identificarea jucătorului încearcă mai întâi `uid` din state/export `driftzone_auth`;
- apoi caută în `users.uid`;
- abia după aceea încearcă license/identifier și mapping tables;
- la spawn/resource start face retry de mai multe ori;
- log în consolă când statusul a fost încărcat.

## users.stats

Exemplu:

```json
{"health": 100, "armour": 0, "food": 61, "water": 81}
```

Resource-ul aplică pe player:
- `health`
- `armour`

Și păstrează:
- `food`
- `water`

## Instalare

```cfg
ensure oxmysql
ensure driftzone_minimap
```

Dacă nu ai coloana `users.stats`, rulează:

```text
sql/users_stats.sql
```
