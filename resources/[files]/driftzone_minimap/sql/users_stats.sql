-- Rulează doar dacă nu dorești ca resursa să creeze automat coloana.
-- Dacă users.stats există deja, nu mai executa această comandă.

ALTER TABLE `users`
ADD COLUMN `stats` LONGTEXT NULL;

-- Exemplu de valoare salvată:
-- {"health":100,"armour":0,"food":100,"water":100}
