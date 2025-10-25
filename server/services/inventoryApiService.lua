local T    = TranslationInv.Langs[Lang]
local Core = exports.vorp_core:GetCore()

--used to sync time to the clients
CreateThread(function()
	while true do
		Wait(1000)
		GlobalState.TimeNow = os.time()
	end
end)


---@class InventoryAPI
InventoryAPI         = {}

---@class CustomInventoryInfos @Custom Inventory Infos
---@field id string
---@field name string
---@field limit number
---@field acceptWeapons boolean
---@field shared boolean
---@field limitedItems table<string, integer>
---@field whitelistItems boolean
---@field ignoreItemStackLimit boolean
---@field PermissionTakeFrom table<string, integer>
---@field PermissionMoveTo table<string, integer>
---@field CharIdPermissionTakeFrom table<number, boolean>
---@field CharIdPermissionMoveTo table<number, boolean>
---@field UsePermissions boolean
---@field UseBlackList boolean
---@field BlackListItems table<string, string>
---@field whitelistWeapons boolean
---@field limitedWeapons table<string, integer>
---@field webhook string | boolean
CustomInventoryInfos = {
	default = {
		id = "default",
		name = "Satchel",
		limit = 0,
		shared = false,
		limitedItems = {},
		ignoreItemStackLimit = false,
		whitelistItems = false,
		PermissionTakeFrom = {},
		PermissionMoveTo = {},
		CharIdPermissionTakeFrom = {},
		CharIdPermissionMoveTo = {},
		UsePermissions = false,
		UseBlackList = false,
		BlackListItems = {},
		whitelistWeapons = false,
		limitedWeapons = {},
		webook = false,
		--TODO: Add parameter to use contaner with weight
	}
}

---@type table<string,function> table of Registered items
UsableItemsFunctions = {}
PlayerItemsLimit     = {}
CoolDownStarted      = {}
AmmoData             = {}
---@type table<string, table<number, table<number, Item>>> contain users inventory items
UsersInventories     = { default = {} }

--- sync or async helper
local function respond(cb, result, message)
	if message then print(message) end
	if cb then cb(result) end
	return result
end


---private function to check if item exist
function InventoryAPI.canCarryAmountItem(player, amount, cb)
	local _source = player
	local character = Core.getUser(_source)
	if not character then return respond(cb, false) end
	character = character.getUsedCharacter
	local userInventory = UsersInventories.default[character.identifier]

	if not userInventory then
		return respond(cb, false)
	end

	local function cancarryammount()
		local totalAmount = InventoryAPI.getUserTotalCountItems(character.identifier, character.charIdentifier)
		local totalAmountWeapons = InventoryAPI.getUserTotalCountWeapons(character.identifier, character.charIdentifier, true)
		return character.invCapacity ~= -1 and totalAmount + totalAmountWeapons <= character.invCapacity
	end

	return respond(cb, cancarryammount())
end

---@deprecated
exports("canCarryItems", InventoryAPI.canCarryAmountItem)

---check limit of item
---@param target number source
---@param itemName string item name
---@param amount number amount of item
---@param cb fun(canCarry: boolean)? async or sync callback
function InventoryAPI.canCarryItem(target, itemName, amount, cb)
	local user = Core.getUser(target)
	if not user then
		return respond(cb, false)
	end

	local function exceedsItemLimit(identifier, limit)
		local items = SvUtils.FindAllItemsByName("default", identifier, itemName)
		local count = 0
		for _, item in pairs(items) do
			count = count + item:getCount()
		end
		return count + amount > limit
	end

	local function exceedsInvLimit(identifier, charIdentifier, limit, itemWeight)
		local totalAmount = InventoryAPI.getUserTotalCountItems(identifier, charIdentifier)
		local totalAmountWeapons = InventoryAPI.getUserTotalCountWeapons(identifier, charIdentifier, true)
		itemWeight = itemWeight * amount
		return limit ~= -1 and totalAmount + totalAmountWeapons + itemWeight > limit
	end

	local character = user.getUsedCharacter
	local canCarry = false

	local svItem = SvUtils.DoesItemExist(itemName, "InventoryAPI.canCarryItem")
	if not svItem then
		return respond(cb, false)
	end

	if svItem.limit ~= -1 and not exceedsItemLimit(character.identifier, svItem.limit) then
		canCarry = not exceedsInvLimit(character.identifier, character.charIdentifier, character.invCapacity, svItem.weight)
	elseif svItem.limit == -1 then
		canCarry = true
	end

	return respond(cb, canCarry)
end

exports("canCarryItem", InventoryAPI.canCarryItem)

---get player inventory
---@param source number source
---@param cb fun(items: table)? async or sync callback
function InventoryAPI.getInventory(source, cb)
	local sourceCharacter = Core.getUser(source)
	if not sourceCharacter then
		return respond(cb, nil)
	end
	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local userInventory = UsersInventories.default[identifier]

	if userInventory then
		local playerItems = {}

		for _, item in pairs(userInventory) do
			-- for existing scripts we need to check if labels and descriptions exist in metadata to avoid showing the default ones
			local newItem = {
				id = item:getId(),
				label = item.metadata?.label or item:getLabel(),
				name = item:getName(),
				desc = item.metadata?.description or item:getDesc(),
				metadata = item:getMetadata(), -- this contains label descriptions image weight tooltip as reserved keys
				type = item:getType(),
				count = item:getCount(),
				limit = item:getLimit(),
				canUse = item:getCanUse(),
				group = item:getGroup(),
				weight = item.metadata?.weight or item:getWeight(),
				percentage = item:getPercentage(),
				isDegradable = item:getMaxDegradation() ~= 0
			}
			table.insert(playerItems, newItem)
		end
		return respond(cb, playerItems)
	end
end

exports("getUserInventoryItems", InventoryAPI.getInventory)

--- register usable item
---@param name string item name
---@param cb function callback
function InventoryAPI.registerUsableItem(name, cb, resource)
	if Config.Debug then
		SetTimeout(9000, function()
			print("Callback for item[^3" .. name .. "^7] ^2Registered!^7")
		end)
	end

	if not name then
		return print("InventoryAPI.registerUsableItem: name is required")
	end

	-- this is just to help users see whats wrong with their items and to fix them
	SetTimeout(20000, function()
		if not ServerItems[name] then
			print("^3Warning^7: item ", name, " was added as usabled but ^1 does not exist in database ^7", resource or "")
		end

		if ServerItems[name] and not ServerItems[name].canUse then
			print("^3Warning^7: item", name, " is not usable in database , ^1 you need to set usable to 1 in database ^7", resource or "")
		end
	end)

	if UsableItemsFunctions[name] then
		print("^3Warning^7: item ", name, " is already registered, ^1 cant register the same item twice ^7", resource or "")
		print("^5Info:^7 if you restarting a script this is normal and you can ignore it!.^7")
	end
	UsableItemsFunctions[name] = cb
end

exports("registerUsableItem", InventoryAPI.registerUsableItem)

---to use when stopping your resource that registers the usable item
---@param name string | table item name or table of item names
function InventoryAPI.unRegisterUsableItem(name)
	if UsableItemsFunctions[name] then
		UsableItemsFunctions[name] = nil
	end
end

exports("unRegisterUsableItem", InventoryAPI.unRegisterUsableItem)


--- THIS EXPORT SHOULD ONLY BE USED FOR NORMAL ITEMS NOTHING ELSE for items with decay and metadata use the getUserInventoryItems they are unique items
---@param source number source
---@param cb fun(count: number | nil)? async or sync callback
---@param itemName string item name
---@param metadata table | nil? metadata
---@param percentage number? if 0 it will get all expired items, anything above 0 will get items with that percentage or more if nil will get all items
---@return number
function InventoryAPI.getItemCount(source, cb, itemName, metadata, percentage)
	local _source <const> = source

	if not _source then
		error("InventoryAPI.getItemCount: specify a source")
		return respond(cb, 0)
	end

	local svItem <const> = SvUtils.DoesItemExist(itemName, "getItemCount")
	if not svItem then
		return respond(cb, 0)
	end

	local user <const> = Core.getUser(_source)
	if not user then
		return respond(cb, 0)
	end

	local identifier <const> = user.getUsedCharacter.identifier


	local userInventory <const> = UsersInventories.default[identifier]
	if not userInventory then
		return respond(cb, 0)
	end

	if metadata then
		metadata = SharedUtils.MergeTables(svItem.metadata, metadata or {})
		--if metadata then get only the item that matches the metadata we are looking for
		local item <const> = SvUtils.FindItemByNameAndMetadata("default", identifier, itemName, metadata)
		if item then return respond(cb, item:getCount()) end
		return respond(cb, 0)
	end

	-- get count of all items but can choose to get expired items, by default will only get normal items
	-- it will also return items with metadata because people use this export to get them when it doesnt even make sense they are unique items
	local itemTotalCount <const> = SvUtils.GetItemCount("default", identifier, itemName, percentage)

	return respond(cb, itemTotalCount)
end

exports("getItemCount", InventoryAPI.getItemCount)

--- get item data from items loaded DB
---@param itemName string item name
---@param cb fun(item: table | nil)? async or sync callback
---@return table | nil
function InventoryAPI.getItemDB(itemName, cb)
	local svItem = SvUtils.DoesItemExist(itemName, "getItemDB")
	return respond(cb, svItem)
