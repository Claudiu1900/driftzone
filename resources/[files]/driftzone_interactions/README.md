# DriftZone Interactions - Hide prompt after use

## Fix

Dupa ce jucatorul ajunge la o interactiune si apasa `E`:

- UI-ul cu `Apasa E` dispare imediat;
- nu mai apare inapoi cat timp jucatorul ramane in acel radius;
- apare din nou doar dupa ce jucatorul iese complet din radius si intra inapoi;
- marker-ul ramane neschimbat;
- eventurile existente raman neschimbate;
- resource-ul ramane optimizat, folosind acelasi `Config.CheckInterval`.

## Instalare

Pune folderul in:

```txt
resources/[files]/driftzone_interactions
```

In `server.cfg`:

```cfg
ensure driftzone_interactions
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_interactions
git commit -m "Hide interaction prompt after use until re-enter"
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
restart driftzone_interactions
```
