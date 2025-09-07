local PickupsService = {}
local T <const>      = TranslationInv.Langs[Lang]
local WorldPickups   = {}
local PickUpPrompt   = 0
local group <const>  = GetRandomIntInRange(0, 0xffffff)

function PickupsService.loadModel(model)
	if not IsModelValid(model) then return print(model, "not a valid model") end

	if not HasModelLoaded(model) then
		RequestModel(model, false)
		repeat Wait(0) until HasModelLoaded(model)
	end
end

function PickupsService.getUniqueId()
	local index = GetRandomIntInRange(0, 0xffffff)
	while WorldPickups[index] do
		index = GetRandomIntInRange(0, 0xffffff)
	end
	return index
end

local function createPrompt()
	PickUpPrompt = UiPromptRegisterBegin()
	UiPromptSetControlAction(PickUpPrompt, Config.PickupKey)
	UiPromptSetText(PickUpPrompt, VarString(10, "LITERAL_STRING", T.TakeFromFloor))
	UiPromptSetEnabled(PickUpPrompt, true)
	UiPromptSetVisible(PickUpPrompt, true)
	UiPromptSetHoldMode(PickUpPrompt, 1000)
	UiPromptSetGroup(PickUpPrompt, group, 0)
	UiPromptRegisterEnd(PickUpPrompt)
end

local function getRandomPositionAround(position, radius)
	local angle <const> = math.random() * 2 * math.pi -- Random angle in radians
	local dx = radius * math.cos(angle)
	local dy = radius * math.sin(angle)

	return vector3(position.x + dx, position.y + dy, position.z)
end


function PickupsService.CreateObject(objectHash, position, itemType)
	if itemType == "item_standard" then
		local model <const> = Config.spawnableProps[objectHash] or Config.spawnableProps.default_box
		PickupsService.loadModel(model)
		local entityHandle <const> = CreateObject(joaat(model), position.x, position.y, position.z - 1, false, false, false, false)
		repeat Wait(0) until DoesEntityExist(entityHandle)

		PlaceObjectOnGroundProperly(entityHandle, false)
		FreezeEntityPosition(entityHandle, true)
		SetPickupLight(entityHandle, true)
		SetEntityCollision(entityHandle, false, true)
		SetModelAsNoLongerNeeded(model)

		return entityHandle
	else
		if not SharedData.Weapons[objectHash] then
			return PickupsService.CreateObject("default_box", position, "item_standard")
		end

		if not Config.UseWeaponModels then
			return PickupsService.CreateObject("default_box", position, "item_standard")
		end

		Citizen.InvokeNative(0x72D4CB5DB927009C, joaat(objectHash), 1, true) -- request weapon asset
		repeat Wait(0) until Citizen.InvokeNative(0xFF07CF465F48B830, joaat(objectHash))
		local object <const> = CreateWeaponObject(joaat(objectHash), 0, position.x, position.y, position.z, true, 1.0)
		repeat Wait(0) until DoesEntityExist(object)
		PlaceObjectOnGroundProperly(object, true)
		SetPickupLight(object, true)
		SetEntityVisible(object, true)
		if Config.weaponAdjustments[objectHash] then
			SetEntityRotation(object, Config.weaponAdjustments[objectHash], 0.0, 0.0, 0, true)
		end

		SetEntityCollision(object, false, false)
		SetEntityInvincible(object, true)
		SetEntityProofs(object, 1, true)
		FreezeEntityPosition(object, true)

		return object
	end
end

function PickupsService.createPickup(name, amount, metadata, weaponId, id, degradation)
	local playerPed <const> = PlayerPedId()
	local coords <const>    = GetEntityCoords(playerPed, true, true)
	local forward <const>   = GetEntityForwardVector(playerPed)
	local position          = vector3(coords.x + forward.x * 1.6, coords.y + forward.y * 1.6, coords.z + forward.z * 1.6)
	position                = getRandomPositionAround(position, 1)
	local index <const>     = PickupsService.getUniqueId()
	local data <const>      = { name = name, obj = index, amount = amount, metadata = metadata, weaponId = weaponId, position = position, id = id, degradation = degradation }
	if weaponId == 1 then
		TriggerServerEvent("vorpinventory:sharePickupServerItem", data)
	else
		TriggerServerEvent("vorpinventory:sharePickupServerWeapon", data)
	end
	Wait(1000)
	if Config.SFX.ItemDrop then
		PlaySoundFrontend("show_info", "Study_Sounds", true, 0)
	end
