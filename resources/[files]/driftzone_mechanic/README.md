# driftzone_mechanic

Job complet de mecanic pentru FiveM, fără comandă și fără acces pe F6. Jucătorul folosește NPC-ul atelierului.

## Funcții

- NPC pentru angajare, informații, pornirea turei și demisie
- uniformă automată și restaurarea hainelor la final
- vehicul de serviciu cu 3 poziții de spawn și verificare de ocupare
- blip permanent pe vehiculul de serviciu
- depozit de unelte
- intervenții aleatorii în Los Santos și Blaine County
- 6 minijocuri: diagnoză, baterie, anvelopă, ulei, frâne și motor
- ranguri Mecanic I, Mecanic II și Mecanic III
- XP, promovări, plată variabilă și intervenții urgente
- bonus pentru tură fără greșeli
- verificări server-side pentru distanță, timpi și task ID
- salvare MySQL
- suport automat QBCore și ESX
- mod intern pentru servere custom

## Instalare

1. Pune folderul `driftzone_mechanic` în `resources`.
2. Asigură-te că `oxmysql` pornește înaintea jobului.
3. Adaugă în `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_mechanic
```

Tabela SQL este creată automat. Poți importa și `sql/install.sql` manual.

## Economie / framework

În `config.lua`, `Config.Framework = 'auto'` detectează QBCore sau ESX.

Dacă serverul tău folosește un framework custom, editează funcția `DZMechanicBridge.AddMoney` din `server/bridge.lua`. Când funcția returnează `true`, plata a intrat în economia serverului. Fără integrare, banii sunt salvați în `internal_wallet`, astfel încât nu se pierd.

## Notificări DriftZone

Resursa încearcă automat evenimentul configurat aici:

```lua
Config.NotificationEvent = 'driftzone_notifications:client:notify'
```

Dacă evenimentul sistemului tău are altă structură, modifică funcția `notify` din `client/main.lua`. Dacă resursa nu rulează, se folosește notificarea GTA standard.

## Configurare

Toate coordonatele, plățile, XP-ul, rangurile, uniformele, vehiculele și probabilitatea intervențiilor urgente sunt în `config.lua`.

Nu există `/mechanic`, F6 sau tabletă. Meniul se deschide doar la NPC.

## Corecție v1.1.0

- angajarea confirmă rezultatul direct din baza de date
- tabela este verificată și reparată automat dacă lipsesc coloane
- butoanele afișează corect starea de procesare și nu mai pot fi apăsate repetat
- erorile SQL sunt afișate în consola serverului și jucătorul primește notificare
