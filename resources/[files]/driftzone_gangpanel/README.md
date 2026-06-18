# driftzone_gangpanel - withdrawal + tablet fix

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_inventory
ensure driftzone_gangpanel
```

Ruleaza `SQL.sql` daca nu ai tabelele.

## Update inclus

- Fix animatie tableta: nu mai porneste animatia in loop la fiecare frame.
- Tableta se porneste cand deschizi panoul si se opreste fortat cand inchizi meniul / resource stop.
- Retragerea nu mai pune waypoint clasic cu `SetNewWaypoint`.
- Retragerea creeaza blip local albastru + marker/prompt local doar pentru liderul care trebuie sa ridice pachetul.
- Nu mai foloseste `driftzone_interactions:addPersonalWaypoint` pentru retrageri, ca sa evite crash/bug de compatibilitate.
- UI polish: iconuri SVG refacute si navigatie cu iconuri.

## Config important

In `shared/config.lua`:

```lua
Config.Withdrawal.UseInteractions = false
Config.Withdrawal.SetGpsWaypoint = false
Config.Withdrawal.CustomBlip = {
    Sprite = 500,
    Color = 3,
    Scale = 0.82,
    Name = 'Ridicare pachet',
    Route = false
}
```

Pentru animatia tabletei:

```lua
Config.TabletAnimation = {
    enabled = true,
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
    anim = 'base',
    flag = 49,
    prop = 'prop_cs_tablet'
}
```
