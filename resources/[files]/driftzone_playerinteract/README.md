# driftzone_playerinteract

Sistem FiveM pentru interactiune directa cu playerii.

## Comanda

```txt
/playerinteract
```

## Actiuni

- `01` TRADE - schimb de masini/cash.
- `02` PAY - transfer cash.
- `03` BARBUT - duel cu zaruri pe cash.

## BARBUT

Flow:
1. Selectezi playerul.
2. Apesi `BARBUT`.
3. Daca nu ai cerere primita de la acel player, se deschide UI pentru suma si `INVITE`.
4. Celalalt player primeste notificare si accepta selectandu-te pe tine + `BARBUT`.
5. Se deschide UI cu zaruri la ambii.
6. Ambii apasa `READY`, zarurile ruleaza, serverul calculeaza castigatorul.
7. Castigatorul primeste potul minus 10% taxa.
8. `CLOSE` inchide la ambii. `RETRY` trebuie apasat de ambii.

## SQL

Ruleaza `sql.sql`.

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_playerinteract
```

## Update Barbut v2

- S-a scos numarul 03 din meniul unde introduci suma.
- S-a scos limita maxima de 1.000.000 din Barbut.
- S-a scos textul lung cu instructiunea READY din UI.
- Rezultatul si scorurile apar doar dupa ce zarurile se opresc.
- Animatia zarurilor este mai lunga si cu efect 3D.
- RETRY a fost reparat si verifica din nou cash-ul ambilor jucatori.
- Combinatia 1 + 1 este cea mai mare combinatie la Barbut.


## Update Barbut v4

- Animatia zarurilor este simpla, fara efect 3D.
- Banii se retrag de la ambii jucatori cand ambii apasa READY.
- Castigatorul primeste payout-ul dupa ce zarurile finale sunt afisate.
- CLOSE este blocat cat timp runda ruleaza.
- Dupa runda se foloseste direct READY pentru o runda noua.
