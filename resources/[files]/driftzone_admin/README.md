# driftzone_admin

Versiune optimizata pentru management vehicule.

## Fixuri noi

- `/configveh` foloseste acum UI de confirmare intern, nu `confirm()` din browser.
- `/vehs` foloseste UI de confirmare pentru TAKE si UI cu input pentru TRANSFER.
- Fix la `/vehs` -> SPAWN: asteapta Net ID-ul si entity-ul pe server, ca sa nu mai spawneze masina dar sa zica fals ca nu s-a putut.
- Loguri pentru: addveh, configveh save/delete, vehs take/transfer/spawn/goto/bring.
- UI mai curat si mai premium.

## Comenzi

```txt
/addveh
/configveh
/vehs uid
```

Acces: `admin_level 6+` si `aduty yes`.

## Instalare

Ruleaza o data:

```sql
driftzone_admin/SQL.sql
```

Apoi:

```cfg
restart driftzone_admin
```
