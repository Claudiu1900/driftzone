# DriftZone VS Optimized

## Ce include

- `/vs`, `/dv`, `/gotoveh`, `/bringveh`, `/fixveh` raman la fel.
- Masinile inregistrate in tabela `vs` se verifica automat.
- Daca o masina sta fara niciun jucator in ea mai mult decat timpul setat in config, isi ia DV singura.
- Cand un jucator urca in masina, timer-ul se reseteaza.
- Cand masina este adusa cu `/bringveh`, timer-ul se reseteaza ca sa nu fie stearsa imediat.
- Se sterge si din tabela `vs` cand isi ia auto DV.

## Config

In `config.lua`:

```lua
Config.AbandonedAutoDV = {
    enabled = true,
    minutes = 30,
    checkIntervalSeconds = 60,
    printLog = true
}
```

`minutes` = dupa cate minute fara jucator in masina isi ia DV.

## Instalare

Inlocuieste folderul:

```txt
resources/driftzone_vs
```

Apoi:

```cfg
restart driftzone_vs
```
