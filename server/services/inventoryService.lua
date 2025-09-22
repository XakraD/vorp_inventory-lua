local T <const>     = TranslationInv.Langs[Lang]
local Core <const>  = exports.vorp_core:GetCore()
local timer <const> = Config.CoolDownNewPlayer or 120
local newchar       = {}
math.randomseed(GetGameTimer())
InventoryService = {}
ItemPickUps      = {}
MoneyPickUps     = {}
GoldPickUps      = {}


function InventoryService.CheckNewPlayer(_source, charid)
	if not Config.NewPlayers then return true end

	if not newchar[charid] then return true end

	Core.NotifyRightTip(_source, T.ToNew, 5000)
	SvUtils.Trem(_source)
	return false
end

local function getSourceInfo(_source)
	local user <const> = Core.getUser(_source)
	if not user then return end

	local sourceCharacter <const> = user.getUsedCharacter
	local charname <const> = sourceCharacter.firstname .. ' ' .. sourceCharacter.lastname
	local sourceIdentifier <const> = sourceCharacter.charIdentifier
	local steamname <const> = GetPlayerName(_source)
	return charname, sourceIdentifier, steamname
end


function InventoryService.UseItem(data)
	local _source <const> = source
	local sourceCharacter <const> = Core.getUser(_source)
	if not sourceCharacter then return end

	local itemId <const> = data.id
	local itemName <const> = data.item
	local identifier <const> = sourceCharacter.getUsedCharacter.identifier
	local userInventory <const> = UsersInventories.default[identifier]

	local svItem = SvUtils.DoesItemExist(itemName, "UseItem")
	if not svItem then return end

	local item = userInventory[itemId]
	if not item or not UsableItemsFunctions[itemName] then return end

	local arguments <const> = {
		source = _source,
		item = {
			---@deprecated -- same as item.id
			mainid = itemId,
			item = item:getName(), -- for backwards compat
			---
			metadata = item:getMetadata(),
			percentage = item:getPercentage(),
			isDegradable = item:getMaxDegradation() ~= 0,
			id = item:getId(),
			count = item:getCount(),
			label = item.metadata?.label or item:getLabel(),
			name = item:getName(),
			desc = item.metadata?.description or item:getDesc(),
			type = item:getType(),
			limit = item:getLimit(),
			group = item:getGroup(),
			weight = item.metadata?.weight or item:getWeight()
		}
	}

	-- if its an item that can degrade then check if its expired
	if arguments.item.isDegradable then
		local isExpired = item:isItemExpired()
		if isExpired then
			local canUseExpired = arguments.item.metadata?.useExpired or ServerItems[itemName]?.useExpired
			if not canUseExpired then
				local text = "Item is expired and can't be used"
				if Config.DeleteItemOnUseWhenExpired then
					InventoryAPI.subItemID(_source, item:getId())
					text = "Item is expired and can't be used, item was removed from your inventory"
				end
				Core.NotifyRightTip(_source, text, 3000)
				return
			end
		end
	end

	TriggerEvent("vorp_inventory:Server:OnItemUse", arguments)

	local success <const>, result <const> = pcall(UsableItemsFunctions[itemName], arguments)
	if not success then
		return print("Function call failed with error:", result, "a usable item :", itemName, " have an error in the callback function")
	end
end

function InventoryService.DropMoney(amount)
	local _source <const> = source

	local user <const> = Core.getUser(_source)
	if not user then return end

	if SvUtils.InProcessing(_source) then return end
	SvUtils.ProcessUser(_source)

	local character = user.getUsedCharacter
	local userMoney <const> = character.money
	local charid <const> = character.charIdentifier

	if userMoney < amount then return SvUtils.Trem(_source) end

	if not InventoryService.CheckNewPlayer(_source, charid) then return SvUtils.Trem(_source) end

	if not Config.DeleteOnlyDontDrop then
		TriggerClientEvent("vorpInventory:createMoneyPickup", _source, amount)
	else
		character.removeCurrency(0, amount)
	end
	local charname <const>, _, steamname <const> = getSourceInfo(_source)
	local title <const> = T.dropmoney
	local description <const> = "**" .. T.WebHookLang.money .. ":** `" .. amount .. "` `$` \n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`\n"
	local info <const> = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorDropMoney, }
	SvUtils.SendDiscordWebhook(info)

	SvUtils.Trem(_source)
end

function InventoryService.giveMoneyToPlayer(target, amount)
	local _source <const> = source
	local _target <const> = target
	local user <const> = Core.getUser(_source)
	local targetUser <const> = Core.getUser(_target)

	if not user or not targetUser then
		return TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
	end
	local sourceCharacter <const> = user.getUsedCharacter
	local targetCharacter <const> = targetUser.getUsedCharacter
	local sourceMoney <const> = sourceCharacter.money
	local charid <const> = sourceCharacter.charIdentifier
	if not InventoryService.CheckNewPlayer(_source, charid) then
		return TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
	end

	if sourceMoney < amount then
		Core.NotifyRightTip(_source, T.NotEnoughMoney, 3000)
		return TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
	end

	if SvUtils.InProcessing(_source) then return end
	SvUtils.ProcessUser(_source)


	sourceCharacter.removeCurrency(0, amount)
	targetCharacter.addCurrency(0, amount)
	Core.NotifyRightTip(_source, T.YouPaid .. amount .. " ID: " .. _target, 3000)
	Core.NotifyRightTip(_target, T.YouReceived .. amount .. " ID: " .. _source, 3000)


	local charname <const>, _, steamname <const> = getSourceInfo(_source)
	local charname2 <const>, _, steamname2 <const> = getSourceInfo(_target)
	local title <const> = T.givemoney
	local description <const> = "**" .. T.WebHookLang.amount .. "**: `" .. amount .. "`\n **" .. T.WebHookLang.charname .. ":** `" .. charname .. "` \n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "` \n**" .. T.to .. "** `" .. charname2 .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname2 .. "` \n"
	local info <const> = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorgiveMoney, }
	SvUtils.SendDiscordWebhook(info)

	TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
	SvUtils.Trem(_source)
end

function InventoryService.DropGold(amount)
	local _source <const> = source

	local user <const> = Core.getUser(_source)
	if not user then return end

	local userCharacter <const> = user.getUsedCharacter
	local userGold <const> = userCharacter.gold

	if userGold < amount then return end

	if SvUtils.InProcessing(_source) then return end
	SvUtils.ProcessUser(_source)


	if not Config.DeleteOnlyDontDrop then
		TriggerClientEvent("vorpInventory:createGoldPickup", _source, amount)
	else
		userCharacter.removeCurrency(1, amount)
	end

	local charname <const>, _, steamname <const> = getSourceInfo(_source)
	local title <const> = T.dropgold
	local description <const> = "**" .. T.WebHookLang.gold .. ":** `" .. amount .. "` \n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`\n"
	local info <const> = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorDropGold, }
	SvUtils.SendDiscordWebhook(info)

	SvUtils.Trem(_source)
end

