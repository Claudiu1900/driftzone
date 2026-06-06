# DriftZone VoiceChat Loud - Fixed Range

Standalone voice chat pentru FiveM, optimizat si simplificat.

## Fixuri

- Un singur mod: `Tipa/Loud`.
- Push-to-talk pe `N`.
- Distanta audio hard-limit: `15.0`.
- Jucatorii peste distanta sunt muted client-side cu `MumbleSetVolumeOverrideByServerId(..., 0.0)`.
- Daca un jucator nu tine `N`, este muted pentru ceilalti.
- `/voicevol` deschide cursorul.
- Cursorul se inchide doar cu `ESC` sau cu tasta backtick/grave: `.
- Slider-ul nu se mai inchide dupa ce schimbi volumul.
- Volumul 0 ramane 0, nu mai sare la 100.
- Slider mai smooth, trimite update throttled.

## server.cfg

```cfg
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
setr voice_enableUi 0

ensure driftzone_voicechat
```

Nu porni impreuna cu `pma-voice` sau alt voicechat.

## Config

```lua
Config.VoiceMode.distance = 15.0
```

## Comenzi

```txt
/voicevol
```

## Tasta

```txt
N = push-to-talk
```


## UI update

- Icon-ul de microfon care apare cand tii `N` este mutat in dreapta jos si este mai mic.
- UI-ul de volum poate fi ascuns/afisat cu:

```txt
/voiceui
```

Trigger client-side:

```lua
TriggerEvent('driftzone_voicechat:client:showVolumeUi')
TriggerEvent('driftzone_voicechat:client:hideVolumeUi')
TriggerEvent('driftzone_voicechat:client:toggleVolumeUi')
```

Exports client-side:

```lua
exports['driftzone_voicechat']:ShowVolumeUi()
exports['driftzone_voicechat']:HideVolumeUi()
exports['driftzone_voicechat']:ToggleVolumeUi()
```
