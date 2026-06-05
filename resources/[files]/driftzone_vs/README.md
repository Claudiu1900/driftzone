# DriftZone VS Optimized

## Ce am optimizat

Nu am schimbat refresh rate-ul din config si nu am schimbat comenzile.

### Client
- cache pentru NetID -> entity;
- distanta calculata cu squared distance pana trece de limita;
- nu mai creeaza tabelul `lines` la fiecare frame;
- coordonatele playerului se iau o singura data pe frame;
- sterge cache-ul cand opresti VS.

### Server
- payload cache pentru vehicle list;
- trimite update doar la adminii care au `/vs` activ, nu la tot serverul;
- cache scurt pentru admin data;
- curata watchers la playerDropped;
- DB upsert separat la intervalul existent `Config.UpdateInterval`;
- pastreaza statebag update si tabela `vs`.

## Comenzi

```txt
/vs
/dv
/gotoveh
/bringveh
/fixveh
```

## Instalare

```cfg
ensure oxmysql
ensure driftzone_vs
```
