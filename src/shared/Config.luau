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

-- Update 3: Ледяная Цитадель, подземелья, гайд новичка, мифическое оружие --------------------------
Config.Rarities.Mythic = { Name = "Мифический", Color = rgb(255, 72, 120), Order = 7 }
local function addItems(list)
 for _, entry in ipairs(list) do
  Config.Items[entry[1]] = entry[2]
  table.insert(Config.ItemOrder, entry[1])
 end
end
addItems({
 { "BoneCleaver", { Name = "Костяной тесак", Kind = "Gear", Slot = "Weapon", Rarity = "Rare", Damage = 55, Health = 0, Sell = 900, Description = "Тяжёлый клинок из Катакомб Слизней." } },
 { "BoneCharm", { Name = "Амулет некроманта", Kind = "Gear", Slot = "Accessory", Rarity = "Rare", Damage = 12, Health = 90, Sell = 700, Description = "Череп в серебряной оправе. Тихо шепчет по ночам." } },
 { "PharaohKhopesh", { Name = "Хопеш фараона", Kind = "Gear", Slot = "Weapon", Rarity = "Epic", Damage = 150, Health = 0, Sell = 3600, Description = "Изогнутый клинок из Гробницы Песчаного Короля." } },
 { "SandKingMask", { Name = "Маска Песчаного Короля", Kind = "Gear", Slot = "Accessory", Rarity = "Epic", Damage = 28, Health = 180, Sell = 3200, Description = "Золотая погребальная маска с лазуритом." } },
 { "ForgeBlade", { Name = "Клинок Кузни Пепла", Kind = "Gear", Slot = "Weapon", Rarity = "Legendary", Damage = 300, Health = 120, Sell = 15000, Description = "Выкован в сердце Кузни Пепла. Лезвие не остывает." } },
 { "AshenPlate", { Name = "Пепельные латы", Kind = "Gear", Slot = "Armor", Rarity = "Legendary", Damage = 0, Health = 900, Sell = 14000, Description = "Латы Повелителя Кузни из обсидиана и меди." } },
 { "FrostBlade", { Name = "Морозный клинок", Kind = "Gear", Slot = "Weapon", Rarity = "Epic", Damage = 380, Health = 0, Sell = 5200, Description = "Клинок изо льда, который не тает. Добыча Ледяной Цитадели." } },
 { "CitadelPlate", { Name = "Латы цитадели", Kind = "Gear", Slot = "Armor", Rarity = "Epic", Damage = 0, Health = 650, Sell = 4800, Description = "Голубая сталь стражей Ледяной Цитадели." } },
 { "WinterRune", { Name = "Руна зимы", Kind = "Gear", Slot = "Accessory", Rarity = "Epic", Damage = 35, Health = 220, Sell = 4200, Description = "Ледяной кристалл с древней руной." } },
 { "EternalWinter", { Name = "Вечная Зима", Kind = "Gear", Slot = "Weapon", Rarity = "Mythic", Damage = 650, Health = 400, Sell = 60000, Description = "Мифический меч Императора Вечной Мерзлоты. Шанс: 8% за победу." } },
 { "BoneDust", { Name = "Костяная пыль", Kind = "Trash", Rarity = "Common", Sell = 60, Description = "Серый прах из Катакомб." } },
 { "FrostShard", { Name = "Осколок вечного льда", Kind = "Trash", Rarity = "Rare", Sell = 420, Description = "Не тает даже в руке." } },
 { "GlacialHeart", { Name = "Ледяное сердце", Kind = "Trash", Rarity = "Epic", Sell = 1300, Description = "Пульсирующее ядро морозного голема." } },
 { "VoidEssence", { Name = "Эссенция бездны", Kind = "Trash", Rarity = "Epic", Sell = 1800, Description = "Фиолетовый туман в стеклянной сфере." } },
})

