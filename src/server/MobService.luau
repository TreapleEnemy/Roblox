-- GladeSlayer: мобы — спавн по зонам, ИИ (агр, преследование, «поводок», атака с замахом),
-- полоска ХП над головой, урон, награда (убийце и всем, кто нанёс ≥ RewardShare ХП) и респавн.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Models = require(Shared:WaitForChild("Models"))

local MobService = {}
local DataService, CharacterService, Remotes
local folder = nil
local mobs = {}
local byModel = {}
local rng = Random.new()

local AI_STEP = 0.2
local MOB_GROUP = "GladeMobs"

-- Мобы не сталкиваются друг с другом (не толкаются и не залезают сверху), но сталкиваются с миром и игроками.
pcall(function()
	local PhysicsService = game:GetService("PhysicsService")
	if not PhysicsService:IsCollisionGroupRegistered(MOB_GROUP) then
		PhysicsService:RegisterCollisionGroup(MOB_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(MOB_GROUP, MOB_GROUP, false)
end)

local function rollFn()
	return rng:NextNumber()
end

local function randomPoint(zone)
	local angle = rng:NextNumber() * math.pi * 2
	local radius = math.sqrt(rng:NextNumber()) * zone.Radius
	return Vector3.new(zone.Center.X + math.cos(angle) * radius, Config.GroundY, zone.Center.Z + math.sin(angle) * radius)
end

local function buildBar(mob)
	local def = mob.Def
	local gui = Instance.new("BillboardGui")
	gui.Name = "MobBar"
	gui.Size = UDim2.fromOffset(def.Boss and 310 or 150, def.Boss and 48 or 34)
	-- Смещение в мировых осях: полоска не качается вместе с поворотом/наклоном корня.
	gui.StudsOffsetWorldSpace = Vector3.new(0, def.BarHeight, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = def.Boss and 200 or 90
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, def.Boss and 24 or 16)
	title.Font = Enum.Font.GothamBold
	title.TextSize = def.Boss and 18 or 13
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = def.Name .. "  [ур. " .. def.Level .. "]"
	title.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.new(0, 0, 0, def.Boss and 29 or 19)
	back.Size = UDim2.new(1, 0, 0, def.Boss and 17 or 11)
	back.BackgroundColor3 = Color3.fromRGB(30, 22, 26)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(10, 8, 10)
	stroke.Thickness = 1.5
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 96, 96), Color3.fromRGB(200, 40, 60))
	gradient.Rotation = 90
	gradient.Parent = fill
	gui.Parent = mob.Root
	mob.Fill = fill
end

local function updateBar(mob)
	if mob.Fill then
		local ratio = math.clamp(mob.Humanoid.Health / mob.Humanoid.MaxHealth, 0, 1)
		mob.Fill.Size = UDim2.fromScale(ratio, 1)
	end
end

local function spawnMob(mobId)
	local def = Config.Mobs[mobId]
	local model = Models.BuildMob(mobId)
	if not def or not model then
		return nil
	end
	local root = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local zone = Config.Zones[def.Zone]
	local home = randomPoint(zone)
	local height = def.HipHeight + root.Size.Y / 2 + 0.4
	local yaw = rng:NextNumber() * math.pi * 2
	model:PivotTo(CFrame.new(home + Vector3.new(0, height, 0)) * CFrame.Angles(0, yaw, 0))
	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- Мобы не прыгают и не карабкаются: иначе слизни запрыгивают друг на друга и на заборы.
	for _, state in ipairs({ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Jumping }) do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.MaxSlopeAngle = 30
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CollisionGroup = MOB_GROUP
		end
	end
	model:SetAttribute("MobId", mobId)
	model:SetAttribute("Level", def.Level)
 model:SetAttribute("Boss", def.Boss == true)
 model:SetAttribute("Phase", 1)
 model:SetAttribute("MobDead", false)
	local mob = {
		Model = model, Root = root, Humanoid = humanoid, Id = mobId, Def = def,
		Home = home, Dead = false, Hits = {}, Target = nil,
		LastEngaged = os.clock(), NextAoE = os.clock() + 4, Phase = 1, NextAttack = 0, Attacking = false, NextWander = os.clock() + rng:NextNumber(2, 6),
	}
	buildBar(mob)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	mobs[mob] = true
	byModel[model] = mob
	return mob
