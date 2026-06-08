# driftzone_racejob

Fix final pentru Race Job + Special Duo Race.

## Fixuri

- Cardul SPECIAL are aceeasi marime ca restul cardurilor si nu se mai suprapune textul.
- Invite-ul Duo Race nu mai inchide UI-ul daca ID-ul este invalid.
- Daca invite-ul nu se poate trimite, ramane meniul deschis si apare eroarea in UI.
- Campul de invite accepta atat server ID, cat si UID-ul jucatorului, daca UID-ul este cel afisat in HUD.
- Dupa invite trimis corect, cursorul se inchide si jucatorul nu mai ramane blocat.
- ESC inchide meniurile corect.
- /racejob ramane scos.
- /rracecd <id> reseteaza cooldown-ul fara sa deschida meniul.

## Instalare

Pune folderul ca:

```txt
resources/[files]/driftzone_racejob
```

Apoi:

```cfg
restart driftzone_racejob
```


## Update
- `/rracecd <uid>` reseteaza cooldown-ul dupa UID, nu dupa server ID.
- Timer-ul cursei este pozitionat jos, in dreapta minimap-ului.
- Cooldown separat pe castig/pierdere: `cooldown` pentru castig si `failCooldown` pentru pierdere, configurabile in `config.lua`.


## Update selectie masini
- La deschiderea meniului nu este selectata nicio masina.
- Click pe o masina selecteaza strict masina respectiva.
- Click pe alta masina deselecteaza automat selectia veche.
- La Duo invite, input-ul si butonul au spatiu mai curat intre ele.


## Update garage block

- In timpul oricarei curse din `driftzone_racejob`, garajul este blocat.
- Nu se mai poate deschide din comanda, trigger sau interactiune.
- Daca jucatorul incearca sa deschida garajul, primeste notificarea: `Garaj indisponibil.`
- Dupa finish/fail/resource stop, garajul se deblocheaza automat.

Porneste `driftzone_garage` inainte de `driftzone_racejob`:

```cfg
ensure driftzone_garage
ensure driftzone_racejob
```
