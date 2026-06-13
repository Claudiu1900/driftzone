# driftzone_vehicless

FiveM local vehicle photo studio pentru DriftZone.

## Comanda

```txt
/vehss model_name
```

Exemplu:

```txt
/vehss s15
```

Acces default: `admin_level 6+` si `aduty yes`.

## Ce face versiunea asta

- Spawn local pentru masina, doar pentru adminul care foloseste comanda.
- Masina se pune automat pe alb la primary + secondary.
- Camera ramane fixa; se roteste doar masina.
- Playerul este ascuns si apoi readus la pozitia initiala.
- Screenshot-ul se salveaza in `driftzone_vehicless/screenshots/`.
- Numele fisierului este exact modelul masinii, de exemplu `s15.png`.
- Daca `Config.ScreenshotOverwriteSameModel = true`, poza veche cu acelasi model se suprascrie.
- Daca `Config.ScreenshotOverwriteSameModel = false`, salveaza `s15.png`, `s15_2.png`, `s15_3.png` etc.

## Recomandat pentru screenshot fara poza neagra

Resource-ul incearca prima data sa foloseasca `screenshot-basic`, pentru ca acela captureaza corect game render target-ul FiveM.
Daca nu este pornit, foloseste fallback intern NUI.

In `server.cfg` pune:

```cfg
ensure screenshot-basic
ensure driftzone_vehicless
```

Daca nu ai `screenshot-basic`, resource-ul tot porneste, dar fallback-ul intern poate da poza neagra pe unele build-uri FiveM.

## Config important

Fisier: `shared/config.lua`

```lua
Config.ScreenshotOverwriteSameModel = true
Config.Studio.forceWhiteColor = true
Config.UseScreenshotBasic = true
```

## Unde se salveaza pozele

```txt
resources/[folder]/driftzone_vehicless/screenshots/model_name.png
```

Exemplu:

```txt
resources/[driftzone]/driftzone_vehicless/screenshots/s15.png
```
