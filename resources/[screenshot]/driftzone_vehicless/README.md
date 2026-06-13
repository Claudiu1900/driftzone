# driftzone_vehicless v12 final

Comanda: `/vehss model`

Pozele se salveaza in `driftzone_vehicless/screenshots/model.jpg`.

Screenshot-ul foloseste `screenshot-basic` inclus in zip, fara yarn/webpack real. Upload-ul catre server se face prin `TriggerLatentServerEvent`, nu prin chunk-uri normale, ca sa nu mai dea crash cu `Reliable network event size overflow`.
