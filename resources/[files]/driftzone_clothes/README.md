# DriftZone Clothes - categorii extinse + fara auto-load la join

Resource complet pentru `driftzone_clothes`.

## Ce este modificat

- Meniul de haine are mai multe categorii: hair, jacket, top, vest, pants, shoes, hats, mask, accessories, watches, bracelets, glasses, ears, bag, torso/arms si insignia.
- `watches` foloseste prop-ul GTA pentru ceasuri.
- `bracelets` foloseste prop-ul GTA pentru bratari.
- A fost scoasa incarcarea automata a hainelor la intrarea pe server / spawn.
- Comenzile si triggerele manuale de reload au ramas disponibile.
- `/haine` si `/clothes` raman doar pentru admin 7+ cu aduty activ, ca in versiunea initiala.

## Instalare

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_clothes
```

Ruleaza `SQL.sql` daca nu ai coloana/tabelele.

## Comenzi

```txt
/haine
/clothes
/fixskin (id)
/setcl (id) (categorie 1-16) (numar haina)
/bancl (categorie 1-16) (numar haina)
/reloadclothes
/reloadclothes (id/uid) -- admin 7+ aduty yes
```

Categorii pentru `/setcl` si `/bancl`:

```txt
1 hair
2 jacket
3 top
4 vest
5 pants
6 shoes
7 hat
8 mask
9 accessories
10 watches
11 bracelets
12 glasses
13 ears
14 bag
15 torso/arms
16 insignia
```

## Reload manual

Client:

```lua
TriggerEvent('driftzone_clothes:client:reloadSaved')
```

Server pentru un jucator:

```lua
TriggerEvent('driftzone_clothes:server:reloadPlayerClothes', targetSource)
```

Export server-side:

```lua
exports.driftzone_clothes:ReloadClothes(targetSource)
exports.driftzone_clothes:ApplySavedClothes(targetSource)
```

## Git

```bash
git add -A resources/[files]/driftzone_clothes
git commit -m "Update clothes categories and disable auto load"
git pull --rebase origin main
git push origin main
```