end

local function aliveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 and DataService.Get(player) then
		return character, root
	end
	return nil
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function findTarget(mob)
	local position = mob.Root.Position
	-- Тот, кто ударил, остаётся целью, пока не вышел за поводок.
	if mob.Target then
		local _, root = aliveCharacter(mob.Target)
		if root and flatDistance(root.Position, mob.Home) <= mob.Def.LeashRange then
			return mob.Target, root
		end
		mob.Target = nil
	end
	local best, bestRoot, bestDistance = nil, nil, mob.Def.AggroRange
	for _, player in ipairs(Players:GetPlayers()) do
		local _, root = aliveCharacter(player)
		if root then
			local distance = flatDistance(root.Position, position)
			if distance <= bestDistance and flatDistance(root.Position, mob.Home) <= mob.Def.LeashRange then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

local function attack(mob, player, targetRoot)
	local def = mob.Def
	mob.Attacking = true
	mob.NextAttack = os.clock() + def.AttackCooldown
	mob.Humanoid:MoveTo(mob.Root.Position)
	-- Поворот к цели только по горизонтали и без телепорта корня (раньше слизень «подпрыгивал»).
	local position = mob.Root.Position
	local look = Vector3.new(targetRoot.Position.X - position.X, 0, targetRoot.Position.Z - position.Z)
	if look.Magnitude > 0.1 then
		mob.Humanoid:MoveTo(position + look.Unit * 0.5)
	end
	local clip = "SlimeLunge"
	if mob.Id ~= "Slime" then
		clip = rng:NextNumber() < 0.5 and "GuardianSlam" or "GuardianPunch"
	end
	Remotes.FX:FireAllClients("MobAttack", mob.Model, mob.Id, clip)
	task.delay(def.AttackWindup, function()
		mob.Attacking = false
		if mob.Dead or not mob.Model.Parent then
			return
		end
		local character, root = aliveCharacter(player)
		if not character or root ~= targetRoot then
			return
		end
		-- Уклонение: если игрок отбежал за время замаха — промах.
		if math.abs(root.Position.Y - mob.Root.Position.Y) < (def.Boss and 18 or 10) and flatDistance(root.Position, mob.Root.Position) - def.Radius <= def.AttackRange + 1.5 then
			local amount = math.floor(def.Damage * (mob.Phase == 2 and 1.25 or 1))
   if CharacterService.Damage(player, amount) then
    player:SetAttribute("GladeCombatAt", os.clock())
				Remotes.FX:FireAllClients("PlayerHit", character, amount)
			end
		end
	end)
end

