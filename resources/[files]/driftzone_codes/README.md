# DriftZone Codes

## Fix `nil column`

A fost reparat complet bugul:

```txt
UPDATE users SET `nil` = ...
```

Acum scriptul nu mai foloseste niciodata `reward.column` direct daca nu exista. Rezolva coloana prin `getRewardColumn()` si verifica in database cu `INFORMATION_SCHEMA`.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_codes
```

Ruleaza `SQL.sql`.

## Reward-uri

```txt
/createcode TEST 250 dz       -> 250 DriftZone Coins, users.dzcoins
/createcode TEST 250 c        -> 250 Money, users.money sau users.cash
/createcode TEST 250 coin     -> 250 Money, users.money sau users.cash
/createcode TEST 250 coins    -> 250 Money, users.money sau users.cash
/createcode TEST 250c         -> 250 Money, users.money sau users.cash
/creatercode 250 coins 10 7d  -> random code, 10 uses, expira in 7 zile
```

## Coloane reward

In `config.lua`:

```lua
Config.Rewards = {
    dzcoins = {
        label = 'DriftZone Coins',
        columns = { 'dzcoins' }
    },

    money = {
        label = 'Money',
        columns = { 'money', 'cash' }
    }
}
```

Daca banii tai sunt in alta coloana, schimba:

```lua
columns = { 'coloana_ta' }
```

## Case-sensitive

Codurile sunt case-sensitive:

```txt
ABC != abc
```

Ruleaza SQL-ul inclus ca sa aplice collation `utf8mb4_bin`.

## Pentru driftzone_chat

Pastreaza in chat:

```lua
local codesCommands = {
    code = true,
    codes = true,
    createcode = true,
    creatercode = true,
    delcode = true,
    codeslist = true
}
```

Si in `handleCommand`:

```lua
if codesCommands[command] then
    local ok, err = pcall(function()
        exports.driftzone_codes:RunCommand(src, command, args or {})
    end)

    if not ok then
        print(('[DRIFTZONE_CHAT] /%s codes command error:'):format(command))
        print(err)
        sendError(src, ('Eroare la /%s. Verifica daca driftzone_codes este pornit.'):format(command))
    end

    return
end
```

## Comenzi

```txt
/code
/codes
/createcode (code) (1000 dz) (redeems optional) (1d optional)
/creatercode (1000 dz) (redeems optional) (1d optional)
/delcode (id)
/codeslist
```
