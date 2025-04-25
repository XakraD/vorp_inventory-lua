local Core           = exports.vorp_core:GetCore()

---@class SvUtils @Server Utility Service
---@field FindAllWeaponsByName fun(invId: string, name: string): table<number, Weapon>
---@field FindAllItemsByName fun(invId: string, identifier: string, name: string): table<number, Item>
---@field FindItemByName fun(invId: string, identifier: string, name: string): {} | nil
---@field FindItemByNameAndMetadata fun(invId: string, identifier: string, name: string, metadata: table): Item
---@field FindItemByNameAndContainingMetadata fun(invId: string, identifier: string, name: string, metadata: table): Item
---@field ProcessUser fun(id: number)
---@field InProcessing fun(id: number): boolean
---@field Trem fun(id: string, keepInventoryOpen: boolean)
---@field DoesItemExist fun(itemName:string,api:string): boolean
SvUtils              = {}

local processingUser = {}
math.randomseed(GetGameTimer())

---return a table will all weapons that match the name
---@param invId string
---@param name string
---@return table
function SvUtils.FindAllWeaponsByName(invId, name)
    local userWeapons = UsersWeapons[invId]
    local weapons = {}

    if userWeapons == nil then
        return {}
    end

    for _, weapon in pairs(userWeapons) do
        if name == weapon:getName() then
            weapons[#weapons + 1] = weapons
        end
    end

    return weapons
end

--- return a table will all items that match the name
---@param invId string
---@param identifier string
---@param name string
---@return table
function SvUtils.FindAllItemsByName(invId, identifier, name)
    local userInventory = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]
    local items = {}

    if userInventory == nil then
        return items
    end

    for _, item in pairs(userInventory) do
        if name == item:getName() then
            items[#items + 1] = item
        end
    end

    return items
end

--- return a item that match the name
---@param invId string
---@param identifier string
---@param name string
---@return {} | nil
function SvUtils.FindItemByName(invId, identifier, name)
    local userInventory = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]
    if not userInventory then
        return nil
    end

    for _, item in pairs(userInventory) do
        if name == item:getName() then
            return item
        end
    end

    return nil
end

--- returns a item that match the name and metadata
---@param invId string
---@param identifier string
---@param name string
---@param metadata table | nil
---@return nil | table
function SvUtils.FindItemByNameAndMetadata(invId, identifier, name, metadata)
    local userInventory = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]
    if not userInventory then
        return nil
    end

    if metadata then
        for _, item in pairs(userInventory) do
            if name == item:getName() and SharedUtils.Table_equals(metadata, item:getMetadata()) then
                return item
            end
        end
    else
        -- this returns the first item that matches the name, not carring for metadata
        for _, item in pairs(userInventory) do
            if name == item:getName() then
                return item
            end
        end
    end

    return nil
end

-- this is used to get an item that does not contain metadata instead of using the above that just gets a random one if metadata is not passed
---@param invId string
---@param identifier string
---@param name string
---@return nil | table
function SvUtils.GetItemNoMetadata(invId, identifier, name)
    local userInventory = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]
    for _, item in pairs(userInventory) do
        if name == item:getName() and next(item:getMetadata()) == nil then
            return item
        end
    end
    return nil
end

function SvUtils.GetItemCount(invId, identifier, name, percentage)
    local userInventory = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]

    if not userInventory then return 0 end

    --get item count  by percentage , this allows to control get expired items or at a desired percentage
    local count = 0
    for _, item in pairs(userInventory) do
        if percentage then
            local expiredPercentage = true
            -- items with decay detection
            if percentage == 0 then
                expiredPercentage = item:getPercentage() == 0
            else
                expiredPercentage = item:getPercentage() >= percentage
            end

            if name == item:getName() and expiredPercentage then
                count = count + item:getCount()
            end
        else
            -- detect any items because if we change this it breaks other scripts that are using it wrong
            if name == item:getName() then
                -- by not allowing decay items in here we are getting the count of only normal items
                -- in conjunction with subItem that will only delete items that dont have decay if decay detection is not passed this allows to function normal as before
                count = count + item:getCount()
            end
        end
    end

    return count
end

--- returns a item that match the name and containing metadata
---@param invId string
---@param identifier string
---@param name string
---@param metadata table | nil
---@return nil
function SvUtils.FindItemByNameAndContainingMetadata(invId, identifier, name, metadata)
    local userInventory = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]

    if not userInventory then
        return nil
    end

    for _, item in pairs(userInventory) do
        if name == item:getName() and SharedUtils.Table_contains(item:getMetadata(), metadata) then
            return item
        end
    end

    return nil
end

---PoccessUser when in transaction
---@param id number user id
function SvUtils.ProcessUser(id)
    TriggerClientEvent("vorp_inventory:transactionStarted", id)
    processingUser[id] = true
end

--- is user in processing transaction
---@param id number user id
---@return boolean
function SvUtils.InProcessing(id)
    return processingUser[id]
end

--- Transaction Ended
---@param id number user id
---@param keepInventoryOpen? boolean keep inventory open
function SvUtils.Trem(id, keepInventoryOpen)
    keepInventoryOpen = keepInventoryOpen == nil and true or keepInventoryOpen
    if processingUser[id] then
        TriggerClientEvent("vorp_inventory:transactionCompleted", id, keepInventoryOpen)
        processingUser[id] = nil
    end
end

--- does item exist in server items table meaning databse
---@param itemName string item name
---@param api string name
---@return boolean | table
function SvUtils.DoesItemExist(itemName, api)
    if ServerItems[itemName] then
        return ServerItems[itemName]
    end
    print("[^2" .. api .. "7] Item [^3" .. tostring(itemName) .. "^7] does not exist in DB.")
    return false
end

--- generate a weapon label
---@param name string weapon name
---@return string
function SvUtils.GenerateWeaponLabel(name)
    return SharedData.Weapons[name] and SharedData.Weapons[name].Name or ""
end

--- filter weapons that should not have a serial number
---@param name string weapon name
---@return boolean
function SvUtils.filterWeaponsSerialNumber(name)
    return Config.noSerialNumber[name]
end

--- generate a unique random id
---@return string
function SvUtils.GenerateUniqueID()
    local time = os.time()
    local randomNum = math.random(1000000, 9999999)
    return tostring(time) .. tostring(randomNum)
end

--- generate a unique serial number
---@return string
function SvUtils.GenerateSerialNumber(name)
    if SvUtils.filterWeaponsSerialNumber(name) then
        return ""
    end
    local timeStamp = os.time()
    local randomNumber = math.random(1000, 9999)
    return string.format("%s-%s", timeStamp, randomNumber)
end

--- discord webhook service
---@param data {title: string, webhook: string, description: string, color: number, name: string, logo: string, footerlogo: string, avatar: string, source: number, target: number}
function SvUtils.SendDiscordWebhook(data)
    Core.AddWebhook(data.title, data.webhook, data.description, data.color, data.name)
end

--- get weapon weight
---@param name string | number weapon name
---@return number
function SvUtils.GetWeaponWeight(name)
    local weaponName = nil
    if type(name) == "number" then
        for _, value in pairs(SharedData.Weapons) do
            if joaat(value.HashName) == name then
                weaponName = value.HashName
                break
            end
        end
    else
        weaponName = name
    end
    return SharedData.Weapons[weaponName] and SharedData.Weapons[weaponName].Weight or 1
end

AddEventHandler("playerDropped", function()
    local _source = source
    if processingUser[_source] then
        processingUser[_source] = nil
    end
end)