Config.Islands.Frost = { Name = "Ледяная Цитадель", Level = 60, Arrival = Vector3.new(2160, 6, 112), Color = rgb(140, 210, 255) }
table.insert(Config.IslandOrder, "Frost")
Config.Zones.FrostFields = { Name = "Поля призраков", Center = Vector3.new(2112, 2, 40), Radius = 30 }
Config.Zones.GlacierPass = { Name = "Ледниковый перевал", Center = Vector3.new(2210, 2, 32), Radius = 28 }
Config.Zones.GolemQuarry = { Name = "Карьер големов", Center = Vector3.new(2110, 2, -45), Radius = 28 }
Config.Zones.CitadelGate = { Name = "Врата цитадели", Center = Vector3.new(2210, 2, -48), Radius = 26 }
Config.Zones.VoidRift = { Name = "Разлом бездны", Center = Vector3.new(2262, 2, 5), Radius = 20 }
Config.Zones.FrostThrone = { Name = "Трон Императора", Center = Vector3.new(2160, 2, -112), Radius = 3 }

-- Model — какой процедурной моделью рисовать моба, Scale — масштаб рига (у гуманоидов HipHeight = 2 * Scale).
-- Ranged — уклоняемый снаряд, SlamRadius — удар по площади, DamageReduction — доля поглощённого урона.
local function shape(def, fields)
 for key, value in pairs(fields) do
  def[key] = value
 end
 return def
end
local newMobs = {
 { "FrostWraith", shape(enemy("Ледяной призрак", 60, "FrostFields", 5, 9000, 140, 15, { 700, 950 }, 1500, {
  { Item = "FrostShard", Chance = 0.7 }, { Item = "FrostBlade", Chance = 0.02 } }),
  { Scale = 1.3, HipHeight = 3.2, Radius = 2, BarHeight = 6, AttackWindup = 0.4, AttackCooldown = 1.6, IdleClip = "WraithFloat", WalkClip = "WraithFloat", AttackClips = { "WraithSwipe" } }) },
 { "FrostMage", shape(enemy("Морозный маг", 64, "GlacierPass", 4, 7800, 165, 10, { 800, 1100 }, 1750, {
  { Item = "FrostShard", Chance = 0.75 }, { Item = "WinterRune", Chance = 0.03 } }),
  { Scale = 1.2, HipHeight = 2.4, Radius = 1.8, BarHeight = 5.4, Ranged = true, AttackRange = 32, AggroRange = 40, LeashRange = 60,
   AttackWindup = 0.8, AttackCooldown = 2.6, ProjectileSpeed = 55, ProjectileRadius = 4, ProjectileColor = rgb(150, 220, 255), AttackClips = { "MageCast" } }) },
 { "FrostGolem", shape(enemy("Морозный голем", 70, "GolemQuarry", 3, 26000, 260, 8, { 1500, 2100 }, 3200, {
  { Item = "GlacialHeart", Chance = 0.55 }, { Item = "CitadelPlate", Chance = 0.03 } }),
  { Scale = 2.2, HipHeight = 4.4, Radius = 3.4, BarHeight = 10, AttackRange = 9, AttackWindup = 0.9, AttackCooldown = 3.2, SlamRadius = 11, RespawnSeconds = 18, AttackClips = { "HeavySlam" } }) },
 { "CitadelSentinel", shape(enemy("Страж цитадели", 76, "CitadelGate", 3, 34000, 300, 10, { 1900, 2600 }, 4000, {
  { Item = "GlacialHeart", Chance = 0.7 }, { Item = "CitadelPlate", Chance = 0.05 }, { Item = "FrostBlade", Chance = 0.04 } }),
  { Scale = 1.7, HipHeight = 3.4, Radius = 2.6, BarHeight = 8, AttackRange = 8.5, AttackWindup = 0.7, AttackCooldown = 2.6, DamageReduction = 0.2, RespawnSeconds = 18, AttackClips = { "HeavySlam", "GuardianPunch" } }) },
 { "VoidWarlock", shape(enemy("Колдун бездны", 84, "VoidRift", 3, 30000, 340, 10, { 2400, 3200 }, 5200, {
  { Item = "VoidEssence", Chance = 0.6 }, { Item = "WinterRune", Chance = 0.05 } }),
  { Scale = 1.35, HipHeight = 2.7, Radius = 2, BarHeight = 6, Ranged = true, AttackRange = 34, AggroRange = 42, LeashRange = 58,
   AttackWindup = 0.9, AttackCooldown = 2.4, ProjectileSpeed = 48, ProjectileRadius = 5, ProjectileColor = rgb(190, 90, 255), AttackClips = { "MageCast" } }) },
 { "SkeletonWarrior", shape(enemy("Скелет-воин", 12, nil, 0, 450, 26, 12, { 30, 45 }, 70, {
  { Item = "BoneDust", Chance = 0.6 } }),
  { Scale = 1.1, HipHeight = 2.2, Radius = 1.8, BarHeight = 5, AttackWindup = 0.45, AttackCooldown = 1.9, Dungeon = true, AggroRange = 70, LeashRange = 90, AttackClips = { "WraithSwipe", "GuardianPunch" } }) },
 { "FrostEmperor", shape(enemy("Император Вечной Мерзлоты", 100, "FrostThrone", 1, 160000, 320, 9, { 18000, 24000 }, 30000, {
  { Item = "GlacialHeart", Chance = 1 }, { Item = "FrostBlade", Chance = 0.4 }, { Item = "CitadelPlate", Chance = 0.25 }, { Item = "EternalWinter", Chance = 0.08 } }),
  { Boss = true, Scale = 4, HipHeight = 8, Radius = 6.5, BarHeight = 19, AttackRange = 10, AggroRange = 56, LeashRange = 66, RespawnSeconds = 180,
   AoERadius = 20, AoEWindup = 1.6, AoECooldown = 9, AoEDamage = 520, PhaseThresholds = { 0.66, 0.33 },
   Summon = { Mob = "FrostWraith", Count = 2, Cooldown = 20, Max = 6, FromPhase = 2 },
   Meteors = { Radius = 8, Damage = 380, Windup = 1.5, Cooldown = 11, FromPhase = 2, PerPlayer = 1, LastPhasePerPlayer = 3, Color = rgb(120, 200, 255) },
   AttackClips = { "GuardianSlam", "GuardianPunch" } }) },
}
for _, entry in ipairs(newMobs) do
 Config.Mobs[entry[1]] = entry[2]
 table.insert(Config.MobOrder, entry[1])
