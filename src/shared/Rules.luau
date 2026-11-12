-- GladeSlayer: чистые игровые правила (без Instance и сервисов). Сервер меняет профиль только через эти
-- функции, клиент использует их для форматирования. Модуль покрыт tests/rules_spec.lua.
local Config = require(script.Parent:WaitForChild("Config"))

local Rules = {}

-- Вспомогательные проверки ---------------------------------------------------------------------
local function clamp(value, low, high)
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isInteger(value, low, high)
	return finite(value) and math.floor(value) == value and value >= low and value <= high
end

local function whole(value, low, high)
	return clamp(math.floor(value), low, high)
end

local function itemDef(itemId)
	if type(itemId) ~= "string" then
		return nil
	end
	return Config.Items[itemId]
end

Rules.Clamp = clamp
Rules.IsInteger = isInteger
Rules.ItemDef = itemDef

-- Прогрессия -----------------------------------------------------------------------------------
function Rules.XPRequired(level)
	local n = math.max(0, (level or 1) - 1)
	return Config.XPBase + Config.XPLinear * n + Config.XPQuadratic * n * n
end

function Rules.StatValue(statId, level)
	local def = Config.Stats[statId]
	if not def then
		return 0
	end
	local value = def.Base + def.PerLevel * (level or 0)
	local scale = 10 ^ def.Decimals
	return math.floor(value * scale + 0.5) / scale
end

function Rules.UpgradeCost(level)
	return 1 + math.floor(level / Config.UpgradeCostStep)
end

function Rules.NewProfile()
	local profile = {
		Version = Config.SchemaVersion,
		Coins = 0,
		Level = 1,
		XP = 0,
		SkillPoints = Config.StartSkillPoints,
		Kills = 0,
		Stats = {},
		Inventory = {},
		Equipped = {},
		Buffs = {},
		Tutorial = 1,
		TutorialProgress = 0,
	}
	for _, statId in ipairs(Config.StatOrder) do
		profile.Stats[statId] = 0
	end
	return profile
end

-- Превращает запись DataStore в живой профиль. Структурно битые записи отклоняются,
-- чтобы сервер не перезаписал чужой прогресс пустым; диапазоны и устаревшие предметы чистятся.
function Rules.Decode(record, now)
	now = now or 0
	if type(record) ~= "table" then
		return nil, "Профиль повреждён."
	end
	if record.Version ~= Config.SchemaVersion then
		return nil, "Профиль сохранён неизвестной версией игры."
	end
	for _, key in ipairs({ "Coins", "Level", "XP", "SkillPoints", "Kills" }) do
		if not finite(record[key]) then
			return nil, "Повреждено поле " .. key .. "."
		end
	end
	if type(record.Stats) ~= "table" or type(record.Inventory) ~= "table" then
		return nil, "Повреждены характеристики или инвентарь."
	end

	local profile = Rules.NewProfile()
	profile.Coins = whole(record.Coins, 0, Config.MaxCoins)
	profile.Level = whole(record.Level, 1, Config.MaxLevel)
	if profile.Level >= Config.MaxLevel then
		profile.XP = 0
	else
		profile.XP = whole(record.XP, 0, Rules.XPRequired(profile.Level) - 1)
	end
	profile.SkillPoints = whole(record.SkillPoints, 0, Config.MaxSkillPoints)
	profile.Kills = whole(record.Kills, 0, Config.MaxKills)

	for _, statId in ipairs(Config.StatOrder) do
		local level = record.Stats[statId]
		if level ~= nil and not finite(level) then
			return nil, "Повреждена характеристика " .. statId .. "."
		end
		if level ~= nil then
			profile.Stats[statId] = whole(level, 0, Config.Stats[statId].MaxLevel)
		end
	end

	for itemId, count in pairs(record.Inventory) do
		if itemDef(itemId) and finite(count) then
			local amount = whole(count, 0, Config.MaxStack)
			if amount > 0 then
				profile.Inventory[itemId] = amount
			end
		end
	end

	if type(record.Equipped) == "table" then
		for _, slot in ipairs(Config.Slots) do
			local itemId = record.Equipped[slot]
			local def = itemDef(itemId)
			if def and def.Kind == "Gear" and def.Slot == slot and (profile.Inventory[itemId] or 0) > 0 then
				profile.Equipped[slot] = itemId
			end
		end
	end

	if type(record.Buffs) == "table" then
		for _, buffId in ipairs(Config.BuffOrder) do
			local remaining = record.Buffs[buffId]
			if finite(remaining) and remaining >= 1 then
				profile.Buffs[buffId] = now + math.min(math.floor(remaining), Config.BuffMaxSeconds)
			end
		end
	end
	-- Поля гайда необязательны: старые сохранения той же версии схемы остаются валидными.
	local doneStep = #Config.Tutorial.Steps + 1
	if finite(record.Tutorial) then
		profile.Tutorial = whole(record.Tutorial, 1, doneStep)
		profile.TutorialProgress = finite(record.TutorialProgress) and whole(record.TutorialProgress, 0, 1000) or 0
	else
		profile.Tutorial = (profile.Level >= 3 or profile.Kills >= 10) and doneStep or 1
	end
	return profile
