# driftzone_rockstareditor fixed

## Fix

Versiunea asta rezolva bug-ul unde `/editor` zicea ca nu poate porni, desi pornea, si dupa nu mai stia sa opreasca.

Cauza principala era verificarea prea rapida cu `IsRecording()` si posibil dublu trigger daca era comanda si pe client si pe server.

Acum:
- `/editor` este comandă server-side;
- serverul trimite un singur event clientului;
- clientul tine state intern `recording`;
- `IsRecording()` este folosit doar ca backup;
- nu mai asteapta confirmare stricta de la native dupa `StartRecording(1)`;
- anti-spam 1.2 secunde.

## Comenzi

```txt
/editor
```

Prima data porneste recording.
A doua data opreste si salveaza.

```txt
/editorstatus
```

Arata status ON/OFF.

## Config

```lua
Config.SaveClipOnStop = true
```

Daca pui `false`, clipul este aruncat la oprire.

## server.cfg

```cfg
ensure driftzone_rockstareditor
```

## Pentru driftzone_chat custom

Daca din F8 merge, dar din chat nu merge, adauga ruta:

```lua
editor = 'driftzone_rockstareditor',
editorstatus = 'driftzone_rockstareditor',
```

sau:

```lua
exports.driftzone_rockstareditor:RunCommand(src, command, args)
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_rockstareditor
git commit -m "Fix Rockstar Editor toggle"
git pull --rebase origin main
git push origin main
```

Pe VPS:

```bash
cd ~/server-data
git pull --rebase origin main
```

txAdmin:

```txt
restart driftzone_rockstareditor
```
