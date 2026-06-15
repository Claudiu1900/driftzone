# driftzone_notifications

UI de notificari DriftZone refacut, optimizat si fara mesaj automat la pornire.

## Instalare

```cfg
ensure driftzone_notifications
```

## Exemple

```lua
TriggerEvent('client:notify', 'info', 5000, 'Mesaj informativ')
TriggerEvent('client:notify', 'success', 5000, 'Actiune reusita')
TriggerEvent('client:notify', 'warning', 5000, 'Atentie')
TriggerEvent('client:notify', 'error', 5000, 'Eroare')
```

Compatibil si cu forma:

```lua
TriggerEvent('client:notify', 'info', 'Mesaj informativ', 5000)
```

## Exports

```lua
exports['driftzone_notifications']:Info('Mesaj', 5000)
exports['driftzone_notifications']:Success('Mesaj', 5000)
exports['driftzone_notifications']:Warning('Mesaj', 5000)
exports['driftzone_notifications']:Error('Mesaj', 5000)
exports['driftzone_notifications']:Show('info', 5000, 'Mesaj')
exports['driftzone_notifications']:Clear()
exports['driftzone_notifications']:SetSound(false)
```

## Test

```txt
/testnotify
```
