# driftzone_playerinteract

Interact FiveM pentru playeri cu PAY + TRADE.

## Comanda

```cfg
/playerinteract
```

## Functii

- selectezi playerul cu cursorul normal;
- UI-ul ramane transparent si curat;
- PAY card premium;
- TRADE cu masini + cash;
- cererea de trade expira in 30 secunde;
- playerul care trimite trade nu poate trimite alt trade pana se termina cererea;
- masina se transfera prin `ownedvehicles.owner_id`;
- loguri PAY in `pay_logs`;
- loguri TRADE in `trade_logs`.

## SQL

Ruleaza `sql.sql`.

## Config important

Daca tabela ta de masini are alte coloane, schimba in `config.lua`:

```lua
Config.OwnedVehiclesTable = 'ownedvehicles'
Config.OwnedVehiclesIdColumn = 'id'
Config.OwnedVehiclesOwnerColumn = 'owner_id'
Config.OwnedVehiclesModelColumn = 'vehicle_model'
Config.OwnedVehiclesPlateColumn = 'vehicle_plate'
```

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```
