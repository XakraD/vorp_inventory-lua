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