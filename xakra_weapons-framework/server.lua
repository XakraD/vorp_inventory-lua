local VORPcore = exports.vorp_core:GetCore()

function NotifyObjective(source, text, time)
    VORPcore.NotifyObjective(source, text, time)
end

function NotifyAvanced(source, title, dict, icon, color, time)
    VORPcore.NotifyAvanced(source, title, dict, icon, color, time)
end

function GetCharacter(source)
    -- .identifier
    -- .charIdentifier
    -- .group
    -- .job
    -- .money
    -- .gold
    -- .firstname
    -- .lastname
    return VORPcore.getUser(source).getUsedCharacter
end

function AddWebhook(title, webhook, description, color, name, logo, footerlogo, avatar)
    VORPcore.AddWebhook(title, webhook, description, color, name, logo, footerlogo, avatar)
end

function removeCurrency(source, currency, amount)
    local Character = GetCharacter(source)
    Character.removeCurrency(currency, amount) -- Remove money 1000 | 0 = money, 1 = gold, 2 = rol
end

function RegisterUsableItem(item, cb)
    exports.vorp_inventory:registerUsableItem(item, function(data)
        -- .source
        -- .data.item.label
        -- .data.item.metadata (breakable weapons)
        -- .data.item.mainid (breakable weapons)
        return cb(data)
    end)
end

function getItemCount(source, callback, item, metadata)
    return exports.vorp_inventory:getItemCount(source, callback, item, metadata)
end

function canCarryItem(source, item, amount, callback)
    return exports.vorp_inventory:canCarryItem(source, item, amount, callback)
end

function canCarryWeapons(source, amount, callback, weaponName)
    return exports.vorp_inventory:canCarryWeapons(source, amount, callback, weaponName)
end

function addItem(source, item, amount, metadata)
    return exports.vorp_inventory:addItem(source, item, amount, metadata)
end

function createWeapon(source, weaponName, ammo, components, comps, callback, serial, label, desc)
    exports.vorp_inventory:createWeapon(source, weaponName, ammo, components, comps, callback, serial, label, desc)
end

function subItem(source, item, amount, metadata, callback)
    exports.vorp_inventory:subItem(source, item, amount, metadata, callback)
end

function subWeapon(source, weaponId, callback)
    exports.vorp_inventory:subWeapon(source, weaponId, callback)
end

function CloseInv(source, invId)
    exports.vorp_inventory:closeInventory(source, invId)
end

function getItem(source, item,callback, metadata, percentage)
    return exports.vorp_inventory:getItem(source, item,callback, metadata, percentage)
end

function getItemDB(item, callback)  -- uses
    return exports.vorp_inventory:getItemDB(item, callback)
end

function subItemID(source, id, callback)    -- breakable weapons
    exports.vorp_inventory:subItemID(source, id, callback)
end

function setItemMetadata(source, itemId, metadata, amount, callback)    -- uses
    exports.vorp_inventory:setItemMetadata(source, itemId, metadata, amount, callback)
end

function getUserAmmo(source, itemId, metadata, amount, callback)
    return exports.vorp_inventory:getUserAmmo(source)
end

function addBullets(source, bulletType, amount, callback)
    exports.vorp_inventory:addBullets(source, bulletType, amount, callback)
end

function setWeaponCustomLabel(source, weaponId, label, cb)
    exports.vorp_inventory:setWeaponCustomLabel(weaponId, label, cb)
end

function setWeaponSerialNumber(source, weaponId, serial, cb)
    exports.vorp_inventory:setWeaponSerialNumber(weaponId, serial, cb)
end

function setWeaponCustomDesc(source, weaponId, label, cb)
    exports.vorp_inventory:setWeaponCustomDesc(weaponId, label, cb)
end

RegisterServerEvent('syn_weapons:weaponused')
AddEventHandler('syn_weapons:weaponused', function(data)
    local _source = source

    exports.oxmysql:execute('SELECT * FROM loadout WHERE id = @id ', { ['id'] = data.id }, function(result)
        if result[1] then 
            local components = json.decode(result[1].comps)

            if components.nothing then
                components = {}
            end

            local weaponStatus = { degradation = result[1].conditionlevel, dirt = result[1].dirtlevel, soot = result[1].rustlevel, damage = result[1].mudlevel }

            local Weapon = {
                id = data.id,
                hash = data.hash,
                name = result[1].name,
                label = result[1].custom_label,
                serial = result[1].serial_number,
                desc = result[1].custom_desc,
                comps = components,
            }

            TriggerClientEvent('xakra_weapons:UseWeapon', _source, Weapon, weaponStatus)
        end
    end)
end)

Updates = {
    Condition = function(source, weaponId, weaponStatus)
        local Parameters = {
            degradation = weaponStatus.degradation,
            dirt = weaponStatus.dirt,
            soot = weaponStatus.soot,
            damage = weaponStatus.damage,
            id = weaponId,
        }

        exports.oxmysql:execute('UPDATE loadout SET conditionlevel = @degradation, dirtlevel = @dirt, rustlevel = @soot, mudlevel = @damage WHERE id = @id', Parameters)
    end,
    
    Comps = function(source, weaponId, oldComps, newComps)
        local Parameters = {
            comps = json.encode(newComps),
            id = weaponId,
        }
        exports.oxmysql:execute('UPDATE loadout SET comps = @comps WHERE id = @id', Parameters)
    end,
}