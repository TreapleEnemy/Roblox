-- GladeSlayer («Охотник Поляны»): все игровые числа в одном месте. Меняйте баланс здесь —
-- сервер, клиент и тесты читают одни и те же значения.
local Config = {}

local rgb = Color3.fromRGB

Config.GameName = "Охотник Поляны"
Config.SchemaVersion = 1

-- Сохранения ----------------------------------------------------------------------------------
Config.DataStoreName = "GladeSlayer_Profiles_v1"
Config.StudioStoreSuffix = "_Studio" -- в Studio пишем в отдельное хранилище, чтобы не портить боевые данные
Config.StudioForceMemory = false -- true = никогда не трогать DataStore (тесты в памяти)
Config.AutosaveSeconds = 90
Config.LeaseSeconds = 240
Config.LeaseSafetySeconds = 30
Config.SaveAttempts = 3

-- Карта -----------------------------------------------------------------------------------------
Config.GroundY = 2
Config.SpawnPosition = Vector3.new(0, 2, 118)
Config.MapHalfSize = 165
Config.FallResetY = -40

-- Прогрессия ------------------------------------------------------------------------------------
Config.StartSkillPoints = 3
Config.LevelUpSkillPoints = 3
Config.MaxLevel = 200
Config.MaxSkillPoints = 100000
Config.MaxCoins = 1000000000000
Config.MaxStack = 999
Config.MaxKills = 2000000000
Config.XPBase = 40
Config.XPLinear = 20
Config.XPQuadratic = 2
Config.UpgradeCostStep = 10 -- стоимость апгрейда = 1 + floor(уровень / 10) очков навыков

-- Характеристики: значение = Base + PerLevel * уровень прокачки ------------------------------------------
Config.Stats = {
	Damage = {
		Name = "Урон кулака",
		Icon = "👊",
		Base = 6,
		PerLevel = 2,
		MaxLevel = 250,
		Decimals = 0,
		Suffix = "",
		Color = rgb(255, 112, 86),
		Description = "Сила удара рукой. Бонус оружия прибавляется сверху.",
	},
	Health = {
		Name = "Здоровье",
		Icon = "❤",
		Base = 100,
		PerLevel = 15,
		MaxLevel = 250,
		Decimals = 0,
		Suffix = "",
		Color = rgb(255, 82, 120),
		Description = "Максимальный запас ХП. Броня и амулеты добавляют сверху.",
	},
	Regen = {
		Name = "Регенерация",
		Icon = "✚",
		Base = 1,
		PerLevel = 0.4,
		MaxLevel = 150,
		Decimals = 1,
		Suffix = " ХП/с",
		Color = rgb(96, 226, 140),
		Description = "Сколько ХП восстанавливается каждую секунду.",
	},
	Speed = {
		Name = "Скорость бега",
		Icon = "»",
		Base = 16,
		PerLevel = 0.5,
		MaxLevel = 40,
		Decimals = 1,
		Suffix = "",
		Color = rgb(96, 190, 255),
		Description = "Скорость передвижения персонажа (WalkSpeed).",
	},
}
Config.StatOrder = { "Damage", "Health", "Regen", "Speed" }

-- Боёвка (всё проверяется на сервере) ---------------------------------------------------------
Config.Combat = {
	FistCooldown = 0.38,
	SwordCooldown = 0.55,
	CooldownTolerance = 0.85, -- сервер прощает 15% джиттера сети
	FistImpactDelay = 0.13,
	SwordImpactDelay = 0.2,
	FistReach = 6.5,
	SwordReach = 9,
	HitboxWidth = 6,
	HitboxHeight = 7,
	ExtraReachTolerance = 2.5,
	SwordMaxTargets = 3,
	CritChance = 0.1,
	CritMultiplier = 1.75,
	AttackBurst = 6,
	AttackRefillPerSecond = 4,
	RequestBurst = 12,
	RequestRefillPerSecond = 5,
}

-- Предметы --------------------------------------------------------------------------------------
Config.Rarities = {
	Junk = { Name = "Хлам", Color = rgb(150, 156, 166), Order = 1 },
	Beggar = { Name = "Нищий", Color = rgb(196, 152, 104), Order = 2 },
	Common = { Name = "Обычный", Color = rgb(165, 177, 194), Order = 3 },
	Rare = { Name = "Редкий", Color = rgb(92, 172, 255), Order = 4 },
	Epic = { Name = "Эпический", Color = rgb(196, 116, 255), Order = 5 },
}

Config.Slots = { "Weapon", "Armor", "Accessory" }
Config.SlotNames = { Weapon = "Оружие", Armor = "Броня", Accessory = "Аксессуар" }

