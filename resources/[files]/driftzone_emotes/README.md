# driftzone_emotes

Sistem de emotes pentru FiveM, redenumit si adaptat pentru DriftZone.

## Pornire

```cfg
ensure driftzone_emotes
```

Nu are nevoie de ESX/QBCore/QBX. Ruleaza standalone/custom framework.

## Comenzi

```txt
/emotes
/e nume_emote
/e c
/e cancel
/e stop
```

## Trigger normal

Poate fi oprit de jucator cu `/e c`.

```lua
TriggerEvent('driftzone_emotes:client:play', 'sit')
TriggerEvent('driftzone_emotes:client:stop')
```

De pe server:

```lua
TriggerClientEvent('driftzone_emotes:client:play', targetId, 'sit')
TriggerClientEvent('driftzone_emotes:client:stop', targetId)
```

## Trigger locked

Nu poate fi oprit cu `/e c`. Se opreste doar cu forceStop.

```lua
TriggerEvent('driftzone_emotes:client:playLocked', 'sit')
TriggerEvent('driftzone_emotes:client:forceStop')
```

De pe server:

```lua
TriggerClientEvent('driftzone_emotes:client:playLocked', targetId, 'sit')
TriggerClientEvent('driftzone_emotes:client:forceStop', targetId)
```

## Exports

```lua
exports['driftzone_emotes']:OpenMenu()
exports['driftzone_emotes']:PlayEmote('sit')
exports['driftzone_emotes']:PlayLockedEmote('sit')
exports['driftzone_emotes']:CancelEmote(false)
exports['driftzone_emotes']:ForceStopEmote()
```

## Poze UI

UI-ul este cel original 0r-style. Pozele emote-urilor se incarca exact ca inainte, din linkurile originale. Daca vrei fallback local, poti pune imagini in:

```txt
html/files/
html/assets/images/
```

Format acceptat: `.webp`, `.png`, `.svg`.

## Sunete UI

Pune sunetele in:

```txt
html/sounds/
html/assets/sounds/
```

`writing.mp3` merge in oricare din cele doua foldere.

## Stream

Pune manual fisierele mari in:

```txt
stream/
```

Sunt acceptate foldere in interiorul `stream`, de exemplu `[Props]`, `[Gang]`, `[Custom Emotes]`.


## Acces admin

Sistemul este limitat server-side la `users.admin_level >= 6`. Configul este în `shared/config.lua`, secțiunea `Config.Access`.

Necesită `oxmysql` pornit înainte de resource:

```cfg
ensure oxmysql
ensure driftzone_emotes
```

Dacă folosești alt nume de coloană/tabel, modifici:

```lua
Config.Access.UsersTable = 'users'
Config.Access.UsersIdColumn = 'uid'
Config.Access.AdminColumn = 'admin_level'
Config.Access.AdminColumnFallback = ''
Config.Access.MinAdminLevel = 6
```

## Update single synced emotes

- Emote-urile din categoria `shared` / `synced` nu mai cer selectarea unui jucator.
- Cand apesi pe ele din UI sau folosesti `/e nume_emote`, animatia porneste direct pe tine, single.
- Sistemul vechi de request/selectare player a ramas in cod pentru compatibilitate cu event-uri vechi, dar UI-ul si comenzile DriftZone folosesc single-play.
