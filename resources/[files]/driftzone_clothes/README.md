# driftzone_clothes - FIXED SQL

Resource-ul nu mai incearca sa creeze baza separata `driftzone_logs`.
Foloseste baza principala `driftzone` pentru:
- `users.clothes`
- `unallowed_clothes`
- `clothes_logs`

## Comenzi
/haine, /clothes, /fixskin id, /setcl id categorie drawable, /bancl categorie drawable

Access: admin_level 7+ si aduty yes.

## server.cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_clothes

## Git
git add -A resources/[files]/driftzone_clothes
git commit -m "Fix clothes SQL logs database"
git pull --rebase origin main
git push origin main
