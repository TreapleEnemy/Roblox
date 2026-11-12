-- Update 3: гайд новичка, совместимость сохранений, подземелья, Ледяная Цитадель и новые мобы.
local doneStep = #Config.Tutorial.Steps + 1

-- Новые и старые профили.
local fresh = Rules.NewProfile()
check("New profile starts tutorial", fresh.Tutorial == 1 and fresh.TutorialProgress == 0 and Rules.TutorialActive(fresh))
local legacy = Rules.Snapshot(Rules.NewProfile(), 0)
legacy.Tutorial = nil
legacy.TutorialProgress = nil
local decodedNew = Rules.Decode(legacy, 0)
check("Legacy save without tutorial fields still loads", decodedNew ~= nil and decodedNew.Tutorial == 1)
legacy.Level = 12
local decodedVeteran = Rules.Decode(legacy, 0)
check("Veteran legacy save skips tutorial", decodedVeteran ~= nil and decodedVeteran.Tutorial == doneStep)
local roundTrip = Rules.NewProfile()
roundTrip.Tutorial = 3
roundTrip.TutorialProgress = 0
local decodedRound = Rules.Decode(Rules.Snapshot(roundTrip, 0), 0)
check("Tutorial step persists", decodedRound.Tutorial == 3)
local corrupt = Rules.Snapshot(Rules.NewProfile(), 0)
corrupt.Tutorial = 99
check("Tutorial step clamped", Rules.Decode(corrupt, 0).Tutorial == doneStep)
check("Schema version unchanged", Config.SchemaVersion == 1)

-- Полное прохождение гайда.
local p = Rules.NewProfile()
check("Wrong mob does not count", Rules.TutorialEvent(p, "Kill", "Guardian") == nil and p.TutorialProgress == 0)
Rules.TutorialEvent(p, "Kill", "Slime")
Rules.TutorialEvent(p, "Kill", "Slime")
check("Slime progress counted", p.Tutorial == 1 and p.TutorialProgress == 2)
local r = Rules.TutorialEvent(p, "Kill", "Slime")
check("Step 1 completes after 3 slimes", r ~= nil and r.Advanced and p.Tutorial == 2)
check("Old sword guaranteed", Rules.Count(p, "OldSword") == 1)
check("Junk granted for the sell step", Rules.FreeCount(p, "SlimeGel") >= 1)
check("Upgrade before equip ignored", Rules.TutorialEvent(p, "Upgrade") == nil and p.Tutorial == 2)
check("Equipping armor is not the sword step", Rules.TutorialEvent(p, "Equip", "BeggarRags") == nil)
Rules.Equip(p, "OldSword")
r = Rules.TutorialEvent(p, "Equip", "OldSword")
check("Step 2 completes on weapon equip", r ~= nil and p.Tutorial == 3)
r = Rules.TutorialEvent(p, "Upgrade")
check("Step 3 completes on upgrade", r ~= nil and p.Tutorial == 4)
local coinsBefore = p.Coins
r = Rules.TutorialEvent(p, "Sell")
check("Tutorial finishes on sell", r ~= nil and r.Finished and not Rules.TutorialActive(p))
check("Tutorial reward coins", p.Coins - coinsBefore == Config.Tutorial.RewardCoins and r.Coins == Config.Tutorial.RewardCoins)
check("Tutorial reward potion", Rules.Count(p, Config.Tutorial.RewardItem) == 1)
check("Finished tutorial ignores events", Rules.TutorialEvent(p, "Sell") == nil and p.Coins - coinsBefore == Config.Tutorial.RewardCoins)

-- Оружие уже надето к шагу 2 — шаг засчитывается сразу.
local q = Rules.NewProfile()
Rules.AddItem(q, "IronSword", 1)
Rules.Equip(q, "IronSword")
for _ = 1, 3 do
	Rules.TutorialEvent(q, "Kill", "Slime")
end
check("Equip step auto-completes when a weapon is already worn", q.Tutorial == 3)

-- Пропуск.
local s = Rules.NewProfile()
check("Skip works", Rules.TutorialSkip(s) and not Rules.TutorialActive(s) and s.Coins == 0)
check("Second skip rejected", not Rules.TutorialSkip(s))

