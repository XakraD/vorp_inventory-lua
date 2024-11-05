-- exports

exports('closeInventory', function()
    return NUIService.CloseInv()
end)

exports('getWeaponDefaultWeight', function(hash)
    return Utils.GetWeaponDefaultWeight(hash)
end)

exports('getWeaponDefaultDesc', function(hash)
    return Utils.GetWeaponDefaultDesc(hash)
end)

exports('getWeaponDefaultLabel', function(hash)
    return Utils.GetWeaponDefaultLabel(hash)
end)

exports('getWeaponName', function(hash)
    return Utils.GetWeaponName(hash)
end)

exports('getWeaponsDefaultData', function(request)
    return Utils.GetWeaponsDefaultData(request)
end)

exports('getWeaponAmmoTypes', function(group)
    return SharedData.AmmoTypes[group]
end)

exports('getAmmoLabel', function(ammo)
    return Utils.GetAmmoLabels(ammo)
end)

exports('getInventoryItem', function(name)
    return Utils.GetItem(name)
end)

exports('getInventoryItems', function()
    return Utils.GetInventoryItems()
end)
