# DriftZone Shop

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_shop
```

Ruleaza `SQL.sql`.

## Triggere

```lua
TriggerEvent('driftzone_shop:client:show')
TriggerEvent('driftzone_shop:client:hide')
```

## Categorii

Prima categorie este `Cash`, apoi `Vehicles`.

## Imagini necesare in html/images/

```txt
cash_50000.png          900x420 px
cash_100000.png         900x420 px
cash_250000.png         900x420 px
cash_500000.png         900x420 px
cash_1000000.png        900x420 px

garage_slots.png        900x420 px
outside_vehicles.png    900x420 px
test_item.png           900x420 px
```

## Produse Cash

```txt
50,000 cash     - 300 DZ Coins
100,000 cash    - 500 DZ Coins
250,000 cash    - 1000 DZ Coins
500,000 cash    - 1750 DZ Coins
1,000,000 cash  - 3000 DZ Coins
```

## Produse Vehicles

```txt
Garage Slots      - 1000 DZ Coins - users.garageslots +1
Outside Vehicles  - 1000 DZ Coins - users.outsidevehicles +1
Test Item         - indisponibil
```

## Note

Am scos `Config.Defaults`; shop-ul nu mai folosește default pentru garageslots/outsidevehicles.
