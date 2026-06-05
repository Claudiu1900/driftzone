# DriftZone Outfits - SAFE Trigger Only + Sex Filter

## Important

Nu mai are keybind intern.
Nu mai are comenzi client `/outfit` sau `/outfits`.

Deschiderea se face doar prin:

```lua
TriggerEvent('driftzone_outfits:client:requestOpen')
```

sau:

```lua
exports.driftzone_outfits:Open()
```

## Sex filter

La `/addoutfit`, sistemul detecteaza ped-ul:

- `mp_m_freemode_01` => `m`
- `mp_f_freemode_01` => `f`

In DB se salveaza:

```sql
outfits.sex
```

Jucatorii vad doar outfit-uri pentru sexul caracterului lor.

## SQL

Ruleaza `SQL.sql` sau lasa resource-ul sa faca automat ALTER la pornire.

## driftzone_keybinds

La tasta setata de tine, pune client-side:

```lua
TriggerEvent('driftzone_outfits:client:requestOpen')
```

## server.cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_notifications
ensure driftzone_clothes
ensure driftzone_outfits
```
