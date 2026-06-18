# DriftZone Chat

Fix complet pentru comenzi, mute si lockchat.

## Important

- Comenzile scrise in chat cu `/` sunt trimise la server.
- Daca sunt comenzi admin, se ruleaza prin `exports.driftzone_admin:RunCommand`.
- Daca nu sunt routate, chat-ul trimite fallback la client si ruleaza `ExecuteCommand`, ca in F8.
- `/mute` foloseste `users.mute`, `users.mute_reason`, `users.mute_by`, `users.mute_by_name`, `users.mute_at`.
- `/lockchat` blocheaza doar mesajele normale pentru playeri; adminii ON DUTY pot scrie.

## SQL

Ruleaza `SQL.sql` o data.
