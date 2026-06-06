# driftzone_tickets - Modern Fullscreen UI

## Ce s-a schimbat

- UI refacut complet fullscreen.
- Design modern/futuristic, fara emoji-uri.
- Iconurile sunt SVG inline.
- Admin panel cu search.
- Counter-ul de tickete ramane.
- Logica ticketelor ramane aceeasi.
- Bug accept fix: adminul nu mai este teleportat de doua ori.
- Anti double-click pe Accept in NUI.

## Comenzi

```txt
/ticket
/tickets
/cancelticket
```

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_tickets
```

## Pentru driftzone_chat custom

```lua
ticket = 'driftzone_tickets',
tickets = 'driftzone_tickets',
cancelticket = 'driftzone_tickets',
```

sau:

```lua
exports.driftzone_tickets:RunCommand(src, command)
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_tickets
git commit -m "Modernize tickets UI and fix double teleport"
git pull --rebase origin main
git push origin main
```

Pe VPS:

```bash
cd ~/server-data
git pull --rebase origin main
```

txAdmin:

```txt
restart driftzone_tickets
```


## FINAL aduty fix

Regula este strict:

```txt
users.aduty = 1 -> admin ON DUTY -> /ticket deschide staff panel
users.aduty = 0 -> admin OFF DUTY -> /ticket deschide ticket normal de player
```

Nu mai blocheaza /ticket dupa ce schimbi ON/OFF duty.

Ce s-a schimbat:
- nu mai depinde strict de `IsLoggedIn` cand UID-ul exista;
- `isDutyValue()` trateaza numeric: doar `1` inseamna ON;
- `0` inseamna OFF;
- /ticket verifica DB live de fiecare data;
- /ticket deschide mereu ceva: staff panel daca esti aduty 1, player panel daca esti aduty 0;
- accept/delete/teleport raman doar pentru staff ON DUTY.

## FIX aduty 0 dupa staff panel

Fix aplicat:
- eliminat loop-ul NUI `close -> close callback -> close` care putea bloca meniul dupa ce ai deschis staff panel;
- `/ticket` verifica live DB de fiecare data;
- `users.aduty = 1` deschide panel staff;
- `users.aduty = 0` deschide panel normal de player;
- daca adminul avea staff panel deschis si trece OFF DUTY, urmatorul `/ticket` comuta direct pe player panel;
- daca ai deja ticket activ, UI-ul tot se deschide, ca sa nu para ca nu se intampla nimic.

Pentru driftzone_chat custom:

```lua
ticket = 'driftzone_tickets',
tickets = 'driftzone_tickets',
tikcet = 'driftzone_tickets',
cancelticket = 'driftzone_tickets',
```

sau:

```lua
exports.driftzone_tickets:RunCommand(src, command)
```
