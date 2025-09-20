local Core = exports.vorp_core:GetCore()

-- * CLEAR ITEMS WEAPONS AND MONEY * --
RegisterNetEvent("vorp:PlayerForceRespawn", function()
    local _source = source

    local user <const> = Core.getUser(_source)
    if not user then return end

    local character <const> = user.getUsedCharacter
    local job <const> = character.job
    local isdead <const> = character.isdead

    if not Config.UseClearAll or not isdead then
        return
    end

    local value <const> = Config.OnPlayerRespawn

    --MONEY
    if value.Money.ClearMoney then
        if not SharedUtils.IsValueInArray(job, value.Money.JobLock) then
            if not value.Money.MoneyPercentage then
                character.removeCurrency(0, character.money)
            else
                character.removeCurrency(0, character.money * value.Money.MoneyPercentage)
            end
        end
    end

    -- GOLD
    if value.Gold.ClearGold then
        if not SharedUtils.IsValueInArray(job, value.Gold.JobLock) then
            if not value.Gold.GoldPercentage then
                character.removeCurrency(1, character.gold)
            else
                character.removeCurrency(1, character.gold * value.Gold.GoldPercentage)
            end
        end
    end

    -- ITEMS
    if value.Items.AllItems then
        if not SharedUtils.IsValueInArray(job, value.Items.JobLock) then
            InventoryAPI.getInventory(_source, function(Userinventory)
                for _, item in pairs(Userinventory) do
                    local keep = false

                    if next(value.Items.itemWhiteList) then
                        for _, v in ipairs(value.Items.itemWhiteList) do
                            if item.name == v then
                                keep = true
                                break
                            end
                        end
                    end

                    if not keep then
                        InventoryAPI.subItem(_source, item.name, item.count, item.metadata)
                    end
                end
            end)
        end
    end

    -- WEAPONS
    if value.Weapons.AllWeapons then
        if not SharedUtils.IsValueInArray(job, value.Weapons.JobLock) then
            InventoryAPI.getUserWeapons(_source, function(Userweapons)
                for i, weapon in pairs(Userweapons) do
                    if next(value.Weapons.WeaponWhitelisted) then
                        for index, v in ipairs(value.Weapons.WeaponWhitelisted) do
                            if v ~= weapon.name then
                                InventoryAPI.subWeapon(_source, weapon.id)
                                InventoryAPI.deleteWeapon(_source, weapon.id)
                            end
                        end
                    else
                        InventoryAPI.subWeapon(_source, weapon.id)
                        InventoryAPI.deleteWeapon(_source, weapon.id)
                    end
                end
            end)
        end
    end


    --AMMO
    if value.Ammo.AllAmmo then
        if not SharedUtils.IsValueInArray(job, value.Ammo.JobLock) then
            TriggerClientEvent('syn_weapons:removeallammo', _source)  -- syn script
            TriggerClientEvent('vorp_weapons:removeallammo', _source) -- vorp script
            InventoryAPI.removeAllUserAmmo(_source)
        end
    end
end)
