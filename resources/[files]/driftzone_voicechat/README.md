# DriftZone VoiceChat V4 Phone Compatible

Voicechat-ul este modificat pentru apeluri telefonice.

- N = push-to-talk.
- Proximitatea ramane normala la 15m.
- In apel telefonic, vocea este trimisa si catre persoana din telefon folosind Mumble Voice Target.
- Jucatorii de langa tine te aud normal cand vorbesti.
- Jucatorii de langa tine nu aud vocea persoanei din telefon.
- Nu porni acest voicechat impreuna cu pma-voice sau alt voice script.

## server.cfg

```cfg
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
setr voice_enableUi 0

ensure driftzone_voicechat
```
