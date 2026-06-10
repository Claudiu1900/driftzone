# driftzone_gradients

Sistem DriftZone pentru aplicarea gradientelor pe vehicule.

## Fix important

Versiunea aceasta nu mai foloseste colorId-uri chameleon 161+ ca vopsea principala, pentru ca pe unele build-uri FiveM/GTA apar negru/gri.

Acum fiecare gradient are:

- `startColor` RGB
- `endColor` RGB
- `pearlColor` RGB

Astfel gradientele sunt vizibile pe toate masinile compatibile cu custom colours.

## Folosire admin

```txt
/gradient id
```

Necesita admin 6+ si aduty yes.

## Folosire din item/inventory

Item pentru gradient ID 25:

```txt
25_gradient
```

Trigger client:

```lua
TriggerEvent('driftzone_gradients:client:useGradient', 25)
```

Server export:

```lua
exports.driftzone_gradients:OpenGradient(source, 25)
```

## Aplicare

Dupa selectarea masinii alegi:

- Culoare Principala
- Culoare Secundara
- Ambele

La folosire cu item, masina trebuie sa fie personala. La comanda admin merge pe orice masina.

## SQL

Ruleaza `SQL.sql`.
