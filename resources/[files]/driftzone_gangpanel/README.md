# driftzone_gangpanel

Gang panel complet pentru DriftZone.

## Ce contine

- `/gang` deschide meniul.
- Animatie `tablet2` facuta local, fara sa depinda de permisiunile din `driftzone_emotes`.
- Cand inchizi meniul, animatia si prop-ul de tableta se opresc curat.
- Notificarile folosesc sistemul serverului: `client:notify`.
- Acces total pentru `users.sindicate = 1`.
- Acces gang pentru membri din `gang_members`.
- Grade fixe: `Membru`, `Co-Lider`, `Lider`.
- Tipuri gang: `Mafie Neoficiala`, `Mafie Oficiala`.
- UI premium/dark, optimizat, fara colturi exagerate.
- Dashboard, Gangs, Members, Taxes, Logs, Settings.
- Syndicate poate crea, edita, dezactiva mafii si vede UID/ID server/loguri.
- Liderul si Co-Liderul pot vedea total membri si online fara date de syndicate.
- Co-Lider poate adauga/kick doar membri simpli.
- Lider poate administra membri si Co-Lideri.
- Butoane rapide pentru folosirea coordonatelor tale la garage/storage.

## Instalare

Pune folderul in `resources/[files]/driftzone_gangpanel` sau unde tii resursele.

In `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_gangpanel
```

Ruleaza:

```txt
driftzone_gangpanel/SQL.sql
```

Daca baza ta nu suporta `ADD COLUMN IF NOT EXISTS`, ruleaza manual:

```sql
ALTER TABLE `users` ADD COLUMN `sindicate` TINYINT(1) NOT NULL DEFAULT 0;
```

Seteaza acces total:

```sql
UPDATE `users` SET `sindicate` = 1 WHERE `uid` = UID_UL_TAU;
```

## Config

In `shared/config.lua` poti schimba:

```lua
Config.NotifyEvent = 'client:notify'
Config.Command = 'gang'
Config.SyndicateColumn = 'sindicate'
Config.TabletAnimation.enabled = true
```