-- Kind: "Trash" (только продажа), "Gear" (надевается в Slot), "Potion" (даёт Buff на Duration секунд).
-- Junk = true — снаряжение нищего уровня, которое уходит Скупщику по кнопке «Продать весь хлам».
Config.Items = {
	SlimeGel = { Name = "Комок слизи", Kind = "Trash", Rarity = "Junk", Sell = 3, Description = "Липкий зелёный комок. Скупщик берёт его для своих смесей." },
	MossyPebble = { Name = "Мшистый камень", Kind = "Trash", Rarity = "Junk", Sell = 8, Description = "Камешек, обросший мхом. Говорят, приносит удачу." },
	GuardianShard = { Name = "Осколок Стража", Kind = "Trash", Rarity = "Common", Sell = 26, Description = "Обломок каменного тела Стража с тусклой руной." },
	AncientCoin = { Name = "Древняя монета", Kind = "Trash", Rarity = "Rare", Sell = 85, Description = "Монета забытого королевства. Коллекционеры платят щедро." },

	OldSword = { Name = "Старый меч", Kind = "Gear", Slot = "Weapon", Rarity = "Beggar", Damage = 6, Health = 0, Junk = true, Sell = 15, Description = "Ржавый клинок с зазубринами. Лучше, чем голые руки." },
	BeggarRags = { Name = "Лохмотья нищего", Kind = "Gear", Slot = "Armor", Rarity = "Beggar", Damage = 0, Health = 30, Junk = true, Sell = 12, Description = "Залатанная рубаха с верёвочным поясом." },
	BeggarAmulet = { Name = "Ржавый амулет", Kind = "Gear", Slot = "Accessory", Rarity = "Beggar", Damage = 3, Health = 10, Junk = true, Sell = 10, Description = "Потемневший медальон на бечёвке." },

	IronSword = { Name = "Железный меч", Kind = "Gear", Slot = "Weapon", Rarity = "Common", Damage = 18, Health = 0, Price = 350, Sell = 140, Description = "Надёжный клинок с долом из кузницы Добрыни." },
	KnightBlade = { Name = "Клинок рыцаря", Kind = "Gear", Slot = "Weapon", Rarity = "Rare", Damage = 42, Health = 0, Price = 1600, Sell = 640, Description = "Длинный клинок с золочёной гардой и синими камнями." },
	LeatherVest = { Name = "Кожаный доспех", Kind = "Gear", Slot = "Armor", Rarity = "Common", Damage = 0, Health = 90, Price = 300, Sell = 120, Description = "Плотная кожа с наплечниками и ремнём." },
	ChainMail = { Name = "Кольчуга", Kind = "Gear", Slot = "Armor", Rarity = "Rare", Damage = 0, Health = 220, Price = 1400, Sell = 560, Description = "Стальные кольца и латные наплечники." },
	HunterCharm = { Name = "Амулет охотника", Kind = "Gear", Slot = "Accessory", Rarity = "Epic", Damage = 8, Health = 40, Price = 900, Sell = 360, Description = "Клык зверя в золотой оправе с фиолетовым камнем." },

	CoinPotion = { Name = "Зелье богатства", Kind = "Potion", Rarity = "Rare", Buff = "Coins", Duration = 300, Price = 120, Sell = 40, Description = "Золотистый эликсир: монеты с мобов x2 на 5 минут." },
	RagePotion = { Name = "Зелье ярости", Kind = "Potion", Rarity = "Rare", Buff = "Damage", Duration = 300, Price = 160, Sell = 50, Description = "Алый эликсир: +50% к урону на 5 минут." },
	WisdomPotion = { Name = "Зелье мудрости", Kind = "Potion", Rarity = "Rare", Buff = "XP", Duration = 300, Price = 110, Sell = 35, Description = "Синий эликсир: +50% к опыту на 5 минут." },
}

Config.ItemOrder = {
	"OldSword", "IronSword", "KnightBlade",
	"BeggarRags", "LeatherVest", "ChainMail",
	"BeggarAmulet", "HunterCharm",
	"CoinPotion", "RagePotion", "WisdomPotion",
	"SlimeGel", "MossyPebble", "GuardianShard", "AncientCoin",
}

-- Ассортимент Кузнеца-Алхимика и вкладки его окна.
Config.ShopOrder = { "IronSword", "KnightBlade", "LeatherVest", "ChainMail", "HunterCharm", "CoinPotion", "RagePotion", "WisdomPotion" }
Config.ShopTabs = {
	{ Id = "Weapons", Name = "Оружие", Filter = "Weapon" },
	{ Id = "Gear", Name = "Броня и амулеты", Filter = "Defense" },
	{ Id = "Potions", Name = "Зелья", Filter = "Potion" },
}

