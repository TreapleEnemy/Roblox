-- Pure regression suite: additive config, persistence, gated travel, safe cleanup, rewards.
check("Old schema retained", Config.SchemaVersion==1 and Config.DataStoreName=="GladeSlayer_Profiles_v1")
local ids={}
for _,id in ipairs(Config.ItemOrder) do
 check("No duplicate item: "..id,not ids[id])
 ids[id]=true
 check("Rarity exists: "..id,Config.Rarities[Config.Items[id].Rarity]~=nil)
end
for id in pairs(Config.Items) do check("All items visible: "..id,ids[id]==true) end
local mobIds={}
for _,id in ipairs(Config.MobOrder) do
 check("No duplicate mob: "..id,not mobIds[id])
 mobIds[id]=true
 local def=Config.Mobs[id]
 -- Мобы подземелий (Dungeon = true) не живут на островах: их спавнит DungeonService по волнам.
 check("Mob configured: "..id,def.Health>0 and (def.Count>=1 or def.Dungeon==true) and def.Coins[2]>=def.Coins[1])
 for _,drop in ipairs(def.Loot) do check("Valid probability: "..id,drop.Chance>=0 and drop.Chance<=1) end
end
local p=Rules.NewProfile()
check("Glade initially open",Rules.CanTeleport(p,"Glade"))
check("Desert initially locked",not Rules.CanTeleport(p,"Desert"))
check("Volcano initially locked",not Rules.CanTeleport(p,"Volcano"))
check("Unknown destination blocked",not Rules.CanTeleport(p,"Invalid"))
check("Nonstring destination blocked",not Rules.CanTeleport(p,{}))
p.Level=14
check("Desert boundary -1",not Rules.CanTeleport(p,"Desert"))
p.Level=15
check("Desert boundary allowed",Rules.CanTeleport(p,"Desert"))
p.Level=34
check("Volcano boundary -1",not Rules.CanTeleport(p,"Volcano"))
p.Level=35
check("Volcano boundary allowed",Rules.CanTeleport(p,"Volcano"))
Rules.AddItem(p,"OldSword",2)
Rules.Equip(p,"OldSword")
Rules.AddItem(p,"SlimeGel",10)
Rules.AddItem(p,"BeggarRags",3)
Rules.AddItem(p,"Cataclysm",1)
Rules.AddItem(p,"EmberCore",5)
Rules.AddItem(p,"CoinPotion",2)
local coins=p.Coins
check("Discard succeeds",Rules.DiscardJunk(p))
check("Equipped old item kept",Rules.Count(p,"OldSword")==1 and p.Equipped.Weapon=="OldSword")
check("Junk removed",Rules.Count(p,"SlimeGel")==0 and Rules.Count(p,"BeggarRags")==0)
check("Rare materials protected",Rules.Count(p,"EmberCore")==5)
check("Legendary protected",Rules.Count(p,"Cataclysm")==1)
check("Potions protected",Rules.Count(p,"CoinPotion")==2)
check("Discard never pays",p.Coins==coins)
check("Empty cleanup is safe",not Rules.DiscardJunk(p))
check("Legendary equip",Rules.Equip(p,"Cataclysm"))
check("Legendary bonuses",Rules.Derived(p).GearDamage==230 and Rules.Derived(p).GearHealth==150)
check("Legendary cannot sell while equipped",not Rules.Sell(p,"Cataclysm",1))
local decoded=Rules.Decode(Rules.Snapshot(p,0),0)
check("New gear survives save",decoded and decoded.Equipped.Weapon=="Cataclysm" and Rules.Count(decoded,"EmberCore")==5)
local unlucky=Rules.Reward(Rules.NewProfile(),"AshOverlord",function() return 0.999 end,0)
check("Boss minimum material guaranteed",table.find(unlucky.Items,"EmberCore")~=nil)
check("Legendary is rare not guaranteed",table.find(unlucky.Items,"Cataclysm")==nil)
local lucky=Rules.Reward(Rules.NewProfile(),"AshOverlord",function() return 0 end,0)
check("Boss can drop legendary",table.find(lucky.Items,"Cataclysm")~=nil)
check("Boss gold amount",lucky.Coins>=3500 and unlucky.Coins<=5000)
check("Boss two phase AoE config",Config.Mobs.AshOverlord.AoEWindup>=1 and Config.Mobs.AshOverlord.AoERadius>=20)
check("Original slime unchanged",Config.Mobs.Slime.Health==45 and Config.Mobs.Slime.Count==9)
check("Original guardian unchanged",Config.Mobs.Guardian.Health==320 and Config.Mobs.Guardian.Count==3)
