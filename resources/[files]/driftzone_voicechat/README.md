# DriftZone VoiceChat

Versiune cu suport pentru apeluri telefonice din `driftzone_phone`.

## Server.cfg

```cfg
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
setr voice_enableUi 0

ensure driftzone_voicechat
ensure driftzone_phone
```

## Vorbit

- Proximity normal: 15m.
- Push-to-talk: `N`.
- În apel telefonic, tot cu `N` vorbești.
- Jucătorii care nu sunt în apel nu aud conversația telefonică.

## Events server-side folosite de phone

```lua
TriggerEvent('driftzone_voicechat:server:startPhoneCall', callId, playerA, playerB)
TriggerEvent('driftzone_voicechat:server:endPhoneCall', callId)
```

## Fix telefon audio

- Apelurile telefonice folosesc acum Mumble Voice Target, nu doar range mare.
- In apel, audio-ul se trimite direct catre participantul apelului cand tii apasat `N`.
- Ceilalti jucatori nu aud apelul.
- Daca nu se aude, verifica sa nu ai pornit `pma-voice` sau alt voicechat in paralel.
