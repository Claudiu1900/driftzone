# DriftZone Turometru Modern

Speedometer FiveM NUI pentru DriftZone, refacut in stil arc/gauge ca in poza.

## Ce arata

- viteza in KM/H;
- gear-ul;
- arc modern cu glow;
- zona rosu/blue pe arc;
- animatii usoare si optimizate.

## Optimizare

- NUI update doar cand viteza/gear/rpm se schimba;
- loop doarme 350ms cand nu esti in vehicul;
- apare doar cand esti sofer;
- nu apare pe biciclete, barci, elicoptere, avioane sau trenuri;
- requestAnimationFrame ruleaza doar cand turometrul este vizibil.

## Instalare

1. Pune folderul `driftzone_turometru` in `resources/[driftzone]/`.
2. In `server.cfg`:

```cfg
ensure driftzone_turometru
```

3. Restart:

```cfg
restart driftzone_turometru
```
