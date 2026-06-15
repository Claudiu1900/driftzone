# driftzone_phone V8

Telefon DriftZone refacut.

## Ce include

- UI nou mai curat si mai fluid.
- Contacte: add, edit, block, delete.
- Daca ai un numar la block, nu te mai poate suna.
- Apeluri cu accept/refuz/inchidere.
- Mesaje live: apar instant la ambii jucatori, fara refresh greu.
- Istoric mesaje in `message_history`.
- Istoric apeluri in `call_history`.
- Share location in conversatie, cu waypoint cand apesi pe locatie.
- Sunete controlate: nu se mai suprapun in loop aiurea.
- Cursor cu tasta ` cat timp telefonul e vizibil.
- Mute si Speaker pentru apel prin `driftzone_voicechat`.

## Instalare

Ruleaza SQL:

```sql
source driftzone_phone/SQL.sql
```

server.cfg:

```cfg
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
setr voice_enableUi 0

ensure oxmysql
ensure driftzone_auth
ensure driftzone_voicechat
ensure driftzone_phone
```

## Sound-uri

Sunetele se pun in:

```txt
driftzone_phone/html/assets/sounds/ring.mp3
driftzone_phone/html/assets/sounds/ring2.mp3
driftzone_phone/html/assets/sounds/decline.mp3
driftzone_phone/html/assets/sounds/message.mp3
```