end

exports("getItemDB", InventoryAPI.getItemDB)


---@deprecated this cannot be used as there is items with metadata and decay system which will return either one of these
---get item data by item name
---@param player number source
---@param itemName string item name
---@param cb fun(item: table | nil)?
---@return table | nil
function InventoryAPI.getItemByName(player, itemName, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, nil)
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier

	if not SvUtils.DoesItemExist(itemName, "getItemByName") then
		return respond(cb, nil)
	end

	local item = SvUtils.FindItemByNameAndMetadata("default", identifier, itemName, nil)

	if not item then
		return respond(cb, nil)
	end

	return respond(cb, item)
end

exports("getItemByName", InventoryAPI.getItemByName)

---@deprecated this does the same thing as getItem use getItem instead
---get item data by item name and its metadata
---@param player number source
---@param itemName string item name
---@param metadata table metadata
---@param cb fun(item: table | nil)? async or sync callback
---@return table | nil
function InventoryAPI.getItemContainingMetadata(player, itemName, metadata, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, nil)
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier

	if not SvUtils.DoesItemExist(itemName, "getItemContainingMetadata") then
		return respond(cb, nil)
	end

	local item = SvUtils.FindItemByNameAndContainingMetadata("default", identifier, itemName, metadata)

	if not item then
		return respond(cb, nil)
	end

	return respond(cb, item)
end

exports("getItemContainingMetadata", InventoryAPI.getItemContainingMetadata)

---@deprecated this does the same thing as getItem use getItem instead
--- get item matching metadata
---@param player number source
---@param itemName string item name
---@param metadata table metadata
---@param cb fun(item: table | nil)? async or sync callback
function InventoryAPI.getItemMatchingMetadata(player, itemName, metadata, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, nil)
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier

	local svItem = SvUtils.DoesItemExist(itemName, "getItemContainingMetadata")
	if not svItem then
		return respond(cb, nil)
	end

	metadata = SharedUtils.MergeTables(svItem.metadata or {}, metadata or {})
	local item = SvUtils.FindItemByNameAndMetadata("default", identifier, itemName, metadata)

	if not item then
		return respond(cb, nil)
	end

	return respond(cb, item)
end

exports("getItemMatchingMetadata", InventoryAPI.getItemMatchingMetadata)

--- used through exports and by openplayerinventory to take or move
---@param source number source
---@param name string item name
---@param amount number
---@param metadata table metadata
---@param allow boolean? allow to detect item creation false means allow true meand dont allow
---@param degradation number? used for internal purposes moveToPlayer takeFromPlayer its a timestamp items are being exchanged
---@param percentage number? used for internal purposes for synscripts to support degradation
---@param cb fun(success: boolean)? async or sync callback
function InventoryAPI.addItem(source, name, amount, metadata, cb, allow, degradation, percentage)
	local _source = source

	if not _source then
		error("InventoryAPI.addItem: specify a source")
		return respond(cb, false)
	end

	local svItem = SvUtils.DoesItemExist(name, "addItem")
	if not svItem then
		return respond(cb, false)
	end

	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, false)
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local charIdentifier = sourceCharacter.charIdentifier
	local userInventory = UsersInventories.default[identifier]

	if userInventory == nil then
		UsersInventories.default[identifier] = {}
		userInventory = UsersInventories.default[identifier]
	end

	if not userInventory or amount <= 0 then
		return respond(cb, false)
	end

	-- support metadata from default items table
	if not metadata then
		if svItem.metadata and next(svItem.metadata) then
			metadata = svItem.metadata
		end
	end

	--local metadata_merged = SharedUtils.MergeTables(svItem.metadata, metadata or {})
	local item = SvUtils.FindItemByNameAndMetadata("default", identifier, name, metadata or {}) -- get item
	-- items that cant degrade we add ammount and items that exist
	if item then
		local result = SharedUtils.Table_equals(item:getMetadata(), metadata or {}) -- does metadata equals
		local doesMetadataExist = metadata ~= nil                             -- was metadata passed
		local existingMetadata = next(item:getMetadata()) ~= nil

		if item:getMaxDegradation() == 0 then
			-- if metadata equals and metadata was passed then add count to same stack
			if result and doesMetadataExist then
				item:addCount(amount)
				DBService.SetItemAmount(charIdentifier, item:getId(), item:getCount())
				TriggerClientEvent("vorpCoreClient:addItem", _source, item)
				return respond(cb, true)
			end

			-- if item does not contain metadata and metadata was not passed then add amount
			if not doesMetadataExist and not existingMetadata then
				-- item exists and does no t contain metdata or was passed as nil
				item:addCount(amount)
				DBService.SetItemAmount(charIdentifier, item:getId(), item:getCount())
				TriggerClientEvent("vorpCoreClient:addItem", _source, item)
				return respond(cb, true)
			end

			-- we need to get an item that does not have a metadata here other wise it will create a new one because the loop could return one with metadata that does not match
			local itemNoMetadata = SvUtils.GetItemNoMetadata("default", identifier, name)
			if itemNoMetadata then
				itemNoMetadata:addCount(amount)
				DBService.SetItemAmount(charIdentifier, itemNoMetadata:getId(), itemNoMetadata:getCount())
				TriggerClientEvent("vorpCoreClient:addItem", _source, itemNoMetadata)
				return respond(cb, true)
			end
		end
	end

	local isDegradable = svItem:getMaxDegradation() ~= 0
	local isExpired = nil
	if degradation and isDegradable and degradation > 0 then
		isExpired = degradation >= os.time() and 0 or degradation
	end

	local promise = promise.new()
	DBService.CreateItem(charIdentifier, svItem:getId(), amount, metadata or {}, name, isExpired, function(craftedItem)
		local newItem = Item:New({
			id = craftedItem.id,
			count = amount,
			limit = svItem:getLimit(),
			label = svItem:getLabel(),
			metadata = metadata or {},
			name = name,
			type = svItem:getType(),
			canUse = true,
			canRemove = svItem:getCanRemove(),
			owner = charIdentifier,
			desc = svItem:getDesc(),
			group = svItem:getGroup(),
			weight = svItem:getWeight(),
			maxDegradation = svItem:getMaxDegradation()
		})

		if isDegradable and not degradation then
			newItem.degradation = os.time()
			newItem.percentage = 100
			DBService.queryAwait('UPDATE character_inventories SET degradation = @degradation, percentage = @percentage WHERE item_crafted_id = @id', { degradation = newItem.degradation, percentage = newItem.percentage, id = craftedItem.id })
		end

		if percentage then
			newItem.degradation = os.time() - newItem:getElapsedTime(svItem:getMaxDegradation(), percentage)
			newItem.percentage = newItem:getPercentage(svItem:getMaxDegradation(), degradation)
			DBService.queryAwait('UPDATE character_inventories SET percentage = @percentage WHERE item_crafted_id = @id', { percentage = newItem.percentage, id = craftedItem.id })
		end

		userInventory[craftedItem.id] = newItem
		TriggerClientEvent("vorpCoreClient:addItem", _source, newItem)


		if not allow then
			local data = { name = newItem:getName(), count = amount, metadata = newItem:getMetadata() }
			TriggerEvent("vorp_inventory:Server:OnItemCreated", data, _source)
		end
		promise:resolve(true)
	end, "default")

	Citizen.Await(promise)
	return respond(cb, true)
end

exports("addItem", InventoryAPI.addItem)


--- get item by its main id
---@param player number source
---@param mainid number item id
---@param cb fun(item: table | nil)? async or sync callback
---@return table | nil
function InventoryAPI.getItemByMainId(player, mainid, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, nil)
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local userInventory = UsersInventories.default[identifier]
	if not userInventory then return respond(cb, nil) end

	local itemRequested = {}
	local item = userInventory[mainid]
	if not item then return respond(cb, nil) end

	-- needs to be like this so we dont inject them to the player inventory
	itemRequested.id = item:getId()
	itemRequested.label = item.metadata?.label or item:getLabel()
	itemRequested.name = item:getName()
	itemRequested.metadata = item:getMetadata()
	itemRequested.type = item:getType()
	itemRequested.count = item:getCount()
	itemRequested.limit = item:getLimit()
	itemRequested.canUse = item:getCanUse()
	itemRequested.group = item:getGroup()
	itemRequested.weight = item.metadata?.weight or item:getWeight()
	itemRequested.desc = item.metadata?.description or item:getDesc()
	itemRequested.percentage = item:getPercentage()
	itemRequested.isDegradable = item:getMaxDegradation() ~= 0

	return respond(cb, itemRequested)
end

exports("getItemByMainId", InventoryAPI.getItemByMainId)
-- alias for getItemByMainId
exports("getItemById", InventoryAPI.getItemByMainId)

