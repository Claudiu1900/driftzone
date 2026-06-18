# driftzone_vehicleconfig

Sistem lock/unlock + engine pentru masini personale.

## Fix important

Lock/unlock NU mai merge pe orice masina.

Acum verifica:
- SQL ID masina = `ownedvehicles.id`;
- owner masina = `ownedvehicles.owner_id`;
- doar owner-ul sau un UID care are cheie temporara poate incuia/descuia.

## Taste

```txt
TAB = porneste/opreste motorul
F3 = incuie/descuie masina personala
```

## Comenzi

```txt
/engine
/vehiclelock
```

## Pentru garaj / spawn masina

Dupa ce spawnezi masina owned, cheama:

```lua
TriggerEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', vehicle, ownedVehicleSqlId)
```

sau cu Net ID:

```lua
TriggerEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', VehToNet(vehicle), ownedVehicleSqlId)
```

Asta face automat:
- seteaza SQL ID-ul pe entity state;
- incuie masina default;
- opreste motorul default;
- sterge cheile temporare vechi pentru masina aia.

## Cheie temporara pentru alt UID

Server-side:

```lua
exports.driftzone_vehicleconfig:GiveTemporaryKey(sqlId, uid, netId_optional)
```

sau:

```lua
TriggerEvent('driftzone_vehicleconfig:server:giveTemporaryKey', sqlId, uid, netId_optional)
```

Cheia temporara:
- nu se salveaza in DB;
- dispare cand playerul iese;
- dispare cand masina se respawneaza cu `registerSpawnedVehicle`.

## Lock/unlock dupa SQL ID

```lua
exports.driftzone_vehicleconfig:SetVehicleLockBySqlId(sqlId, true)
exports.driftzone_vehicleconfig:SetVehicleLockBySqlId(sqlId, false)
```

sau:

```lua
TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', sqlId, true)
TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', sqlId, false)
```

## Structura DB folosita

```sql
ownedvehicles.id
ownedvehicles.owner_id
ownedvehicles.vehicle_plate
```

Nu necesita SQL nou.
