local function cleanModel(value)
    return tostring(value or ''):lower():gsub('%s+', ''):gsub('[^%w_%-]', '')
end

local function notify(src, typ, msg, duration)
    TriggerClientEvent('driftzone_vehicless:client:notify', src, typ or 'info', tostring(msg or ''), duration or 5000)
end

local function isDuty(value)
    local text = tostring(value or ''):lower()
    return value == true or tonumber(value) == 1 or text == 'yes' or text == 'true' or text == 'on'
end

local function hasAccess(src)
    if Config.RequirePermission ~= true then return true end

    if Config.PermissionAce and Config.PermissionAce ~= '' and IsPlayerAceAllowed(src, Config.PermissionAce) then
        return true
    end

    if Config.UseDriftzoneAuth == true and Config.AuthResource and GetResourceState(Config.AuthResource) == 'started' then
        local res = Config.AuthResource
        local uid = nil
        local attempts = {
            function() return exports[res]:GetUID(src) end,
            function() return exports[res]:GetUid(src) end,
            function() return exports[res]:getUID(src) end,
            function() return exports[res]:GetUserId(src) end
        }

        for _, fn in ipairs(attempts) do
            local ok, value = pcall(fn)
            if ok and tonumber(value) then
                uid = tonumber(value)
                break
            end
        end

        if uid and MySQL and MySQL.single and MySQL.single.await then
            local ok, row = pcall(function()
                return MySQL.single.await('SELECT admin_level, admin, aduty FROM users WHERE uid = ? LIMIT 1', { uid })
            end)

            if ok and row then
                local level = tonumber(row.admin_level or row.admin or 0) or 0
                if level >= (Config.RequiredAdminLevel or 6) and (Config.RequireAduty ~= true or isDuty(row.aduty)) then
                    return true
                end
            end
        end
    end

    return false
end

RegisterNetEvent('driftzone_vehicless:server:requestOpen', function(model)
    local src = source

    if not hasAccess(src) then
        notify(src, 'warning', 'Nu ai acces la aceasta comanda.', 5500)
        return
    end

    model = cleanModel(model)
    if model == '' then
        notify(src, 'warning', ('Folosire: /%s model_name'):format(Config.Command or 'vehss'), 5500)
        return
    end

    TriggerClientEvent('driftzone_vehicless:client:openStudio', src, {
        model = model,
        mainColor = Config.MainColor or '#04c7f7'
    })
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[DRIFTZONE_VEHICLESS] Loaded v13 clean mode. Screenshot removed completely.')
end)
