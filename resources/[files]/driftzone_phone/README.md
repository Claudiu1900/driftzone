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


## Garage App

Adaugat app `Garaj` in telefon.

Functii:
- afiseaza toate masinile playerului din `ownedvehicles`;
- apasare pe masina => pagina doar cu masina;
- `Scoate din Garaj` verifica `ownedvehicles.garage` si permite spawn doar daca masina este in garajul unde sta playerul;
- `Parcheaza` apare doar cand playerul este in radiusul unui garaj si masina este scoasa;
- `Tracteaza` cere playerul sa fie la un garaj, costa 5000 din `users.cash` si muta masina in garajul curent;
- daca masina este deja in acelasi garaj: `Masina este deja la cel mai apropiat garaj.`;
- daca nu are bani: `Nu ai suma de 5000 pentru tractare.`;
- `Localizeaza` apare doar daca masina este scoasa si pune waypoint la masina.

SQL:
- `ownedvehicles.garage`
- `users.outsidevehicles`
- tabela `garages` daca nu exista deja.

Mesaje:
- notificarea tip peek pentru mesaj dispare automat dupa 3 secunde;
- pagina de mesaje este simplificata.


## V1.1.1 fixes

- Fix `sendState nil` in garage refresh.
- `Parcheaza` verifica acum ca playerul si masina sa fie in radiusul aceluiasi garaj.
- Cand parchezi masina, seteaza `ownedvehicles.garage` la garajul respectiv.
- `Tracteaza` nu mai merge daca masina este scoasa din garaj.
- `Localizeaza` ramane doar pentru masini scoase.
- Aplicatia separata `Apeluri` a fost scoasa de pe Home; istoricul este acum in aplicatia `Telefon`, tabul `Apeluri`.
- Fix pentru apel ramas blocat cand celalalt inchide inainte sa raspunzi.
- Sunetele sunt initializate si reincercate mai stabil.
- Telefonul se deschide de pe tasta `L` prin `RegisterKeyMapping`.
