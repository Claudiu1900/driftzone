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


## Fix duty state

Versiunea asta repara cazul:
- esti ON DUTY si `/ticket` deschide staff panel;
- dai OFF DUTY si `/ticket` devine ticket normal de player;
- dai iar ON DUTY si `/ticket` revine la staff panel.

Fixuri:
- UID fallback mai robust;
- nu mai blocheaza comanda daca `IsLoggedIn` nu raspunde dupa toggle aduty, dar UID-ul exista;
- verifica `users.admin_level` si `users.aduty` direct din DB la fiecare folosire;
- refresh la counter/state la 2.5 secunde si cand folosesti comanda;
- `RunCommand` accepta si comenzi primite cu slash, ex `/ticket`.