-- Баффы зелий -----------------------------------------------------------------------------------
Config.Buffs = {
	Coins = { Name = "Богатство", Short = "x2 монеты", Icon = "💰", Multiplier = 2, Color = rgb(255, 204, 84) },
	Damage = { Name = "Ярость", Short = "+50% урона", Icon = "🔥", Multiplier = 1.5, Color = rgb(255, 92, 84) },
	XP = { Name = "Мудрость", Short = "+50% опыта", Icon = "📘", Multiplier = 1.5, Color = rgb(128, 160, 255) },
}
Config.BuffOrder = { "Coins", "Damage", "XP" }
Config.BuffMaxSeconds = 3600

-- Зоны и мобы -----------------------------------------------------------------------------------
Config.Zones = {
	Meadow = { Name = "Луг слизней", Center = Vector3.new(0, 2, 10), Radius = 40 },
	Ruins = { Name = "Руины Стражей", Center = Vector3.new(0, 2, -108), Radius = 22 },
}

Config.Mobs = {
	Slime = {
		Name = "Лесной слизень",
		Level = 1,
		Zone = "Meadow",
		Count = 9,
		Health = 45,
		Damage = 6,
		AttackRange = 5.2,
		AttackWindup = 0.32,
		AttackCooldown = 1.7,
		AggroRange = 24,
		LeashRange = 58,
		WalkSpeed = 9,
		RespawnSeconds = 6,
		HipHeight = 0.1,
		Radius = 1.6,
		BarHeight = 3.4,
		Coins = { 4, 7 },
		XP = 12,
		Loot = {
			{ Item = "SlimeGel", Chance = 0.7 },
			{ Item = "MossyPebble", Chance = 0.14 },
			{ Item = "OldSword", Chance = 0.04 },
			{ Item = "BeggarRags", Chance = 0.035 },
			{ Item = "BeggarAmulet", Chance = 0.025 },
		},
	},
	Guardian = {
		Name = "Страж руин",
		Level = 8,
		Zone = "Ruins",
		Count = 3,
		Health = 320,
		Damage = 17,
		AttackRange = 7.5,
		AttackWindup = 0.55,
		AttackCooldown = 2.4,
		AggroRange = 30,
		LeashRange = 46,
		WalkSpeed = 10,
		RespawnSeconds = 14,
		HipHeight = 3,
		Radius = 2.2,
		BarHeight = 4.6,
		Coins = { 28, 42 },
		XP = 55,
		Loot = {
			{ Item = "GuardianShard", Chance = 0.85 },
			{ Item = "AncientCoin", Chance = 0.18 },
			{ Item = "OldSword", Chance = 0.14 },
			{ Item = "BeggarRags", Chance = 0.12 },
			{ Item = "BeggarAmulet", Chance = 0.1 },
		},
	},
}
Config.MobOrder = { "Slime", "Guardian" }
Config.RewardShare = 0.25 -- награду получает убийца и все, кто нанёс не меньше 25% ХП моба

-- NPC -------------------------------------------------------------------------------------------
Config.NPC = {
	Merchant = {
		Name = "Скупщик Фрол",
		Title = "Покупает хлам и старое снаряжение",
		Position = Vector3.new(-46, 2, 74),
		Facing = Vector3.new(1, 0, 0),
		Prompt = "Продать добычу",
	},
	Blacksmith = {
		Name = "Кузнец Добрыня",
		Title = "Оружие, броня и зелья",
		Position = Vector3.new(46, 2, 74),
		Facing = Vector3.new(-1, 0, 0),
		Prompt = "Открыть кузницу",
	},
}
Config.PromptDistance = 11
Config.ShopDistance = 22

-- Expansion: additions are deliberately outside the legacy tables.
Config.Rarities.Legendary = { Name = "Легендарный", Color = rgb(255, 200, 65), Order = 6 }
Config.Items.SunShard = { Name = "Солнечный осколок", Kind = "Trash", Rarity = "Rare", Sell = 125, Description = "Кристалл из сердца песчаного стража." }
Config.Items.RoyalScarab = { Name = "Царский скарабей", Kind = "Trash", Rarity = "Epic", Sell = 380, Description = "Золотая печать забытой династии." }
Config.Items.EmberCore = { Name = "Пылающее ядро", Kind = "Trash", Rarity = "Epic", Sell = 510, Description = "Не остывает даже вдали от вулкана." }
Config.Items.ObsidianRelic = { Name = "Обсидиановая реликвия", Kind = "Trash", Rarity = "Rare", Sell = 270, Description = "Вулканическое стекло с алыми прожилками." }
Config.Items.DuneBlade = { Name = "Клинок дюн", Kind = "Gear", Slot = "Weapon", Rarity = "Rare", Damage = 72, Health = 0, Sell = 1100, Description = "Золотистый клинок часовых пустыни." }
Config.Items.ObsidianBlade = { Name = "Обсидиановый меч", Kind = "Gear", Slot = "Weapon", Rarity = "Epic", Damage = 125, Health = 0, Sell = 2600, Description = "Острый осколок вулканической короны." }
Config.Items.Cataclysm = { Name = "Катаклизм", Kind = "Gear", Slot = "Weapon", Rarity = "Legendary", Damage = 230, Health = 150, Sell = 12000, Description = "Легендарный меч Владыки пепла. Шанс: 12% за победу." }
for _, id in ipairs({ "DuneBlade", "ObsidianBlade", "Cataclysm", "SunShard", "RoyalScarab", "EmberCore", "ObsidianRelic" }) do
 table.insert(Config.ItemOrder, id)