end
Config.Mobs.AshOverlord.PhaseThresholds = { 0.5 }

-- Подземелья: варианты мобов только для арен (Count = 0, Dungeon = true); модель берётся из Model.
local function dungeonMob(id, base, fields)
 local src = Config.Mobs[base]
 local def = {}
 for key, value in pairs(src) do
  def[key] = value
 end
 def.Model = src.Model or base
 def.Zone = nil
 def.Count = 0
 def.Dungeon = true
 def.Boss = nil
 def.AggroRange = 70
 def.LeashRange = 90
 shape(def, fields)
 Config.Mobs[id] = def
 table.insert(Config.MobOrder, id)
end
dungeonMob("CryptSlime", "Slime", { Name = "Склепный слизень", Level = 10, Health = 320, Damage = 20, Coins = { 20, 30 }, XP = 45, Scale = 1.3, BarHeight = 4.4, Radius = 2, WalkSpeed = 11,
 Loot = { { Item = "SlimeGel", Chance = 0.8 }, { Item = "BoneDust", Chance = 0.25 } } })
dungeonMob("CryptGuardian", "Guardian", { Name = "Склепный страж", Level = 14, Health = 1300, Damage = 40, Coins = { 60, 90 }, XP = 160, Scale = 1.2, HipHeight = 3.6, Radius = 2.6, BarHeight = 5.6,
 Loot = { { Item = "GuardianShard", Chance = 0.9 }, { Item = "BoneCleaver", Chance = 0.03 } } })
