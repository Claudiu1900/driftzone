# driftzone_gangpanel

Gang panel pentru DriftZone.

## Instalare

1. Pune folderul `driftzone_gangpanel` in resources.
2. Ruleaza `SQL.sql` in baza de date.
3. In `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_emotes
ensure driftzone_gangpanel
```

## Comanda

```txt
/gang
```

## Acces

- `users.sindicate = 1` = acces total.
- Membrii din `gang_members` au acces la panelul gangului lor.
- Grade disponibile: `Membru`, `Co-Lider`, `Lider`.

## Ce face

- `Syndicate` poate crea/edita/dezactiva ganguri.
- Create gang: tip `Neo`/`Oficiala`, nume, shortcut, culoare HEX, UID lider, garage/storage optional.
- Liderul si Co-Liderul pot administra membrii, conform restrictiilor din `shared/config.lua`.
- Membrul simplu are acces pregatit pentru taxe.
- Panelul porneste emote-ul `tablet2` cat timp este deschis si il opreste la inchidere.

## Database

Tabele create:

```txt
gangs
gang_members
gang_logs
gang_taxes
```

Daca nu ai coloana pentru syndicate:

```sql
ALTER TABLE `users` ADD COLUMN `sindicate` TINYINT(1) NOT NULL DEFAULT 0;
```

## Config

Setari in:

```txt
shared/config.lua
```

Poti modifica:

- numele comenzii;
- coloanele DB;
- accesul Co-Liderului;
- hook-uri pentru alte scripturi;
- emote-ul folosit la deschiderea panelului.
