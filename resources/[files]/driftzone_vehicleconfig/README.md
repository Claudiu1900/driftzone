# driftzone_vehicleconfig

Sistem optimizat pentru lock/unlock masini si engine toggle.

## Comenzi

```txt
/vehiclelock
/engine
```

## Ce face

- `/vehiclelock` blocheaza/deblocheaza masina de langa tine.
- Cand masina este blocata, alti jucatori nu se pot urca in ea.
- `/engine` porneste/opreste motorul. Merge doar daca esti sofer intr-o masina.
- `/engine` nu trimite notificari.
- Sistemul tine lock state dupa netId, SQL ID si plate.

## Server.cfg

```cfg
ensure driftzone_vehicleconfig
```

## Trigger lock/unlock dupa SQL ID masina

```lua
TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', sqlId, true)  -- lock
TriggerEvent('driftzone_vehicleconfig:server:setLockBySqlId', sqlId, false) -- unlock
```

Sau:

```lua
exports.driftzone_vehicleconfig:SetVehicleLockBySqlId(sqlId, true)
exports.driftzone_vehicleconfig:SetVehicleLockBySqlId(sqlId, false)
```

## Trigger motor oprit cand scoti masina din garaj

Dupa ce creezi masina in garaj, pune unul dintre astea:

Client-side:

```lua
TriggerEvent('driftzone_vehicleconfig:client:setEngineOff', vehicle)
```

sau cu netId:

```lua
TriggerEvent('driftzone_vehicleconfig:client:setEngineOff', VehToNet(vehicle))
```

Server-side:

```lua
TriggerEvent('driftzone_vehicleconfig:server:setEngineOff', netId)
```

## Important pentru SQL ID

Resource-ul cauta SQL ID-ul in Entity(vehicle).state pe cheile:

```lua
dz_garage_db_id
vehicleDbId
ownedVehicleId
dz_vs_sql_id
sqlId
vehicle_id
```

Daca garajul tau foloseste alta cheie, adauga cheia in `Config.SqlIdStateKeys`.
