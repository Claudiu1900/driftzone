# driftzone_chat - final lockchat fix

## Fixuri

- `/lockchat` blocheaza chat-ul direct in driftzone_chat si nu mai trece prin toggle.
- `/unlockchat` deblocheaza chat-ul direct.
- `/cc` sterge toate mesajele din chat pentru toata lumea.
- Chat-ul este default deblocat la pornirea resource-ului.
- Cand chat-ul este blocat, pot scrie doar adminii care sunt ON DUTY.
- `/mute uid minute motiv` foloseste `users.mute`, `users.mute_reason`, `users.mute_by`, `users.mute_by_name`, `users.mute_at`.
- `/unmute uid` curata mute-ul din `users`.
- Comenzile din chat sunt rutate prin server si fallback client `ExecuteCommand`.

## Server cfg

```cfg
ensure oxmysql
ensure driftzone_auth
ensure driftzone_chat
ensure driftzone_vehicleconfig
ensure driftzone_admin
```

## Important

Structura ta SQL deja are coloanele de mute in `users`, dar SQL.sql este inclus pentru siguranta.
