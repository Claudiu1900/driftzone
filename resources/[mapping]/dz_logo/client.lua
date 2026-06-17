local model = `dz_logo`
local spawnedLogo = nil

RegisterCommand('testlogo', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)

    local spawnCoords = vector3(
        coords.x + forward.x * 3.0,
        coords.y + forward.y * 3.0,
        coords.z + 1.0
    )

    RequestModel(model)

    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not HasModelLoaded(model) then
        print('[driftzone_logo_prop] Modelul dz_logo NU s-a incarcat.')
        return
    end

    if spawnedLogo and DoesEntityExist(spawnedLogo) then
        DeleteEntity(spawnedLogo)
    end

    spawnedLogo = CreateObject(
        model,
        spawnCoords.x,
        spawnCoords.y,
        spawnCoords.z,
        false,
        false,
        false
    )

    SetEntityHeading(spawnedLogo, GetEntityHeading(ped))
    FreezeEntityPosition(spawnedLogo, true)
    SetEntityInvincible(spawnedLogo, true)
    SetEntityAsMissionEntity(spawnedLogo, true, true)

    print('[driftzone_logo_prop] Logo spawnat.')
end, false)