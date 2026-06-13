# driftzone_vehicless v13 clean

Comanda:

```txt
/vehss model
```

Exemplu:

```txt
/vehss s15
```

Screenshot-ul a fost scos complet. Nu mai exista `screenshot-basic`, `yarn`, `webpack`, `screenshots` sau buton de screenshot.

Clean mode:

- apasa tasta ` ca sa dispara UI-ul, radarul/minimap-ul si HUD-ul;
- apasa din nou ` ca sa apara tot inapoi;
- daca tasta nu merge, foloseste comanda `/vehssclean`.

Pentru HUD extern se apeleaza automat:

```lua
TriggerEvent('driftzone_hud:client:hide')
TriggerEvent('driftzone_hud:visible', false)
TriggerEvent('driftzone_hud:client:show')
TriggerEvent('driftzone_hud:visible', true)
```

Instalare in `server.cfg`:

```cfg
ensure driftzone_vehicless
```
