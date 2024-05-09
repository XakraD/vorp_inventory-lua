---@diagnostic disable: undefined-global

Core = exports.vorp_core:GetCore()
T = TranslationInv.Langs[Lang]

if Config.DevMode then
    Log.Warning("^1[DEV] ^7You are in dev mode, dont use this in production live servers")
end

RegisterServerEvent("syn:stopscene")
AddEventHandler("syn:stopscene", function(x) -- new
    local _source = source
    TriggerClientEvent("inv:dropstatus", _source, x)
end)


RegisterServerEvent("vorpinventory:check_slots")
AddEventHandler("vorpinventory:check_slots", function()
    local _source = source

    local User = Core.getUser(_source)
    if not User then
        return
    end

    User = User.getUsedCharacter
    local slots = User.invCapacity
    local identifier = User.identifier
    local charid = User.charIdentifier
    local money = User.money
    local gold = User.gold
    local rol = User.rol
    local totalItems = InventoryAPI.getUserTotalCountItems(identifier, charid)
    local totalWeapons = InventoryAPI.getUserTotalCountWeapons(identifier, charid, true)
    local totalInvWeight = (totalItems + totalWeapons)
    TriggerClientEvent("vorpinventory:send_slots", _source, totalInvWeight, slots, money, gold, rol)
end)


RegisterServerEvent("vorpinventory:netduplog")
AddEventHandler("vorpinventory:netduplog", function()
    local _source = source
    local playername = GetPlayerName(_source)
    local description = Logs.NetDupWebHook.Language.descriptionstart ..
        name .. Logs.NetDupWebHook.Language.descriptionend

    if Logs.NetDupWebHook.Active then
        Info = {
            source = _source,
            title = Config.NetDupWebHook.Language.title,
            name = playername,
            description = description,
            webhook = Logs.NetDupWebHook.webhook,
            color = Logs.NetDupWebHook.color
        }
        SvUtils.SendDiscordWebhook(Info)
    else
        print('[' .. Logs.NetDupWebHook.Language.title .. '] ', description)
    end
end)



-- * CUSTOM INVENTORY CHECK IS OPEN * --
local InventoryBeingUsed = {}

Core.Callback.Register("vorp_inventory:Server:CanOpenCustom", function(source, cb, id)
    local _source = source
    id = tostring(id)
    if not InventoryBeingUsed[id] then
        InventoryBeingUsed[id] = _source
        return cb(true)
    end

    Core.NotifyObjective(_source, "someone is using this stash, wait for your turn", 5000)
    return cb(false)
end)

RegisterServerEvent("vorp_inventory:Server:UnlockCustomInv", function()
    local _source = source
    for i, value in pairs(InventoryBeingUsed) do
        if value == _source then
            InventoryBeingUsed[i] = nil
            break
        end
    end
end)


AddEventHandler('playerDropped', function()
    local _source = source
    if _source then
        local char = Core.getUser(_source)
        local weapons = UsersWeapons.default
        allplayersammo[_source] = nil

        for i, value in pairs(InventoryBeingUsed) do
            if value == _source then
                InventoryBeingUsed[i] = nil
                break
            end
        end

        if char then
            local charid = char.getUsedCharacter.charIdentifier
            for key, value in pairs(weapons) do
                if value.charId == charid then
                    UsersWeapons.default[key] = nil
                    break
                end
            end
        end
    end
end)