-- Telegraph is a server part so late-arriving clients see exactly the damaging area.
local function bossAoE(mob)
 local def = mob.Def
 local phase = mob.Phase
 local center = Vector3.new(mob.Root.Position.X, Config.GroundY + 0.38, mob.Root.Position.Z)
 local radius = def.AoERadius * (phase == 2 and 1.2 or 1)
 local windup = def.AoEWindup
 mob.Attacking = true
 mob.NextAoE = os.clock() + def.AoECooldown * (phase == 2 and 0.7 or 1)
 mob.NextAttack = os.clock() + windup + 0.9
 mob.Humanoid:MoveTo(mob.Root.Position)
 local marker = Instance.new("Part")
 marker.Name = "BossWarning"
 marker.Shape = Enum.PartType.Cylinder
 marker.Anchored, marker.CanCollide, marker.CanTouch, marker.CanQuery = true, false, false, false
 marker.Size = Vector3.new(0.15, radius*2, radius*2)
 marker.CFrame = CFrame.new(center) * Models.UPRIGHT
 marker.Color, marker.Material, marker.Transparency = Color3.fromRGB(255,40,55), Enum.Material.Neon, 0.45
 marker.Parent = mob.Model
 local labelGui = Instance.new("BillboardGui")
 labelGui.Size, labelGui.AlwaysOnTop = UDim2.fromOffset(220,36), true
 labelGui.StudsOffsetWorldSpace = Vector3.new(0,2,0)
 labelGui.MaxDistance = 110
 labelGui.Parent = marker
 local label = Instance.new("TextLabel")
 label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1,1)
 label.Text, label.TextColor3 = "ОТОЙДИ ОТ КРАСНОЙ ЗОНЫ!", Color3.new(1,1,1)
 label.TextSize, label.Font, label.TextStrokeTransparency = 16, Enum.Font.GothamBold, 0.2
 label.Parent = labelGui
 game:GetService("TweenService"):Create(marker,TweenInfo.new(windup),{Transparency = 0.12}):Play()
 game:GetService("Debris"):AddItem(marker,windup+0.2)
 Remotes.FX:FireAllClients("MobAttack",mob.Model,mob.Id,"BossSlam")
 task.delay(windup,function()
  if marker.Parent then marker:Destroy() end
  if mob.Dead or not mob.Model.Parent then return end
  for _, player in ipairs(Players:GetPlayers()) do
   local character, root = aliveCharacter(player)
   if root and flatDistance(root.Position,center) <= radius and math.abs(root.Position.Y-center.Y)<16 then
    local amount = math.floor(def.AoEDamage*(phase==2 and 1.3 or 1))
    if CharacterService.Damage(player,amount) then
     player:SetAttribute("GladeCombatAt",os.clock())
     Remotes.FX:FireAllClients("PlayerHit",character,amount)
    end
   end
  end
  Remotes.FX:FireAllClients("BossImpact",center,radius)
  task.delay(0.55,function() if not mob.Dead then mob.Attacking=false end end)
 end)
end

local function think(mob, now)
	if mob.Dead or mob.Attacking or not mob.Model.Parent then
		return
	end
	local def = mob.Def
 local position = mob.Root.Position
 if def.Boss then
  local phase = mob.Humanoid.Health <= mob.Humanoid.MaxHealth*0.5 and 2 or 1
  if phase ~= mob.Phase then
   mob.Phase = phase
   mob.Model:SetAttribute("Phase",phase)
   mob.Humanoid.WalkSpeed = def.WalkSpeed*(phase==2 and 1.3 or 1)
  end
 end
 local player, targetRoot = findTarget(mob)
 if player then
  mob.LastEngaged = now
  if def.Boss and now >= mob.NextAoE and flatDistance(targetRoot.Position,position)<def.AoERadius+10 then
   bossAoE(mob)
   return
  end
  local distance = flatDistance(targetRoot.Position, position) - def.Radius
		if distance <= def.AttackRange then
			if now >= mob.NextAttack then
				attack(mob, player, targetRoot)
			else
				mob.Humanoid:MoveTo(position)
			end
		else
			mob.Humanoid:MoveTo(targetRoot.Position)
		end
		return
	end
 mob.Target = nil
 if def.Boss and now-mob.LastEngaged>10 and mob.Humanoid.Health<mob.Humanoid.MaxHealth then
  mob.Humanoid.Health=mob.Humanoid.MaxHealth
  mob.Hits={}
  mob.Phase=1
  mob.Model:SetAttribute("Phase",1)
  mob.Humanoid.WalkSpeed=def.WalkSpeed
  mob.NextAoE=now+4
  updateBar(mob)
 end
 local fromHome = flatDistance(position, mob.Home)
	if fromHome > def.LeashRange * 0.5 then
		-- Возврат домой с полным восстановлением ХП (без «выбивания» моба по одному удару).
		mob.Humanoid:MoveTo(mob.Home)
		if mob.Humanoid.Health < mob.Humanoid.MaxHealth then
			mob.Humanoid.Health = mob.Humanoid.MaxHealth
			mob.Hits = {}
			updateBar(mob)
		end
	elseif now >= mob.NextWander then
		mob.NextWander = now + rng:NextNumber(3, 7)
		local zone = Config.Zones[def.Zone]
		local point = mob.Home + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		if flatDistance(point, zone.Center) <= zone.Radius then
			mob.Humanoid:MoveTo(point)
		end
	end
end

local function itemNames(items)
	local names = {}
	for _, itemId in ipairs(items) do
		local def = Config.Items[itemId]
		table.insert(names, def and def.Name or itemId)
	end
	return table.concat(names, ", ")
