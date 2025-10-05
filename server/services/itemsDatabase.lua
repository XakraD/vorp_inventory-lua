local Core   = exports.vorp_core:GetCore()
ServerItems  = {}
UsersWeapons = { default = {} }

--- load all player weapons
---@param db_weapon table
local function loadAllWeapons(db_weapon)
	local ammo = json.decode(db_weapon.ammo)
	local comp = json.decode(db_weapon.components)

	if db_weapon.dropped == 0 then
		local label = db_weapon.custom_label or db_weapon.label
		local weight = SvUtils.GetWeaponWeight(db_weapon.name)
		local weapon = Weapon:New({
			id = db_weapon.id,
			propietary = db_weapon.identifier,
			name = db_weapon.name,
			ammo = ammo,
			components = comp,
			used = false,
			used2 = false,
			charId = db_weapon.charidentifier,
			currInv = db_weapon.curr_inv,
			dropped = db_weapon.dropped,
			group = 5,
			label = label,
			serial_number = db_weapon.serial_number,
			custom_label = db_weapon.custom_label,
			custom_desc = db_weapon.custom_desc,
			weight = weight,
		})

		if not UsersWeapons[db_weapon.curr_inv] then
			UsersWeapons[db_weapon.curr_inv] = {}
		end

		UsersWeapons[db_weapon.curr_inv][weapon:getId()] = weapon
	else
		DBService.deleteAsync('DELETE FROM loadout WHERE id = @id', { id = db_weapon.id }, function() end)
	end
end




--- load player default inventory weapons
---@param source number
---@param character table character table data
local function loadPlayerWeapons(source, character)
	local _source = source
	DBService.queryAsync('SELECT * FROM loadout WHERE charidentifier = ? ', { character.charIdentifier },
		function(result)
			if next(result) then
				for _, db_weapon in pairs(result) do
					if db_weapon.charidentifier and db_weapon.curr_inv == "default" then -- only load default inventory
						loadAllWeapons(db_weapon)
					end
				end
			end
		end)
end

-- convert json string to pure lua table
local function luaTable(value)
	if type(value) == "table" then
		local t = {}
		for k, v in pairs(value) do
			t[k] = luaTable(v)
		end
		return t
	else
		return value
	end
end


MySQL.ready(function()
	-- load all items from database
	DBService.queryAsync("SELECT * FROM items", {}, function(result)
		for _, db_item in pairs(result) do
			if db_item.id then
				local meta = {}
				if db_item.metadata ~= "{}" then
					meta = luaTable(json.decode(db_item.metadata))
				end
				local item = Item:New({
					id = db_item.id,
					item = db_item.item,
					metadata = meta,
					label = db_item.label,
					limit = db_item.limit,
					type = db_item.type,
					canUse = db_item.usable,
					canRemove = db_item.can_remove,
					desc = db_item.desc,
					group = db_item.groupId,
					weight = db_item.weight,
					maxDegradation = db_item.degradation,
					useExpired = db_item.useExpired == 0 and false or true,
				})
				ServerItems[item.item] = item
			end
		end
	end)

	--load all secondary inventory weapons from database
	DBService.queryAsync("SELECT * FROM loadout", {}, function(result)
		for _, db_weapon in pairs(result) do
			if db_weapon.curr_inv ~= "default" then
				loadAllWeapons(db_weapon)
			end
		end
	end)
end)

local function cacheImages()
	-- only items from the database because items folder can contain duplicates or unused images
	local newtable = {}
	for k, v in pairs(ServerItems) do
		newtable[k] = v.item
	end
	-- all weapon images from config because items folder can contain duplicates or unused images
	for k, _ in pairs(SharedData.Weapons) do
		newtable[k] = k
	end
	local packed = msgpack.pack(newtable)

	return packed
end

-- on player select character event
AddEventHandler("vorp:SelectedCharacter", function(source, char)
	loadPlayerWeapons(source, char)

	local packed = cacheImages()
	TriggerClientEvent("vorp_inventory:server:CacheImages", source, packed)
end)

-- reload on script restart for testing
if Config.DevMode then
	RegisterNetEvent("DEV:loadweapons", function()
		local _source = source
		local character = Core.getUser(_source).getUsedCharacter
		loadPlayerWeapons(_source, character)

		local packed = cacheImages()
		TriggerClientEvent("vorp_inventory:server:CacheImages", _source, packed)
	end)
end