end

RegisterNetEvent("vorpInventory:createPickup", PickupsService.createPickup)

function PickupsService.createMoneyPickup(amount)
	local playerPed <const> = PlayerPedId()
	local coords <const>    = GetEntityCoords(playerPed, true, true)
	local forward <const>   = GetEntityForwardVector(playerPed)
	local position          = vector3(coords.x + forward.x * 1.6, coords.y + forward.y * 1.6, coords.z + forward.z * 1.6)
	position                = getRandomPositionAround(position, 1)
	local handle <const>    = PickupsService.getUniqueId()
	local data <const>      = { handle = handle, amount = amount, position = position }
	TriggerServerEvent("vorpinventory:shareMoneyPickupServer", data)
	Wait(1000)
	if Config.SFX.MoneyDrop then
		PlaySoundFrontend("show_info", "Study_Sounds", true, 0)
	end
end

RegisterNetEvent("vorpInventory:createMoneyPickup", PickupsService.createMoneyPickup)

function PickupsService.createGoldPickup(amount)
	if not Config.UseGoldItem then return end

	local playerPed <const> = PlayerPedId()
	local coords <const>    = GetEntityCoords(playerPed, true, true)
	local forward <const>   = GetEntityForwardVector(playerPed)
	local position          = vector3(coords.x + forward.x * 1.6, coords.y + forward.y * 1.6, coords.z + forward.z * 1.6)
	position                = getRandomPositionAround(position, 1)
	local handle <const>    = PickupsService.getUniqueId()
	local data <const>      = { handle = handle, amount = amount, position = position }
	TriggerServerEvent("vorpinventory:shareGoldPickupServer", data)
	Wait(1000)
	if Config.SFX.GoldDrop then
		PlaySoundFrontend("show_info", "Study_Sounds", true, 0)
	end
end

RegisterNetEvent("vorpInventory:createGoldPickup", PickupsService.createGoldPickup)

function PickupsService.sharePickupClient(data, value)
	if value == 1 then
		if WorldPickups[data.obj] then return end
		local id = 1

		if data.type == "item_standard" then
			local item <const> = UserInventory[data.id]
			if item then
				item:quitCount(data.amount)
				if item:getCount() == 0 then
					UserInventory[data.id] = nil
				end
			end
			id = 2
		end

		local label <const> = Utils.GetLabel(data.name, id, data.metadata)
		if not label then
			print(("label not found for %s %s"):format(data.name, id))
		end
		local pickup <const> = {
			label    = (label or data.name) .. " x " .. tostring(data.amount),
			entityId = 0,
			coords   = data.position,
			uid      = data.uid,
			type     = data.type,
			name     = data.name,
		}
		WorldPickups[data.obj] = pickup

		NUIService.LoadInv()
	else
		local pickup <const> = WorldPickups[data.obj]
		if pickup then
			if pickup.entityId and DoesEntityExist(pickup.entityId) then
				DeleteEntity(pickup.entityId)
			end
			WorldPickups[data.obj] = nil
		end
	end
end

RegisterNetEvent("vorpInventory:sharePickupClient", PickupsService.sharePickupClient)

function PickupsService.shareMoneyPickupClient(handle, amount, position, uuid, value)
	if value == 1 then
		if WorldPickups[handle] == nil then
			local pickup <const> = {
				label = T.money .. tostring(amount) .. ")",
				entityId = 0,
				amount = amount,
				isMoney = true,
				isGold = false,
				coords = position,
				uuid = uuid,
				type = "item_standard",
				name = "money_bag"
			}
			WorldPickups[handle] = pickup
		end
	else
		local pickup <const> = WorldPickups[handle]
		if pickup then
			if pickup.entityId and DoesEntityExist(pickup.entityId) then
				DeleteEntity(pickup.entityId)
			end

			WorldPickups[handle] = nil
		end
	end
end

RegisterNetEvent("vorpInventory:shareMoneyPickupClient", PickupsService.shareMoneyPickupClient)

