local Core <const> = exports.vorp_core:GetCore()

if Config.DevMode then
    print("^1[DEV] ^7DEV MODE IS ENABLED, THIS IS NOT FOR PRODUCTION SERVERS")
end


RegisterServerEvent("syn:stopscene")
AddEventHandler("syn:stopscene", function(x)
    local _source <const> = source
    TriggerClientEvent("inv:dropstatus", _source, x)
end)

RegisterServerEvent("vorpinventory:netduplog", function()
    local _source <const> = source
    local playername <const> = GetPlayerName(_source)
    local description <const> = Logs.NetDupWebHook.Language.descriptionstart .. playername .. Logs.NetDupWebHook.Language.descriptionend

    if Logs.NetDupWebHook.Active then
        local info <const> = {
            source = _source,
            title = Config.NetDupWebHook.Language.title,
            name = playername,
            description = description,
            webhook = Logs.NetDupWebHook.webhook,
            color = Logs.NetDupWebHook.color
        }
        SvUtils.SendDiscordWebhook(info)
    else
        print('[' .. Logs.NetDupWebHook.Language.title .. '] ', description)
    end
end)

AddEventHandler('playerDropped', function()
    local _source <const> = source
    if _source then
        local user <const>    = Core.getUser(_source)

        local weapons <const> = UsersWeapons.default

        if AmmoData[_source] then
            AmmoData[_source] = nil
        end

        local invId = INVENTORY_IN_USE[_source]

        if invId ~= nil then
            INVENTORY_IN_USE[_source] = nil

            local customInv = CustomInventoryInfos[invId]

            if customInv and customInv:isInUse() then
                customInv:setInUse(false)
            end
        end

        if not user then return end

        local charid <const> = user.getUsedCharacter.charIdentifier
        for key, value in pairs(weapons) do
            if value.charId == charid then
                UsersWeapons.default[key] = nil
                break
            end
        end
    end
end)

Core.Callback.Register("vorpinventory:get_slots", function(source, cb, _)
    local user <const> = Core.getUser(source)
    if not user then return cb(nil) end

    local character <const>      = user.getUsedCharacter
    local totalItems <const>     = InventoryAPI.getUserTotalCountItems(character.identifier, character.charIdentifier)
    local totalWeapons <const>   = InventoryAPI.getUserTotalCountWeapons(character.identifier, character.charIdentifier, true)
    local totalInvWeight <const> = (totalItems + totalWeapons)
    return cb({
        totalInvWeight = totalInvWeight,
        slots = character.invCapacity,
        money = character.money,
        gold = character.gold,
        rol = character.rol
    })
end)


RegisterServerEvent("vorp_inventory:Server:CloseCustomInventory", function()
    local _source <const> = source
    -- here we will do a look up if this source was in any inventory
    if not INVENTORY_IN_USE[_source] then
        return print("player:", GetPlayerName(_source), "did not open inventory through the server  but it closed it meaning it opened from the client", "possible Cheat!!")
    end
    local id <const> = INVENTORY_IN_USE[_source]
    if not CustomInventoryInfos[id] then
        return print("player:", GetPlayerName(_source), "tried to close inventory with id:", id, "but it was not found", "possible Cheat!!")
    end

    if not CustomInventoryInfos[id]:isInUse() then
        return print("player:", GetPlayerName(_source), "tried to close inventory with id:", id, "but it was not in use", "possible Cheat!!")
    end

    CustomInventoryInfos[id]:setInUse(false)
    INVENTORY_IN_USE[_source] = nil
end)

-- SERVER EVENTS ONLY
local ALLOWED_CONTEXT_MENU_EVENTS <const> = {}

RegisterServerEvent("vorpinventory:validateContextMenuEvent", function(data)
    local _source <const> = source

    if not data or type(data) ~= "table" then return end

    if not data.event?.server then return end

    if next(ALLOWED_CONTEXT_MENU_EVENTS) == nil then
        return print("no events whitelisted", GetPlayerName(_source), " tried to call event:", data.event.server, "but no events were whitelisted", "possible Cheat!!")
    end

    if not ALLOWED_CONTEXT_MENU_EVENTS[joaat(data.event.server)] then
        return print("event not whitelisted", GetPlayerName(_source), " tried to call event:", data.event.server, "but it was not whitelisted", "possible Cheat!!")
    end

    TriggerEvent(data.event.server, _source, data.event?.arguments, data.itemid)
end)

---@param event string | table
---@param resourcename string
exports("addAllowedContextMenuEvent", function(event, resourcename)
    if not resourcename then return print("resourcename is required use GetCurrentResourceName() as argument") end

    if not event then return print("event name is required", resourcename) end

    if type(event) == "table" then
        for _, v in pairs(event) do
            ALLOWED_CONTEXT_MENU_EVENTS[joaat(v)] = true
        end
        return
    end

    if type(event) ~= "string" then return print("invalid eventname must be a string", resourcename) end
    ALLOWED_CONTEXT_MENU_EVENTS[joaat(event)] = true

    --  print("added event ", event, "from", resourcename)
end)

---@param event string | table
---@param resourcename string
exports("removeAllowedContextMenuEvent", function(event, resourcename)
    if not resourcename then return print("resourcename is required use GetCurrentResourceName() as argument") end

    if not event then return print("event name is required", resourcename) end

    if type(event) == "table" then
        for _, v in pairs(event) do
            ALLOWED_CONTEXT_MENU_EVENTS[joaat(v)] = nil
        end
        return
    end

    if type(event) ~= "string" then return print("invalid event name must be a string", resourcename) end
    ALLOWED_CONTEXT_MENU_EVENTS[joaat(event)] = nil

    -- print("removed event ", event, "from", resourcename)
end)