--- sub item by its id
---@param player number source
---@param id number item id
---@param cb fun(success: boolean)? async or sync callback
---@param allow boolean? allow to detect item removal false means allow true meand dont allow
---@param amount number? amount to remove
---@return fun(success: boolean)
function InventoryAPI.subItemID(player, id, cb, allow, amount)
	local _source = player
	local sourceCharacter = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, false)
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local charIdentifier = sourceCharacter.charIdentifier
	local userInventory = UsersInventories.default[identifier]
	local item = userInventory[id]

	if not userInventory or not item then
		return respond(cb, false)
	end
	amount = amount or 1
	item:quitCount(amount)
	local itemName = item:getName()
	local itemMetadata = item:getMetadata()

	if item:getCount() == 0 then
		DBService.DeleteItem(charIdentifier, item:getId())
		TriggerClientEvent("vorpCoreClient:subItem", _source, item:getId(), 0)
		userInventory[item:getId()] = nil
	else
		DBService.SetItemAmount(charIdentifier, item:getId(), item:getCount())
		TriggerClientEvent("vorpCoreClient:subItem", _source, item:getId(), item:getCount())
	end

	if not allow then
		local data = { name = itemName, count = amount, metadata = itemMetadata }
		TriggerEvent("vorp_inventory:Server:OnItemRemoved", data, _source)
	end
	return respond(cb, true)
end

exports("subItemID", InventoryAPI.subItemID)
--alias for subItemID
exports("subItemById", InventoryAPI.subItemID)

--- sub item by its name
---@param source number source
---@param name string item name
---@param amount number
---@param metadata table? metadata
---@param cb fun(success: boolean)? async or sync callback
---@param allow boolean? allow to detect item removal false means allow true means dont allow
---@param percentage number? if 0 then it will delete expired items or will delete item at a desired percentage or above, if nil then it will delete any item with or without metadata or not normal item or not
---@return boolean
function InventoryAPI.subItem(source, name, amount, metadata, cb, allow, percentage)
	local _source <const> = source
	local sourceCharacter = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, false)
	end

	local svItem <const> = SvUtils.DoesItemExist(name, "subItem")
	if not svItem then
		return respond(cb, false)
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier <const> = sourceCharacter.identifier

	local userInventory <const> = CustomInventoryInfos.default.shared and UsersInventories.default or UsersInventories.default[identifier]
	if not userInventory then
		return respond(cb, false)
	end

	--* for items with metadata only
	if metadata then
		local itemFound <const> = SvUtils.FindItemByNameAndMetadata("default", identifier, name, metadata or {})
		if not itemFound then
			return respond(cb, false)
		end

		local itemName <const> = itemFound:getName()
		local itemMetadata <const> = itemFound:getMetadata()

		itemFound:quitCount(amount)
		TriggerClientEvent("vorpCoreClient:subItem", _source, itemFound:getId(), itemFound:getCount())
		if itemFound:getCount() == 0 then
			UsersInventories.default[identifier][itemFound:getId()] = nil
			DBService.DeleteItem(sourceCharacter.charIdentifier, itemFound:getId())
		else
			DBService.SetItemAmount(sourceCharacter.charIdentifier, itemFound:getId(), itemFound:getCount())
		end

		if not allow then
			local data <const> = { name = itemName, count = amount, metadata = itemMetadata }
			TriggerEvent("vorp_inventory:Server:OnItemRemoved", data, _source)
		end
		return respond(cb, true)
	end

	--* items with no metadata
	local sortedItems = {}
	for _, item in pairs(userInventory) do
		-- allow items with metadata so we dont break existing scripts because people are using this export to delete random items instead of specific items
		if name == item:getName() then
			-- decide which items to get
			if percentage then
				if percentage > 0 then
					-- only items with a percentage greater than or equal to the percentage requested
					if item:getPercentage() >= percentage then
						table.insert(sortedItems, item)
					end
				else
					-- only expired items
					if item:getPercentage() == 0 then
						table.insert(sortedItems, item)
					end
				end
			else
				-- only items with no decay should be added, currently there was no way to get normal items, if you want to use decay you must pass the argument since its new and optional
				--if item:getMaxDegradation() == 0 then -- canno use this because people are using this export to delete random items instead of specific items
				-- this works in conjunction with getItemCount that will only get items without decay, decay is optional
				table.insert(sortedItems, item)
				--end
			end
		end
	end

	-- if there is a stack with the same amount then remove that stack instead of removing from any stack
	local exactMatchItem = nil
	for _, item in ipairs(sortedItems) do
		-- do we look for items expired or not expired?
		if item:getCount() == amount then
			exactMatchItem = item
			break
		end
	end

	if exactMatchItem then
		-- if an exact match is found, use this instance
		local itemName <const> = exactMatchItem:getName()
		local itemMetadata <const> = exactMatchItem:getMetadata()
		exactMatchItem:quitCount(amount)
		TriggerClientEvent("vorpCoreClient:subItem", _source, exactMatchItem:getId(), exactMatchItem:getCount())
		if exactMatchItem:getCount() == 0 then
			UsersInventories.default[identifier][exactMatchItem:getId()] = nil
			DBService.DeleteItem(sourceCharacter.charIdentifier, exactMatchItem:getId())
		else
			DBService.SetItemAmount(sourceCharacter.charIdentifier, exactMatchItem:getId(), exactMatchItem:getCount())
		end

		if not allow then
			local data <const> = { name = itemName, count = amount, metadata = itemMetadata }
			TriggerEvent("vorp_inventory:Server:OnItemRemoved", data, _source)
		end
	else
		-- sort items from lower to higher
		table.sort(sortedItems, function(a, b) return a:getCount() < b:getCount() end)

		-- combine stacks starting from the lowest to higher this allows to eliminate smaller stacks first
		local itemsToRemove = {}
		local totalNeeded = amount
		for _, item in ipairs(sortedItems) do
			if totalNeeded <= 0 then break end

			-- in here we can add a condition to only get items expired or not expired? but this would cause issues if you get the amount of items and not selecting expired or not expired, because what if there is amount needed but not enough as expired or not expired.
			local countAvailable <const> = item:getCount()
			local removeCount <const> = math.min(countAvailable, totalNeeded)
			local itemMetadata <const> = item:getMetadata()

			table.insert(itemsToRemove, { item = item, count = removeCount, metadata = itemMetadata })
			totalNeeded = totalNeeded - removeCount
		end

		-- if there isnt enough items to remove then return false (you should be using the export getItemCount before using this export thats why we have it) either way you dont need to use it this check will secure it
		if #itemsToRemove == 0 or totalNeeded > 0 then
			return respond(cb, false)
		end

		-- remove the items
		for _, value in ipairs(itemsToRemove) do
			local item <const> = value.item
			local removeCount <const> = value.count
			local itemName <const> = item:getName()
			local itemMetadata <const> = item:getMetadata()

			item:quitCount(removeCount)
			TriggerClientEvent("vorpCoreClient:subItem", _source, item:getId(), item:getCount())
			if item:getCount() == 0 then
				UsersInventories.default[identifier][item:getId()] = nil
				DBService.DeleteItem(sourceCharacter.charIdentifier, item:getId())
			else
				DBService.SetItemAmount(sourceCharacter.charIdentifier, item:getId(), item:getCount())
			end
			if not allow then
				-- allow other scripts to detect the item removal and its amount, (count) was added
				local data <const> = { name = itemName, count = removeCount, metadata = itemMetadata }
				TriggerEvent("vorp_inventory:Server:OnItemRemoved", data, _source)
			end
		end
	end
	return respond(cb, true)
end

exports("subItem", InventoryAPI.subItem)