function InventoryService.giveGoldToPlayer(target, amount)
	local _source <const> = source

	local user <const> = Core.getUser(_source)
	local targetUser <const> = Core.getUser(target)
	if not user or not targetUser then return end

	local sourceCharacter <const> = user.getUsedCharacter
	local targetCharacter <const> = targetUser.getUsedCharacter
	local sourceGold <const> = sourceCharacter.gold

	if sourceGold < amount then
		Core.NotifyRightTip(_source, T.NotEnoughGold, 3000)
		return TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
	end

	if SvUtils.InProcessing(_source) then return end
	SvUtils.ProcessUser(_source)

	sourceCharacter.removeCurrency(1, amount)
	targetCharacter.addCurrency(1, amount)

	Core.NotifyRightTip(_source, T.YouPaid .. amount .. "ID: " .. target, 3000)
	Core.NotifyRightTip(target, T.YouReceived .. amount .. "ID: " .. _source, 3000)


	local charname <const>, _, steamname <const> = getSourceInfo(_source)
	local charname2 <const>, _, steamname2 <const> = getSourceInfo(target)
	local title <const> = T.givegold
	local description = "**" .. T.WebHookLang.amount .. "**: `" .. amount .. "`\n **" .. T.WebHookLang.charname .. ":** `" .. charname .. "` \n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "` \n**" .. T.to .. "** `" .. charname2 .. "`\n**" .. T.WebHookLang.Steamname .. " `" .. steamname2 .. "` \n**"

	local info <const> = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorgiveGold, }
	SvUtils.SendDiscordWebhook(info)

	TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
	SvUtils.Trem(_source)
end

function InventoryService.setWeaponBullets(weaponId, type, amount)
	local userWeapons <const> = UsersWeapons.default

	if userWeapons[weaponId] ~= nil then
		userWeapons[weaponId]:setAmmo(type, amount)
	end
end

function InventoryService.usedWeapon(id, _used, _used2)
	local query <const> = 'UPDATE loadout SET used = @used, used2 = @used2 WHERE id = @id'
	local params <const> = { used = _used and 1 or 0, used2 = _used2 and 1 or 0, id = id }
	DBService.updateAsync(query, params)
end

function InventoryService.subItem(source, invId, itemId, amount)
	local _source <const> = source

	local user <const> = Core.getUser(_source)
	if not user then return end

	local sourceCharacter <const> = user.getUsedCharacter
	local identifier <const> = sourceCharacter.identifier
	local userInventory <const> = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]

	if not userInventory then
		return false
	end

	local item <const> = userInventory[itemId]
	if not item then
		return false
	end

	if amount <= item:getCount() then
		item:quitCount(amount)
	end

	if item:getCount() == 0 then
		if invId == "default" then
			local data = { name = item:getName(), count = amount }
			TriggerEvent("vorp_inventory:Server:OnItemRemoved", data, _source)
		end
		userInventory[itemId] = nil
		DBService.DeleteItem(item:getOwner(), itemId)
	else
		DBService.SetItemAmount(item:getOwner(), itemId, item:getCount())
	end

	return true
end

-- on pick up, move to custom and take from custom internal function to add items
---@param source integer
---@param invId string
---@param name string
---@param amount integer
---@param metadata table
---@param data {degradation: integer, isPickup: boolean|nil, percentage: integer|nil}
---@param cb function
---@return boolean | {}
function InventoryService.addItem(source, invId, name, amount, metadata, data, cb)
	local _source <const> = source
	local user <const> = Core.getUser(_source)
	if not user then return cb(nil) end

	local sourceCharacter <const> = user.getUsedCharacter
	local identifier <const> = sourceCharacter.identifier
	local charIdentifier <const> = sourceCharacter.charIdentifier
	local svItem <const> = SvUtils.DoesItemExist(name, "addItem")

	if not svItem then
		return cb(nil)
	end

	metadata = SharedUtils.MergeTables(svItem.metadata, metadata or {})
	local userInventory <const> = CustomInventoryInfos[invId].shared and UsersInventories[invId] or UsersInventories[invId][identifier]
	if not userInventory then
		return cb(nil)
	end


	local function createItem()
		local degrade <const> = svItem:getMaxDegradation()
		local isExpired <const> = degrade ~= 0 and os.time() or nil

		DBService.CreateItem(charIdentifier, svItem:getId(), amount, metadata, name, isExpired, function(craftedItem)
			local item <const> = Item:New({
				id = craftedItem.id,
				count = amount,
				limit = svItem:getLimit(),
				label = svItem:getLabel(),
				metadata = SharedUtils.MergeTables(svItem.metadata, metadata),
				name = name,
				type = "item_standard",
				canUse = svItem:getCanUse(),
				canRemove = svItem:getCanRemove(),
				owner = charIdentifier,
				desc = svItem:getDesc(),
				group = svItem:getGroup(),
				weight = svItem:getWeight(),
				maxDegradation = degrade,
			})

			if invId == "default" then
				if degrade ~= 0 then
					if data.degradation then
						if data.degradation > 0 then
							if data.isPickup then
								if not item:isItemExpired(data.degradation, degrade) then
									local elapsedTime <const> = os.time() - data.degradation
									item.degradation = os.time() - elapsedTime
									item.percentage = item:getPercentage(degrade, item.degradation)
								else
									item.degradation = 0
									item.percentage = 0
								end
							else
								item.degradation = os.time() - item:getElapsedTime(degrade, data.percentage)
								item.percentage = item:getPercentage(degrade, item.degradation)
							end
							DBService.queryAwait('UPDATE character_inventories SET degradation = @degradation, percentage = @percentage WHERE item_crafted_id = @id',
								{ degradation = item.degradation, percentage = item.percentage, id = craftedItem.id }
							)
						else
							item.degradation = 0
							item.percentage = 0
							DBService.queryAwait('UPDATE character_inventories SET degradation = @degradation, percentage = @percentage WHERE item_crafted_id = @id',
								{ degradation = 0, percentage = 0, id = craftedItem.id }
							)
						end
					else
						item.degradation = os.time()
						item.percentage = 100
						DBService.queryAwait('UPDATE character_inventories SET degradation = @degradation, percentage = @percentage WHERE item_crafted_id = @id',
							{ degradation = os.time(), percentage = 100, id = craftedItem.id }
						)
					end
				end
			else
				if data.degradation and degrade ~= 0 then
					if item:isItemExpired(data.degradation, degrade) then
						item.degradation = 0
						item.percentage = 0
					else
						item.percentage = item:getPercentage(degrade, data.degradation)
						item.degradation = os.time()
					end
					-- custom invs need to be updated everytime
					DBService.queryAwait('UPDATE character_inventories SET percentage = @percentage, degradation = @degradation WHERE item_crafted_id = @id',
						{ percentage = item.percentage, degradation = item.degradation, id = craftedItem.id }
					)
				end
			end


			userInventory[craftedItem.id] = item
			if invId == "default" then
				TriggerEvent("vorp_inventory:Server:OnItemCreated", { name = item:getName(), count = amount, metadata = item:getMetadata() }, _source)
			end

			return cb(item)
		end, invId)
	end

	-- item exists in inventory by name and metadata?
	local item <const> = SvUtils.FindItemByNameAndMetadata(invId, identifier, name, metadata)
	if item then
		-- items exists with the same name and metadata
		-- amount is greater than 0 for error
		if amount > 0 then
			-- if item is not a degradation item
			if svItem:getMaxDegradation() == 0 then
				item:addCount(amount, CustomInventoryInfos[invId].ignoreItemStackLimit)
				DBService.SetItemAmount(item:getOwner(), item:getId(), item:getCount())
				return cb(item)
			else
				-- if item is degradation item
				-- if is the correct item with the same values increase amount
				if item:getPercentage() == data.percentage then
					item:addCount(amount, CustomInventoryInfos[invId].ignoreItemStackLimit)
					DBService.SetItemAmount(item:getOwner(), item:getId(), item:getCount())
					return cb(item)
				end
			end
			-- create new item
			return createItem()
		end
		-- error
		return cb(nil)
	end
	-- item does not exist in inventory, or metadata is different create new item
	return createItem()
end

function InventoryService.addWeapon(source, weaponId)
	local _source <const> = source
	local userWeapons <const> = UsersWeapons.default
	local weaponcomps = {}
	local result <const> = DBService.queryAwait('SELECT comps FROM loadout WHERE id = @id', { id = weaponId })
	if result[1] then
		weaponcomps = json.decode(result[1].comps)
	end

	local weaponname <const> = userWeapons[weaponId]:getName()
	local ammo <const> = { ["nothing"] = 0 }
	local components <const> = { ["nothing"] = 0 }
	InventoryAPI.registerWeapon(_source, weaponname, ammo, components, weaponcomps, nil, weaponId)
	InventoryAPI.deleteWeapon(_source, weaponId)
end

function InventoryService.subWeapon(source, weaponId)
	local _source <const> = source
	local user <const> = Core.getUser(_source)
	if not user then return false end

	local sourceCharacter <const> = user.getUsedCharacter
	local charId <const> = sourceCharacter.charIdentifier
	local userWeapons <const> = UsersWeapons.default

	if not weaponId or not userWeapons[weaponId] then return false end

	userWeapons[weaponId]:setPropietary('')
	local params <const> = { charId = charId, id = weaponId, }
	DBService.updateAsync('UPDATE loadout SET identifier = "", dropped = 1, charidentifier = @charId WHERE id = @id', params)
	return true
end

function InventoryService.onPickup(data)
	local _source <const> = source
	local uid <const> = data.uid
	local user <const> = Core.getUser(_source)
	local pickup <const> = ItemPickUps[uid]

	if not pickup or not user or SvUtils.InProcessing(_source) then
		return
	end

	SvUtils.ProcessUser(_source)

	local character <const> = user.getUsedCharacter
	local identifier <const> = character.identifier
	local charId <const> = character.charIdentifier
	local invCapacity <const> = character.invCapacity
	local job <const> = character.job
	local userInventory <const> = UsersInventories.default[identifier]


	if not userInventory then
		SvUtils.Trem(_source, false)
		return
	end

	-- is item
	if pickup.weaponid == 1 then
		local canCarryWeight <const> = InventoryAPI.canCarryAmountItem(_source, pickup.amount)
		local canCarryLimit <const> = InventoryAPI.canCarryItem(_source, pickup.name, pickup.amount)

		if not canCarryWeight or not canCarryLimit then
			Core.NotifyRightTip(_source, T.fullInventory, 2000)
			SvUtils.Trem(_source, false)
			return
		end
		local info <const> = { degradation = pickup.degradation, isPickup = true }
		InventoryService.addItem(_source, "default", pickup.name, pickup.amount, pickup.metadata, info, function(item)
			if item ~= nil and ItemPickUps[uid] then
				ItemPickUps[uid] = nil

				TriggerClientEvent("vorpInventory:sharePickupClient", -1, data, 2)
				TriggerClientEvent("vorpInventory:receiveItem", _source, pickup.name, item:getId(), pickup.amount, pickup.metadata, item.degradation, item.percentage)
				TriggerClientEvent("vorpInventory:playerAnim", _source, uid)

				local charname <const>, _, steamname <const> = getSourceInfo(_source)
				local title <const>                          = T.itempickup
				local description <const>                    = "**" .. T.WebHookLang.amount .. "** `" .. pickup.amount .. "`\n **" .. T.WebHookLang.item .. "** `" .. pickup.name .. "` \n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`"
				local info <const>                           = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.coloritempickup, }
				SvUtils.SendDiscordWebhook(info)
			end
		end)
	else
		-- weapons
		local notListed = false
		local totalInvWeight = 0
		local sourceInventoryWeaponCount = 0
		local DefaultAmount = Config.MaxItemsInInventory.Weapons
		local weaponId = ItemPickUps[uid].weaponid
		local userWeapons = UsersWeapons.default
		local weapon = userWeapons[weaponId]
		if weapon then
			local serialNumber = weapon:getSerialNumber()
			local weaponCustomDesc = weapon:getCustomDesc()

			if Config.JobsAllowed[job] then
				DefaultAmount = Config.JobsAllowed[job]
			end

			if DefaultAmount ~= 0 then
				local weaponName = weapon:getName()
				if weaponName and Config.notweapons[weaponName:upper()] then
					notListed = true
				end

				if not notListed then
					local itemsToTalWeight = InventoryAPI.getUserTotalCountItems(identifier, charId)
					local sourceInventoryWeaponWeight = InventoryAPI.getUserTotalCountWeapons(identifier, charId, true)
					totalInvWeight = (itemsToTalWeight + weapon:getWeight() + sourceInventoryWeaponWeight)
					sourceInventoryWeaponCount = InventoryAPI.getUserTotalCountWeapons(identifier, charId) + 1
				end

				if totalInvWeight <= invCapacity or sourceInventoryWeaponCount <= DefaultAmount then
					local weaponObj = ItemPickUps[uid].obj

					weapon:setDropped(0)
					local dataweapon = { obj = weaponObj }
					ItemPickUps[uid] = nil
					if weaponCustomDesc == nil then
						weaponCustomDesc = "Custom Description not set"
					end
					if serialNumber == nil then
						serialNumber = "Serial Number not set"
					end
					local charname, _, steamname = getSourceInfo(_source)
					local title = T.weppickup
					local description = "**" .. T.WebHookLang.Weapontype .. ":** `" .. weaponName .. "`\n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.serialnumber .. "** `" .. serialNumber .. "`\n **" .. T.WebHookLang.Desc .. "** `" .. weaponCustomDesc .. "` \n **" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`"
					local info = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorweppickupd }
					TriggerClientEvent("vorpInventory:sharePickupClient", -1, dataweapon, 2)
					TriggerClientEvent("vorpInventory:playerAnim", _source, uid)
					InventoryService.addWeapon(_source, weaponId)
					SvUtils.SendDiscordWebhook(info)
				end
			else
				Core.NotifyRightTip(_source, T.fullInventoryWeapon, 2000)
			end
		end
	end

	SvUtils.Trem(_source, false)
end

function InventoryService.onPickupMoney(data)
	local _source = source
	local charname, _, steamname = getSourceInfo(_source)

	data = MoneyPickUps[data.uuid]
	if not data then return end

	if not SvUtils.InProcessing(_source) then
		SvUtils.ProcessUser(_source)

		local moneyAmount = data.amount
		local title = T.WebHookLang.moneypickup
		local description = "**" .. T.WebHookLang.money .. ":** `" .. moneyAmount .. "` `$` \n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`\n"
		local info = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorDropGold }
		SvUtils.SendDiscordWebhook(info)

		TriggerClientEvent("vorpInventory:shareMoneyPickupClient", -1, data.obj, nil, nil, nil, 2)
		TriggerClientEvent("vorpInventory:playerAnim", _source, data.obj)
		local character = Core.getUser(_source).getUsedCharacter
		character.addCurrency(0, data.amount)
		MoneyPickUps[data.uuid] = nil

		SvUtils.Trem(_source, false)
	end
