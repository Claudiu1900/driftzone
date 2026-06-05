# DriftZone Chat Optimized

## Ce s-a schimbat

- Nu mai trebuie sa bagi fiecare comanda manual in `server/main.lua`.
- Pentru comenzile cu `RegisterCommand` pe client, chat-ul trimite comanda direct la client si ruleaza:
  ```lua
  ExecuteCommand(commandLine)
  ```
- Pentru scripturi server-side care au export `RunCommand`, comenzile sunt puse in `config.lua`, nu in `server/main.lua`.
- Server/main.lua este curatat si mai optimizat.
- Cache UID: 30 secunde.
- Cache meta/rank/admin: 3 secunde.
- Command routes sunt cached si se pot reincarca cu:
  ```lua
  exports.driftzone_chat:ReloadCommandRoutes()
  ```

## Instalare

Inlocuieste folderul:

```txt
resources/[driftzone]/driftzone_chat
```

Apoi:

```cfg
restart driftzone_chat
```

## Important

FiveM nu ofera o metoda safe prin care un resource sa vada automat toate `RegisterCommand` server-side cu source-ul jucatorului.

De aceea functioneaza asa:

### 1. Comenzi cu RegisterCommand client-side

Merg automat fara sa le pui nicaieri.

Exemplu: daca un script are in client:

```lua
RegisterCommand('shop', function()
    TriggerEvent('driftzone_shop:client:show')
end)
```

atunci in chat merge direct:

```txt
/shop
```

### 2. Comenzi server-side cu export RunCommand

Le pui doar in `config.lua`, in:

```lua
Config.CommandRoutes = {
    driftzone_admin = { 'aduty', 'goto', 'bring' }
}
```

Nu mai modifici `server/main.lua`.

## Recomandare pentru scripturile tale

Pentru orice resource nou, fa una din variante:

### Varianta recomandata: client RegisterCommand

```lua
RegisterCommand('numecomanda', function(_, args)
    TriggerServerEvent('resursa:server:run', 'numecomanda', args or {})
end, false)
```

Atunci nu mai trebuie nimic in chat.

### Varianta server export

```lua
exports('RunCommand', function(src, command, args)
    -- codul tau
end)
```

Atunci bagi comanda doar in `config.lua`.


## Fix badge admin/aduty

- Chat-ul invalideaza imediat MetaCache cand se schimba `Player.state.dz_aduty`.
- Chat-ul invalideaza imediat MetaCache cand se schimba `Player.state.dz_admin_level`.
- `getAdutyFromState` foloseste direct valoarea din state, inclusiv `false/no/0`, fara sa cada pe export vechi.
- La `/aduty`, chat-ul mai face refresh meta de siguranta dupa 250ms si 1000ms.
- `MetaCacheMs` este 1000ms pentru update rapid, dar ramane optimizat.


## Update live grade check

- Chat-ul verifică gradul/aduty live la fiecare mesaj trimis.
- Nu mai folosește MetaCache pentru badge-ul de staff.
- Dacă ai `aduty no`, următorul mesaj nu mai afișează gradul de staff.
- `MetaCacheMs = 0` în config pentru partea de meta chat.
- UID cache rămâne activ, deci sistemul rămâne optimizat.
