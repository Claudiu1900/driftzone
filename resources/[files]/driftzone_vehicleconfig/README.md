# driftzone_vehicleconfig

## Fixuri

- notificarea de lock/unlock se trimite o singura data;
- cooldown 3 secunde intre incuiat/descuiat;
- pe cooldown nu apare nicio notificare;
- masina spawned se incuie real, nu doar in state;
- lock-ul de spawn se reaplica de cateva ori, pentru ca GTA poate reseta lock-ul imediat dupa spawn;
- lock/unlock ramane doar pentru masina owned:
  - `ownedvehicles.id` = SQL ID masina;
  - `ownedvehicles.owner_id` = UID owner.

## Taste

```txt
TAB = porneste/opreste motorul
F3 = incuie/descuie masina personala
```

## Pentru garaj / spawn masina

Dupa ce spawnezi masina owned:

```lua
TriggerEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', vehicle, ownedVehicleSqlId)
```

sau:

```lua
TriggerEvent('driftzone_vehicleconfig:client:registerSpawnedVehicle', VehToNet(vehicle), ownedVehicleSqlId)
```

## Cheie temporara

```lua
exports.driftzone_vehicleconfig:GiveTemporaryKey(sqlId, uid, netId_optional)
```

Cheia dispare cand playerul iese sau masina se respawneaza.
