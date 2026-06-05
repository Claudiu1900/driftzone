# DriftZone LevelSystem

Sistem FiveM + oxmysql care verifica `users.xp` si seteaza automat:

- `users.rank`
- `users.rankcolor`

## Instalare

1. Pune folderul `driftzone_levelsystem` in `resources/[driftzone]/`.
2. Ruleaza `SQL.sql` in baza `driftzone`.
3. Pune in `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_levelsystem
```

## Leveluri default

- 1000 XP -> LEVEL1
- 5000 XP -> LEVEL2
- 15000 XP -> LEVEL3
- 30000 XP -> LEVEL4
- 50000 XP -> LEVEL5
- 75000 XP -> LEVEL6
- 100000 XP -> LEVEL7
- 250000 XP -> LEVEL8
- 500000 XP -> LEVEL9
- 1000000 XP -> LEVEL10

## Config

Editezi `config.lua` pentru:

- interval de verificare;
- numele rankului;
- culoarea rankului;
- valorile XP pentru fiecare level.

## Comanda

```txt
/refreshlevel
```

Din consola serverului refresh la toti jucatorii online. Din joc refresh pentru tine.
