# driftzone_inventory - Optimized FINAL

Inventory DriftZone optimizat pentru framework propriu.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
```

Ruleaza `SQL.sql` daca nu ai tabelele.

## Update-uri incluse

- Cand dai GIVE la un item, se ruleaza animatia `give2` o singura data.
- Cand dai DROP sau PICKUP la un item, se ruleaza animatia `pickup` o singura data.
- Inventarul face reload din DB de fiecare data cand il deschizi.
- Dupa GIVE nu se mai redeschide inventarul automat.
- Markerul/sageata de la drop-uri se vede la tot serverul in radius, nu doar la cel care arunca.
- Drag & drop cu item in afara inventarului = DROP pe jos.
- Hook-uri usor de modificat in `shared/config.lua`.
- Drop polling optimizat si configurabil.

## Config hook-uri

In `shared/config.lua` ai:

```lua
Config.ClientHooks.OnGiveSuccess = function(data)
    TriggerEvent('driftzone_inventory:client:playActionAnimation', 'give')
end

Config.ClientHooks.OnDropSuccess = function(data)
    TriggerEvent('driftzone_inventory:client:playActionAnimation', 'pickup')
end

Config.ClientHooks.OnPickupSuccess = function(data)
    TriggerEvent('driftzone_inventory:client:playActionAnimation', 'pickup')
end
```

Poti pune si alte triggere/exporturi acolo.

## Animatii

Default foloseste animatii native GTA pentru toti jucatorii:

```lua
Config.ActionAnimations.UseDriftzoneEmotes = false
```

Daca vrei sa foloseasca `driftzone_emotes`, setezi:

```lua
Config.ActionAnimations.UseDriftzoneEmotes = true
```

Emote-urile default sunt:

```lua
give = 'give2'
pickup = 'pickup'
```

Sunt oprite automat dupa durata setata in config ca sa nu ramana in loop.
