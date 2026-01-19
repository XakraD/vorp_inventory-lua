if Config.DevMode then
    AddEventHandler('onClientResourceStart', function(resourceName)
        if (GetCurrentResourceName() ~= resourceName) then
            return
        end

        SendNUIMessage({ action = "hide" })
        TriggerServerEvent("DEV:loadweapons")
        TriggerServerEvent("vorpinventory:getItemsTable")
        Wait(1000)
        TriggerServerEvent("vorpinventory:getInventory")
        Wait(1000)
        TriggerServerEvent("vorpCore:LoadAllAmmo")
        Wait(100)
        TriggerEvent("vorpinventory:loaded")
        print("^1WARNING: Dev mode is enabled^7 do not use this in production live servers")
    end)
end


CreateThread(function()
    if not Config.UseLanternPutOnBelt then
        return
    end

    repeat Wait(2000) until LocalPlayer.state.IsInSession

    local lastLantern = 0
    while true do
        local pedid = PlayerPedId()
        local weaponHeld <const> = GetPedCurrentHeldWeapon(pedid)
        local isLantern <const> = IsWeaponLantern(weaponHeld) == 1 -- assuming it will return all lanterns to true
        if isLantern then
            lastLantern = weaponHeld
        end

        if lastLantern ~= 0 and not isLantern then
            SetCurrentPedWeapon(pedid, lastLantern, true, 12, false, false)
            lastLantern = 0
        end
        Wait(500)
    end
end)


-- ENABLE PUSH TO TALK
CreateThread(function()
    repeat Wait(5000) until LocalPlayer.state.IsInSession
    if not Config.EnablePushToTalk then
        return
    end
    local isNuiFocused = false

    while true do
        local sleep = 0
        if InInventory then
            if not isNuiFocused then
                SetNuiFocusKeepInput(true)
                isNuiFocused = true
            end

            DisableAllControlActions(0)
            EnableControlAction(0, `INPUT_PUSH_TO_TALK`, true)
        else
            sleep = 1000
            if isNuiFocused then
                SetNuiFocusKeepInput(false)
                isNuiFocused = false
            end
        end
        Wait(sleep)
    end
end)
