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
