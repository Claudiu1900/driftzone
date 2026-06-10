CreateThread(function()
    -- Diamond Casino & Resort exterior/interior IPLs
    RequestIpl("vw_casino_main")
    RequestIpl("vw_casino_garage")
    RequestIpl("vw_casino_carpark")
    RequestIpl("vw_casino_penthouse")
    RequestIpl("vw_casino_penthouse_bar")
    RequestIpl("vw_casino_penthouse_media")
    RequestIpl("vw_casino_penthouse_dealer")
    RequestIpl("vw_casino_penthouse_door")
    RequestIpl("vw_casino_penthouse_bath")
    RequestIpl("vw_casino_penthouse_lounge")
    RequestIpl("vw_casino_penthouse_guest")
    RequestIpl("vw_casino_penthouse_office")
    RequestIpl("vw_casino_penthouse_cinema")
    RequestIpl("vw_casino_penthouse_spa")
    RequestIpl("vw_casino_penthouse_bar_party")
    RequestIpl("vw_casino_penthouse_bar_light")

    -- Activează zona casino
    SetIplPropState("vw_casino_main", "casino_manager_default", true, true)

    print("[DriftZone Casino] IPL-urile casino au fost incarcate.")
end)