---set item metadata with item id
---@param _source number source
---@param itemId number item id
---@param metadata table metadata
---@param amount number? amount
---@param cb fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.setItemMetadata(_source, itemId, metadata, amount, cb)
	local sourceCharacter <const> = Core.getUser(_source)?.getUsedCharacter
	if not sourceCharacter then return respond(cb, false, "player with id: " .. _source .. " not found") end

	if type(metadata) ~= "table" then return respond(cb, false, "metadata is not a table") end

	local identifier <const> = sourceCharacter.identifier
	local charId <const> = sourceCharacter.charIdentifier

	local userInventory <const> = UsersInventories.default[identifier]
	if not userInventory then return respond(cb, false) end

	local item <const> = userInventory[itemId]
	if not item then return respond(cb, false, "item not found with id: " .. itemId) end

	local svItem <const> = SvUtils.DoesItemExist(item.name, "setItemMetadata")
	if not svItem then return respond(cb, false, "item with name: " .. item.name .. " not found") end

	local function removeFromStack(amountToUpdate)
		item:quitCount(amountToUpdate)

		if item:getCount() == 0 then
			userInventory[item:getId()] = nil
			DBService.DeleteItem(charId, item:getId())
			return TriggerClientEvent("vorpCoreClient:subItem", _source, item:getId(), 0)
		end

		DBService.SetItemAmount(charId, item:getId(), item:getCount())
		TriggerClientEvent("vorpCoreClient:subItem", _source, item:getId(), item:getCount())
	end

	local function updateStack(dataItem, meta)
		DBService.SetItemMetadata(charId, dataItem:getId(), meta)
		dataItem:setMetadata(meta)
		TriggerClientEvent("vorpCoreClient:SetItemMetadata", _source, dataItem:getId(), meta)
	end

	local function moveToStack(itemFound, amountToUpdate)
		itemFound:addCount(amountToUpdate)
		DBService.SetItemAmount(charId, itemFound:getId(), itemFound:getCount())
		TriggerClientEvent("vorpCoreClient:addItem", _source, itemFound)
	end

	local function createNewStack(newMeta, amountToUpdate)
		local isExpired = svItem:getMaxDegradation() ~= 0 and os.time() or nil

		DBService.CreateItem(charId, ServerItems[item.name].id, amountToUpdate, newMeta, item:getName(), isExpired, function(craftedItem)
			local newItem <const> = Item:New({
				id = craftedItem.id,
				count = amountToUpdate,
				limit = item:getLimit(),
				label = item:getLabel(),
				metadata = newMeta,
				name = item:getName(),
				type = item:getType(),
				canUse = true,
				canRemove = item:getCanRemove(),
				owner = charId,
				desc = item:getDesc(),
				group = item:getGroup(),
				weight = item:getWeight(),
				maxDegradation = svItem:getMaxDegradation()
			})

			if svItem:getMaxDegradation() ~= 0 then
				newItem.degradation = os.time()
				newItem.percentage = 100
				DBService.queryAwait('UPDATE character_inventories SET degradation = @degradation, percentage = @percentage WHERE item_crafted_id = @id',
					{ degradation = newItem.degradation, percentage = newItem.percentage, id = craftedItem.id }
				)
			end

			userInventory[craftedItem.id] = newItem
			TriggerClientEvent("vorpCoreClient:addItem", _source, newItem)
		end)
	end

	local amountToUpdate = amount or 1
	local count <const> = item:getCount()
	if amountToUpdate > count then
		amountToUpdate = count
	end

	local itemFound <const> = SvUtils.FindItemByNameAndMetadata("default", identifier, item.name, metadata)
	-- allows to keep entries that are not in the metadata we are passing. allowing to update only some entries and not all or all
	local newMeta <const> = SharedUtils.MergeTables(item:getMetadata(), metadata)
	if amountToUpdate == count then
		if itemFound then
			if item:getId() ~= itemFound:getId() then
				moveToStack(itemFound, amountToUpdate)
				removeFromStack(amountToUpdate)
			else
				-- SAME ID AND SAME METADATA DO NOTHING  USER IS TRYING TO UPDATE THE SAME STACK WITH THE SAME METADATA.
			end
		else
			updateStack(item, newMeta)
		end
	else
		if not itemFound then
			removeFromStack(amountToUpdate)
			createNewStack(newMeta, amountToUpdate)
		else
			if item:getId() ~= itemFound:getId() then
				moveToStack(itemFound, amountToUpdate)
				removeFromStack(amountToUpdate)
			else
				-- SAME ID AND SAME METADATA DO NOTHING  USER IS TRYING TO UPDATE THE SAME STACK WITH THE SAME METADATA.
			end
		end
	end

	return respond(cb, true)
end

exports("setItemMetadata", InventoryAPI.setItemMetadata)


---get item data
---@param source number source
---@param itemName string item name
---@param cb fun(success: boolean)| nil  async or sync callback
---@param metadata table | nil? metadata
---@param percentage number? if 0 then gets expired items if more than 0 then gets any item above this number if nil then gets any item
---@return  table | nil
function InventoryAPI.getItem(source, itemName, cb, metadata, percentage)
	local _source <const> = source
	local sourceCharacter <const> = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, nil)
	end

	local character <const> = sourceCharacter.getUsedCharacter
	local identifier <const> = character.identifier

	local svItem <const> = SvUtils.DoesItemExist(itemName, "getItem")
	if not svItem then
		return respond(cb, nil)
	end

	local function updateItemValues(item)
		item.label = item.metadata?.label or item:getLabel()
		item.desc = item.metadata?.description or item:getDesc()
		item.weight = item.metadata?.weight or item:getWeight()
		item.percentage = item:getPercentage()
		item.isDegradable = item:getMaxDegradation() ~= 0
		return item
	end

	local function getItemExpired()
		percentage = percentage or 0
		local userInventory <const> = UsersInventories.default[identifier]
		if not userInventory then return nil end
		for _, item in pairs(userInventory) do
			if item:getName() == itemName then
				local itemPercentage = item:getPercentage()
				if percentage > 0 then
					if itemPercentage >= percentage then
						return item
					end
				else
					if itemPercentage <= 0 then
						return item
					end
				end
			end
		end
		return false
	end

	-- if metadata is provided we check if it exists if not returns nil, and not any other items, only what we asked for
	if metadata then
		metadata = SharedUtils.MergeTables(svItem.metadata or {}, metadata)
		local item <const> = SvUtils.FindItemByNameAndMetadata("default", identifier, itemName, metadata)
		if not item then
			return respond(cb, nil)
		end
		return respond(cb, updateItemValues(item))
	end

	-- return expired or not expired items when specified
	if percentage ~= nil then
		local item <const> = getItemExpired()
		if not item then
			return respond(cb, nil)
		end
		return respond(cb, updateItemValues(item))
	end

	-- no metadata was specified or getExpired was nil  we get a random item
	local item <const> = SvUtils.FindItemByName("default", identifier, itemName)
	if not item then
		return respond(cb, nil)
	end
	return respond(cb, updateItemValues(item))
end

exports("getItem", InventoryAPI.getItem)


---get total items weight (internal function)
---@param identifier string user identifier
---@param charid number user charid
---@return integer
function InventoryAPI.getUserTotalCountItems(identifier, charid)
	local userTotalItemCount = 0
	local userInventory = UsersInventories.default[identifier]

	for _, item in pairs(userInventory or {}) do
		if item:getCount() == nil then
			userInventory[item:getId()] = nil
			DBService.DeleteItem(charid, item:getId())
		else
			local weight = item:getWeight() and (item:getWeight() * item:getCount()) or item:getCount()
			userTotalItemCount = userTotalItemCount + weight
		end
	end

	return userTotalItemCount
end

-----------------------------------------------------------------------------------------------
--WEAPONS

--- get user weapon
---@param player number player source
---@param cb fun(items: table)? async or sync callback
---@param weaponId number weapon id
---@return table
function InventoryAPI.getUserWeapon(player, cb, weaponId)
	local _source = player
	local weapon = {}
	local foundWeapon = UsersWeapons.default[weaponId]

	if not foundWeapon then
		return respond(cb, false)
	end

	weapon.name = foundWeapon:getName()
	weapon.id = foundWeapon:getId()
	weapon.propietary = foundWeapon:getPropietary()
	weapon.used = foundWeapon:getUsed()
	weapon.used2 = foundWeapon:getUsed2()
	weapon.ammo = foundWeapon:getAllAmmo()
	weapon.desc = foundWeapon:getDesc()
	weapon.group = 5
	weapon.source = foundWeapon:getSource()
	weapon.label = foundWeapon:getLabel()
	weapon.serial_number = foundWeapon:getSerialNumber()
	weapon.custom_label = foundWeapon:getCustomLabel()
	weapon.custom_desc = foundWeapon:getCustomDesc()
	weapon.weight = foundWeapon:getWeight()

	return respond(cb, weapon)
end

exports("getUserWeapon", InventoryAPI.getUserWeapon)

--- get all user weapons
---@param player number source
---@param cb fun(weapons: table)? async or sync callback
function InventoryAPI.getUserWeapons(player, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, nil)
	end
	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local charidentifier = sourceCharacter.charIdentifier
	local usersWeapons = UsersWeapons.default

	local userWeapons2 = {}

	for _, currentWeapon in pairs(usersWeapons) do
		if currentWeapon:getPropietary() == identifier and currentWeapon:getCharId() == charidentifier then
			local weapon = {
				name = currentWeapon:getName(),
				id = currentWeapon:getId(),
				propietary = currentWeapon:getPropietary(),
				used = currentWeapon:getUsed(),
				used2 = currentWeapon:getUsed2(),
				ammo = currentWeapon:getAllAmmo(),
				desc = currentWeapon:getDesc(),
				group = 5,
				source = currentWeapon:getSource(),
				label = currentWeapon:getLabel(),
				serial_number = currentWeapon:getSerialNumber(),
				custom_label = currentWeapon:getCustomLabel(),
				custom_desc = currentWeapon:getCustomDesc(),
				weight = currentWeapon:getWeight()
			}
			table.insert(userWeapons2, weapon)
		end
	end

	return respond(cb, userWeapons2)
end

exports("getUserInventoryWeapons", InventoryAPI.getUserWeapons)

--- get user weapon bullets
---@param player number source
---@param weaponId number weapon id
---@param cb fun(ammo: number)? async or sync callback
---@return number
function InventoryAPI.getWeaponBullets(player, weaponId, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, nil)
	end
	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local userWeapons = UsersWeapons.default[weaponId]

	if userWeapons then
		if userWeapons:getPropietary() == identifier then
			return respond(cb, userWeapons:getAllAmmo())
		end
	end
	return respond(cb, 0)
end

exports("getWeaponBullets", InventoryAPI.getWeaponBullets)

--- remove all user ammo
---@param player number source
---@param cb fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.removeAllUserAmmo(player, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, nil)
	end
	sourceCharacter = sourceCharacter.getUsedCharacter
	AmmoData[_source].ammo = {}
	TriggerClientEvent("vorpinventory:updateuiammocount", _source, AmmoData[_source].ammo)
	TriggerClientEvent("vorpinventory:recammo", _source, AmmoData[_source])
	local params = { charId = sourceCharacter.charIdentifier, ammo = json.encode({}) }
	DBService.updateAsync('UPDATE characters SET ammo = @ammo WHERE charidentifier = @charId', params)
	return respond(cb, true)
end

exports("removeAllUserAmmo", InventoryAPI.removeAllUserAmmo)

