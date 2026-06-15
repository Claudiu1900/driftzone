# driftzone_phone V7

Telefon prototip pentru DriftZone, cu UI refacut, contacte, block, istoric apeluri, mesaje sincronizate si share location.

## Fixuri V7

- UI refacut complet: contacte, mesaje, apeluri, dialer si ecran de apel.
- Iconurile SVG sunt transparente, fara background in fisier.
- Fix major la JavaScript: nu mai pica meniul cand apesi +, cand scrii sau cand salvezi contacte.
- State refresh nu mai rescrie ecranul cat timp scrii in input.
- Sunetele nu se mai suprapun in loop.
- `ring.mp3` si `ring2.mp3` ruleaza ca loop controlat si se opresc la raspuns/respins/inchidere.
- `decline.mp3` ruleaza doar la esec/respins/nepreluat, nu cand inchizi un apel activ normal.
- `message.mp3` ruleaza o singura data la trimis/primit mesaj.
- Speaker si Mute folosesc `driftzone_voicechat:client:setPhoneOptions`.
- Tasta ` face toggle la cursor cat timp telefonul este vizibil.
- Home bar: in aplicatii merge inapoi; pe home inchide telefonul.

## SQL

Ruleaza `SQL.sql`.

## Comanda

```txt
/phone
```
