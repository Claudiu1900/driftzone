# driftzone_phone V4

Prototip telefon DriftZone cu apeluri prin `driftzone_voicechat`.

## Comanda

```txt
/phone
```

## Ce face

- Telefonul se deschide in dreapta cu animatie de jos in sus.
- Inchiderea are animatie de sus/jos, nu dispare instant.
- Telefonul porneste pe home screen si are aplicatie Telefon.
- Numarul playerului se ia din `users.phonenumber`.
- Poti suna doar numere de telefon existente in DB si online.
- Cand cineva te suna, telefonul apare partial in dreapta cu butoane de raspuns/respins.
- Nu mai trimite notificari externe prin `client:notify`.
- Sunete:
  - `ring.mp3` = cand tu suni pe cineva;
  - `ring2.mp3` = cand te suna cineva;
  - `decline.mp3` = numar invalid, persoana offline, respins, nepreluat.
- Backtick / tasta ` face toggle la cursor cat timp telefonul este vizibil.

## Unde pui sound-urile

Pune fisierele aici:

```txt
driftzone_phone/html/assets/sounds/ring.mp3
driftzone_phone/html/assets/sounds/ring2.mp3
driftzone_phone/html/assets/sounds/decline.mp3
```

Zip-ul include placeholder-uri. Le poti inlocui cu sunetele tale.

## VoiceChat

Telefonul foloseste `driftzone_voicechat` inclus in zip.
In apel:
- persoana din telefon te aude indiferent de distanta;
- jucatorii de langa tine te aud normal cand tii N;
- jucatorii de langa tine NU aud persoana din telefon.

## server.cfg

```cfg
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
setr voice_enableUi 0

ensure oxmysql
ensure driftzone_auth
ensure driftzone_voicechat
ensure driftzone_phone
```