end
Config.Islands = {
 Glade = { Name = "Изумрудная поляна", Level = 1, Arrival = Vector3.new(0, 6, 118), Color = rgb(90, 210, 145) },
 Desert = { Name = "Затерянные пески", Level = 15, Arrival = Vector3.new(720, 6, 112), Color = rgb(242, 194, 100) },
 Volcano = { Name = "Пепельная корона", Level = 35, Arrival = Vector3.new(1440, 6, 112), Color = rgb(255, 105, 65) },
}
Config.IslandOrder = { "Glade", "Desert", "Volcano" }
Config.TeleportCooldown = 5
Config.TeleportCombatSeconds = 8
-- Leave empty for a coin-only shop. Optional real passes can be configured by the owner.
Config.GamePasses = {}
Config.Zones.Dunes = { Name = "Дюны часовых", Center = Vector3.new(678, 2, 20), Radius = 31 }
Config.Zones.SunTemple = { Name = "Солнечный храм", Center = Vector3.new(758, 2, -68), Radius = 28 }
Config.Zones.AshFields = { Name = "Пепельные поля", Center = Vector3.new(1392, 2, 16), Radius = 32 }
Config.Zones.ObsidianGate = { Name = "Обсидиановые врата", Center = Vector3.new(1495, 2, -15), Radius = 26 }
Config.Zones.AshThrone = { Name = "Трон Владыки", Center = Vector3.new(1440, 2, -105), Radius = 3 }
local function enemy(name, level, zone, count, hp, damage, speed, coins, xp, loot)
 return { Name = name, Level = level, Zone = zone, Count = count, Health = hp, Damage = damage,
  AttackRange = 6, AttackWindup = 0.55, AttackCooldown = 2.2, AggroRange = 30, LeashRange = 48,
  WalkSpeed = speed, RespawnSeconds = 12, HipHeight = 2.5, Radius = 2, BarHeight = 5,
  Coins = coins, XP = xp, Loot = loot }
end
Config.Mobs.SandSentinel = enemy("Песчаный часовой", 15, "Dunes", 5, 780, 29, 11, {80, 120}, 150, {
 {Item = "SunShard", Chance = 0.8}, {Item = "DuneBlade", Chance = 0.045} })
Config.Mobs.SunWarden = enemy("Хранитель солнца", 22, "SunTemple", 3, 1500, 43, 10, {150, 230}, 270, {
 {Item = "RoyalScarab", Chance = 0.45}, {Item = "DuneBlade", Chance = 0.085} })
Config.Mobs.EmberKnight = enemy("Рыцарь углей", 35, "AshFields", 4, 2900, 64, 12, {260, 390}, 460, {
 {Item = "EmberCore", Chance = 0.65}, {Item = "ObsidianBlade", Chance = 0.045} })
Config.Mobs.ObsidianGuard = enemy("Обсидиановый страж", 42, "ObsidianGate", 3, 4300, 82, 10, {400, 580}, 650, {
 {Item = "ObsidianRelic", Chance = 0.9}, {Item = "ObsidianBlade", Chance = 0.09} })
Config.Mobs.AshOverlord = enemy("Владыка пепла", 50, "AshThrone", 1, 24000, 100, 9, {3500, 5000}, 4500, {
 {Item = "EmberCore", Chance = 1}, {Item = "ObsidianBlade", Chance = 0.45}, {Item = "Cataclysm", Chance = 0.12} })
local boss = Config.Mobs.AshOverlord
boss.Boss = true
boss.HipHeight = 7
boss.Radius = 6
boss.BarHeight = 15
boss.AttackRange = 9
boss.AggroRange = 52
boss.LeashRange = 62
boss.RespawnSeconds = 120
boss.AoERadius = 21
boss.AoEWindup = 1.65
boss.AoECooldown = 8
boss.AoEDamage = 135
for _, id in ipairs({ "SandSentinel", "SunWarden", "EmberKnight", "ObsidianGuard", "AshOverlord" }) do
 table.insert(Config.MobOrder, id)
end
return Config
