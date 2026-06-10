# driftzone_gradients

Sistem pentru aplicarea gradientelor / chameleon colors pe vehicule.

## Comanda admin

```txt
/gradient id
```

Acces: admin 6+ si aduty yes. In modul admin poate fi aplicat pe orice masina selectata.

## Trigger / item inventory

Pentru iteme din inventar foloseste:

```lua
TriggerEvent('driftzone_gradients:client:useGradient', gradientId)
```

sau server-side export:

```lua
exports.driftzone_gradients:OpenGradient(source, gradientId)
```

In modul trigger/item:
- masina trebuie sa fie personala;
- itemul este sters doar dupa aplicare reusita;
- item id-ul este format asa: `id_gradient`, exemplu `25_gradient`.

## Salvare DB

In `ownedvehicles.gradient` se salveaza JSON cu:
- id gradient;
- colorId;
- nume gradient;
- unde a fost aplicat: primary / secondary / both.

Loguri in `gradient_logs`.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gradients
```

Ruleaza `SQL.sql`, apoi restart la resource.
