# driftzone_phone

Prototip telefon DriftZone cu apeluri, contacte, block, istoric apeluri, mesaje sync si share location.

## Instalare

Ruleaza SQL:

```sql
source driftzone_phone/SQL.sql
```

Asigura-te ca in tabela `users` exista coloana `phonenumber`.

In `server.cfg`:

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

Sound-urile sunt incluse in:

```txt
driftzone_phone/html/assets/sounds/ring.mp3
driftzone_phone/html/assets/sounds/ring2.mp3
driftzone_phone/html/assets/sounds/decline.mp3
driftzone_phone/html/assets/sounds/message.mp3
```

## Comanda

```txt
/phone
```

Backtick ` toggles cursorul cat timp telefonul este vizibil.
