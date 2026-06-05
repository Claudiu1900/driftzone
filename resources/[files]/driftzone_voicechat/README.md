# DriftZone VoiceChat Loud

Standalone voice chat pentru FiveM, optimizat și simplificat.

## Ce face

- un singur mod: `Tipa/Loud`;
- push-to-talk pe `N`;
- când nu ții `N`, proximitatea este 0;
- când ții `N`, proximitatea este `Config.VoiceMode.distance`;
- volum voice pentru ceilalți jucători 0-100;
- volumul se salvează în:
  - NUI localStorage;
  - KVP client-side;
- icon mic stânga jos:
  - `mic_off.svg` când nu vorbești;
  - `mic_on.svg` când vorbești.

## Instalare

Pune folderul:

```txt
resources/[driftzone]/driftzone_voicechat
```

În `server.cfg`:

```cfg
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
setr voice_enableUi 0

ensure driftzone_voicechat
```

Nu porni împreună cu `pma-voice` sau alt voicechat separat.

## Taste

```txt
N = push-to-talk
```

## Volum

Slider-ul stă mereu sus.

Pentru a-l modifica cu mouse-ul:

```txt
/voicevol
```

După ce ai schimbat volumul, ESC închide focus-ul NUI.

## Structura

```txt
driftzone_voicechat/
  fxmanifest.lua
  config.lua
  client/main.lua
  server/main.lua
  html/index.html
  html/style.css
  html/script.js
  html/images/mic_on.svg
  html/images/mic_off.svg
```