end

function InventoryService.onPickupGold(data)
	local _source = source
	data = GoldPickUps[data.uuid]
	if not data then return end

	if not SvUtils.InProcessing(_source) then
		SvUtils.ProcessUser(_source)

		local goldAmount = data.amount
		TriggerClientEvent("vorpInventory:shareGoldPickupClient", -1, data.obj, goldAmount, data.coords, data.uuid, 2)
		TriggerClientEvent("vorpInventory:playerAnim", _source, data.obj)

		local character = Core.getUser(_source).getUsedCharacter
		local charname, _, steamname = getSourceInfo(_source)
		local title = T.WebHookLang.pickedgold
		local description = "**" .. T.WebHookLang.gold .. ":** `" .. data.amount .. "` \n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`\n"
		local info = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorpickedgold }
		character.addCurrency(1, goldAmount)
		SvUtils.SendDiscordWebhook(info)
		GoldPickUps[data.uuid] = nil
		SvUtils.Trem(_source, false)
	end
end

local function shareData(data)
	local uid = SvUtils.GenerateUniqueID()

	ItemPickUps[uid] = {
		name = data.name,
		obj = data.obj,
		amount = data.amount,
		metadata = data.metadata,
		weaponid = data.weaponId,
		coords = data.position,
		id = data.id,
		degradation = data.degradation,
	}
	data.uid = uid
	TriggerClientEvent("vorpInventory:sharePickupClient", -1, data, 1)

	if not Config.DeletePickups.Enable then
		return
	end

	SetTimeout(Config.DeletePickups.Time * 60000, function()
		if ItemPickUps[uid] then
			TriggerClientEvent("vorpInventory:sharePickupClient", -1, data, 2)
			ItemPickUps[uid] = nil
		end
	end)
end


function InventoryService.sharePickupServerWeapon(data)
	local _source = source
	local weapon = UsersWeapons.default[data.weaponId]

	if not weapon then
		return
	end

	local result = InventoryService.subWeapon(_source, data.weaponId)
	if not result then
		return
	end

	local wepname = weapon:getName()
	local serialNumber = weapon:getSerialNumber()
	local desc = weapon:getCustomDesc()
	local charname, _, steamname = getSourceInfo(_source)
	local title = T.WebHookLang.dropedwep
	if not desc or desc == "" then
		desc = "Custom Description not set"
	end
	if not serialNumber or serialNumber == "" then
		serialNumber = "Serial Number not set"
	end
	local description = "**" .. T.WebHookLang.Weapontype .. ":** `" .. wepname .. "`\n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.serialnumber .. "** ` " .. serialNumber .. " ` \n **" .. T.WebHookLang.Desc .. "** `" .. desc .. "` \n **" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`"
	local info = {
		source = _source,
		name = Logs.WebHook.webhookname,
		title = title,
		description = description,
		webhook = Logs.WebHook.webhook,
		color = Logs.WebHook.colordropedwep,
	}
	SvUtils.SendDiscordWebhook(info)
	UsersWeapons.default[data.weaponId]:setDropped(1)
	data.type = "item_weapon"
	shareData(data)
end