-- Подземелья.
local d = Rules.NewProfile()
check("Unknown dungeon rejected", not Rules.CanEnterDungeon(d, "Nope") and not Rules.CanEnterDungeon(d, {}))
d.Level = 9
check("Catacombs locked at 9", not Rules.CanEnterDungeon(d, "Catacombs"))
d.Level = 10
check("Catacombs open at 10", Rules.CanEnterDungeon(d, "Catacombs"))
check("Tomb locked at 10", not Rules.CanEnterDungeon(d, "Tomb"))
d.Level = 25
check("Tomb open at 25", Rules.CanEnterDungeon(d, "Tomb"))
d.Level = 50
check("Forge open at 50", Rules.CanEnterDungeon(d, "Forge"))
check("Dungeon levels", Config.Dungeons.Catacombs.Level == 10 and Config.Dungeons.Tomb.Level == 25 and Config.Dungeons.Forge.Level == 50)
local chest = Rules.DungeonChest(d, "Catacombs", function() return 0 end, 0)
check("Chest gives min coins", chest.Coins == Config.Dungeons.Catacombs.Chest.Coins[1])
check("Chest gives all drops on lucky roll", #chest.Items == #Config.Dungeons.Catacombs.Chest.Loot)
local unlucky = Rules.DungeonChest(Rules.NewProfile(), "Forge", function() return 0.999 end, 0)
check("Chest guaranteed drop only on unlucky roll", #unlucky.Items == 1 and unlucky.Items[1] == "EmberCore")
check("Unknown dungeon chest is empty", Rules.DungeonChest(Rules.NewProfile(), "Nope", function() return 0 end, 0).Coins == 0)
for _, id in ipairs(Config.DungeonOrder) do
	local def = Config.Dungeons[id]
	check("Dungeon has 3 waves: " .. id, #def.Waves == 3)
	check("Dungeon boss exists: " .. id, Config.Mobs[def.Boss] ~= nil and Config.Mobs[def.Boss].Boss == true and Config.Mobs[def.Boss].Dungeon == true)
	for _, wave in ipairs(def.Waves) do
		for mobId, amount in pairs(wave) do
			check("Wave mob exists: " .. mobId, Config.Mobs[mobId] ~= nil and Config.Mobs[mobId].Dungeon == true and amount >= 1)
		end
	end
	for _, entry in ipairs(def.Chest.Loot) do
		check("Chest item exists: " .. entry.Item, Config.Items[entry.Item] ~= nil)
	end
end

-- Остров 60+, новые мобы и мировой босс.
local f = Rules.NewProfile()
f.Level = 59
check("Frost locked at 59", not Rules.CanTeleport(f, "Frost"))
f.Level = 60
check("Frost open at 60", Rules.CanTeleport(f, "Frost"))
for _, id in ipairs({ "FrostWraith", "FrostMage", "FrostGolem", "CitadelSentinel", "VoidWarlock", "SkeletonWarrior" }) do
	check("New mob type: " .. id, Config.Mobs[id] ~= nil and Config.Mobs[id].Model == nil)
end
check("Ranged mobs configured", Config.Mobs.FrostMage.Ranged and Config.Mobs.VoidWarlock.Ranged and Config.Mobs.FrostMage.ProjectileSpeed > 0)
check("Heavy guards configured", Config.Mobs.FrostGolem.SlamRadius > 0 and Config.Mobs.CitadelSentinel.DamageReduction > 0)
local emperor = Config.Mobs.FrostEmperor
check("World boss has 3 phases", emperor.Boss and #emperor.PhaseThresholds == 2)
check("World boss summons minions", Config.Mobs[emperor.Summon.Mob] ~= nil and emperor.Summon.Max >= emperor.Summon.Count)
check("World boss telegraphs", emperor.AoERadius > 0 and emperor.Meteors.Radius > 0)
local mythic = false
for _, drop in ipairs(emperor.Loot) do
	if Config.Items[drop.Item].Rarity == "Mythic" then
		mythic = true
	end
end
check("World boss drops a mythic weapon", mythic and Config.Items.EternalWinter.Slot == "Weapon")
check("Zones exist for island mobs", Config.Zones[emperor.Zone] ~= nil and Config.Zones[Config.Mobs.FrostMage.Zone] ~= nil)
check("Max level supports 100+", Config.MaxLevel >= 100)
check("Hotkeys", Config.Hotkeys.Inventory == "I" and Config.Hotkeys.Stats == "K" and Config.Hotkeys.Dungeons == "J" and Config.Hotkeys.Teleports == "T")