--- get all user ammo
---@param player number source
---@param cb fun(ammo: table)? async or sync callback
---@return table
function InventoryAPI.getUserAmmo(player, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, nil)
	end
	local ammo = AmmoData[_source].ammo
	if not ammo then
		return respond(cb, nil)
	end

	return respond(cb, ammo)
end

exports("getUserAmmo", InventoryAPI.getUserAmmo)

--- add bullets to player
---@param player number source
---@param bulletType string bullet type
---@param amount number amount of bullets
---@param cb fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.addBullets(player, bulletType, amount, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, nil)
	end
	sourceCharacter = sourceCharacter.getUsedCharacter
	local charidentifier = sourceCharacter.charIdentifier
	local ammo = AmmoData[_source].ammo

	if ammo and ammo[bulletType] then
		ammo[bulletType] = tonumber(ammo[bulletType]) + amount
	else
		ammo[bulletType] = amount
	end

	AmmoData[_source].ammo = ammo
	TriggerClientEvent("vorpinventory:updateuiammocount", _source, AmmoData[_source].ammo)
	TriggerClientEvent("vorpCoreClient:addBullets", _source, bulletType, ammo[bulletType])
	TriggerClientEvent("vorpinventory:recammo", _source, AmmoData[_source])
	local query1 = 'UPDATE characters SET ammo = @ammo WHERE charidentifier = @charidentifier'
	local params1 = { charidentifier = charidentifier, ammo = json.encode(ammo) }
	DBService.updateAsync(query1, params1)
	return respond(cb, true)
end

exports("addBullets", InventoryAPI.addBullets)


---sub bullets from player
---@param weaponId number
---@param bulletType string
---@param amount number
---@param cb fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.subBullets(weaponId, bulletType, amount, cb)
	local _source = source
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, nil)
	end
	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local userWeapons = UsersWeapons.default[weaponId]

	if userWeapons then
		if userWeapons:getPropietary() == identifier then
			userWeapons:subAmmo(bulletType, amount)
			TriggerClientEvent("vorpCoreClient:subBullets", _source, bulletType, amount)
			TriggerClientEvent("vorpinventory:updateuiammocount", _source, AmmoData[_source].ammo)
			return respond(cb, true)
		end
	end
	return respond(cb, false)
end

exports("subBullets", InventoryAPI.subBullets)

--- can carry ammount of weapons
---@param player number source
---@param amount number amount to check
---@param cb fun(success: boolean)?   async or sync callback
---@param weaponName string|number weapon name not neccesary but allows to check if weapon is in the list of not weapons
---@return boolean
function InventoryAPI.canCarryAmountWeapons(player, amount, cb, weaponName)
	local _source = player
	local sourceCharacter = Core.getUser(_source)

	if not sourceCharacter then
		return respond(cb, false)
	end

	local function getWeaponNameFromHash()
		if weaponName and type(weaponName) == "number" then
			for _, value in pairs(SharedData.Weapons) do
				if joaat(value.HashName) == weaponName then
					return value.HashName
				end
			end
		end
		return SharedData.Weapons[weaponName] and weaponName or nil
	end

	weaponName = getWeaponNameFromHash()

	local function isInventoryFull(identifier, charId, invCapacity)
		local weaponWeight = SvUtils.GetWeaponWeight(weaponName) * amount
		local itemsTotalWeight = InventoryAPI.getUserTotalCountItems(identifier, charId)
		local weaponsTotalWeight = InventoryAPI.getUserTotalCountWeapons(identifier, charId, true)

		if (itemsTotalWeight + weaponsTotalWeight + weaponWeight) > invCapacity then
			return true
		end
		return false
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local charId = sourceCharacter.charIdentifier
	local invCapacity = sourceCharacter.invCapacity
	local job = sourceCharacter.job
	local DefaultAmount = Config.MaxItemsInInventory.Weapons

	if weaponName and isInventoryFull(identifier, charId, invCapacity) then
		return respond(cb, false)
	end

	if weaponName and Config.notweapons[weaponName:upper()] then
		return respond(cb, true)
	end

	if Config.JobsAllowed[job] then
		DefaultAmount = Config.JobsAllowed[job]
	end

	if DefaultAmount ~= -1 then
		local sourceInventoryWeaponCount = InventoryAPI.getUserTotalCountWeapons(identifier, charId) + amount
		if sourceInventoryWeaponCount > DefaultAmount then
			return respond(cb, false)
		end
	end

	return respond(cb, true)
end

exports("canCarryWeapons", InventoryAPI.canCarryAmountWeapons)


--- set custom labels
---@param weaponId number weapon id
---@param label string weapon label
---@param cb fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.setWeaponCustomLabel(weaponId, label, cb)
	local userWeapons = UsersWeapons.default[weaponId]

	if userWeapons then
		userWeapons:setCustomLabel(label)
		TriggerClientEvent("vorpInventory:setWeaponCustomLabel", -1, weaponId, label)
		DBService.updateAsync('UPDATE loadout SET custom_label = @custom_label WHERE id = @id', { id = weaponId, custom_label = label })
		return respond(cb, true)
	end
	return respond(cb, false)
end

exports("setWeaponCustomLabel", InventoryAPI.setWeaponCustomLabel)

--- set custom serial numbers
---@param weaponId number weapon id
---@param serial string weapon serial number
---@param cb fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.setWeaponSerialNumber(weaponId, serial, cb)
	local userWeapons = UsersWeapons.default[weaponId]

	if userWeapons then
		userWeapons:setSerialNumber(serial)
		TriggerClientEvent("vorpInventory:setWeaponSerialNumber", -1, weaponId, serial)
		DBService.updateAsync('UPDATE loadout SET serial_number = @serial_number WHERE id = @id', { id = weaponId, serial_number = serial })
		return respond(cb, true)
	end
	return respond(cb, false)
end

exports("setWeaponSerialNumber", InventoryAPI.setWeaponSerialNumber)

--- set custom desc
---@param weaponId number weapon id
---@param desc string weapon desc
---@param cb fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.setWeaponCustomDesc(weaponId, desc, cb)
	local userWeapons = UsersWeapons.default[weaponId]
	if not userWeapons then
		return respond(cb, false)
	end
	TriggerClientEvent("vorpInventory:setWeaponCustomDesc", -1, weaponId, desc)
	userWeapons:setCustomDesc(desc)
	DBService.updateAsync('UPDATE loadout SET custom_desc = @custom_desc WHERE id = @id', { id = weaponId, custom_desc = desc })
	return respond(cb, true)
end

exports("setWeaponCustomDesc", InventoryAPI.setWeaponCustomDesc)

--- get weapon components
---@param player number source
---@param weaponid number weapon id
---@param cb fun(comps: table)? async or sync callback
---@return table | nil
function InventoryAPI.getcomps(player, weaponid, cb)
	local query = 'SELECT comps FROM loadout WHERE id = @id '
	local parameters = { id = weaponid }
	DBService.queryAsync(query, parameters, function(result)
		if result[1] then
			return respond(cb, json.decode(result[1].comps))
		end
		return respond(cb, nil)
	end)
end

exports("getWeaponComponents", InventoryAPI.getcomps)

---delete weapon from player using id
---@param player number source
---@param weaponid number weapon id
---@param cb fun(success: boolean)? async or sync callback
---@return nil | boolean
function InventoryAPI.deleteWeapon(player, weaponid, cb)
	local userWeapons = UsersWeapons.default
	if not userWeapons[weaponid] then
		return respond(cb, false)
	end
	userWeapons[weaponid]:setPropietary('')
	local query = 'DELETE FROM loadout WHERE id = @id'
	local params = { id = weaponid }
	DBService.deleteAsync(query, params, function(r) end)
	return respond(cb, true)
end

exports("deleteWeapon", InventoryAPI.deleteWeapon)

