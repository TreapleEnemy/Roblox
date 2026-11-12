-- GladeSlayer: офлайн-тесты чистой логики (Rules + Config). Запуск: python tools/verify.py
-- Харнесс подставляет Config, Rules и функцию check(name, condition).
local function firstItem(predicate)
	for _, itemId in ipairs(Config.ItemOrder) do
		local def = Config.Items[itemId]
		if def and predicate(def, itemId) then
			return itemId, def
		end
	end
	return nil, nil
end

-- Конфиг целостен
for _, itemId in ipairs(Config.ItemOrder) do
	check("ItemOrder ссылается на существующий предмет: " .. itemId, Config.Items[itemId] ~= nil)
end
for _, itemId in ipairs(Config.ShopOrder) do
	local def = Config.Items[itemId]
	check("ShopOrder: предмет с ценой " .. itemId, def ~= nil and (def.Price or 0) > 0)
end
for mobId, mob in pairs(Config.Mobs) do
	check("Зона моба существует: " .. mobId, Config.Zones[mob.Zone] ~= nil)
	for _, entry in ipairs(mob.Loot) do
		check("Лут моба существует: " .. mobId .. "/" .. tostring(entry.Item), Config.Items[entry.Item] ~= nil)
	end
end
for _, potionId in ipairs(Config.ItemOrder) do
	local def = Config.Items[potionId]
	if def.Kind == "Potion" then
		check("Бафф зелья существует: " .. potionId, Config.Buffs[def.Buff] ~= nil)
	end
end

-- Новый профиль и опыт
local profile = Rules.NewProfile()
check("Новый профиль: 0 монет, ур.1", profile.Coins == 0 and profile.Level == 1)
check("XPRequired(1) = 40", Rules.XPRequired(1) == 40)
check("XPRequired(3) = 88", Rules.XPRequired(3) == 88)
local pointsBefore = profile.SkillPoints
local levels = Rules.AddXP(profile, Rules.XPRequired(1))
check("AddXP повышает уровень", levels == 1 and profile.Level == 2)
check("Уровень даёт очки навыков", profile.SkillPoints > pointsBefore)

-- Прокачка
local statId = Config.StatOrder[1]
local before = Rules.Derived(profile)
local ok = Rules.Upgrade(profile, statId)
check("Upgrade с очками проходит", ok == true and profile.Stats[statId] == 1)
profile.SkillPoints = 0
local denied = Rules.Upgrade(profile, statId)
check("Upgrade без очков отклонён", not denied)
check("Derived возвращает MaxHealth и WalkSpeed", before.MaxHealth > 0 and before.WalkSpeed > 0)
check("Неизвестная характеристика отклонена", not Rules.Upgrade(profile, "Hack"))

-- Снаряжение и продажа
local weaponId = firstItem(function(def)
	return def.Kind == "Gear" and def.Slot == "Weapon" and (def.Sell or 0) > 0
end)
check("Есть продаваемое оружие", weaponId ~= nil)
if weaponId then
	Rules.AddItem(profile, weaponId, 2)
	local base = Rules.Derived(profile).Damage
	check("Equip оружия", Rules.Equip(profile, weaponId) == true and profile.Equipped.Weapon == weaponId)
	check("Оружие увеличивает урон", Rules.Derived(profile).Damage > base)
	check("FreeCount не считает надетое", Rules.FreeCount(profile, weaponId) == 1)
	check("Нельзя продать больше свободных", not Rules.Sell(profile, weaponId, 2))
	check("Продажа свободного экземпляра", Rules.Sell(profile, weaponId, 1) == true and Rules.Count(profile, weaponId) == 1)
	check("Надетое не продаётся", not Rules.Sell(profile, weaponId, 1))
	check("Unequip", Rules.Unequip(profile, "Weapon") == true and profile.Equipped.Weapon == nil)
end

local junkId = firstItem(function(def, itemId)
	return Rules.IsJunk(itemId)
end)
check("Есть хлам", junkId ~= nil)
if junkId then
	Rules.AddItem(profile, junkId, 3)
	local value = Rules.JunkValue(profile)
	local coins = profile.Coins
	Rules.SellAllJunk(profile)
	check("SellAllJunk платит JunkValue", profile.Coins == coins + value and Rules.Count(profile, junkId) == 0)
	check("Отрицательное количество не принимается", Rules.AddItem(profile, junkId, -5) == 0)
end

-- Покупка
local shopId = Config.ShopOrder[1]
local price = Config.Items[shopId].Price
profile.Coins = price - 1
check("Покупка без денег отклонена", not Rules.Buy(profile, shopId))
profile.Coins = price
check("Покупка с деньгами", Rules.Buy(profile, shopId) == true and profile.Coins == 0 and Rules.Count(profile, shopId) == 1)
check("Предмет не из магазина не продаётся", not Rules.Buy(profile, junkId or "Nope"))

-- Зелья и баффы
local potionId, potion = firstItem(function(def)
	return def.Kind == "Potion"
end)
if potionId then
	Rules.AddItem(profile, potionId, 1)
	check("UsePotion", Rules.UsePotion(profile, potionId, 100) == true)
	check("Бафф активен", Rules.BuffMultiplier(profile, potion.Buff, 101) > 1)
	check("Бафф истекает", Rules.BuffMultiplier(profile, potion.Buff, 100 + potion.Duration + 1) == 1)
	check("Нельзя выпить отсутствующее зелье", not Rules.UsePotion(profile, potionId, 200))
end

-- Награда за моба
for mobId, mob in pairs(Config.Mobs) do
	local p = Rules.NewProfile()
	local reward = Rules.Reward(p, mobId, function()
		return 0.999
	end, 0)
	check("Награда в диапазоне монет: " .. mobId, reward.Coins >= mob.Coins[1] and reward.Coins <= mob.Coins[2])
	check("Награда даёт опыт: " .. mobId, reward.XP == mob.XP and p.Kills == 1)
	local lucky = Rules.Reward(Rules.NewProfile(), mobId, function()
		return 0
	end, 0)
	check("Шанс 0 → выпадает весь лут: " .. mobId, #lucky.Items == #mob.Loot)
end

-- Сохранение и загрузка
profile.Coins = 1234
local saved = Rules.Snapshot(profile, 0)
local loaded = Rules.Decode(Rules.CopyRecord(saved), 0)
check("Snapshot → Decode сохраняет монеты и уровень", loaded ~= nil and loaded.Coins == 1234 and loaded.Level == profile.Level)
check("Битая запись отклонена", Rules.Decode("garbage", 0) == nil)
local state = Rules.ClientState(profile, 0)
check("ClientState содержит производные", state.Derived ~= nil and state.XPRequired ~= nil and state.JunkValue ~= nil)

-- Форматирование
check("FormatNumber(1500) = 1.5K", Rules.FormatNumber(1500) == "1.5K")
check("FormatTime(65) = 1:05", Rules.FormatTime(65) == "1:05")
