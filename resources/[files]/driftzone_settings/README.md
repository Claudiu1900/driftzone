# driftzone_settings

Settings pentru DriftZone:
- HUD cu hard hide real;
- Radar / minimap;
- Overhead players;
- Overhead personal;
- Turometru;
- Voice Volume UI.

Cand toggle-ul HUD este OFF, foloseste hard hide:

```lua
TriggerEvent('driftzone_hud:client:lockHide')
```

Cat timp hard hide este activ, trigger-ele vechi precum `driftzone_hud:client:show` sau `driftzone_hud:visible, true` nu mai pot afisa HUD-ul.