dungeonMob("SlimeKing", "Slime", { Name = "Король Слизней", Level = 16, Boss = true, Health = 6500, Damage = 55, Coins = { 450, 650 }, XP = 900, Scale = 3.4, HipHeight = 0.35, Radius = 5, BarHeight = 11,
 AttackRange = 7, AoERadius = 15, AoEWindup = 1.5, AoECooldown = 9, AoEDamage = 80, PhaseThresholds = { 0.5 },
 Summon = { Mob = "CryptSlime", Count = 2, Cooldown = 16, Max = 4, FromPhase = 2 },
 Loot = { { Item = "SlimeGel", Chance = 1 }, { Item = "BoneCleaver", Chance = 0.2 } } })
dungeonMob("TombSentinel", "SandSentinel", { Name = "Страж гробницы", Level = 25, Health = 2400, Damage = 52, Coins = { 120, 170 }, XP = 330 })
dungeonMob("TombSkeleton", "SkeletonWarrior", { Name = "Мумия-воин", Level = 26, Health = 2000, Damage = 58, Coins = { 110, 160 }, XP = 320, Scale = 1.2, HipHeight = 2.4,
 Loot = { { Item = "BoneDust", Chance = 0.8 }, { Item = "RoyalScarab", Chance = 0.08 } } })
dungeonMob("TombWarden", "SunWarden", { Name = "Жрец гробницы", Level = 28, Health = 3600, Damage = 66, Coins = { 200, 280 }, XP = 520,
 Loot = { { Item = "RoyalScarab", Chance = 0.4 }, { Item = "PharaohKhopesh", Chance = 0.02 } } })
dungeonMob("SandKing", "SunWarden", { Name = "Песчаный Король", Level = 32, Boss = true, Health = 30000, Damage = 95, Coins = { 1600, 2200 }, XP = 3200, Scale = 3, HipHeight = 6, Radius = 5.5, BarHeight = 14,
 AttackRange = 9, AoERadius = 18, AoEWindup = 1.5, AoECooldown = 8, AoEDamage = 140, PhaseThresholds = { 0.5 },
 Meteors = { Radius = 7, Damage = 110, Windup = 1.6, Cooldown = 12, FromPhase = 2, PerPlayer = 2, LastPhasePerPlayer = 2, Color = rgb(255, 200, 90) },
 Loot = { { Item = "RoyalScarab", Chance = 1 }, { Item = "PharaohKhopesh", Chance = 0.15 } } })
dungeonMob("ForgeKnight", "EmberKnight", { Name = "Рыцарь Кузни", Level = 50, Health = 6500, Damage = 110, Coins = { 420, 560 }, XP = 820 })
dungeonMob("ForgeGuard", "ObsidianGuard", { Name = "Кузнечный страж", Level = 54, Health = 9000, Damage = 130, Coins = { 520, 700 }, XP = 1050, Scale = 1.5, HipHeight = 3, Radius = 2.4, BarHeight = 6.5, SlamRadius = 9, AttackClips = { "HeavySlam" } })
dungeonMob("ForgeWarlock", "VoidWarlock", { Name = "Пепельный колдун", Level = 52, Health = 5200, Damage = 120, Coins = { 450, 600 }, XP = 900,
 ProjectileColor = rgb(255, 130, 60), Loot = { { Item = "EmberCore", Chance = 0.35 }, { Item = "ObsidianRelic", Chance = 0.4 } } })
dungeonMob("ForgeTyrant", "ObsidianGuard", { Name = "Повелитель Кузни", Level = 58, Boss = true, Health = 90000, Damage = 170, Coins = { 5000, 7000 }, XP = 9000, Scale = 3.4, HipHeight = 6.8, Radius = 6, BarHeight = 16,
 AttackRange = 10, AoERadius = 20, AoEWindup = 1.5, AoECooldown = 8, AoEDamage = 240, PhaseThresholds = { 0.6, 0.3 },
 Summon = { Mob = "ForgeKnight", Count = 2, Cooldown = 22, Max = 4, FromPhase = 2 },
 Meteors = { Radius = 8, Damage = 200, Windup = 1.5, Cooldown = 10, FromPhase = 3, PerPlayer = 2, LastPhasePerPlayer = 3, Color = rgb(255, 120, 50) },
 Loot = { { Item = "EmberCore", Chance = 1 }, { Item = "ForgeBlade", Chance = 0.12 }, { Item = "AshenPlate", Chance = 0.12 } } })

