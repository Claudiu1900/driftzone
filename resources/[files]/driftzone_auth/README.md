# DriftZone Auth

## Update anti multi-account

La conectare, auth verifica numele actual si cauta in `users` alt cont cu nume diferit dar cu acelasi:
- IP
- license
- steam
- fivem
- discord

Daca gaseste alt cont, playerul este respins direct din FiveM connect, inainte sa intre in meniul auth.
Mesajul il trimite sa intre cu numele contului vechi.

## Starter car

La prima inregistrare se adauga automat `caddy` in `ownedvehicles` cu tuningul configurat in `config.lua`.