end

local function reward(mob, killer)
	local share = mob.Humanoid.MaxHealth * Config.RewardShare
	local position = mob.Root.Position
	for player, dealt in pairs(mob.Hits) do
		local profile = player.Parent and DataService.Get(player)
		if profile and (player == killer or dealt >= share) then
			local result = Rules.Reward(profile, mob.Id, rollFn, os.clock())
			Remotes.FX:FireClient(player, "Loot", position, { Coins = result.Coins, XP = result.XP, Items = result.Items })
			if #result.Items > 0 then
				DataService.Toast(player, "Добыча: " .. itemNames(result.Items), "loot")
			end
			if result.Levels > 0 then
				if player.Character then
					Remotes.FX:FireAllClients("LevelUp", player.Character, profile.Level)
				end
				DataService.Toast(player, "Новый уровень " .. profile.Level .. "! +" .. result.Points .. " очков навыков (C — прокачка)", "success")
			end
			DataService.Changed(player)
		end
	end
end

local function die(mob, killer)
	if mob.Dead then
		return
	end
	mob.Dead = true
 mob.Model:SetAttribute("MobDead",true)
	mobs[mob] = nil
	Remotes.FX:FireAllClients("MobDied", mob.Model)
	local ok, err = pcall(reward, mob, killer)
	if not ok then
		warn("[GladeSlayer] Награда за моба: " .. tostring(err))
	end
	local bar = mob.Root:FindFirstChild("MobBar")
	if bar then
		bar:Destroy()
	end
	mob.Humanoid.WalkSpeed = 0
	task.delay(1.2, function()
		byModel[mob.Model] = nil
		mob.Model:Destroy()
	end)
	task.delay(mob.Def.RespawnSeconds, function()
		spawnMob(mob.Id)
	end)
end

function MobService.GetFolder()
	return folder
end

function MobService.FromPart(part)
	local current = part
	while current and current.Parent ~= folder do
		current = current.Parent
	end
	if current then
		local mob = byModel[current]
		if mob and not mob.Dead then
			return mob
		end
	end
	return nil
end

function MobService.Damage(mob, player, amount, crit)
	if mob.Dead or not mob.Model.Parent then
		return
	end
	local humanoid = mob.Humanoid
	player:SetAttribute("GladeCombatAt",os.clock())
	local dealt = math.min(amount, humanoid.Health)
	mob.Hits[player] = (mob.Hits[player] or 0) + dealt
	mob.Target = player
	humanoid.Health = math.max(0, humanoid.Health - amount)
	updateBar(mob)
	local hitPosition = mob.Root.Position + Vector3.new(0, mob.Def.BarHeight * 0.5, 0)
	Remotes.FX:FireAllClients("Damage", mob.Model, hitPosition, amount, crit, player.UserId)
	if humanoid.Health <= 0 then
		die(mob, player)
	end
end

function MobService.Init(dataService, characterService, remotes)
	DataService = dataService
	CharacterService = characterService
	Remotes = remotes
	local old = workspace:FindFirstChild("GladeSlayerMobs")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "GladeSlayerMobs"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(function(player)
		for mob in pairs(mobs) do
			mob.Hits[player] = nil
			if mob.Target == player then
				mob.Target = nil
			end
		end
	end)
end

function MobService.Start()
	for _, mobId in ipairs(Config.MobOrder) do
		for _ = 1, Config.Mobs[mobId].Count do
			spawnMob(mobId)
		end
	end
	task.spawn(function()
		while true do
			task.wait(AI_STEP)
			local now = os.clock()
			local list = {}
			for mob in pairs(mobs) do
				table.insert(list, mob)
			end
			for _, mob in ipairs(list) do
				local ok, err = pcall(think, mob, now)
				if not ok then
					warn("[GladeSlayer] ИИ моба: " .. tostring(err))
				end
				-- Моб провалился под карту — возвращаем домой.
				if mob.Root.Position.Y < Config.FallResetY then
					mob.Model:PivotTo(CFrame.new(mob.Home + Vector3.new(0, mob.Def.HipHeight + 3, 0)))
				end
			end
		end
	end)
end

return MobService
