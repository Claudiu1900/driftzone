# driftzone_rockstareditor

Resource simplu pentru FiveM care pornește/oprește recording-ul Rockstar Editor.

## Comandă

```txt
/editor
```

Prima dată pornește recording-ul.
A doua oară îl oprește și salvează clipul.

Este valabil pentru toată lumea, fără admin.

## Config

În `config.lua`:

```lua
Config.SaveClipOnStop = true
```

Dacă îl pui `false`, când dai a doua oară `/editor`, clipul se șterge în loc să fie salvat.

## Instalare

Pune folderul în:

```txt
resources/[files]/driftzone_rockstareditor
```

În `server.cfg`:

```cfg
ensure driftzone_rockstareditor
```

## Pentru driftzone_chat custom

Dacă din F8 merge, dar din chat nu merge, adaugă ruta:

```lua
editor = 'driftzone_rockstareditor',
```

sau apelează:

```lua
exports.driftzone_rockstareditor:RunCommand(src, command, args)
```

## Git

Pe PC:

```bash
git add -A resources/[files]/driftzone_rockstareditor
git commit -m "Add Rockstar Editor command"
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
ensure driftzone_rockstareditor
```

sau dacă e deja în server.cfg:

```txt
restart driftzone_rockstareditor
```
