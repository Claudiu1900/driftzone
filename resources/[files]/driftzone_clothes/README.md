# DriftZone Clothes - Load on Join Fix

## Fix
- incarca automat `users.clothes` dupa join/spawn;
- clientul cere reload de mai multe ori dupa join;
- serverul reincerca daca UID-ul inca nu este disponibil;
- trigger pentru reload manual din `users.clothes`.

## Trigger client-side

```lua
TriggerEvent('driftzone_clothes:client:reloadSaved')
```

sau:

```lua
TriggerServerEvent('driftzone_clothes:server:reloadSaved')
```

## Trigger server-side

```lua
TriggerEvent('driftzone_clothes:server:reloadPlayerClothes', targetSource)
```

## Export server-side

```lua
exports.driftzone_clothes:ReloadClothes(targetSource)
exports.driftzone_clothes:ApplySavedClothes(targetSource)
```

## Command

```txt
/reloadclothes
/reloadclothes (id/uid) -- admin 7+ aduty yes
```

## Git

Pe PC:
```bash
git add -A resources/[files]/driftzone_clothes
git commit -m "Fix clothes load on join"
git pull --rebase origin main
git push origin main
```

Pe VPS:
```bash
cd ~/server-data
git pull --rebase origin main
```

txAdmin:
```txt
restart driftzone_clothes
```
