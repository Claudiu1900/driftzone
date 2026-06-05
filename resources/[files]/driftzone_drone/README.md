# driftzone_drone

Admin fixed drone camera pentru FiveM.

## Comenzi

```txt
/pdrone
```

Salveaza punctul camerei la coordonatele capului adminului.

```txt
/drone
```

Activeaza/dezactiveaza camera fixa.

## Permisiuni

Necesita:

```txt
users.admin_level >= 6
users.aduty = yes / true / 1
```

## Ce face

- `/pdrone` salveaza coordonatele capului in cache server-side;
- `/drone` muta doar camera la coordonatele salvate;
- caracterul ramane controlabil;
- camera ramane fixa;
- camera se roteste smooth constant dupa caracterul adminului;
- mouse look/camera controls sunt blocate cat timp drone este activ;
- `/drone` din nou dezactiveaza camera.

## Instalare

Pune folderul:

```txt
resources/[files]/driftzone_drone
```

In `server.cfg`, dupa oxmysql si driftzone_auth:

```cfg
ensure driftzone_drone
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_drone
git commit -m "Add admin drone camera"
git pull --rebase origin main
git push origin main
```

Pe VPS:

```bash
cd ~/server-data
git pull --rebase origin main
```

In txAdmin console:

```txt
restart driftzone_drone
```
