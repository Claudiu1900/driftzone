# driftzone_gradients

Sistem pentru aplicarea gradient/chameleon/monochrome colors pe masini.

## Fix inclus

- Nu mai selecteaza coloana `users.admin` daca nu exista.
- Foloseste `users.admin_level` pentru verificarea adminului.
- `Config.AdminColumnFallback = nil` by default.
- Config-ul are fiecare gradient scris clar cu ID propriu.
- Au fost adaugate gradiente/c culori `monochrome`.

## Comanda admin

```txt
/gradient id
```

Acces: admin 6+ si aduty yes.

Exemplu:

```txt
/gradient 25
```

## Item inventory

Pentru trigger/item, itemul trebuie sa fie:

```txt
25_gradient
```

pentru gradient ID 25.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gradients
```

Ruleaza:

```txt
driftzone_gradients/SQL.sql
```

Apoi:

```cfg
restart driftzone_gradients
```
