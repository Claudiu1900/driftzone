# driftzone_emotes

FiveM emote menu custom pentru DriftZone.

## Comenzi

```txt
/emotes        - deschide meniul
/e nume        - porneste emote-ul direct
/e c           - opreste emote-ul
/ecancel       - opreste emote-ul
X              - cancel emote
ESC            - inchide meniul
```

## Stream

Daca ai un folder `stream` cu animatii/props/ytyp, copiaza continutul lui in:

```txt
driftzone_emotes/stream/
```

Daca ai fisiere `.ytyp`, adauga fiecare in `fxmanifest.lua` ca:

```lua
data_file 'DLC_ITYP_REQUEST' 'stream/nume_fisier.ytyp'
```

## Adaugare emotes

Editezi:

```txt
data/emotes.lua
```

Exemplu animatie:

```lua
nume = {
    label = 'Nume Frumos',
    category = 'general',
    type = 'anim',
    dict = 'anim@dict',
    anim = 'anim_name',
    flag = 1,
    description = 'Descriere.'
}
```

Exemplu scenario:

```lua
lean = {
    label = 'Lean',
    category = 'actions',
    type = 'scenario',
    scenario = 'WORLD_HUMAN_LEANING'
}
```

## Instalare

```cfg
ensure driftzone_emotes
```
