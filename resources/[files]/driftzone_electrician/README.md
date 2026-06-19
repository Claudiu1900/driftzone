# driftzone_electrician

Job complet de electrician creat pentru structura serverului DriftZone.

## Ce conține

- NPC dispecer cu angajare, informații, pornirea turei și demisie;
- uniformă de serviciu aplicată la început și restaurată la final;
- dubă de serviciu cu trei poziții de spawn verificate în ordine;
- dacă toate cele trei locuri sunt ocupate, duba nu este creată și jucătorul primește notificare;
- blip dinamic legat de dubă, care urmărește poziția curentă a vehiculului pe hartă;
- depozit de unelte cu ridicarea și returnarea trusei;
- tabletă NUI accesibilă din fluxul jobului și de la NPC, fără comandă și fără keybind F6;
- stâlpi, cutii de siguranțe, panouri de joasă și înaltă tensiune;
- cinci proceduri interactive: conectare fire, siguranțe arse, secvențe, întrerupătoare și calibrare tensiune;
- mini-game ales server-side pentru fiecare intervenție, astfel încât taskurile să varieze;
- animații diferite după tipul intervenției;
- vreme rea cu șansă de intervenții suplimentare;
- Electrician I, II și III, XP, promovări și multiplicatori salariali;
- bonus pentru tură completă fără greșeli;
- plăți și validări făcute pe server;
- protecție nonce, timp minim, distanță, rate limit și expirarea turei;
- salvare permanentă prin oxmysql;
- detectare UID prin player state sau exporturile driftzone_auth;
- detectare automată a economiei din users.wallet/users.cash/users.money sau vrp_user_moneys;
- plăți restante salvate dacă economia nu este configurată corect;
- loop-uri adaptive pe client pentru consum redus.

## Instalare

1. Pune folderul `driftzone_electrician` în `resources/[jobs]/`.
2. Asigură-te că oxmysql și sistemul de autentificare pornesc înainte.
3. Adaugă în `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_electrician
```

Dacă autentificarea ta are altă denumire, resource-ul poate lua UID și din state bag-urile:

```txt
dz_uid
uid
user_id
userId
driftzone_uid
```

Tabelul SQL se creează automat. Fișierul manual este în `sql/driftzone_electrician.sql`.

## Controale

```txt
E - interacțiuni cu NPC-ul, depozitul și intervențiile
ESC - închide meniul companiei/tableta când nu este activ un mini-game
```

Nu există `/electrician` și nu există keybind F6.

## Spawnurile dubei

Sunt verificate în această ordine:

```lua
vector4(744.303284, 136.219788, 80.267456, 249.45)
vector4(742.575806, 132.962632, 80.233642, 257.95)
vector4(751.635192, 110.518684, 79.071044, 136.06)
```

Raza de verificare poate fi modificată din:

```lua
Config.Vehicle.clearanceRadius = 3.5
```

## Configurare importantă

Toată configurarea se află în:

```txt
shared/config.lua
```

Acolo poți modifica:

- coordonatele NPC-ului;
- depozitul de unelte;
- spawnurile și blipul dubei;
- modelul dubei;
- uniformele male/female;
- plățile și XP-ul;
- nivelurile;
- procedurile interactive disponibile pentru fiecare tip de task;
- toate intervențiile;
- bonusul de tură;
- distanțele și protecțiile.

## Economie

Implicit:

```lua
Config.Economy.mode = 'auto'
```

Sistemul caută automat următoarele structuri:

```txt
users.id / users.uid / users.user_id
users.wallet / users.cash / users.money / users.bank

vrp_user_moneys.user_id
vrp_user_moneys.wallet / vrp_user_moneys.bank
```

Dacă economia ta folosește alt tabel, adaugă profilul în `Config.Economy.databaseProfiles`.

### Plata prin export

```lua
Config.Economy.mode = 'export'
Config.Economy.export = {
    resource = 'numele_economiei',
    name = 'AddMoney',
    argumentOrder = 'source_uid_amount_reason'
}
```

Ordini suportate:

```txt
source_uid_amount_reason
uid_amount_reason
source_amount_reason
uid_amount
```

### Plata prin event

```lua
Config.Economy.mode = 'event'
Config.Economy.event = 'driftzone_electrician:server:addMoney'
```

În resource-ul economiei:

```lua
AddEventHandler('driftzone_electrician:server:addMoney', function(source, uid, amount, reason)
    -- funcția ta de adăugare bani
end)
```

## Integrare notificări

Resource-ul folosește:

```lua
TriggerEvent('client:notify', tip, durata, mesaj)
```

Evenimentul poate fi schimbat din:

```lua
Config.NotifyEvent = 'client:notify'
```

## Exporturi server

```lua
local profile = exports.driftzone_electrician:GetElectricianProfile(source)
local active = exports.driftzone_electrician:HasActiveElectricianShift(source)
local uid = exports.driftzone_electrician:GetElectricianUid(source)
```

## Observații

- Uniformele incluse sunt pentru `mp_m_freemode_01` și `mp_f_freemode_01`.
- Dacă pachetele tale de haine schimbă drawable-urile, editează `Config.Uniform`.
- Cu `Config.Security.RequireOneSync = true`, serverul validează distanțele folosind ped-ul server-side.
- Coordonatele intervențiilor trebuie ajustate dacă folosești un MLO sau o hartă diferită.
