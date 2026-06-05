-- Cursor ON când pornește loadingscreen-ul
CreateThread(function()
    Wait(500)
    SetNuiFocus(true, true)
end)

-- Primește comenzi din NUI
RegisterNUICallback("setCursor", function(data, cb)
    SetNuiFocus(data.show, data.show)
    cb("ok")
end)

-- SIGUR: cursor OFF când LS se închide
AddEventHandler("onClientResourceStop", function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
