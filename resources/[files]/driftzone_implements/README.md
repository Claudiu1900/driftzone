# DriftZone Implements

Resource FiveM pentru:

- ascundere HUD GTA default inutil;
- dezactivare weapon wheel;
- dezactivare radio/music wheel in masina;
- godmode/no ragdoll/infinite stamina;
- palaria/casca ramane pe cap;
- reset automat `users.aduty = 0`.

## Nou

Cand serverul/resource-ul porneste:

```sql
UPDATE users SET aduty = 0;
```

Cand un jucator intra pe server:

```sql
UPDATE users SET aduty = 0 WHERE uid = jucator_uid;
```

Sistemul incearca de mai multe ori sa prinda UID-ul, pentru ca auth-ul poate seta UID-ul dupa cateva secunde.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_implements
```

Restart:

```cfg
restart driftzone_implements
```

## Exporturi server

```lua
exports.driftzone_implements:ResetAllAduty()
exports.driftzone_implements:ResetPlayerAduty(source)
```