Config.Dungeons = {
 Catacombs = {
  Name = "Катакомбы Слизней", Level = 10, Theme = "Catacombs", Color = rgb(120, 230, 140), TimeLimit = 360,
  Description = "Сырые склепы под Поляной. Слизни, скелеты и их Король.",
  Waves = { { CryptSlime = 5 }, { CryptSlime = 3, SkeletonWarrior = 3 }, { SkeletonWarrior = 4, CryptGuardian = 1 } },
  Boss = "SlimeKing",
  Chest = { Coins = { 700, 1000 }, XP = 1200, Loot = { { Item = "BoneCleaver", Chance = 0.35 }, { Item = "BoneCharm", Chance = 0.3 }, { Item = "AncientCoin", Chance = 1 }, { Item = "WisdomPotion", Chance = 0.5 } } },
 },
 Tomb = {
  Name = "Гробница Песчаного Короля", Level = 25, Theme = "Tomb", Color = rgb(255, 205, 100), TimeLimit = 420,
  Description = "Золотые залы под пустыней, полные мумий и жрецов.",
  Waves = { { TombSentinel = 4 }, { TombSkeleton = 3, TombSentinel = 2 }, { TombWarden = 2, TombSkeleton = 3 } },
  Boss = "SandKing",
  Chest = { Coins = { 3000, 4200 }, XP = 4500, Loot = { { Item = "PharaohKhopesh", Chance = 0.3 }, { Item = "SandKingMask", Chance = 0.3 }, { Item = "RoyalScarab", Chance = 1 }, { Item = "CoinPotion", Chance = 0.5 } } },
 },
 Forge = {
  Name = "Кузня Пепла", Level = 50, Theme = "Forge", Color = rgb(255, 120, 60), TimeLimit = 480,
  Description = "Лавовые цеха под вулканом. Здесь куют легендарное оружие.",
  Waves = { { ForgeKnight = 4 }, { ForgeKnight = 2, ForgeWarlock = 3 }, { ForgeGuard = 2, ForgeWarlock = 2, ForgeKnight = 2 } },
  Boss = "ForgeTyrant",
  Chest = { Coins = { 9000, 12000 }, XP = 14000, Loot = { { Item = "ForgeBlade", Chance = 0.25 }, { Item = "AshenPlate", Chance = 0.25 }, { Item = "EmberCore", Chance = 1 }, { Item = "RagePotion", Chance = 0.5 } } },
 },
}
Config.DungeonOrder = { "Catacombs", "Tomb", "Forge" }
Config.DungeonOrigin = Vector3.new(-3200, 2, 0) -- арены строятся далеко от островов, по слотам вдоль Z
Config.DungeonSlotSpacing = 400
Config.DungeonCountdown = 4
Config.DungeonWaveDelay = 3

Config.Tutorial = {
 Controls = "Движение: WASD  |  Атака: ЛКМ  |  Взаимодействие с NPC и порталами: E",
 Steps = {
  { Id = "Slimes", Text = "Подойди на Луг слизней и победи 3 Слизней (Атака — ЛКМ)", Goal = 3, Target = Config.Zones.Meadow.Center },
  { Id = "Equip", Text = "Открой Инвентарь [I] и экипируй выбитый Старый меч", Goal = 1, Highlight = "Inventory" },
  { Id = "Upgrade", Text = "Открой Прокачку [K] и улучши любую характеристику (Урон, ХП, Реген или Скорость)", Goal = 1, Highlight = "Stats" },
  { Id = "Sell", Text = "Продай собранный мусор Скупщику в лавке", Goal = 1, Target = Config.NPC.Merchant.Position },
 },
 RewardCoins = 300,
 RewardItem = "CoinPotion",
}
Config.Hotkeys = { Inventory = "I", Stats = "K", Dungeons = "J", Teleports = "T" }
return Config