end

-- Снимок для DataStore: баффы хранятся как «остаток секунд», поэтому офлайн их таймер стоит.
function Rules.Snapshot(profile, now)
	local record = {
		Version = Config.SchemaVersion,
		Coins = profile.Coins,
		Level = profile.Level,
		XP = profile.XP,
		SkillPoints = profile.SkillPoints,
		Kills = profile.Kills,
		Stats = {},
		Inventory = {},
		Equipped = {},
		Buffs = {},
		Tutorial = profile.Tutorial or (#Config.Tutorial.Steps + 1),
		TutorialProgress = profile.TutorialProgress or 0,
	}
	for _, statId in ipairs(Config.StatOrder) do
		record.Stats[statId] = profile.Stats[statId]
	end
	for itemId, count in pairs(profile.Inventory) do
		record.Inventory[itemId] = count
	end
	for _, slot in ipairs(Config.Slots) do
		record.Equipped[slot] = profile.Equipped[slot]
	end
	for _, buffId in ipairs(Config.BuffOrder) do
		local remaining = math.floor(Rules.BuffRemaining(profile, buffId, now))
		if remaining >= 1 then
			record.Buffs[buffId] = remaining
		end
	end
	return record
end

function Rules.CopyRecord(record)
	local copy = {}
	for key, value in pairs(record) do
		if type(value) == "table" then
			copy[key] = Rules.CopyRecord(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Баффы (в живом профиле — абсолютное время окончания по часам сервера) ------------------------------
function Rules.BuffRemaining(profile, buffId, now)
	local endsAt = profile.Buffs[buffId]
	if not finite(endsAt) then
		return 0
	end
	return math.max(0, endsAt - (now or 0))
end

function Rules.BuffMultiplier(profile, buffId, now)
	local def = Config.Buffs[buffId]
	if def and Rules.BuffRemaining(profile, buffId, now) > 0 then
		return def.Multiplier
	end
	return 1
end

-- Удаляет истёкшие баффы. Возвращает true, если что-то изменилось (нужно отправить состояние).
function Rules.PruneBuffs(profile, now)
	local changed = false
	for _, buffId in ipairs(Config.BuffOrder) do
		if profile.Buffs[buffId] ~= nil and Rules.BuffRemaining(profile, buffId, now) <= 0 then
			profile.Buffs[buffId] = nil
			changed = true
		end
	end
	return changed
end

-- Характеристики -------------------------------------------------------------------------------
function Rules.GearBonus(profile)
	local damage, health = 0, 0
	for _, slot in ipairs(Config.Slots) do
		local def = itemDef(profile.Equipped[slot])
		if def then
			damage = damage + (def.Damage or 0)
			health = health + (def.Health or 0)
		end
	end
	return damage, health
end

function Rules.Derived(profile)
	local gearDamage, gearHealth = Rules.GearBonus(profile)
	local fist = Rules.StatValue("Damage", profile.Stats.Damage)
	return {
		FistDamage = fist,
		Damage = fist + gearDamage,
		MaxHealth = Rules.StatValue("Health", profile.Stats.Health) + gearHealth,
		Regen = Rules.StatValue("Regen", profile.Stats.Regen),
		WalkSpeed = Rules.StatValue("Speed", profile.Stats.Speed),
		GearDamage = gearDamage,
		GearHealth = gearHealth,
		Weapon = profile.Equipped.Weapon,
	}
end

function Rules.Upgrade(profile, statId)
	local def = Config.Stats[statId]
	if not def then
		return false, "Неизвестная характеристика."
	end
	local level = profile.Stats[statId] or 0
	if level >= def.MaxLevel then
		return false, def.Name .. ": уже максимальный уровень."
	end
	local cost = Rules.UpgradeCost(level)
	if profile.SkillPoints < cost then
		return false, "Не хватает очков навыков (нужно " .. cost .. ")."
	end
	profile.SkillPoints = profile.SkillPoints - cost
	profile.Stats[statId] = level + 1
	return true, level + 1
end

-- Опыт и монеты ---------------------------------------------------------------------------------
-- Возвращает (сколько уровней получено, сколько очков навыков начислено).
function Rules.AddXP(profile, amount)
	if not finite(amount) or amount <= 0 or profile.Level >= Config.MaxLevel then
		return 0, 0
	end
	profile.XP = profile.XP + math.floor(amount)
	local levels, points = 0, 0
	while profile.Level < Config.MaxLevel and profile.XP >= Rules.XPRequired(profile.Level) do
		profile.XP = profile.XP - Rules.XPRequired(profile.Level)
		profile.Level = profile.Level + 1
		levels = levels + 1
		local before = profile.SkillPoints
		profile.SkillPoints = math.min(Config.MaxSkillPoints, before + Config.LevelUpSkillPoints)
		points = points + (profile.SkillPoints - before)
	end
	if profile.Level >= Config.MaxLevel then
		profile.XP = 0
	end
	return levels, points
end

-- Возвращает, сколько монет реально добавлено (кошелёк ограничен MaxCoins).
function Rules.AddCoins(profile, amount)
	if not finite(amount) or amount <= 0 then
		return 0
	end
	local before = profile.Coins
	profile.Coins = math.min(Config.MaxCoins, before + math.floor(amount))
	return profile.Coins - before
end

-- Инвентарь -------------------------------------------------------------------------------------
function Rules.Count(profile, itemId)
	return profile.Inventory[itemId] or 0
end

-- Сколько штук можно продать/потратить: надетый экземпляр не считается.
function Rules.FreeCount(profile, itemId)
	local count = Rules.Count(profile, itemId)
	local def = itemDef(itemId)
	if def and def.Kind == "Gear" and profile.Equipped[def.Slot] == itemId then
		count = count - 1
	end
	return math.max(0, count)
end

-- Возвращает, сколько штук реально добавлено (стак ограничен MaxStack).
function Rules.AddItem(profile, itemId, amount)
	amount = amount or 1
	if not itemDef(itemId) or not isInteger(amount, 1, 1000000000) then
		return 0
	end
	local before = Rules.Count(profile, itemId)
	local after = math.min(Config.MaxStack, before + amount)
	if after > 0 then
		profile.Inventory[itemId] = after
	end
	return after - before
end

function Rules.RemoveItem(profile, itemId, amount)
	amount = amount or 1
	if not itemDef(itemId) or not isInteger(amount, 1, Config.MaxStack) then
		return false
	end
	local count = Rules.Count(profile, itemId)
	if count < amount then
		return false
	end
	local left = count - amount
	if left > 0 then
		profile.Inventory[itemId] = left
	else
		profile.Inventory[itemId] = nil
		local def = itemDef(itemId)
		if def.Kind == "Gear" and profile.Equipped[def.Slot] == itemId then
			profile.Equipped[def.Slot] = nil
		end
	end
	return true
end

function Rules.Equip(profile, itemId)
	local def = itemDef(itemId)
	if not def or def.Kind ~= "Gear" then
		return false, "Этот предмет нельзя надеть."
	end
	if Rules.Count(profile, itemId) < 1 then
		return false, "Предмета нет в инвентаре."
	end
	if profile.Equipped[def.Slot] == itemId then
		return false, "Уже надето."
	end
	profile.Equipped[def.Slot] = itemId
	return true, def.Slot
end

function Rules.Unequip(profile, slot)
	if type(slot) ~= "string" or not Config.SlotNames[slot] then
		return false, "Неизвестный слот."
	end
	if not profile.Equipped[slot] then
		return false, "Слот уже пуст."
	end
	profile.Equipped[slot] = nil
	return true, slot
end

-- Скупщик ---------------------------------------------------------------------------------------
function Rules.IsJunk(itemId)
	local def = itemDef(itemId)
	return def ~= nil and (def.Kind == "Trash" or def.Junk == true)
end

-- Возвращает (true, монеты) или (false, причина).
function Rules.Sell(profile, itemId, amount)
	local def = itemDef(itemId)
	if not def or not def.Sell then
		return false, "Скупщик это не берёт."
	end
	if not isInteger(amount, 1, Config.MaxStack) then
		return false, "Неверное количество."
	end
	if Rules.FreeCount(profile, itemId) < amount then
		if Rules.Count(profile, itemId) >= amount then
			return false, "Сначала сними надетый предмет."
		end
		return false, "Не хватает предметов."
	end
	Rules.RemoveItem(profile, itemId, amount)
	return true, Rules.AddCoins(profile, def.Sell * amount)
end

-- Стоимость и количество всего хлама (надетое не учитывается).
function Rules.JunkValue(profile)
	local value, count = 0, 0
	for _, itemId in ipairs(Config.ItemOrder) do
		if Rules.IsJunk(itemId) then
			local free = Rules.FreeCount(profile, itemId)
			if free > 0 then
				value = value + free * Config.Items[itemId].Sell
				count = count + free
			end
		end
	end
	return value, count
end

-- Возвращает (true, монеты, штук) или (false, причина).
function Rules.SellAllJunk(profile)
	local value, count = Rules.JunkValue(profile)
	if count <= 0 then
		return false, "Хлама для продажи нет."
	end
	for _, itemId in ipairs(Config.ItemOrder) do
		if Rules.IsJunk(itemId) then
			local free = Rules.FreeCount(profile, itemId)
			if free > 0 then
				Rules.RemoveItem(profile, itemId, free)
			end
		end
	end
	return true, Rules.AddCoins(profile, value), count
end

-- Кузнец ----------------------------------------------------------------------------------------
function Rules.InShop(itemId)
	return table.find(Config.ShopOrder, itemId) ~= nil
end

-- Возвращает (true, цена) или (false, причина).
function Rules.Buy(profile, itemId)
	local def = itemDef(itemId)
	if not def or not def.Price or not Rules.InShop(itemId) then
		return false, "Кузнец это не продаёт."
	end
	if Rules.Count(profile, itemId) >= Config.MaxStack then
		return false, "Инвентарь переполнен этим предметом."
	end
	if profile.Coins < def.Price then
		return false, "Не хватает монет (нужно " .. Rules.FormatNumber(def.Price) .. ")."
	end
	profile.Coins = profile.Coins - def.Price
	Rules.AddItem(profile, itemId, 1)
	return true, def.Price
end

function Rules.UsePotion(profile, itemId, now)
	local def = itemDef(itemId)
	if not def or def.Kind ~= "Potion" then
		return false, "Это не зелье."
	end
	if Rules.Count(profile, itemId) < 1 then
		return false, "Зелья нет в инвентаре."
	end
	local remaining = Rules.BuffRemaining(profile, def.Buff, now)
	if remaining + def.Duration > Config.BuffMaxSeconds then
		return false, "Эффект уже почти на максимуме (60 мин)."
	end
	Rules.RemoveItem(profile, itemId, 1)
	profile.Buffs[def.Buff] = now + remaining + def.Duration
	return true, def.Buff
end

-- Награда за моба. roll() -> число в [0, 1).
function Rules.Reward(profile, mobId, roll, now)
	local def = Config.Mobs[mobId]
	local result = { Coins = 0, XP = 0, Items = {}, Levels = 0, Points = 0 }
	if not def then
		return result
	end
	local low, high = def.Coins[1], def.Coins[2]
	local base = math.min(high, low + math.floor(roll() * (high - low + 1)))
	result.Coins = Rules.AddCoins(profile, base * Rules.BuffMultiplier(profile, "Coins", now))
	if profile.Level < Config.MaxLevel then
		result.XP = math.floor(def.XP * Rules.BuffMultiplier(profile, "XP", now) + 0.5)
		result.Levels, result.Points = Rules.AddXP(profile, result.XP)
	end
	for _, entry in ipairs(def.Loot) do
		if roll() < entry.Chance and Rules.AddItem(profile, entry.Item, 1) > 0 then
			table.insert(result.Items, entry.Item)
		end
	end
	profile.Kills = math.min(Config.MaxKills, profile.Kills + 1)
	return result
end

-- Состояние для клиента: снимок + готовые производные числа (клиент ничего не пересчитывает).
function Rules.ClientState(profile, now)
	local state = Rules.Snapshot(profile, now)
	state.XPRequired = Rules.XPRequired(profile.Level)
	state.Derived = Rules.Derived(profile)
	state.JunkValue, state.JunkCount = Rules.JunkValue(profile)
	return state
end

-- Форматирование -------------------------------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T" }

function Rules.FormatNumber(value)
	value = tonumber(value) or 0
	local negative = value < 0
	value = math.abs(value)
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value = value / 1000
		index = index + 1
	end
	local text
	if index == 1 then
		text = tostring(math.floor(value))
	elseif value >= 100 then
		text = string.format("%d", math.floor(value)) .. SUFFIXES[index]
	else
		text = string.format("%.1f", math.floor(value * 10) / 10):gsub("%.0$", "") .. SUFFIXES[index]
	end
	if negative then
		return "-" .. text
	end
	return text
end

function Rules.FormatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local rest = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, rest)
	end
	return string.format("%d:%02d", minutes, rest)
end

function Rules.FormatStat(statId, value)
	local def = Config.Stats[statId]
	if not def then
		return tostring(value)
	end
	return string.format("%." .. def.Decimals .. "f", value) .. def.Suffix
end

-- Короткое описание бонуса предмета для карточек UI.
function Rules.BonusText(itemId)
	local def = itemDef(itemId)
	if not def then
		return ""
	end
	if def.Kind == "Gear" then
		local parts = {}
		if (def.Damage or 0) > 0 then
			table.insert(parts, "+" .. def.Damage .. " урона")
		end
		if (def.Health or 0) > 0 then
			table.insert(parts, "+" .. def.Health .. " ХП")
		end
		return table.concat(parts, ", ")
	elseif def.Kind == "Potion" then
		local buff = Config.Buffs[def.Buff]
		return buff.Short .. " на " .. math.floor(def.Duration / 60) .. " мин"
	end
	return "Продажа: " .. def.Sell .. " монет"
end

-- Teleports share this pure server-side level check with the UI.
function Rules.CanTeleport(profile, islandId)
 local island = type(islandId) == "string" and Config.Islands[islandId]
 if not island then return false, "Неизвестный остров." end
 if profile.Level < island.Level then return false, "Нужен уровень " .. island.Level .. "." end
 return true, island.Name
end

-- Deliberately discard only low-value junk; rare trade materials are protected.
function Rules.DiscardJunk(profile)
 local removed = 0
 for _, itemId in ipairs(Config.ItemOrder) do
  local def = Config.Items[itemId]
  if def.Rarity == "Junk" or def.Junk == true then
   local amount = Rules.FreeCount(profile, itemId)
   if amount > 0 then
    Rules.RemoveItem(profile, itemId, amount)
    removed = removed + amount
   end
  end
 end
 return removed > 0, removed > 0 and ("Удалено мусора: " .. removed .. ".") or "Нет мусора для удаления."
end

-- Гайд новичка ----------------------------------------------------------------------------------
function Rules.TutorialActive(profile)
	return (profile.Tutorial or 1) <= #Config.Tutorial.Steps
end

function Rules.TutorialStep(profile)
	if not Rules.TutorialActive(profile) then
		return nil
	end
	return Config.Tutorial.Steps[profile.Tutorial], profile.Tutorial
end

local function tutorialSatisfied(profile, stepId, event, data)
	if stepId == "Slimes" then
		return event == "Kill" and data == "Slime"
	elseif stepId == "Equip" then
		return (event == "Equip" and itemDef(data) ~= nil and itemDef(data).Slot == "Weapon") or (event == "Enter" and profile.Equipped.Weapon ~= nil)
	elseif stepId == "Upgrade" then
		return event == "Upgrade"
	elseif stepId == "Sell" then
		return event == "Sell"
	end
	return false
end

local function finishTutorial(profile)
	profile.Tutorial = #Config.Tutorial.Steps + 1
	profile.TutorialProgress = 0
	local coins = Rules.AddCoins(profile, Config.Tutorial.RewardCoins)
	local added = Rules.AddItem(profile, Config.Tutorial.RewardItem, 1)
	return coins, added > 0 and Config.Tutorial.RewardItem or nil
end

-- Применяет событие к гайду. Возвращает таблицу { Changed, Advanced, Finished, Coins, Item, Granted } или nil.
-- Granted — предметы, выданные гайдом (гарантированный Старый меч и немного хлама для шага продажи).
function Rules.TutorialEvent(profile, event, data)
	local step = Rules.TutorialStep(profile)
	if not step or not tutorialSatisfied(profile, step.Id, event, data) then
		return nil
	end
	local result = { Changed = true, Advanced = false, Finished = false, Granted = {} }
	profile.TutorialProgress = (profile.TutorialProgress or 0) + 1
	while step and profile.TutorialProgress >= (step.Goal or 1) do
		result.Advanced = true
		if step.Id == "Slimes" then
			if Rules.Count(profile, "OldSword") <= 0 and Rules.AddItem(profile, "OldSword", 1) > 0 then
				table.insert(result.Granted, "OldSword")
			end
			if Rules.FreeCount(profile, "SlimeGel") <= 0 and Rules.AddItem(profile, "SlimeGel", 2) > 0 then
				table.insert(result.Granted, "SlimeGel")
			end
		end
		profile.Tutorial = profile.Tutorial + 1
		profile.TutorialProgress = 0
		step = Rules.TutorialStep(profile)
		if not step then
			result.Finished = true
			result.Coins, result.Item = finishTutorial(profile)
		elseif tutorialSatisfied(profile, step.Id, "Enter", nil) then
			profile.TutorialProgress = step.Goal or 1
		end
	end
	return result
end

function Rules.TutorialSkip(profile)
	if not Rules.TutorialActive(profile) then
		return false, "Гайд уже пройден."
	end
	profile.Tutorial = #Config.Tutorial.Steps + 1
	profile.TutorialProgress = 0
	return true, "Гайд пропущен. Удачной охоты!"
end

-- Подземелья ------------------------------------------------------------------------------------
function Rules.CanEnterDungeon(profile, dungeonId)
	local def = type(dungeonId) == "string" and Config.Dungeons[dungeonId]
	if not def then
		return false, "Неизвестное подземелье."
	end
	if profile.Level < def.Level then
		return false, "Нужен уровень " .. def.Level .. "."
	end
	return true, def.Name
end

-- Награда сундука после победы над боссом подземелья. roll() -> [0, 1).
function Rules.DungeonChest(profile, dungeonId, roll, now)
	local def = Config.Dungeons[dungeonId]
	local result = { Coins = 0, XP = 0, Items = {}, Levels = 0, Points = 0 }
	if not def then
		return result
	end
	local chest = def.Chest
	local low, high = chest.Coins[1], chest.Coins[2]
	local base = math.min(high, low + math.floor(roll() * (high - low + 1)))
	result.Coins = Rules.AddCoins(profile, base * Rules.BuffMultiplier(profile, "Coins", now))
	if profile.Level < Config.MaxLevel then
		result.XP = math.floor(chest.XP * Rules.BuffMultiplier(profile, "XP", now) + 0.5)
		result.Levels, result.Points = Rules.AddXP(profile, result.XP)
	end
	for _, entry in ipairs(chest.Loot) do
		if roll() < entry.Chance and Rules.AddItem(profile, entry.Item, 1) > 0 then
			table.insert(result.Items, entry.Item)
		end
	end
	return result
end
return Rules
