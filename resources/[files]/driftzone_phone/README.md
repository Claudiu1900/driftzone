# driftzone_phone

Prototip telefon DriftZone.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_voicechat
ensure driftzone_phone
```

## Comanda

```txt
/phone
```

## Baza de date

Telefonul citește numărul din:

```sql
users.phonenumber
```

## Voice

Apelurile folosesc `driftzone_voicechat`. După ce apelul este acceptat, vorbești cu push-to-talk pe `N`.

## Flow

- formezi un număr de telefon;
- celălalt jucător primește apel;
- când deschide `/phone`, poate răspunde sau respinge;
- dacă răspunde, apelul se conectează prin `driftzone_voicechat`;
- `Hang Up` închide apelul pentru amândoi.
