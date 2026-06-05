# driftzone_drone fixed

Fix:
- include `@oxmysql/lib/MySQL.lua`;
- comenzi native `/pdrone`, `/drone`;
- export `RunCommand(src, command, args)` pentru `driftzone_chat`.

## Pentru driftzone_chat custom

Adauga ruta:

```lua
pdrone = 'driftzone_drone',
drone = 'driftzone_drone',
```

sau apeleaza:

```lua
exports.driftzone_drone:RunCommand(src, command, args)
```

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_drone
```
