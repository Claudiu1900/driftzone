# DriftZone Admin System - Full Logs Optimized

## Instalare

Pune folderul:

```txt
resources/[driftzone]/driftzone_admin
```

In `server.cfg`:

```cfg
ensure oxmysql
ensure driftzone_admin
```

Ruleaza `SQL.sql`, apoi:

```cfg
restart driftzone_admin
restart driftzone_chat
```

## Ce este nou

- Logs DB pentru fiecare comanda admin.
- Tabela: `admin_command_logs`.
- Logheaza:
  - admin uid;
  - admin name;
  - admin level;
  - command;
  - args;
  - status;
  - target uid;
  - target name;
  - mesaj/eroare;
  - data.
- Pastreaza si trigger-ele vechi catre:
  - `logs:create`;
  - `driftzone_logs:create`.
- Cache admin data 2.5 secunde.
- Cache lookup player 2 secunde.
- Curata cache la playerDropped.
- Creeaza automat `users.warns` si `admin_command_logs` la pornire.

## Comenzi admin/player

```txt
/aduty              - admin 1
/staff              - player
/goto id            - admin 1 + aduty
/bring id           - admin 1 + aduty
/kick id motiv      - admin 1 + aduty
/slap id            - admin 2 + aduty
/warn id motiv      - admin 3 + aduty
/rwarn id           - admin 5 + aduty
/warns              - player
/warns id           - admin 1 + aduty
/resetwarns id      - admin 6 + aduty
/coords             - admin 6 + aduty
/gotocoords x y z   - admin 2 + aduty
/tptow              - player, fara cooldown pentru admin aduty
/nc                 - admin 3 + aduty
/veh model          - admin 3 + aduty
/fix                - admin 2 + aduty
/ban id motiv       - admin 5 + aduty
/tempban id zile motiv - admin 4 + aduty
/unban uid          - admin 5 + aduty
/givecar uid model plate_optional - admin 6 + aduty
/takecar uid id_masina - admin 6 + aduty
/transfercar uid_nou id_masina - admin 6 + aduty
/changeplate id_masina plate - admin 6 + aduty
/addoutfit nume link_optional - admin 6 + aduty
```

## Config logs

In `config.lua`:

```lua
Config.Logs = {
    enabled = true,
    table = 'admin_command_logs',
    logFailed = true,
    triggerExternalLogs = true
}
```

## Config warnings

```lua
Config.Warns = {
    tempBanDays = 4,
    maxWarns = 3
}
```

La `maxWarns`, jucatorul primeste tempban automat pentru `tempBanDays`.


## Update noclip vehicle safety

- Daca adminul este intr-o masina si activeaza `/nc`, il scoate automat din masina.
- Noclip-ul se aplica doar pe ped, nu pe vehicul.
- Masina ramane pe loc si primeste velocity 0, ca sa nu poata pleca cu ea in noclip.


## Update

- Scoase comenzile din driftzone_admin:
  - /fixskin
  - /setcl
  - /bancl
- Daca un jucator ajunge la limita de warn-uri si primeste tempban automat, warn-urile lui se reseteaza la 0.