function InventoryService.sharePickupServerItem(data)
	local _source = source
	local user = Core.getUser(_source)
	if not user then return end

	local Character = user.getUsedCharacter
	local sourceInventory = UsersInventories.default[Character.identifier]
	local item = sourceInventory[data.id]

	if not item and data.weaponId == 1 then return end

	if data.amount > item:getCount() then return end

	local result = InventoryService.subItem(_source, "default", data.id, data.amount)
	if not result then return end

	local charname, _, steamname = getSourceInfo(_source)
	local title = T.WebHookLang.itemDrop
	local description = "**" .. T.WebHookLang.amount .. "** `" .. data.amount .. "`\n **" .. T.WebHookLang.itemDrop .. "**: `" .. data.name .. "`" .. "\n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "`"
	local info = {
		source = _source,
		name = Logs.WebHook.webhookname,
		title = title,
		description = description,
		webhook = Logs.WebHook.webhook,
		color = Logs.WebHook.coloritemDrop,
	}

	SvUtils.SendDiscordWebhook(info)
	data.type = "item_standard"
	shareData(data)
end

function InventoryService.shareMoneyPickupServer(data)
	local _source = source
	local user = Core.getUser(_source)
	if not user then return end

	local Character = user.getUsedCharacter
	local amount = data.amount
	local position = data.position
	local handle = data.handle
	local money = Character.money

	if amount > money then return end

	Character.removeCurrency(0, amount)
	local uid = SvUtils.GenerateUniqueID()
	TriggerClientEvent("vorpInventory:shareMoneyPickupClient", -1, handle, amount, position, uid, 1)

	MoneyPickUps[uid] = {
		name = T.inventorymoneylabel,
		obj = handle,
		amount = amount,
		coords = position,
		uuid = uid
	}

	if not Config.DeletePickups.Enable then
		return
	end

	SetTimeout(Config.DeletePickups.Time * 60000, function()
		if MoneyPickUps[uid] then
			TriggerClientEvent("vorpInventory:shareMoneyPickupClient", -1, MoneyPickUps[uid].obj, nil, nil, nil, 2)
			MoneyPickUps[uid] = nil
		end
	end)
end

function InventoryService.shareGoldPickupServer(data)
	local _source = source
	local user = Core.getUser(_source)
	if not user then return end

	local Character = user.getUsedCharacter
	local gold = Character.gold
	if data.amount > gold then return end

	Character.removeCurrency(1, data.amount)
	local uid = SvUtils.GenerateUniqueID()
	TriggerClientEvent("vorpInventory:shareGoldPickupClient", -1, data.handle, data.amount, data.position, uid, 1)

	GoldPickUps[uid] = {
		name = T.inventorygoldlabel,
		obj = data.handle,
		amount = data.amount,
		inRange = false,
		coords = data.position,
		uuid = uid
	}

	if not Config.DeletePickups.Enable then
		return
	end

	SetTimeout(Config.DeletePickups.Time * 60000, function()
		if GoldPickUps[uid] then
			TriggerClientEvent("vorpInventory:shareGoldPickupClient", -1, GoldPickUps[uid].obj, nil, nil, nil, 2)
			GoldPickUps[uid] = nil
		end
	end)
end

function InventoryService.DropWeapon(weaponId)
	local _source = source
	if not SvUtils.InProcessing(_source) then
		SvUtils.ProcessUser(_source)
		local userWeapons = UsersWeapons.default
		local weapon = userWeapons[weaponId]
		if not weapon then return SvUtils.Trem(_source) end

		local wepName = weapon:getName()
		if not Config.DeleteOnlyDontDrop then
			TriggerClientEvent("vorpInventory:createPickup", _source, wepName, 1, {}, weaponId)
		else
			InventoryService.subWeapon(_source, weaponId)
		end
		SvUtils.Trem(_source)
	end
end

function InventoryService.DropItem(itemName, itemId, amount, metadata, degradation)
	local _source <const> = source

	local doesExist <const> = SvUtils.DoesItemExist(itemName, "InventoryService.DropItem")
	if not doesExist then return end

	local user <const> = Core.getUser(_source)
	if not user then return end

	local character <const> = user.getUsedCharacter
	local sourceInventory <const> = UsersInventories.default[character.identifier]
	if not sourceInventory then return end

	local item <const> = sourceInventory[itemId]
	if not item then return end

	if item:getCount() < amount then return end

	if SvUtils.InProcessing(_source) then return end
	SvUtils.ProcessUser(_source)

	if not Config.DeleteOnlyDontDrop then
		TriggerClientEvent("vorpInventory:createPickup", _source, itemName, amount, metadata, 1, itemId, degradation)
	else
		InventoryAPI.subItemID(_source, itemId, nil, false, amount)
	end
	SvUtils.Trem(_source)
end

function InventoryService.GiveWeapon(weaponId, target)
	local _source = source
	local sourceCharacter = Core.getUser(_source).getUsedCharacter
	local charid = sourceCharacter.charIdentifier

	if not InventoryService.CheckNewPlayer(_source, charid) then
		TriggerClientEvent("vorp_inventory:transactionCompleted", _source)
		return
	end

	if not SvUtils.InProcessing(_source) then
		TriggerClientEvent("vorp_inventory:transactionStarted", _source)
		SvUtils.ProcessUser(_source)

		if UsersWeapons.default[weaponId] ~= nil then
			InventoryService.giveWeapon2(target, weaponId, _source)
		end
		TriggerClientEvent("vorp_inventory:transactionCompleted", _source)
		SvUtils.Trem(_source)
	end
end

function InventoryService.giveWeapon2(player, weaponId, target)
	local _source = player
	local sourceCharacter = Core.getUser(_source).getUsedCharacter
	local sourceIdentifier = sourceCharacter.identifier
	local sourceCharId = sourceCharacter.charIdentifier
	local invCapacity = sourceCharacter.invCapacity
	local job = sourceCharacter.job
	local _target = target
	local userWeapons = UsersWeapons.default
	local DefaultAmount = Config.MaxItemsInInventory.Weapons
	local weaponName = userWeapons[weaponId]:getName()
	local serialNumber = userWeapons[weaponId]:getSerialNumber()
	local desc = userWeapons[weaponId]:getCustomDesc()
	local newWeight = userWeapons[weaponId]:getWeight()
	local charname, _, steamname = getSourceInfo(_source)
	local charname2, _, steamname2 = getSourceInfo(_target)
	local notListed = false

	if not desc then
		desc = userWeapons[weaponId]:getDesc()
	end

	if Config.JobsAllowed[job] then
		DefaultAmount = Config.JobsAllowed[job]
	end

	if DefaultAmount ~= 0 then
		if weaponName and Config.notweapons[weaponName:upper()] then
			notListed = true
		end

		if not notListed then
			local sourceTotalWeaponCount = InventoryAPI.getUserTotalCountWeapons(sourceIdentifier, sourceCharId) + 1
			if sourceTotalWeaponCount > DefaultAmount then
				Core.NotifyRightTip(_source, T.cantweapons, 2000)
				return
			end
		end
	end

	local function canCarryWeapons()
		local itemsTotalWeight = InventoryAPI.getUserTotalCountItems(sourceIdentifier, sourceCharId)
		local sourceTotalWeaponsWeight = InventoryAPI.getUserTotalCountWeapons(sourceIdentifier, sourceCharId, true)
		local totalInvWeight = itemsTotalWeight + sourceTotalWeaponsWeight + newWeight
		if totalInvWeight > invCapacity then
			return false
		end
		return true
	end

	if not canCarryWeapons() then
		return Core.NotifyRightTip(_source, T.cancarryWeapons, 2000)
	end


	local weaponcomps = {}
	local query = 'SELECT comps FROM loadout WHERE id = @id'
	local params = { id = weaponId }
	local result = DBService.singleAwait(query, params)
	if result then
		weaponcomps = json.decode(result.comps)
	end

	userWeapons[weaponId]:setPropietary('')
	local ammo = { ["nothing"] = 0 }
	local components = { ["nothing"] = 0 }
	InventoryAPI.registerWeapon(_source, weaponName, ammo, components, weaponcomps, nil, weaponId)
	InventoryAPI.deleteWeapon(_source, weaponId)
	TriggerClientEvent("vorpinventory:updateinventory", _target)
	TriggerClientEvent("vorpinventory:updateinventory", _source)
	TriggerClientEvent("vorpCoreClient:subWeapon", _target, weaponId)


	if not serialNumber or serialNumber == "" then
		serialNumber = T.NoSerial
	end
	local title = T.WebHookLang.gavewep
	local description = "**" .. T.WebHookLang.charname .. ":** `" .. charname2 .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname2 .. "` \n**" .. T.WebHookLang.give .. "**  **" .. 1 .. "** \n**" .. T.WebHookLang.Weapontype .. ":** `" .. weaponName .. "` \n**" .. T.WebHookLang.Desc .. "** `" .. (desc or "") .. "`\n **" .. T.WebHookLang.serialnumber .. "** `" .. serialNumber .. "`\n **" .. T.to .. ":** ` " .. charname .. "` \n**" .. T.WebHookLang.Steamname .. "** ` " .. steamname .. "` "
	local info = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorgiveWep }
	SvUtils.SendDiscordWebhook(info)
	-- notify
	Core.NotifyRightTip(_target, T.youGaveWeapon, 2000)
	Core.NotifyRightTip(_source, T.youReceivedWeapon, 2000)
end

function InventoryService.GiveItem(itemId, amount, target)
	local _source = source
	local _target = target
	local user = Core.getUser(_source)
	local user1 = Core.getUser(_target)

	if not user or not user1 then return end

	local character = user.getUsedCharacter
	local targetCharacter = user1.getUsedCharacter
	local charid = character.charIdentifier
	local targetCharId = targetCharacter.charIdentifier
	local sourceInventory = UsersInventories.default[character.identifier]
	local targetInventory = UsersInventories.default[targetCharacter.identifier]

	if not InventoryService.CheckNewPlayer(_source, charid) or not sourceInventory or not targetInventory or not sourceInventory[itemId] then
		return
	end

	if SvUtils.InProcessing(_source) then
		return
	end

	TriggerClientEvent("vorp_inventory:transactionStarted", _source)
	SvUtils.ProcessUser(_source)

	local item = sourceInventory[itemId]
	local itemName = item:getName()
	local svItem = ServerItems[itemName]
	if not svItem or not item then
		return
	end
	-- does source ave this amount of items ?
	if item:getCount() < amount then
		return print("tried to give more than you have possible cheat")
	end

	local charname, _, steamname = getSourceInfo(_source)
	local charname2, _, steamname2 = getSourceInfo(_target)
	local title = T.gaveitem
	local description = "**" .. T.WebHookLang.amount .. "**: `" .. amount .. "`\n **" .. T.WebHookLang.item .. "** : `" .. itemName .. "`" .. "\n**" .. T.WebHookLang.charname .. ":** `" .. charname .. "` \n**" .. T.WebHookLang.Steamname .. "** `" .. steamname .. "` \n**" .. T.to .. "** `" .. charname2 .. "`\n**" .. T.WebHookLang.Steamname .. "** `" .. steamname2 .. "` \n"
	local info = { source = _source, name = Logs.WebHook.webhookname, title = title, description = description, webhook = Logs.WebHook.webhook, color = Logs.WebHook.colorgiveitem }


	local function updateClient(addedItem)
		TriggerClientEvent("vorpInventory:receiveItem", _target, itemName, addedItem:getId(), amount, item:getMetadata(), item:getDegradation(), item:getPercentage())
		TriggerClientEvent("vorpInventory:removeItem", _source, itemName, item:getId(), amount)
		local data = { name = itemName, count = amount }
		TriggerEvent("vorp_inventory:Server:OnItemRemoved", data, _source)
		if item:getCount() - amount <= 0 then
			DBService.DeleteItem(charid, item:getId())
			sourceInventory[item:getId()] = nil
		else
			item:quitCount(amount)
			DBService.SetItemAmount(charid, item:getId(), item:getCount())
		end
		local label = svItem:getMetadata()?.label or svItem:getLabel()
		Core.NotifyRightTip(_source, T.yougive .. amount .. T.of .. label, 2000)
		Core.NotifyRightTip(_target, T.youreceive .. amount .. T.of .. label, 2000)
	end

	local canCarryItems = InventoryAPI.canCarryAmountItem(_target, amount)
	local canCarryItem = InventoryAPI.canCarryItem(_target, itemName, amount)

	if not canCarryItems or not canCarryItem then
		Core.NotifyRightTip(_source, T.fullInventoryGive, 2000)
		TriggerClientEvent("vorp_inventory:transactionCompleted", _source)
		SvUtils.Trem(_source)
		return
	end

	local function createItem()
		local isExpired = svItem:getMaxDegradation() ~= 0 and item:getDegradation() or nil
		DBService.CreateItem(targetCharId, svItem:getId(), amount, item:getMetadata(), itemName, isExpired, function(craftedItem)
			local targetItem = Item:New({
				id = craftedItem.id,
				count = amount,
				limit = svItem:getLimit(),
				label = svItem:getLabel(),
				name = itemName,
				type = "item_inventory",
				metadata = item:getMetadata(),
				canUse = svItem:getCanUse(),
				canRemove = svItem:getCanRemove(),
				owner = targetCharId,
				desc = svItem:getDesc(),
				group = svItem:getGroup(),
				weight = svItem:getWeight(),
				degradation = item:getDegradation(),
				percentage = item:getPercentage(),
				maxDegradation = svItem:getMaxDegradation()
			})

			targetInventory[craftedItem.id] = targetItem

			updateClient(targetItem)
			local data = { name = targetItem:getName(), count = amount, metadata = targetItem:getMetadata() }
			TriggerEvent("vorp_inventory:Server:OnItemCreated", data, _target)
		end)
	end

	local targetItem = SvUtils.FindItemByNameAndMetadata("default", targetCharacter.identifier, itemName, item:getMetadata())
	if targetItem then
		if svItem:getMaxDegradation() == 0 then
			targetItem:addCount(amount)
			DBService.SetItemAmount(targetCharId, targetItem:getId(), targetItem:getCount())
			updateClient(targetItem)
		else
			-- needs check hereif they match
			if targetItem:getPercentage() == item:getPercentage() and targetItem:getDegradation() == item:getDegradation() then
				targetItem:addCount(amount)
				DBService.SetItemAmount(targetCharId, targetItem:getId(), targetItem:getCount())
				updateClient(targetItem)
			else
				createItem()
			end
		end
	else
		createItem()
	end
	SvUtils.SendDiscordWebhook(info)
	TriggerClientEvent("vorp_inventory:transactionCompleted", _source)
	SvUtils.Trem(_source)
end

function InventoryService.getItemsTable()
	local _source = source

	if ServerItems then
		local data = msgpack.pack(ServerItems)
		TriggerClientEvent("vorpInventory:giveItemsTable", _source, data)
	end
end

function IsItemExpired(degradation, maxDegradation)
	if not degradation or degradation <= 0 then
		return true
	end

	local maxDegradeSeconds = maxDegradation * 60
	local elapsedSeconds = os.time() - degradation

	return elapsedSeconds >= maxDegradeSeconds
end

--Initialize main inventory on character Selection
function InventoryService.getInventory()
	local _source = source
	local sourceCharacter = Core.getUser(_source)
	if not sourceCharacter then return end

	sourceCharacter = sourceCharacter.getUsedCharacter
	local sourceIdentifier = sourceCharacter.identifier
	local sourceCharId = sourceCharacter.charIdentifier

	local characterInventory = {}

	if sourceCharId ~= nil then
		DBService.GetInventory(sourceCharId, "default", function(inventory)
			for _, item in pairs(inventory) do
				local dbItem = ServerItems[item.item]
				if dbItem then
					local metadata = SharedUtils.MergeTables(dbItem.metadata, item.metadata)

					if dbItem.maxDegradation ~= 0 then
						if item.degradation == nil then
							-- existing items with no degradation
							item.degradation = os.time()
							item.percentage = 100
						else
							-- existing items with degradation
							if item.degradation > 0 then
								local isExpired = IsItemExpired(item.degradation, dbItem.maxDegradation)
								if isExpired then
									item.degradation = 0
									item.percentage = 0
								else
									local elapsedTime = os.time() - item.degradation
									item.degradation = os.time() - elapsedTime
									item.percentage = dbItem:getPercentage(dbItem.maxDegradation, item.degradation)
								end
							end
						end
						-- need to update
						DBService.queryAwait("UPDATE character_inventories SET degradation = @degradation, percentage = @percentage WHERE item_crafted_id = @itemId", { degradation = item.degradation, percentage = item.percentage, itemId = item.id })
					end

					local itemObj = Item:New({
						count = item.amount,
						id = item.id,
						limit = dbItem.limit,
						label = dbItem.label,
						metadata = metadata,
						name = dbItem.item,
						type = dbItem.type,
						canUse = dbItem.canUse,
						canRemove = dbItem.canRemove,
						createdAt = item.created_at,
						owner = sourceCharId,
						desc = dbItem.desc,
						group = dbItem.group,
						weight = dbItem.weight,
						degradation = item.degradation,
						maxDegradation = dbItem.maxDegradation,
						percentage = item.percentage
					})
					characterInventory[item.id] = itemObj
				end
			end
			UsersInventories.default[sourceIdentifier] = characterInventory
			local data = msgpack.pack(characterInventory)
			TriggerClientEvent("vorpInventory:giveInventory", _source, data)
		end)


		local userWeapons = {}
		for _, weapon in pairs(UsersWeapons.default) do
			if weapon.propietary == sourceIdentifier and weapon.charId == sourceCharId and weapon.currInv == "default" and weapon.dropped == 0 then
				userWeapons[#userWeapons + 1] = weapon
			end
		end
		TriggerClientEvent("vorpInventory:giveLoadout", _source, userWeapons)

		for id, _ in pairs(CustomInventoryInfos) do
			if UsersInventories[id][sourceIdentifier] then
				UsersInventories[id][sourceIdentifier] = nil
			end
		end
	end
end

Core.Callback.Register("vorpinventory:getammoinfo", function(source, cb)
	if not AmmoData[source] then
		return cb(false)
	end

	return cb(AmmoData[source])
end)

-- give ammo to player
function InventoryService.serverGiveAmmo(ammotype, amount, target, maxcount)
	local _source = source
	local player1ammo = AmmoData[_source].ammo[ammotype]
	local player2ammo = AmmoData[target].ammo[ammotype]

	if player2ammo == nil then
		AmmoData[target].ammo[ammotype] = 0
	end

	if player1ammo == nil or player2ammo == nil then
		TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
		return
	end

	if 0 > (player1ammo - amount) then
		Core.NotifyRightTip(_source, T.notenoughammo, 2000)
		TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
		return
	elseif (player2ammo + amount) > maxcount then
		Core.NotifyRightTip(_source, T.fullammoyou, 2000)
		Core.NotifyRightTip(target, T.fullammo, 2000)
		TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
		return
	end

	AmmoData[_source].ammo[ammotype] = AmmoData[_source].ammo[ammotype] - amount
	AmmoData[target].ammo[ammotype] = AmmoData[target].ammo[ammotype] + amount
	local charidentifier = AmmoData[_source].charidentifier
	local charidentifier2 = AmmoData[target].charidentifier

	local query = "UPDATE characters Set ammo=@ammo WHERE charidentifier=@charidentifier"
	local params = { charidentifier = charidentifier, ammo = json.encode(AmmoData[_source].ammo) }
	local params2 = { charidentifier = charidentifier2, ammo = json.encode(AmmoData[target].ammo) }
	DBService.updateAsync(query, params)
	DBService.updateAsync(query, params2)

	TriggerClientEvent("vorpinventory:updateuiammocount", _source, AmmoData[_source].ammo)
	TriggerClientEvent("vorpinventory:updateuiammocount", target, AmmoData[target].ammo)
	TriggerClientEvent("vorpinventory:setammotoped", _source, AmmoData[_source].ammo)
	TriggerClientEvent("vorpinventory:setammotoped", target, AmmoData[target].ammo)
	-- notify
	Core.NotifyRightTip(_source, T.transferedammo .. SharedData.AmmoLabels[ammotype] .. " : " .. amount, 2000)
	Core.NotifyRightTip(target, T.recammo .. SharedData.AmmoLabels[ammotype] .. " : " .. amount, 2000)
	TriggerClientEvent("vorp_inventory:ProcessingReady", _source)
	-- update players client side
	TriggerClientEvent("vorpinventory:recammo", _source, AmmoData[_source])
	TriggerClientEvent("vorpinventory:recammo", target, AmmoData[target])
end

function InventoryService.updateAmmo(ammoinfo)
	local _source = source
	local query = "UPDATE characters Set ammo=@ammo WHERE charidentifier=@charidentifier"
	local params = { charidentifier = ammoinfo.charidentifier, ammo = json.encode(ammoinfo.ammo) }
	DBService.updateAsync(query, params, function(result)
		if result and _source then
			AmmoData[_source] = ammoinfo
		end
	end)
end

function InventoryService.LoadAllAmmo()
	local _source = source
	local sourceCharacter = Core.getUser(_source).getUsedCharacter
	local charidentifier = sourceCharacter.charIdentifier
	local query = "SELECT ammo FROM characters WHERE charidentifier=@charidentifier"
	local params = { charidentifier = charidentifier }
	DBService.queryAsync(query, params, function(result)
		if result[1] and result[1].ammo then
			local ammo = json.decode(result[1].ammo)
			AmmoData[_source] = { charidentifier = charidentifier, ammo = ammo }
			if next(ammo) then
				for k, v in pairs(ammo) do
					local ammocount = tonumber(v)
					if ammocount and ammocount > 0 then
						TriggerClientEvent("vorpCoreClient:addBullets", _source, k, ammocount)
					end
				end
				-- update players client side
				TriggerClientEvent("vorpinventory:recammo", _source, AmmoData[_source])
			end
		end
	end)
end

function InventoryService.onNewCharacter(source)
	SetTimeout(5000, function()
		local player <const> = Core.getUser(source)
		if not player then return end

		for key, value in pairs(Config.startItems) do
			InventoryAPI.addItem(source, key, value, {})
		end

		for _, value in ipairs(Config.startWeapons) do
			InventoryAPI.registerWeapon(source, value, {}, {}, {})
		end

		if not Config.NewPlayers then return end

		local Character = player.getUsedCharacter
		local charid = Character.charIdentifier
		if newchar[charid] then return end

		newchar[charid] = source
		SetTimeout(timer * 60000, function()
			newchar[charid] = nil
		end)
	end)
end

function InventoryService.reloadInventory(player, id, type, source)
	local invData = CustomInventoryInfos[id]
	local sourceCharacter = Core.getUser(player).getUsedCharacter
	local sourceIdentifier = sourceCharacter.identifier
	local sourceCharIdentifier = sourceCharacter.charIdentifier
	type = type or "custom"
	local userInventory = {}
	local itemList = {}
	if type == "custom" then
		if invData:isShared() then
			userInventory = UsersInventories[id]
		else
			userInventory = UsersInventories[id][sourceIdentifier]
		end

		for weaponId, weapon in pairs(UsersWeapons[id]) do
			if invData:isShared() or weapon.charId == sourceCharIdentifier then
				itemList[#itemList + 1] = Item:New({
					id            = weaponId,
					count         = 1,
					name          = weapon.name,
					label         = weapon.name,
					limit         = 1,
					type          = "item_weapon",
					desc          = weapon.desc,
					group         = 5,
					serial_number = weapon.serial_number,
					custom_label  = weapon.custom_label,
					custom_desc   = weapon.custom_desc,
				})
			end
		end
	elseif type == "player" then
		userInventory = UsersInventories.default[sourceIdentifier]
		for weaponId, weapon in pairs(UsersWeapons.default) do
			if weapon.charId == sourceCharIdentifier and weapon:getPropietary() == sourceIdentifier then
				itemList[#itemList + 1] = Item:New({
					id            = weaponId,
					count         = 1,
					name          = weapon.name,
					label         = weapon.name,
					limit         = 1,
					type          = "item_weapon",
					desc          = weapon.desc,
					group         = 5,
					serial_number = weapon.serial_number,
					custom_label  = weapon.custom_label,
					custom_desc   = weapon.custom_desc,
					weight        = weapon.weight,
				})
			end
		end
	end

	for _, value in pairs(userInventory) do
		itemList[#itemList + 1] = value
	end

	local payload = {
		itemList = itemList,
		action = "setSecondInventoryItems",
		info = {
			target = player,
			source = source,
		},
	}

	local msgpack = msgpack.pack(payload)
	TriggerClientEvent("vorp_inventory:ReloadCustomInventory", source or player, false, msgpack)
end

--amount of custom inventories dont need weight check
function InventoryService.getInventoryTotalCount(identifier, charIdentifier, invId)
	invId = invId ~= nil and invId or "default"
	local userTotalItemCount = 0
	local userInventory = {}
	local userWeapons = UsersWeapons[invId]
	if CustomInventoryInfos[invId]:isShared() then
		userInventory = UsersInventories[invId]
	else
		userInventory = UsersInventories[invId][identifier]
	end

	for _, item in pairs(userInventory) do
		userTotalItemCount = userTotalItemCount + item:getCount()
	end
	for _, weapon in pairs(userWeapons) do
		if CustomInventoryInfos[invId]:isShared() or weapon.charId == charIdentifier then
			userTotalItemCount = userTotalItemCount + 1
		end
	end
	return userTotalItemCount
end

function InventoryService.canStoreWeapon(identifier, charIdentifier, invId, name, amount)
	local invData = CustomInventoryInfos[invId]
	if not invData then return false end


	if invData:getLimit() > 0 then
		local sourceInventoryItemCount = InventoryService.getInventoryTotalCount(identifier, charIdentifier, invId)
		sourceInventoryItemCount = sourceInventoryItemCount + amount
		if sourceInventoryItemCount > invData:getLimit() then
			return false, "Inventory limit reached"
		end
	end

	if invData:iswhitelistWeaponsEnabled() then
		if not invData:isWeaponInList(name) then
			return false, "Weapon not allowed"
		end

		local weapons = SvUtils.FindAllWeaponsByName(invId, name)
		local weaponCount = #weapons + amount
		if weaponCount > invData:getWeaponLimit(name) then
			return false, "Weapon limit reached"
		end
	end

	return true
end

function InventoryService.canStoreItem(identifier, charIdentifier, invId, name, amount, metadata)
	local invData = CustomInventoryInfos[invId]

	if invData:getLimit() > 0 then
		local sourceInventoryItemCount = InventoryService.getInventoryTotalCount(identifier, charIdentifier, invId)
		sourceInventoryItemCount = sourceInventoryItemCount + amount
		if sourceInventoryItemCount > invData:getLimit() then
			return false, "Inventory limit reached"
		end
	end

	if invData:iswhitelistItemsEnabled() then
		if not invData:isItemInList(name) then
			return false, "Item not allowed"
		end

		local items = SvUtils.FindAllItemsByName(invId, identifier, name)

		if #items > 0 then
			local itemCount = 0
			for _, item in pairs(items) do
				itemCount = itemCount + item:getCount()
			end
			local totalAmount = amount + itemCount

			if totalAmount > invData:getItemLimit(name) then
				return false, "Item limit reached"
			end
		else
			if amount > invData:getItemLimit(name) then
				return false, "Item limit reached"
			end
		end
	end

	if not invData:getIgnoreItemStack() then
		local item = SvUtils.FindItemByNameAndMetadata(invId, identifier, name, metadata)
		if not item then
			local svItem = ServerItems[name]
			if amount > svItem:getLimit() then
				return false, "Item limit reached"
			end
			return true
		end

		local totalCount = item:getCount() + amount -- count how many items there is in custom inv + what we want to allow
		if totalCount > item:getLimit() then  -- check if stack is full
			return false, "Item limit reached"
		end
	end

	return true, ""
end

--* CUSTOM INVENTORY *--

function InventoryService.DoesHavePermission(invId, jobPerm, charidPerm)
	if not CustomInventoryInfos[invId]:isPermEnabled() then
		return true
	end

	if not next(jobPerm.data) and not next(charidPerm.data) then
		return true
	end

	if next(jobPerm.data) then
		if jobPerm.data[jobPerm.job] and jobPerm.grade >= jobPerm.data[jobPerm.job] then
			return true
		end
	end

	if next(charidPerm.data) then
		if charidPerm.data[charidPerm.charid] then
			return true
		end
	end

	return false
end

function InventoryService.CheckIsBlackListed(invId, ItemName)
	if not CustomInventoryInfos[invId]:isBlackListEnabled() then
		return true
	end

	local ItemsTable = CustomInventoryInfos[invId]:getBlackList()

	if next(ItemsTable) then
		for item, _ in pairs(ItemsTable) do
			if item == ItemName then
				return false
			end
		end
	end
	return true
end

function InventoryService.DiscordLogs(inventory, itemName, amount, playerName, action)
	local title = Logs.WebHook.custitle
	local color = Logs.WebHook.cuscolor
	local logo = Logs.WebHook.cuslogo
	local footerlogo = Logs.WebHook.cusfooterlogo
	local avatar = Logs.WebHook.cusavatar
	local names = Logs.WebHook.cuswebhookname
	local webhook = CustomInventoryInfos[inventory]

	if webhook and inventory ~= "default" then
		local wh = webhook:getWebhook()
		webhook = (wh and wh ~= "") and wh or false
	end

	if action == "Move" then
		webhook = (type(webhook) == "string") and webhook or Logs.WebHook.CustomInventoryMoveTo
		local description = "**Player:**`" .. playerName .. "`\n **Moved to:** `" .. inventory .. "` \n**Weapon** `" .. itemName .. "`\n **Count:** `" .. amount .. "`"
		Core.AddWebhook(title, webhook, description, color, names, logo, footerlogo, avatar)
	end

	if action == "Take" then
		webhook = (type(webhook) == "string") and webhook or Logs.WebHook.CustomInventoryTakeFrom
		local description = "**Player:**`" .. playerName .. "`\n **Took from:** `" .. inventory .. "`\n **item** `" .. itemName .. "`\n **amount:** `" .. amount .. "`"
		Core.AddWebhook(title, webhook, description, color, names, logo, footerlogo, avatar)
	end
end

local function CanProceed(item, amount, sourceIdentifier, sourceName)
	if item.type == "item_weapon" then
		if not UsersWeapons.default[item.id] then
			print("Player: " .. sourceName .. " is trying to add weapons to a custom inventory that he does not have, possible Cheat!!")
			return false
		end
		local weaponCount = 0
		for _, weapon in pairs(UsersWeapons.default) do
			if weapon.name == item.name then
				weaponCount = weaponCount + 1
			end
		end
		if weaponCount < amount then
			print("Player: " .. sourceName .. " is trying to add ammount of weapons to a custom inventory that he does not have, possible Cheat!!")
			return false
		end
	else
		local inventory = UsersInventories.default[sourceIdentifier]
		if not inventory or not inventory[item.id] then
			print("Player: " .. sourceName .. " is trying to add items to a custom inventory that he does not have, possible Cheat!!")
			return false
		end

		if inventory[item.id]:getCount() < amount then
			print("Player: " .. sourceName .. " is trying to add ammount of items to a custom inventory that he does not have, possible Cheat!!")
			return false
		end
	end

	return true
end

function InventoryService.MoveToCustom(obj)
	local _source = source
	local data = json.decode(obj)
	local invId <const> = tostring(data.id)
	if not CustomInventoryInfos[invId] then return end

	local item = data.item
	local amount = tonumber(data.number)
	local sourceCharacter = Core.getUser(_source).getUsedCharacter
	local sourceIdentifier = sourceCharacter.identifier
	local sourceName = sourceCharacter.firstname .. ' ' .. sourceCharacter.lastname
	local job = sourceCharacter.job
	local grade = sourceCharacter.jobGrade
	local sourceCharIdentifier = sourceCharacter.charIdentifier
	local tableJobs, tableCharIds = CustomInventoryInfos[invId]:getPermissionMoveTo()
	local jobPerm = { data = tableJobs, job = job, grade = grade }
	local charidPerm = { data = tableCharIds, charid = sourceCharIdentifier }
	local CanMove = InventoryService.DoesHavePermission(invId, jobPerm, charidPerm)
	local IsBlackListed = InventoryService.CheckIsBlackListed(invId, string.lower(item.name)) -- lower so we can checkitems and weapons


	if not CanProceed(item, amount, sourceIdentifier, sourceName) then
		return
	end

	if not IsBlackListed then
		return Core.NotifyObjective(_source, T.itemBlackListed, 5000)
	end

	if not CanMove then
		return Core.NotifyObjective(_source, T.noPermissionStorage, 5000)
	end

	if SvUtils.InProcessing(_source) then
		return
	end
	SvUtils.ProcessUser(_source)

	if item.type == "item_weapon" then
		if not CustomInventoryInfos[invId]:doesAcceptWeapons() then
			SvUtils.Trem(_source)
			return Core.NotifyRightTip(_source, T.storageNoWeapons, 2000)
		end

		local canStore, message = InventoryService.canStoreWeapon(sourceIdentifier, sourceCharIdentifier, invId, item.name, amount)
		if not canStore then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, message, 2000)
		end

		local query = "UPDATE loadout SET identifier = '',curr_inv = @invId WHERE charidentifier = @charid AND id = @weaponId"
		local params = { invId = invId, charid = sourceCharIdentifier, weaponId = item.id }
		DBService.updateAsync(query, params)
		UsersWeapons.default[item.id]:setCurrInv(invId)
		UsersWeapons[invId][item.id] = UsersWeapons.default[item.id]
		UsersWeapons.default[item.id] = nil
		TriggerClientEvent("vorpCoreClient:subWeapon", _source, item.id)
		InventoryService.reloadInventory(_source, invId)
		InventoryService.DiscordLogs(invId, item.name, amount, sourceName, "Move")
		local text = T.movedToStorage

		if string.lower(item.name) == "weapon_revolver_lemat" then
			Icon = "weapon_revolver_doubleaction" -- theres no revolver lemat texture
		else
			Icon = item.name
		end
		Core.NotifyAvanced(_source, text, "inventory_items", Icon, "COLOR_PURE_WHITE", 4000)
		SvUtils.Trem(_source)
	else
		if item.count and amount and item.count < amount then
			SvUtils.Trem(_source)
			return print(T.itemExceedsLimit)
		end

		local result, message = InventoryService.canStoreItem(sourceIdentifier, sourceCharIdentifier, invId, item.name, amount, item.metadata)
		if not result then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, message, 2000)
		end


		local info = { degradation = item.degradation, isPickup = false }
		InventoryService.addItem(_source, invId, item.name, amount, item.metadata, info, function(itemAdded)
			if not itemAdded then
				SvUtils.Trem(_source)
				return print(T.cantAddItem)
			end
			local metadataLabel = item.metadata?.label or item.label
			InventoryService.subItem(_source, "default", item.id, amount)
			TriggerEvent("vorp_inventory:Server:OnItemMovedToCustomInventory", { id = item.id, name = item.name, amount = amount }, invId, _source)
			TriggerClientEvent("vorpInventory:removeItem", _source, item.name, item.id, amount)
			Core.NotifyRightTip(_source, T.movedToStorage .. " " .. amount .. " " .. metadataLabel, 2000)

			InventoryService.reloadInventory(_source, invId)
			InventoryService.DiscordLogs(invId, item.name, amount, sourceName, "Move")
			SvUtils.Trem(_source)
		end)
	end
end

function InventoryService.TakeFromCustom(obj)
	local _source = source

	local data = json.decode(obj)
	local invId <const> = tostring(data.id)
	if not CustomInventoryInfos[invId] then return end

	local item = data.item
	local amount = tonumber(data.number)
	local sourceCharacter = Core.getUser(_source).getUsedCharacter
	local sourceName = sourceCharacter.firstname .. ' ' .. sourceCharacter.lastname
	local sourceIdentifier = sourceCharacter.identifier
	local sourceCharIdentifier = sourceCharacter.charIdentifier
	local job = sourceCharacter.job
	local grade = sourceCharacter.jobGrade
	local tableJobs, tableCharIds = CustomInventoryInfos[invId]:getPermissionTakeFrom()
	local jobPerm = { data = tableJobs, job = job, grade = grade }
	local charidPerm = { data = tableCharIds, charid = sourceCharIdentifier }
	local CanMove = InventoryService.DoesHavePermission(invId, jobPerm, charidPerm)

	if not CanMove then
		return Core.NotifyObjective(_source, T.noPermissionTake, 5000)
	end

	if SvUtils.InProcessing(_source) then
		return
	end
	SvUtils.ProcessUser(_source)

	if item.type == "item_weapon" then
		local canCarryWeapon = InventoryAPI.canCarryAmountWeapons(_source, 1, nil, item.name)

		if not canCarryWeapon then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, T.fullInventory, 2000)
		end

		local query = "UPDATE loadout SET curr_inv = 'default', charidentifier = @charid, identifier = @identifier WHERE id = @weaponId"
		local params = { identifier = sourceIdentifier, weaponId = item.id, charid = sourceCharIdentifier }
		DBService.updateAsync(query, params)
		UsersWeapons[invId][item.id]:setCurrInv("default")
		UsersWeapons.default[item.id] = UsersWeapons[invId][item.id]
		UsersWeapons.default[item.id].propietary = sourceIdentifier
		UsersWeapons.default[item.id].charId = sourceCharIdentifier
		UsersWeapons[invId][item.id] = nil
		local weapon = UsersWeapons.default[item.id]
		local name = weapon:getName()
		local ammo = weapon:getAllAmmo()
		local label = weapon:getLabel()
		local serial = weapon:getSerialNumber()
		local custom = weapon:getCustomLabel()
		local customDesc = weapon:getCustomDesc()
		local weight = weapon:getWeight()

		TriggerClientEvent("vorpInventory:receiveWeapon", _source, item.id, sourceIdentifier, name, ammo, label, serial, custom, _source, customDesc, weight)
		InventoryService.reloadInventory(_source, invId)
		InventoryService.DiscordLogs(invId, item.name, amount, sourceName, "Take")
		local text = T.takenFromStorage

		if string.lower(item.name) == "weapon_revolver_lemat" then
			Icon = "weapon_revolver_doubleaction" -- theres no revolver lemat texture
		else
			Icon = item.name
		end

		Core.NotifyAvanced(_source, text, "inventory_items", Icon, "COLOR_PURE_WHITE", 4000)
		SvUtils.Trem(_source)
	else
		if item.count and amount > item.count then
			SvUtils.Trem(_source)
			return print(T.itemExceedsLimit)
		end

		local canCarryItem = InventoryAPI.canCarryItem(_source, item.name, amount)
		if not canCarryItem then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, T.cantCarryItemStack, 2000)
		end

		local info = { degradation = item.degradation, isPickup = false, percentage = item.percentage }
		InventoryService.addItem(_source, "default", item.name, amount, item.metadata, info, function(itemAdded)
			if not itemAdded then
				SvUtils.Trem(_source)
				return Core.NotifyObjective(_source, T.cantAddItem, 2000)
			end

			local result = InventoryService.subItem(_source, invId, item.id, amount)
			if not result then
				SvUtils.Trem(_source)
				return Core.NotifyObjective(_source, T.cantRemoveItem, 2000)
			end

			TriggerEvent("vorp_inventory:Server:OnItemTakenFromCustomInventory", { id = itemAdded:getId(), name = item.name, amount = amount }, invId, _source)
			TriggerClientEvent("vorpInventory:receiveItem", _source, item.name, itemAdded:getId(), amount, itemAdded:getMetadata(), itemAdded:getDegradation(), itemAdded:getPercentage())
			InventoryService.reloadInventory(_source, invId)
			InventoryService.DiscordLogs(invId, item.name, amount, sourceName, "Take")

			local metadataLabel = item.metadata?.label or item.label
			Core.NotifyRightTip(_source, T.takenFromStorage .. " " .. amount .. " " .. metadataLabel, 2000)
			SvUtils.Trem(_source)
		end)
	end
end

local function HandleLimits(item, amount, target, _source, messages)
	local label = item.type == "item_weapon" and "weapons" or "items"
	if PlayerItemsLimit[target] and PlayerItemsLimit[target][item.type] then
		if PlayerItemsLimit[target][item.type].limit >= amount then
			if PlayerItemsLimit[target][item.type].limit - amount <= 0 then
				Core.NotifyObjective(_source, T.limitWarning .. label .. ".", 2000)
				if PlayerItemsLimit[target][item.type].timeout and not CoolDownStarted[_source][item.type] then
					CoolDownStarted[_source][item.type] = os.time() + PlayerItemsLimit[target][item.type].timeout
				end
			end

			PlayerItemsLimit[target][item.type].limit = PlayerItemsLimit[target][item.type].limit - amount

			return true
		else
			Core.NotifyObjective(_source, messages[label], 2000)
			return false
		end
	elseif CoolDownStarted[_source] and CoolDownStarted[_source][item.type] and os.time() < CoolDownStarted[_source][item.type] then
		Core.NotifyObjective(_source, messages.cooldown .. label, 2000)
		return false
	else
		return true
	end
end

function InventoryService.MoveToPlayer(obj)
	local _source = source

	local data = json.decode(obj)
	local item = data.item
	local amount = tonumber(data.number)
	local sourceCharacter = Core.getUser(_source).getUsedCharacter
	local sourceName = sourceCharacter.firstname .. ' ' .. sourceCharacter.lastname
	local invId = "default"
	local target = data.info.target
	local messages = {
		weapons = T.weaponsLimitExceeded,
		items = T.itemsLimitExceeded,
		cooldown = T.cooldownMessage
	}

	if not CanProceed(item, amount, sourceCharacter.identifier, sourceName) then
		return
	end

	local IsBlackListed = PlayerBlackListedItems[string.lower(item.name)]

	if IsBlackListed then
		Core.NotifyObjective(_source, T.blackListedMessage, 5000)
		return
	end

	if not HandleLimits(item, amount, target, _source, messages) then
		return
	end

	if SvUtils.InProcessing(_source) then
		return
	end
	SvUtils.ProcessUser(_source)

	if item.type == "item_weapon" then
		InventoryAPI.canCarryAmountWeapons(target, 1, function(res)
			if res then
				InventoryAPI.giveWeapon(target, item.id, _source, function(result)
					if result then
						InventoryService.reloadInventory(target, "default", "player", _source)
						InventoryService.DiscordLogs("default", item.name, amount, sourceName, "Move")
					end
					SvUtils.Trem(_source)
				end)
			else
				SvUtils.Trem(_source)
				return Core.NotifyObjective(_source, T.cantweapons, 2000)
			end
		end, item.name)
	else
		if not item.count or not amount then
			SvUtils.Trem(_source)
			return
		end

		local res = InventoryAPI.canCarryItem(target, item.name, amount)
		if not res then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, T.cantCarryItemStack, 2000)
		end

		if amount > item.count then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, T.notEnoughItems, 2000)
		end

		InventoryAPI.addItem(target, item.name, amount, item.metadata, function(result)
			if result then
				InventoryAPI.subItem(_source, item.name, amount, item.metadata, function(result2)
					if result2 then
						SetTimeout(400, function()
							InventoryService.reloadInventory(target, "default", "player", _source)
							InventoryService.DiscordLogs(invId, item.name, amount, sourceName, "Move")
							local metadataLabel = item.metadata?.label or item.label
							Core.NotifyRightTip(_source, T.movedToPlayer .. amount .. " " .. metadataLabel, 2000)
							Core.NotifyRightTip(target, T.itemGivenToPlayer .. " " .. metadataLabel, 2000)
							SvUtils.Trem(_source)
						end)
					else
						SvUtils.Trem(_source)
					end
				end, true)
			else
				SvUtils.Trem(_source)
			end
		end, true, item.degradation)
	end
end

function InventoryService.TakeFromPlayer(obj)
	local _source = source
	local data = json.decode(obj)
	local item = data.item
	local amount = tonumber(data.number)
	local sourceCharacter = Core.getUser(_source).getUsedCharacter
	local sourceName = sourceCharacter.firstname .. ' ' .. sourceCharacter.lastname
	local invId = "default"
	local target = data.info.target
	local IsBlackListed = PlayerBlackListedItems[string.lower(item.name)]
	local messages = {
		weapons = T.weaponsLimitExceeded,
		items = T.itemsLimitExceeded,
		cooldown = T.cooldownMessage
	}

	if IsBlackListed then
		Core.NotifyObjective(_source, T.blackListedMessage, 5000)
		return
	end

	if not HandleLimits(item, amount, target, _source, messages) then
		return
	end

	if SvUtils.InProcessing(_source) then
		return
	end
	SvUtils.ProcessUser(_source)

	if item.type == "item_weapon" then
		InventoryAPI.canCarryAmountWeapons(_source, 1, function(res)
			if res then
				InventoryAPI.giveWeapon(_source, item.id, target, function(result)
					if result then
						InventoryService.reloadInventory(target, "default", "player", _source)
						InventoryService.DiscordLogs("default", item.name, amount, sourceName, "Take")
					end
					SvUtils.Trem(_source)
				end)
			else
				SvUtils.Trem(_source)
				Core.NotifyObjective(_source, T.cantweapons, 2000)
			end
		end, item.name)
	else
		local res = InventoryAPI.canCarryItem(_source, item.name, amount)
		if not res then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, T.cantCarryItemStack, 2000)
		end

		if amount > item.count then
			SvUtils.Trem(_source)
			return Core.NotifyObjective(_source, T.notEnoughItems, 2000)
		end

		InventoryAPI.addItem(_source, item.name, amount, item.metadata, function(result)
			if result then
				InventoryAPI.subItem(target, item.name, amount, item.metadata, function(result2)
					if result2 then
						InventoryService.reloadInventory(target, "default", "player", _source)
						InventoryService.DiscordLogs(invId, item.name, amount, sourceName, "Take")
						local metadataLabel = item.metadata?.label or item.label
						Core.NotifyRightTip(_source, T.takenFromPlayer .. " " .. amount .. " " .. metadataLabel, 2000)
						Core.NotifyRightTip(target, T.itemsTakenFromPlayer .. " " .. metadataLabel, 2000)
					end
					SvUtils.Trem(_source)
				end, true)
			else
				SvUtils.Trem(_source)
			end
		end, true, item.degradation)
	end
end

-- to update custom inv cache
local function updateItem(itemcrafted, value, item, charid, isExpired, id, identifier)
	local item_add <const> = Item:New({
		id = itemcrafted.id,
		count = value.amount,
		limit = item:getLimit(),
		label = item:getLabel(),
		metadata = SharedUtils.MergeTables(item.metadata, value.metadata or {}),
		name = value.name,
		type = "item_standard",
		canUse = item:getCanUse(),
		canRemove = item:getCanRemove(),
		owner = charid,
		desc = item:getDesc(),
		group = item:getGroup(),
		weight = item:getWeight(),
		maxDegradation = isExpired,
	})

	local isShared <const> = CustomInventoryInfos[id]:isShared()
	if isShared then
		local customInventory <const> = UsersInventories[id]
		if not customInventory then
			return print("shared inventory does not exist with id update item " .. id)
		end

		customInventory[itemcrafted.id] = item_add
	else
		if not identifier then
			return print("inventory is not shared and you didnt pass identifier")
		end

		local customInventory <const> = UsersInventories[id][identifier]
		if not customInventory then
			return print("non shared inventory does not exist for this identifier")
		end
		customInventory[itemcrafted.id] = item_add
	end
end

local function updateItemAmount(id, identifier, amount, itemcraftedid, metadata, name)
	local isShared <const> = CustomInventoryInfos[id]:isShared()
	if isShared then
		local customInventory <const> = UsersInventories[id]

		if not customInventory[itemcraftedid] then
			return print("item crafted id does not exist")
		end

		customInventory[itemcraftedid].count = customInventory[itemcraftedid].count + amount
		if metadata then
			customInventory[itemcraftedid].metadata = metadata
		end
	else
		local customInventory <const> = UsersInventories[id][identifier]

		if not customInventory[itemcraftedid] then
			return print("item crafted id does not exist 2")
		end

		customInventory[itemcraftedid].count = customInventory[itemcraftedid].count + amount
		if metadata then
			customInventory[itemcraftedid].metadata = metadata
		end
	end
	DBService.updateAsync("UPDATE character_inventories SET amount = amount + @amount WHERE item_name = @itemname AND inventory_type = @inventory_type", { amount = amount, itemname = name, inventory_type = id })
end

local function updateItemInCustomInventory(id, identifier, itemCraftedId, amount, metadata, value, item, charid, isExpired, name)
	local existingItem = nil

	local customInventory <const> = UsersInventories[id]
	if not customInventory then
		return print("shared inventory does not exist with id " .. id)
	end

	if CustomInventoryInfos[id]:isShared() then
		existingItem = UsersInventories[id][itemCraftedId]
	else
		if identifier then
			existingItem = UsersInventories[id][identifier] and UsersInventories[id][identifier][itemCraftedId]
		end
	end

	if existingItem then
		updateItemAmount(id, identifier, value.amount, itemCraftedId, metadata, name)
	else
		-- If the item doesn't exist in memory, we need to add it because we dont have a loader on server start, we miss some data in the database, like is shared and identifiers
		local result3 = DBService.queryAwait("SELECT metadata FROM items_crafted WHERE id = @id", { id = itemCraftedId })
		if result3[1] then
			local itemData = {
				name = value.name,
				amount = amount + value.amount,
				metadata = json.decode(result3[1].metadata) or {}
			}
			updateItem({ id = itemCraftedId }, itemData, item, charid, isExpired, id, identifier)
		end
	end
end

function InventoryService.addItemsToCustomInventory(id, items, charid, identifier)
	local newTable = {}
	local result <const> = DBService.queryAwait("SELECT inventory_type FROM character_inventories WHERE inventory_type = @id", { id = id })

	if not result[1] then
		for _, value in ipairs(items) do
			local item = ServerItems[value.name]
			if item and value.amount > 0 then
				local isExpired = item:getMaxDegradation() ~= 0 and item:getDegradation() or nil
				DBService.CreateItem(charid, item:getId(), value.amount, (value.metadata or {}), value.name, isExpired, function(itemcraftedid)
					updateItem(itemcraftedid, value, item, charid, isExpired, id, identifier)
				end, id)
			end
		end
	else
		for _, value in ipairs(items) do
			local item = ServerItems[value.name]
			if item and value.amount > 0 then
				local itemMetadata = value.metadata or {}
				local result1 = DBService.queryAwait("SELECT amount, item_crafted_id FROM character_inventories WHERE item_name =@itemname AND inventory_type = @inventory_type", { itemname = value.name, inventory_type = id })

				local isExpired = item:getMaxDegradation() ~= 0 and item:getDegradation() or nil
				if not result1[1] then
					DBService.CreateItem(charid, item:getId(), value.amount, itemMetadata, value.name, isExpired, function(itemcraftedid)
						updateItem(itemcraftedid, value, item, charid, isExpired, id, identifier)
					end, id)
				else
					local resulItems = {}
					for _, v in ipairs(result1) do -- if there is more than one apple we need to check which ones have metadata
						local result2 = DBService.queryAwait("SELECT metadata FROM items_crafted WHERE id =@id", { id = v.item_crafted_id })
						local hasMetadata = result2[1] and json.decode(result2[1].metadata) or {}
						if next(hasMetadata) then
							resulItems[#resulItems + 1] = v
						end
					end

					if #resulItems == 0 then
						if next(itemMetadata) then
							DBService.CreateItem(charid, item:getId(), value.amount, itemMetadata, value.name, isExpired, function(itemcraftedid)
								updateItem(itemcraftedid, value, item, charid, isExpired, id, identifier)
							end, id)
						else
							local itemCraftedId = result1[1].item_crafted_id
							updateItemInCustomInventory(id, identifier, itemCraftedId, value.amount, itemMetadata, value, item, charid, isExpired, value.name)
						end
					else
						for _, v in ipairs(resulItems) do
							local result2 = DBService.queryAwait("SELECT metadata FROM items_crafted WHERE id =@id", { id = v.item_crafted_id })
							local metadata = json.decode(result2[1].metadata)
							local result3 = SharedUtils.Table_equals(metadata, itemMetadata)
							if result3 then
								newTable[#newTable + 1] = v
							end
						end

						if #newTable == 0 then -- metadata of any of the items dont match new one so we create new one
							DBService.CreateItem(charid, item:getId(), value.amount, itemMetadata, value.name, isExpired, function(itemcraftedid)
								updateItem(itemcraftedid, value, item, charid, isExpired, id, identifier)
							end, id)
						else
							local itemCraftedId = result1[1].item_crafted_id
							updateItemInCustomInventory(id, identifier, itemCraftedId, value.amount, itemMetadata, value, item, charid, isExpired, value.name)
						end
					end
				end
			end
		end
	end
end

function InventoryService.addWeaponsToCustomInventory(id, weapons, charid)
	for _, value in ipairs(weapons) do
		local label = SvUtils.GenerateWeaponLabel(value.name)
		local serial_number = value.serial_number or SvUtils.GenerateSerialNumber(value.name)
		local custom_label = value.custom_label or SvUtils.GenerateWeaponLabel(value.name)
		local weight = SvUtils.GetWeaponWeight(value.name)
		local components = value.components and next(value.components) and value.components or {}
		local params = {
			curr_inv = id,
			charidentifier = charid,
			name = value.name,
			serial_number = serial_number,
			label = label,
			custom_label = custom_label,
			custom_desc = value.custom_desc or nil,
			comps = json.encode(components)
		}

		DBService.insertAsync("INSERT INTO loadout (identifier, curr_inv, charidentifier, name,serial_number,label,custom_label,custom_desc,comps) VALUES ('', @curr_inv, @charidentifier, @name, @serial_number, @label, @custom_label, @custom_desc, @comps)", params, function(result)
			local weaponId = result
			local newWeapon = Weapon:New({
				id = weaponId,
				propietary = "",
				name = value.name,
				ammo = {},
				comps = components,
				used = false,
				used2 = false,
				charId = charid,
				currInv = id,
				dropped = 0,
				source = 0,
				label = label,
				serial_number = serial_number,
				custom_label = label,
				custom_desc = value.custom_desc or nil,
				group = 5,
				weight = weight
			})
			if not UsersWeapons[id] then
				UsersWeapons[id] = {}
			end
			UsersWeapons[id][weaponId] = newWeapon
		end)
	end
end

--todo allow metadata to be passed
function InventoryService.removeItemFromCustomInventory(invId, item_name, amount, item_crafted_id)
	local query = "SELECT amount, item_crafted_id FROM character_inventories WHERE item_name = @itemname AND inventory_type = @inventory_type ORDER BY amount DESC"
	local arguments = { itemname = item_name, inventory_type = invId }

	if item_crafted_id then
		query = "SELECT amount, item_crafted_id FROM character_inventories WHERE item_crafted_id = @item_crafted_id AND inventory_type = @inventory_type ORDER BY amount DESC"
		arguments = { item_crafted_id = item_crafted_id, inventory_type = invId }
	end

	local result = DBService.queryAwait(query, arguments)
	if not result[1] then
		return false
	end

	local remainingAmount = amount
	local totalAvailable = 0

	for _, item in ipairs(result) do
		totalAvailable = totalAvailable + item.amount
	end

	if totalAvailable < amount then
		return false
	end

	for _, item in ipairs(result) do
		if remainingAmount <= 0 then
			break
		end

		local amountToRemove = math.min(remainingAmount, item.amount)

		if amountToRemove >= item.amount then
			DBService.queryAwait("DELETE FROM character_inventories WHERE item_crafted_id = @id AND inventory_type = @inventory_type", { id = item.item_crafted_id, inventory_type = invId })
			DBService.queryAwait("DELETE FROM items_crafted WHERE id = @id", { id = item.item_crafted_id })
		else
			DBService.queryAwait("UPDATE character_inventories SET amount = amount - @amount WHERE item_crafted_id = @id AND inventory_type = @inventory_type", { amount = amountToRemove, id = item.item_crafted_id, inventory_type = invId })
		end

		remainingAmount = remainingAmount - amountToRemove
	end
	return true
end

function InventoryService.removeWeaponFromCustomInventory(invId, weapon_name)
	local result = DBService.queryAwait("SELECT id FROM loadout WHERE curr_inv = @invId AND name = @name", { invId = invId, name = weapon_name })
	if not result[1] then
		return false
	end

	local weaponId = result[1].id
	DBService.updateAsync("DELETE FROM loadout WHERE id = @id", { id = weaponId })
	if UsersWeapons[invId] then
		UsersWeapons[invId][weaponId] = nil
	end
	return true
end

function InventoryService.getAllItemsFromCustomInventory(invId)
	local result = DBService.queryAwait("SELECT item_name, amount, item_crafted_id, percentage FROM character_inventories WHERE inventory_type = @inventory_type", { inventory_type = invId })
	local items = {}
	local itemsMap = {}
	for _, value in ipairs(result) do
		local item = ServerItems[value.item_name]
		if item then
			local itemMetadata = {}
			local result1 = DBService.queryAwait("SELECT metadata FROM items_crafted WHERE id =@id", { id = value.item_crafted_id })
			if result1[1] then
				itemMetadata = result1[1].metadata and json.decode(result1[1].metadata) or {}
			end

			if next(itemMetadata) then
				items[#items + 1] = {
					crafted_id = value.item_crafted_id,
					name = value.item_name,
					amount = value.amount,
					metadata = itemMetadata,
					percentage = value.percentage,
					charid = value.character_id,
					label = itemMetadata.label or item:getLabel(),
					desc = itemMetadata.description or item:getDesc(),
					weight = itemMetadata.weight or item:getWeight(),
				}
			else
				if itemsMap[value.item_name] then
					itemsMap[value.item_name].amount = itemsMap[value.item_name].amount + value.amount
				else
					itemsMap[value.item_name] = {
						crafted_id = value.item_crafted_id,
						name = value.item_name,
						amount = value.amount,
						metadata = itemMetadata,
						percentage = value.percentage,
						charid = value.character_id,
						label = itemMetadata.label or item:getLabel(),
						desc = itemMetadata.description or item:getDesc(),
						weight = itemMetadata.weight or item:getWeight(),
					}
					items[#items + 1] = itemsMap[value.item_name]
				end
			end
		end
	end
	return items
end

function InventoryService.getAllWeaponsFromCustomInventory(invId)
	local result = DBService.queryAwait("SELECT id, name, serial_number, label, custom_label, custom_desc FROM loadout WHERE curr_inv = @invId", { invId = invId })
	local weapons = {}
	for _, value in ipairs(result) do
		weapons[#weapons + 1] = {
			name = value.name,
			serial_number = value.serial_number or "",
			label = value.label,
			custom_label = value.custom_label or "",
			custom_desc = value.custom_desc or "",
			id = value.id
		}
	end
	return weapons
end

function InventoryService.removeWeaponsByIdFromCustomInventory(invId, weaponId)
	local result = DBService.queryAwait("SELECT id FROM loadout WHERE id = @id AND curr_inv = @invId", { id = weaponId, invId = invId })
	if not result[1] then
		return false
	end

	DBService.updateAsync("DELETE FROM loadout WHERE id = @id", { id = weaponId })
	if UsersWeapons[invId] then
		UsersWeapons[invId][weaponId] = nil
	end
	return true
end

function InventoryService.updateItemInCustomInventory(invId, item_crafted_id, metadata, amount, identifier)
	local result = DBService.queryAwait("SELECT amount FROM character_inventories WHERE item_crafted_id = @item_crafted_id AND inventory_type = @inventory_type", { item_crafted_id = item_crafted_id, inventory_type = invId })
	if not result[1] then
		return false
	end

	local item = result[1]
	local itemAmount = amount or item.amount
	if itemAmount <= 0 then
		return false
	end

	if metadata and type(metadata) == "table" then
		metadata = json.encode(metadata)
	end

	DBService.updateAsync("UPDATE character_inventories SET amount = @amount WHERE item_crafted_id = @item_crafted_id AND inventory_type = @inventory_type", { amount = itemAmount, item_crafted_id = item_crafted_id, inventory_type = invId })

	if metadata then
		DBService.updateAsync("UPDATE items_crafted SET metadata = @metadata WHERE id = @id", { metadata = metadata, id = item_crafted_id })
	end

	updateItemAmount(invId, nil, itemAmount, item_crafted_id, metadata)

	return true
end

function InventoryService.deleteCustomInventory(invId)
	local result = DBService.queryAwait("SELECT item_crafted_id FROM character_inventories WHERE inventory_type = @inventory_type", { inventory_type = invId })
	if not result[1] then
		return false
	end

	for _, value in ipairs(result) do
		DBService.updateAsync("DELETE FROM items_crafted WHERE id = @id", { id = value.item_crafted_id })
	end

	DBService.updateAsync("DELETE FROM character_inventories WHERE inventory_type = @inventory_type", { inventory_type = invId })
	DBService.updateAsync("DELETE FROM loadout WHERE curr_inv = @invId", { invId = invId })

	if UsersWeapons[invId] then
		UsersWeapons[invId] = nil
	end
end
