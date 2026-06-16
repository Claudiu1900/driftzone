local model = `dz_logo`

local coords = vector3(-1336.180176, -3044.254882, 15.600000)
local heading = 90.0

CreateThread(function()
    RequestModel(model)

    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not HasModelLoaded(model) then
        print('[driftzone_logo_prop] Nu s-a incarcat modelul dz_logo.')
        return
    end

    local obj = CreateObject(
        model,
        coords.x,
        coords.y,
        coords.z,
        false,
        false,
        false
    )

    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetEntityAsMissionEntity(obj, true, true)

    print('[driftzone_logo_prop] Logo spawnat.')
end)