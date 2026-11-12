-- GladeSlayer: действия игрока через RemoteFunction «Request». Каждое действие проверяется на сервере:
-- типы аргументов, лимит частоты, дистанция до NPC, наличие монет и предметов (через Rules).
-- Клиент ничего не решает сам: он только просит, а сервер отвечает (ok, сообщение) и рассылает новое состояние.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local TravelService = require(script.Parent:WaitForChild("TravelService"))
local DungeonService = require(script.Parent:WaitForChild("DungeonService"))
local EconomyService = {}
EconomyService.OnSync = nil
-- Хук успешного действия: function(player, profile, action, arg) — используется гайдом новичка.
EconomyService.OnAction = nil

local DataService = nil
local buckets = {}

local function allow(player)
	local combat = Config.Combat
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = combat.RequestBurst, Updated = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(combat.RequestBurst, bucket.Tokens + (now - bucket.Updated) * combat.RequestRefillPerSecond)
	bucket.Updated = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens = bucket.Tokens - 1
	return true
end

local function validString(value)
	return type(value) == "string" and #value > 0 and #value <= 40
end

local function near(player, kind)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local npc = Config.NPC[kind]
	return root ~= nil and npc ~= nil and (root.Position - npc.Position).Magnitude <= Config.ShopDistance
end

local function itemName(itemId)
	local def = Config.Items[itemId]
	return def and def.Name or tostring(itemId)
end

local handlers = {}

function handlers.Upgrade(_, profile, statId)
	if not validString(statId) or not Config.Stats[statId] then
		return false, "Неизвестная характеристика."
	end
	local ok, result = Rules.Upgrade(profile, statId)
	if not ok then
		return false, result
	end
	return true, Config.Stats[statId].Name .. ": ур. " .. result
end

function handlers.Equip(_, profile, itemId)
	if not validString(itemId) then
		return false, "Неизвестный предмет."
	end
	local ok, result = Rules.Equip(profile, itemId)
	if not ok then
		return false, result
	end
	return true, "Надето: " .. itemName(itemId)
end

function handlers.Unequip(_, profile, slot)
	if not validString(slot) then
		return false, "Неизвестный слот."
	end
	local ok, result = Rules.Unequip(profile, slot)
	if not ok then
		return false, result
	end
	return true, "Снято: " .. Config.SlotNames[slot]
end

function handlers.UsePotion(_, profile, itemId)
	if not validString(itemId) then
		return false, "Неизвестный предмет."
	end
	local ok, result = Rules.UsePotion(profile, itemId, os.clock())
	if not ok then
		return false, result
	end
	local buff = Config.Buffs[result]
	return true, buff.Icon .. " " .. buff.Name .. ": " .. buff.Short
end

function handlers.Sell(player, profile, itemId, amount)
	if not near(player, "Merchant") then
		return false, "Подойди ближе к Скупщику."
	end
	if not validString(itemId) or not Rules.IsInteger(amount, 1, Config.MaxStack) then
		return false, "Неверный запрос."
	end
	local ok, coins = Rules.Sell(profile, itemId, amount)
	if not ok then
		return false, coins
	end
	return true, "Продано: " .. itemName(itemId) .. " x" .. amount .. " (+" .. Rules.FormatNumber(coins) .. " монет)"
end

function handlers.SellAll(player, profile)
	if not near(player, "Merchant") then
		return false, "Подойди ближе к Скупщику."
	end
	local ok, coins, sold = Rules.SellAllJunk(profile)
	if not ok then
		return false, coins
	end
	return true, "Продано хлама: " .. sold .. " шт. (+" .. Rules.FormatNumber(coins) .. " монет)"
end

function handlers.Buy(player, profile, itemId)
	if not near(player, "Blacksmith") then
		return false, "Подойди ближе к Кузнецу."
	end
	if not validString(itemId) then
		return false, "Неизвестный предмет."
	end
	local ok, price = Rules.Buy(profile, itemId)
	if not ok then
		return false, price
	end
	return true, "Куплено: " .. itemName(itemId) .. " (-" .. Rules.FormatNumber(price) .. " монет)"
end

function handlers.Teleport(player, profile, islandId)
 if not validString(islandId) then return false, "Неизвестный остров." end
 return TravelService.Teleport(player, profile, islandId)
end
function handlers.DiscardJunk(_, profile)
 return Rules.DiscardJunk(profile)
end
function handlers.SkipTutorial(_, profile)
	return Rules.TutorialSkip(profile)
end
function handlers.EnterDungeon(player, profile, dungeonId)
	if not validString(dungeonId) then
		return false, "Неизвестное подземелье."
	end
	return DungeonService.Enter(player, profile, dungeonId)
end
function handlers.LeaveDungeon(player)
	return DungeonService.Leave(player)
end
local function onRequest(player, action, a, b)
	if not allow(player) then
		return false, "Слишком часто. Подожди секунду."
	end
	if not validString(action) then
		return false, "Неизвестное действие."
	end
	local profile = DataService.Get(player)
	if action == "Sync" then
		if profile and EconomyService.OnSync then
			EconomyService.OnSync(player)
		end
		return profile ~= nil, ""
	end
	local handler = handlers[action]
	if not handler then
		return false, "Неизвестное действие."
	end
	if not profile then
		return false, "Профиль ещё загружается…"
	end
	local success, ok, message = pcall(handler, player, profile, a, b)
	if not success then
		warn("[GladeSlayer] Request " .. action .. ": " .. tostring(ok))
		return false, "Ошибка сервера. Попробуй ещё раз."
	end
	if ok then
		DataService.Changed(player)
		if EconomyService.OnAction then
			local hookOk, hookError = pcall(EconomyService.OnAction, player, profile, action, a)
			if not hookOk then
				warn("[GladeSlayer] OnAction " .. action .. ": " .. tostring(hookError))
			end
		end
	end
	return ok == true, type(message) == "string" and message or ""
end

function EconomyService.Init(dataService, remotes)
	DataService = dataService
	remotes.Request.OnServerInvoke = onRequest
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return EconomyService