--- registr weapon to player
---@param _target number source
---@param wepname string weapon name
---@param ammos table ammos
---@param components table components table
---@param comps table weapon components
---@param cb fun(success: boolean)? async or sync callback
---@param wepId number | nil?  used for drop and give internally leave nil when registering a new weapon
---@param customSerial string | nil? custom serial number
---@param customLabel string | nil? custom label
---@return nil | boolean
function InventoryAPI.registerWeapon(_target, wepname, ammos, components, comps, cb, wepId, customSerial, customLabel, customDesc)
	local targetUser = Core.getUser(_target)
	if not targetUser then
		return respond(cb, nil)
	end

	if not SharedData.Weapons[wepname:upper()] then
		return respond(cb, nil)
	end

	local targetCharacter = targetUser.getUsedCharacter
	local targetIdentifier = targetCharacter.identifier
	local targetCharId = targetCharacter.charIdentifier
	local name = wepname:upper()
	local ammo = {}
	local component = {}

	if not comps then
		comps = {}
	end

	if ammos then
		for key, value in pairs(ammos) do
			ammo[key] = value
		end
	end


	if components then
		for key, _ in pairs(components) do
			component[#component + 1] = key
		end
	end


	local function hasSerialNumber()
		if wepId and UsersWeapons.default[wepId] then
			local userWeps = UsersWeapons.default
			local wep = userWeps[wepId]
			if wep:getSerialNumber() then
				return wep:getSerialNumber()
			end
		end
		return false
	end

	local function hasCustomLabel()
		if wepId and UsersWeapons.default[wepId] then
			local userWeps = UsersWeapons.default
			local wep = userWeps[wepId]
			if wep:getCustomLabel() then
				return wep:getCustomLabel()
			end
		end
		return nil
	end

	local function hasCustomDesc()
		if wepId and UsersWeapons.default[wepId] then
			local userWeps = UsersWeapons.default
			local wep = userWeps[wepId]
			if wep:getCustomDesc() then
				return wep:getCustomDesc()
			end
		end
		return nil
	end

	local serialNumber = customSerial or hasSerialNumber() or SvUtils.GenerateSerialNumber(name)
	local label = customLabel or hasCustomLabel() or SvUtils.GenerateWeaponLabel(name)
	local desc = customDesc or hasCustomDesc()
	local weight = SvUtils.GetWeaponWeight(name)
	local query = 'INSERT INTO loadout (identifier, charidentifier, name, ammo,components,comps,label,serial_number,custom_label,custom_desc) VALUES (@identifier, @charid, @name, @ammo, @components,@comps,@label,@serial_number,@custom_label,@custom_desc)'
	local params = {
		identifier = targetIdentifier,
		charid = targetCharId,
		name = name,
		label = SvUtils.GenerateWeaponLabel(name),
		ammo = json.encode(ammo),
		components = json.encode(component),
		comps = json.encode(comps),
		custom_label = label,
		serial_number = serialNumber,
		custom_desc = desc,
	}

	DBService.insertAsync(query, params, function(result)
		local weaponId = result
		local newWeapon = Weapon:New({
			id = weaponId,
			propietary = targetIdentifier,
			name = name,
			ammo = ammo,
			used = false,
			used2 = false,
			charId = targetCharId,
			currInv = "default",
			dropped = 0,
			source = _target,
			label = label,
			serial_number = serialNumber,
			custom_label = label,
			custom_desc = desc,
			group = 5,
			weight = weight
		})
		UsersWeapons.default[weaponId] = newWeapon
		TriggerEvent("syn_weapons:registerWeapon", weaponId)
		TriggerClientEvent("vorpInventory:receiveWeapon", _target, weaponId, targetIdentifier, name, ammo, label, serialNumber, label, _target, desc, weight)
	end)
	return respond(cb, true)
end

exports("createWeapon", InventoryAPI.registerWeapon)


---give weapon to target
---@param player number source
---@param weaponId number weapon id
---@param target number | nil target id
---@param cb fun(success: boolean)? async or sync callback
---@return  boolean
function InventoryAPI.giveWeapon(player, weaponId, target, cb)
	local _source = player
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return respond(cb, false)
	end
	sourceCharacter = sourceCharacter.getUsedCharacter
	local sourceIdentifier = sourceCharacter.identifier
	local sourceCharId = sourceCharacter.charIdentifier
	local invCapacity = sourceCharacter.invCapacity
	local job = sourceCharacter.job
	local _target = target
	local userWeapons = UsersWeapons.default
	local DefaultAmount = Config.MaxItemsInInventory.Weapons
	local weapon = userWeapons[weaponId]

	if not weapon then
		return respond(cb, false)
	end

	local weaponName = weapon:getName()
	local weight = weapon:getWeight()
	local notListed = false

	if Config.JobsAllowed[job] then
		DefaultAmount = Config.JobsAllowed[job]
	end

	if DefaultAmount ~= 0 then
		if weaponName and Config.notweapons[weaponName:upper()] then
			notListed = true
		end

		if not notListed then
			local itemsToTalWeight = InventoryAPI.getUserTotalCountItems(sourceIdentifier, sourceCharId)
			local sourceTotalWeaponWeight = InventoryAPI.getUserTotalCountWeapons(sourceIdentifier, sourceCharId, true)

			if (weight + itemsToTalWeight + sourceTotalWeaponWeight) > invCapacity then
				Core.NotifyRightTip(_source, "inventory full", 2000)
				return respond(cb, false)
			end

			local sourceTotalWeaponCount = InventoryAPI.getUserTotalCountWeapons(sourceIdentifier, sourceCharId) + 1
			if sourceTotalWeaponCount > DefaultAmount then
				Core.NotifyRightTip(_source, T.cantweapons, 2000)
				return respond(cb, false)
			end
		end
	end

	if weapon then
		weapon:setPropietary(sourceIdentifier)
		weapon:setCharId(sourceCharId)
		local weaponPropietary = weapon:getPropietary()
		local weaponAmmo = weapon:getAllAmmo()
		local label = weapon:getLabel()
		local serialNumber = weapon:getSerialNumber()
		local customLabel = weapon:getCustomLabel()
		local customDesc = weapon:getCustomDesc()
		local query = "UPDATE loadout SET identifier = @identifier, charidentifier = @charid WHERE id = @id"
		local params = { identifier = sourceIdentifier, charid = sourceCharId, id = weaponId }

		DBService.updateAsync(query, params, function(r)
			if _target and _target > 0 then
				if Core.getUser(_target) then
					weapon:setSource(_target)
					TriggerClientEvent('vorp:ShowAdvancedRightNotification', _target, T.youGaveWeapon, "inventory_items", weaponName, "COLOR_PURE_WHITE", 4000)
					TriggerClientEvent("vorpCoreClient:subWeapon", _target, weaponId)
				end
			end
			TriggerClientEvent('vorp:ShowAdvancedRightNotification', _source, T.youReceivedWeapon, "inventory_items", weaponName, "COLOR_PURE_WHITE", 4000)
			TriggerClientEvent("vorpInventory:receiveWeapon", _source, weaponId, weaponPropietary, weaponName, weaponAmmo, label, serialNumber, customLabel, _source, customDesc, weight)
		end)
	end
	return respond(cb, true)
end

exports("giveWeapon", InventoryAPI.giveWeapon)

--- sub weapon wont delete weapon it will set the propietary to empty
---@param player number source
---@param weaponId number weapon id
---@param cb fun(success: boolean)? async or sync callback
---@return  boolean
function InventoryAPI.subWeapon(player, weaponId, cb)
	local _source = player
	local User = Core.getUser(_source)
	if not User then
		return respond(cb, false)
	end
	local charId = User.getUsedCharacter.charIdentifier
	local userWeapons = UsersWeapons.default[weaponId]

	if userWeapons then
		userWeapons:setPropietary('')
		local query = "UPDATE loadout SET identifier = @identifier, charidentifier = @charid WHERE id = @id"
		local params = {
			identifier = '',
			charid = charId,
			id = weaponId
		}
		DBService.updateAsync(query, params, function(r)
			TriggerClientEvent("vorpCoreClient:subWeapon", _source, weaponId)
		end)
		TriggerClientEvent("vorpCoreClient:subWeapon", _source, weaponId)
		return respond(cb, true)
	end
	return respond(cb, false)
end

exports("subWeapon", InventoryAPI.subWeapon)



---get User by identifier total count of weapons or weight
---@param identifier string user identifier
---@param charId number user charid
---@return integer
function InventoryAPI.getUserTotalCountWeapons(identifier, charId, checkWeight)
	local userTotalWeaponCount = 0

	for _, weapon in pairs(UsersWeapons.default) do
		local owner_identifier = weapon:getPropietary()
		local owner_charid = weapon:getCharId()

		if owner_identifier == identifier and owner_charid == charId then
			local weaponName = weapon:getName()
			if weaponName and not Config.notweapons[weaponName:upper()] or checkWeight then
				local count = 0
				if checkWeight then
					count = weapon:getWeight()
				else
					count = 1
				end
				userTotalWeaponCount = userTotalWeaponCount + count
			end
		end
	end
	return userTotalWeaponCount
end

--- Register custom inventory
---@param data table inventory data
function InventoryAPI.registerInventory(data)
	if CustomInventoryInfos[data.id] then
		return
	end
	local newInventory = CustomInventoryAPI:New(data)
	newInventory:Register()
	return newInventory
end

exports("registerInventory", InventoryAPI.registerInventory)

local function canContinue(id, jobName, grade, charid)
	if not CustomInventoryInfos[id] then
		return false
	end

	if not CustomInventoryInfos[id]:isPermEnabled() then
		return false
	end

	if charid then
		return true
	end

	if not jobName and not grade then
		return false
	end

	return true
end
--- *add permissions to move items to custom inventory by jobs or an charids
---@param id string inventory id
---@param jobName string job name
---@param grade number job grade
function InventoryAPI.AddPermissionMoveToCustom(id, jobName, grade)
	if not canContinue(id, jobName, grade) then
		return
	end
	local data = { name = jobName, grade = grade }
	CustomInventoryInfos[id]:AddPermissionMoveTo(data)
end

exports("AddPermissionMoveToCustom", InventoryAPI.AddPermissionMoveToCustom)

--- * add permissions to take items from custom inventory by jobs or an charids
---@param id string inventory id
---@param jobName string job name
---@param grade number job grade
function InventoryAPI.AddPermissionTakeFromCustom(id, jobName, grade)
	if not canContinue(id, jobName, grade) then
		return
	end

	local data = { name = jobName, grade = grade }
	CustomInventoryInfos[id]:AddPermissionTakeFrom(data)
end

exports("AddPermissionTakeFromCustom", InventoryAPI.AddPermissionTakeFromCustom)



--- * add permissions to move items to custom inventory by char ids the state allows to remove or update temp permissions like false or true
---@param id string inventory id
---@param charid string charid
---@param state boolean | nil
function InventoryAPI.AddCharIdPermissionMoveToCustom(id, charid, state)
	if canContinue(id, false, false, charid) then
		return
	end

	local data = { name = charid, state = state }
	CustomInventoryInfos[id]:AddCharIdPermissionMoveTo(data)
end

exports("AddCharIdPermissionMoveToCustom", InventoryAPI.AddCharIdPermissionMoveToCustom)

--- * add permissions to take items from custom inventory by char ids the state allows to remove or update temp permissions like false or true
---@param id string inventory id
---@param charid string charid
---@param state boolean | nil
function InventoryAPI.AddCharIdPermissionTakeFromCustom(id, charid, state)
	if canContinue(id, false, false, charid) then
		return
	end

	local data = { charid = charid, state = state }
	CustomInventoryInfos[id]:AddCharIdPermissionTakeFrom(data)
end

exports("AddCharIdPermissionTakeFromCustom", InventoryAPI.AddCharIdPermissionTakeFromCustom)

--- Black list weapons or items
---@param id string inventory id
---@param name string item or weapon name
function InventoryAPI.BlackListCustom(id, name)
	if not CustomInventoryInfos[id] or not name then
		return
	end

	local data = { name = name }
	CustomInventoryInfos[id]:BlackList(data)
end

exports("BlackListCustomAny", InventoryAPI.BlackListCustom)

---Remove inventory by id from server
---@param id string inventory id
function InventoryAPI.removeInventory(id)
	if not CustomInventoryInfos[id] then
		return
	end

	CustomInventoryInfos[id]:removeCustomInventory()
end

exports("removeInventory", InventoryAPI.removeInventory)

---update custom inventory slots
---@param id string inventory id
---@param slots number inventory slots
function InventoryAPI.updateCustomInventorySlots(id, slots)
	if not CustomInventoryInfos[id] or not slots then
		return
	end

	if type(slots) ~= "number" then
		print("InventoryAPI.updateCustomInventorySlots: slots is not a number")
		return
	end

	CustomInventoryInfos[id]:setCustomInventoryLimit(slots)
end

exports("updateCustomInventorySlots", InventoryAPI.updateCustomInventorySlots)

--- get custom inventory slots (you can do this in your scripts though each script manages their own slots)
--- @param id string inventory id
--- @param cb fun(slots: number)? async or sync callback
function InventoryAPI.getCustomInventorySlots(id, cb)
	if not CustomInventoryInfos[id] then
		return respond(cb, false)
	end

	local slots = CustomInventoryInfos[id]:getLimit()
	return respond(cb, slots)
end

exports("getCustomInventorySlots", InventoryAPI.getCustomInventorySlots)

---set custom inventory item limit
---@param id string inventory id
---@param itemName string item name
---@param limit number item limit
function InventoryAPI.setCustomInventoryItemLimit(id, itemName, limit)
	if not CustomInventoryInfos[id] then
		return
	end

	if not itemName and not limit then
		return
	end

	if type(limit) ~= "number" then
		print("InventoryAPI.setCustomInventoryItemLimit: limit is not a number")
		return
	end

	local data = { name = itemName:lower(), limit = limit }

	CustomInventoryInfos[id]:setCustomItemLimit(data)
end

exports("setCustomInventoryItemLimit", InventoryAPI.setCustomInventoryItemLimit)

--- set custom inventory weapon limit
---@param id string inventory id
---@param wepName string
---@param limit number
function InventoryAPI.setCustomInventoryWeaponLimit(id, wepName, limit)
	if not CustomInventoryInfos[id] then
		return
	end

	if not wepName and not limit then
		return
	end

	if type(limit) ~= "number" then
		print("InventoryAPI.setCustomInventoryWeaponLimit: limit is not a number")
		return
	end

	local data = { name = wepName:lower(), limit = limit }

	CustomInventoryInfos[id]:setCustomWeaponLimit(data)
end

exports("setCustomInventoryWeaponLimit", InventoryAPI.setCustomInventoryWeaponLimit)

--- open inventory
---@param source number player
---@param id string? inventory id
function InventoryAPI.openInventory(source, id)
	local _source = source

	if not id then
		return TriggerClientEvent("vorp_inventory:OpenInv", _source)
	end

	if not CustomInventoryInfos[id] or not UsersInventories[id] then
		return
	end

	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then
		return
	end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local identifier = sourceCharacter.identifier
	local charid = sourceCharacter.charIdentifier
	local capacity = CustomInventoryInfos[id]:getLimit() > 0 and tostring(CustomInventoryInfos[id]:getLimit()) or 'oo'
	local weight = nil
	if CustomInventoryInfos[id]:useWeight() then
		weight = CustomInventoryInfos[id]:getWeight() > 0 and tostring(CustomInventoryInfos[id]:getWeight())
	end

	local function createCharacterInventoryFromDB(inventory)
		local characterInventory = {}
		for _, item in pairs(inventory) do
			local dbItem = ServerItems[item.item]
			if dbItem then
				-- Build character inventory
				characterInventory[item.id] = Item:New({
					count = tonumber(item.amount),
					id = item.id,
					limit = dbItem.limit,
					label = dbItem.label,
					metadata = SharedUtils.MergeTables(dbItem.metadata, item.metadata),
					name = dbItem.item,
					type = dbItem.type,
					canUse = dbItem.canUse,
					canRemove = dbItem.canRemove,
					createdAt = item.created_at,
					owner = item.character_id,
					desc = dbItem.desc,
					group = dbItem.group,
					weight = dbItem.weight,
					degradation = item.degradation,
					maxDegradation = dbItem.maxDegradation,
					percentage = item.percentage
				})
			end
		end
		return characterInventory
	end


	local function triggerAndReloadInventory()
		TriggerClientEvent("vorp_inventory:OpenCustomInv", _source, CustomInventoryInfos[id]:getName(), id, capacity, weight)
		InventoryService.reloadInventory(_source, id)
	end

	if CustomInventoryInfos[id]:isShared() then
		if UsersInventories[id] and #UsersInventories[id] > 0 then
			triggerAndReloadInventory()
		else
			DBService.GetSharedInventory(id, function(inventory)
				UsersInventories[id] = createCharacterInventoryFromDB(inventory)
				triggerAndReloadInventory()
			end)
		end
	else
		if UsersInventories[id][identifier] then
			triggerAndReloadInventory()
		else
			DBService.GetInventory(charid, id, function(inventory)
				UsersInventories[id][identifier] = createCharacterInventoryFromDB(inventory)
				triggerAndReloadInventory()
			end)
		end
	end
end

exports("openInventory", InventoryAPI.openInventory)

---close  inventory
---@param source number
---@param id? string
function InventoryAPI.closeInventory(source, id)
	local _source = source
	if id and CustomInventoryInfos[id] then
		return TriggerClientEvent("vorp_inventory:CloseCustomInv", _source)
	end

	TriggerClientEvent("vorp_inventory:CloseInv", source)
end

exports("closeInventory", InventoryAPI.closeInventory)


--- check if custom inventory is already registered
---@param id string inventory id
---@param callback fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.isCustomInventoryRegistered(id, callback)
	if CustomInventoryInfos[id] then
		return respond(callback, true)
	end

	return respond(callback, false)
end

exports("isCustomInventoryRegistered", InventoryAPI.isCustomInventoryRegistered)

--- get registered custom inventory data
---@param id string inventory id
---@param callback fun(data:table|boolean)? async or sync callback
---@return table | boolean
function InventoryAPI.getCustomInventoryData(id, callback)
	if CustomInventoryInfos[id] then
		return respond(callback, CustomInventoryInfos[id]:getCustomInvData())
	end
	return respond(callback, false)
end

exports("getCustomInventoryData", InventoryAPI.getCustomInventoryData)

--- update registered custom inventory data
---@param id string inventory id
---@param data table inventory data
---@param callback fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.updateCustomInventoryData(id, data, callback)
	if CustomInventoryInfos[id] then
		CustomInventoryInfos[id]:updateCustomInvData(data)
		return respond(callback, true)
	end
	return respond(callback, false)
end

exports("updateCustomInventoryData", InventoryAPI.updateCustomInventoryData)

---comment
---@param data table
---@param callback fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.openPlayerInventory(data, callback)
	local title = data.title
	local target = data.target
	local source = data.source
	local _target = Core.getUser(target)
	if not _target then return false end
	InventoryAPI.closeInventory(target)
	local charid = _target.getUsedCharacter.charIdentifier

	PlayerBlackListedItems = data.blacklist or {}

	if not CoolDownStarted[source] then
		CoolDownStarted[source] = {}
	end

	local function isInCooldown(itemType)
		return CoolDownStarted[source][itemType] and os.time() < CoolDownStarted[source][itemType]
	end

	local function HandleLimits(limitType)
		if not data.itemsLimit then return true, false end
		local itemType = data.itemsLimit[limitType].itemType
		local limit = data.itemsLimit[limitType].limit

		if not PlayerItemsLimit[target] then
			PlayerItemsLimit[target] = {}
		end

		if not PlayerItemsLimit[target][itemType] then
			PlayerItemsLimit[target][itemType] = { limit = limit, timeout = data.timeout or nil }
		end

		local cooldownActive = isInCooldown(itemType)

		if PlayerItemsLimit[target][itemType].limit <= 0 and cooldownActive then
			return false, true
		elseif not cooldownActive and data.timeout then
			PlayerItemsLimit[target][itemType].limit = limit
		end

		return true, cooldownActive
	end

	local allowWeapons, cooldownWeapons = HandleLimits("weapons")
	local allowItems, cooldownItems = HandleLimits("items")

	if cooldownWeapons and cooldownItems then
		Core.NotifyObjective(source, T.BothonCool, 5000)
		return respond(callback, false)
	end

	if allowWeapons or allowItems then
		InventoryService.reloadInventory(target, "default", "player", source)
		TriggerClientEvent("vorp_inventory:OpenPlayerInventory", source, title, charid, "player")
	end

	return respond(callback, true)
end

exports("openPlayerInventory", InventoryAPI.openPlayerInventory)

local function getTotalAmmountInCustomInventory(id, amount)
	local currentWeaponsAmount = DBService.GetTotalWeaponsInCustomInventory(id)
	local currentItemsAmount = DBService.GetTotalItemsInCustomInventory(id)
	local total = amount + currentWeaponsAmount + currentItemsAmount
	return total
end

-- add items to custom inventory
---@param id string inventory id
---@param items table items
---@param charid number charidentifier of the owner of the storage if custom inv is not shared , if its shared can be any characteridentifer
---@param callback fun(success: boolean)? async or sync callback
---@param identifier string? identifier of the owner of the storage if custom inv is not shared , if its shared dont need one
function InventoryAPI.addItemsToCustomInventory(id, items, charid, callback, identifier)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	if not charid or charid == 0 then
		print(("InventoryAPI.addItemsToCustomInventory: charid is not valid %s"):format(id))
		return respond(callback, false)
	end

	if type(items) ~= "table" then
		print("InventoryAPI.addItemsToCustomInventory: items must be a table")
		return respond(callback, false)
	end

	local totalAmount = 0
	for index, value in ipairs(items) do
		local item = ServerItems[value.name]
		if not item then
			print(("item %s dont exist, this request was cancelled make sure to add the items to database items table"):format(value.name))
			return respond(callback, false)
		end
		totalAmount = totalAmount + value.amount
	end

	local total = getTotalAmmountInCustomInventory(id, totalAmount)
	if total > CustomInventoryInfos[id]:getLimit() then
		print("InventoryAPI.addItemsToCustomInventory: total amount is greater than inventory limit, cannot add items to this inv")
		return respond(callback, false)
	end

	InventoryService.addItemsToCustomInventory(id, items, charid, identifier)

	return respond(callback, true)
end

exports("addItemsToCustomInventory", InventoryAPI.addItemsToCustomInventory)

-- add weapons to custom inventory
---@param id string inventory id
---@param weapons table weapons
---@param charid number charidentifier of the owner of the storage if custom inv is not shared , if its shared can be any characteridentifer
---@param callback fun(success: boolean)? async or sync callback
function InventoryAPI.addWeaponsToCustomInventory(id, weapons, charid, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	if not CustomInventoryInfos[id]:doesAcceptWeapons() then
		print("InventoryAPI.addWeaponsToCustomInventory: this inventory does not accept weapons, change the settings in the registerCustomInventory export")
		return respond(callback, false)
	end

	if not charid or charid == 0 then
		local msg = "InventoryAPI.addWeaponsToCustomInventory: charid is not valid %s"
		print((msg):format(id))
		return respond(callback, false)
	end

	if type(weapons) ~= "table" then
		print("InventoryAPI.addWeaponsToCustomInventory: weapons must be a table")
		return respond(callback, false)
	end

	if getTotalAmmountInCustomInventory(id, #weapons) > CustomInventoryInfos[id]:getLimit() then
		print("InventoryAPI.addWeaponsToCustomInventory: total amount is greater than inventory limit, cannot add weapons to this inv")
		return respond(callback, false)
	end

	InventoryService.addWeaponsToCustomInventory(id, weapons, charid)

	return respond(callback, true)
end

exports("addWeaponsToCustomInventory", InventoryAPI.addWeaponsToCustomInventory)

--- get custom inventory item count
---@param id string inventory id
---@param item_name string item name
---@param item_crafted_id number? item crafted id if defined will return the amount of the item crafted id
---@param callback fun(amount: number)? async or sync callback
---@return number
function InventoryAPI.getCustomInventoryItemCount(id, item_name, item_crafted_id, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, 0)
	end

	local query = "SELECT SUM(amount) as total_amount FROM character_inventories WHERE inventory_type = @invType AND item_name = @item_name;"
	local arguments = { invType = id, item_name = item_name }
	if item_crafted_id then
		query = "SELECT amount as total_amount FROM character_inventories WHERE inventory_type = @invType AND item_crafted_id = @item_crafted_id;"
		arguments = { invType = id, item_crafted_id = item_crafted_id }
	end

	local result = DBService.queryAwait(query, arguments)
	if result[1] and result[1].total_amount then
		return respond(callback, tonumber(result[1].total_amount))
	end

	return respond(callback, 0)
end

exports('getCustomInventoryItemCount', InventoryAPI.getCustomInventoryItemCount)

--- get custom inventory weapon count
---@param id string inventory id
---@param weapon_name string weapon name
---@param callback fun(amount: number)? async or sync callback
---@return number
function InventoryAPI.getCustomInventoryWeaponCount(id, weapon_name, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, 0)
	end

	local result = DBService.queryAwait("SELECT COUNT(*) as total_count FROM loadout WHERE curr_inv = @invType AND weapon = @weapon_name", { invType = id, weapon_name = weapon_name })
	if result[1] and result[1].total_count then
		return respond(callback, tonumber(result[1].total_count))
	end
	return respond(callback, 0)
end

exports('getCustomInventoryWeaponCount', InventoryAPI.getCustomInventoryWeaponCount)


-- remove item from inventory
---@param id string inventory id
---@param item_name string item name
---@param amount number amount to remove
---@param item_crafted_id number? item crafted id if defined will remove by the id and not the name
---@param callback fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.removeItemFromCustomInventory(id, item_name, amount, item_crafted_id, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	if InventoryService.removeItemFromCustomInventory(id, item_name, amount, item_crafted_id) then
		return respond(callback, true)
	end

	return respond(callback, false)
end

exports("removeItemFromCustomInventory", InventoryAPI.removeItemFromCustomInventory)


-- remove weapon from inventory
---@param id string inventory id
---@param weapon_name string weapon name
---@param callback fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.removeWeaponFromCustomInventory(id, weapon_name, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	if InventoryService.removeWeaponFromCustomInventory(id, weapon_name) then
		return respond(callback, true)
	end

	return respond(callback, false)
end

exports("removeWeaponFromCustomInventory", InventoryAPI.removeWeaponFromCustomInventory)


-- get all items from custom inventory
---@param id string inventory id
---@param callback fun(items: table)? async or sync callback
---@return table | nil
function InventoryAPI.getCustomInventoryItems(id, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	local items = InventoryService.getAllItemsFromCustomInventory(id)
	return respond(callback, items)
end

exports("getCustomInventoryItems", InventoryAPI.getCustomInventoryItems)

-- get all weapons from custom inventory
---@param id string inventory id
---@param callback fun(weapons: table)? async or sync callback
---@return table | boolean
function InventoryAPI.getCustomInventoryWeapons(id, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	local weapons = InventoryService.getAllWeaponsFromCustomInventory(id)
	return respond(callback, weapons)
end

exports("getCustomInventoryWeapons", InventoryAPI.getCustomInventoryWeapons)

-- remove weapon from custom inventory by weapon id
---@param id string inventory id
---@param weapon_id number weapon id
---@param callback fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.removeWeaponByIdFromCustomInventory(id, weapon_id, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	if InventoryService.removeWeaponsByIdFromCustomInventory(id, weapon_id) then
		return respond(callback, true)
	end

	return respond(callback, false)
end

exports("removeCustomInventoryWeaponById", InventoryAPI.removeWeaponByIdFromCustomInventory)

-- update item amount and metdata
---@param id string inventory id
---@param item_id number item id
---@param metadata table? metadata
---@param amount number? amount
---@param callback fun(success: boolean)? async or sync callback
---@param identifier string? identifier of the owner of the storage if custom inv is not shared , if its shared dont need one
---@return boolean
function InventoryAPI.updateItemInCustomInventory(id, item_id, metadata, amount, callback, identifier)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	if InventoryService.updateItemInCustomInventory(id, item_id, metadata, amount, identifier) then
		return respond(callback, true)
	end

	return respond(callback, false)
end

exports("updateCustomInventoryItem", InventoryAPI.updateItemInCustomInventory)

-- delete custom inventory items and weapons, after this inventory will be clear from all items and weapons including cache
---@param id string inventory id
---@param callback fun(success: boolean)? async or sync callback
---@return boolean
function InventoryAPI.deleteCustomInventory(id, callback)
	if not CustomInventoryInfos[id] then
		return respond(callback, false)
	end

	if InventoryService.deleteCustomInventory(id) then
		return respond(callback, true)
	end
	CustomInventoryInfos[id]:removeCustomInventory()
	return respond(callback, false)
end

exports("deleteCustomInventory", InventoryAPI.deleteCustomInventory)
