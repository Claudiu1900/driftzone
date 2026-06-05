# driftzone_garage

Garaj FiveM optimizat, cu UI-ul vechi pastrat si sistem VIP.

## Comenzi

- `/garage`
- `/garaj`
- `/park`

Nu exista keybind pe M.

## VIP

- `users.vip` trebuie sa aiba o valoare valida ca playerul sa fie considerat VIP.
- `ownedvehicles.vip = 1` inseamna masina VIP.
- Masinile VIP apar doar in tab-ul VIP si doar daca playerul are VIP activ.

## Optimizari

- render NUI debounced la search;
- selectia masinii nu mai re-randeaza toata lista;
- datele masinilor sunt indexate in UI;
- imagini lazy-load;
- scanarea vehiculelor este rarita cat timp meniul este deschis;
- protectia masinilor ruleaza mai rar cand meniul este deschis;
- SQL include indexuri recomandate.