function PickupsService.shareGoldPickupClient(handle, amount, position, uuid, value)
	if value == 1 then
		if not WorldPickups[handle] then
			local pickup <const> = {
				label = T.gold .. " (" .. tostring(amount) .. ")",
				entityId = 0,
				amount = amount,
				isMoney = false,
				isGold = true,
				coords = position,
				uuid = uuid,
				type = "item_standard",
				name = "gold_bag"
			}

			WorldPickups[handle] = pickup
		end
	else
		local pickup <const> = WorldPickups[handle]
		if pickup then
			if pickup.entityId and DoesEntityExist(pickup.entityId) then
				DeleteEntity(pickup.entityId)
			end

			WorldPickups[handle] = nil
		end
	end
end

RegisterNetEvent("vorpInventory:shareGoldPickupClient", PickupsService.shareGoldPickupClient)


function PickupsService.playerAnim()
	local playerPed <const> = PlayerPedId()
	local animDict <const> = "amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop"
	if not HasAnimDictLoaded(animDict) then
		RequestAnimDict(animDict)
		repeat Wait(0) until HasAnimDictLoaded(animDict)
	end

	TaskPlayAnim(playerPed, animDict, "exit_front", 1.0, 8.0, -1, 1, 0, false, false, false)
	Wait(1200)
	if Config.SFX.PickUp then
		PlaySoundFrontend("CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true, 1)
	end
	Wait(1000)
	ClearPedTasks(playerPed, true, true)
end

RegisterNetEvent("vorpInventory:playerAnim", PickupsService.playerAnim)


CreateThread(function()
	local function isAnyPlayerNear()
		local playerPed <const>    = PlayerPedId()
		local playerCoords <const> = GetEntityCoords(playerPed, true, true)
		local players <const>      = GetActivePlayers()
		local count                = 0
		for _, player in ipairs(players) do
			local targetPed = GetPlayerPed(player)
			if player ~= PlayerId() then
				local targetCoords <const> = GetEntityCoords(targetPed, true, true)
				local distance <const> = #(playerCoords - targetCoords)
				if distance < 2.0 then
					count = count + 1
				end
			end
		end

		return count
	end

	repeat Wait(2000) until LocalPlayer.state.IsInSession
	createPrompt()
	local pressed = false
	while true do
		local sleep = 1000

		local playerPed <const> = PlayerPedId()
		local isDead <const> = IsEntityDead(playerPed)


		for key, pickup in pairs(WorldPickups) do
			local dist <const> = #(GetEntityCoords(playerPed) - pickup.coords)

			if dist < 80.0 then
				if pickup.entityId == 0 or not DoesEntityExist(pickup.entityId) then
					pickup.entityId = PickupsService.CreateObject(pickup.name, pickup.coords, pickup.type)
				end
			else
				if DoesEntityExist(pickup.entityId) then
					DeleteEntity(pickup.entityId)
					pickup.entityId = 0
				end
			end

			UiPromptSetVisible(PickUpPrompt, not isDead)

			if dist <= 1.0 and not InInventory then
				sleep = 0
				local label = VarString(10, "LITERAL_STRING", pickup.label)
				UiPromptSetActiveGroupThisFrame(group, label, 0, 0, 0, 0)

				if UiPromptHasHoldModeCompleted(PickUpPrompt) then
					if pickup.entityId == WorldPickups[key].entityId then
						if not pressed then
							pressed = true

							if isAnyPlayerNear() == 0 then
								print(Config.UseGoldItem, pickup.isGold)
								if pickup.isMoney then
									local data = { obj = key, uuid = pickup.uuid }
									TriggerServerEvent("vorpinventory:onPickupMoney", data)
								elseif Config.UseGoldItem and pickup.isGold then
									local data = { obj = key, uuid = pickup.uuid }
									TriggerServerEvent("vorpinventory:onPickupGold", data)
								else
									local data = { uid = pickup.uid, obj = key }
									TriggerServerEvent("vorpinventory:onPickup", data)
								end
								TaskLookAtEntity(playerPed, pickup.entityId, 1000, 2048, 3, 0)
							end

							SetTimeout(4000, function()
								pressed = false
							end)
						end
					end
				end
			end
		end
		Wait(sleep)
	end
end)


-- for debug
AddEventHandler("onResourceStop", function(resourceName)
	if GetCurrentResourceName() ~= resourceName then return end
	if not Config.DevMode then return end
	--delete all entities
	for key, value in pairs(WorldPickups) do
		if DoesEntityExist(value.entityId) then
			DeleteEntity(value.entityId)
		end
	end
end)
