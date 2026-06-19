# driftzone_electrician

Job complet de electrician creat pentru structura serverului DriftZone.

## Ce contine

- NPC dispecer cu angajare, informatii, pornire tura si demisie;
- uniforma de serviciu aplicata la inceput si restaurata la final;
- duba de serviciu, trei puncte alternative de spawn, cleanup si recuperare;
- depozit de unelte cu ridicare si returnare trusa;
- tableta NUI cu toate interventiile, progres, plata, XP si ruta GPS;
- stalpi, cutii de sigurante, panouri de joasa si inalta tensiune;
- animatii diferite dupa tipul interventiei;
- mini-game de stabilizare a circuitului;
- vreme rea cu sansa de interventii suplimentare;
- Electrician I, II si III, XP, promovari si multiplicatori salariali;
- bonus pentru tura completa fara greseli;
- plati si validari facute pe server;
- protectie nonce, timp minim, distanta, rate limit si expirare tura;
- salvare permanenta prin oxmysql;
- detectare UID prin player state sau exporturile driftzone_auth;
- detectare automata a economiei din users.wallet/users.cash/users.money sau vrp_user_moneys;
- plati restante salvate daca economia nu este configurata corect;
- loop-uri adaptive pe client pentru consum redus.

## Instalare

1. Pune folderul `driftzone_electrician` in `resources/[jobs]/`.
2. Asigura-te ca oxmysql si sistemul de autentificare pornesc inainte.
3. Adauga in `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_electrician
```

Daca autentificarea ta are alta denumire, resource-ul poate lua UID si din state bag-urile:

```txt
dz_uid
uid
user_id
userId
driftzone_uid
```

Tabelul SQL se creeaza automat. Fisierul manual este in `sql/driftzone_electrician.sql`.

## Comenzi

```txt
/electrician
F6 - tableta electricianului
E  - interactiuni
```

## Configurare importanta

Toata configurarea se afla in:

```txt
shared/config.lua
```

Acolo poti modifica:

- coordonatele NPC-ului;
- depozitul de unelte;
- spawn-urile dubei;
- modelul dubei;
- uniformele male/female;
- platile si XP-ul;
- nivelurile;
- toate interventiile;
- bonusul de tura;
- distantele si protectiile.

## Economie

Implicit:

```lua
Config.Economy.mode = 'auto'
```

Sistemul cauta automat urmatoarele structuri:

```txt
users.id / users.uid / users.user_id
users.wallet / users.cash / users.money / users.bank

vrp_user_moneys.user_id
vrp_user_moneys.wallet / vrp_user_moneys.bank
```

Daca economia ta foloseste alt tabel, adauga profilul in:

```lua
Config.Economy.databaseProfiles
```

Exemplu:

```lua
{ table = 'users', uidColumns = { 'id' }, cashColumns = { 'wallet' }, bankColumns = { 'bank' } }
```

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

In resource-ul economiei:

```lua
AddEventHandler('driftzone_electrician:server:addMoney', function(source, uid, amount, reason)
    -- functia ta de adaugare bani
end)
```

## Integrare notificari

Resource-ul foloseste acelasi format ca scriptul oferit ca exemplu:

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

## Observatii

- Uniformele incluse sunt pentru `mp_m_freemode_01` si `mp_f_freemode_01`.
- Daca pachetele tale de haine schimba drawable-urile, editeaza `Config.Uniform`.
- Cu `Config.Security.RequireOneSync = true`, serverul valideaza distantele folosind ped-ul server-side.
- Coordonatele sunt configurabile si trebuie ajustate daca folosesti un MLO diferit.
