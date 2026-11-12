-- GladeSlayer: мобы — спавн по зонам или по точкам (арены подземелий), ИИ (агр, преследование, «поводок»,
-- ближняя атака с замахом, снаряды дальников, удары по площади), боссы с фазами, призывом миньонов и
-- телеграфами AoE, полоска ХП, урон, награда (убийце и всем, кто нанёс ≥ RewardShare ХП) и респавн.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Models = require(Shared:WaitForChild("Models"))

local MobService = {}
-- Хук убийства: function(player, profile, mobId) — вызывается для каждого получившего награду.
MobService.OnKill = nil
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

-- opts (все поля необязательны): Position (точка пола), NoRespawn, NoReward, AggroRange, LeashRange,
-- OnDeath(mob, killer), Tag (метка группы для массового удаления), Owner (босс, призвавший миньона).
local function spawnMob(mobId, opts)
	opts = opts or {}
	local def = Config.Mobs[mobId]
	if not def then
		return nil
	end
	local home = opts.Position
	if not home then
		local zone = def.Zone and Config.Zones[def.Zone]
		if not zone then
			return nil
		end
		home = randomPoint(zone)
	end
	local model = Models.BuildMob(mobId)
	if not model then
		return nil
	end
	local root = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
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
	if def.IdleClip then
		model:SetAttribute("IdleClip", def.IdleClip)
	end
	if def.WalkClip then
		model:SetAttribute("WalkClip", def.WalkClip)
	end
	local now = os.clock()
	local mob = {
		Model = model, Root = root, Humanoid = humanoid, Id = mobId, Def = def, Opts = opts,
		Home = home, Dead = false, Hits = {}, Target = nil,
		Aggro = opts.AggroRange or def.AggroRange, Leash = opts.LeashRange or def.LeashRange,
		LastEngaged = now, NextAoE = now + 4, Phase = 1, NextAttack = 0, Attacking = false, NextWander = now + rng:NextNumber(2, 6),
		NextSummon = now + 6, NextMeteor = now + 5, Minions = {},
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
		if root and flatDistance(root.Position, mob.Home) <= mob.Leash and math.abs(root.Position.Y - mob.Home.Y) < 40 then
			return mob.Target, root
		end
		mob.Target = nil
	end
	local best, bestRoot, bestDistance = nil, nil, mob.Aggro
	for _, player in ipairs(Players:GetPlayers()) do
		local _, root = aliveCharacter(player)
		if root and math.abs(root.Position.Y - mob.Home.Y) < 40 then
			local distance = flatDistance(root.Position, position)
			if distance <= bestDistance and flatDistance(root.Position, mob.Home) <= mob.Leash then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

local function hurt(player, character, amount)
	if CharacterService.Damage(player, amount) then
		player:SetAttribute("GladeCombatAt", os.clock())
		Remotes.FX:FireAllClients("PlayerHit", character, amount)
	end
end

-- Множители фаз: для двухфазного Владыки пепла дают ровно прежние значения (×1.25 урон и т.д.).
local function phaseScale(mob, perPhase)
	return 1 + perPhase * (mob.Phase - 1)
end

local function pickClip(mob)
	local def = mob.Def
	if def.AttackClips and #def.AttackClips > 0 then
		return def.AttackClips[rng:NextInteger(1, #def.AttackClips)]
	end
	if (def.Model or mob.Id) == "Slime" then
		return "SlimeLunge"
	end
	return rng:NextNumber() < 0.5 and "GuardianSlam" or "GuardianPunch"
end

local function facePosition(mob, targetPosition)
	local position = mob.Root.Position
	mob.Humanoid:MoveTo(position)
	-- Поворот к цели только по горизонтали и без телепорта корня (раньше слизень «подпрыгивал»).
	local look = Vector3.new(targetPosition.X - position.X, 0, targetPosition.Z - position.Z)
	if look.Magnitude > 0.1 then
		mob.Humanoid:MoveTo(position + look.Unit * 0.5)
	end
end

-- Снаряд летит в точку, где цель стояла в момент выстрела: отбежал — промах.
local function fireProjectile(mob, targetRoot)
	local def = mob.Def
	local castPoint = mob.Model:FindFirstChild("CastPoint", true)
	local from = castPoint and castPoint:IsA("BasePart") and castPoint.Position or (mob.Root.Position + Vector3.new(0, 2, 0))
	local to = targetRoot.Position
	local speed = def.ProjectileSpeed or 50
	local radius = def.ProjectileRadius or 4
	local color = def.ProjectileColor or Color3.fromRGB(150, 220, 255)
	Remotes.FX:FireAllClients("Projectile", from, to, color, speed)
	local damage = math.floor(def.Damage * phaseScale(mob, 0.25))
	task.delay((to - from).Magnitude / speed, function()
		if mob.Dead then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local character, root = aliveCharacter(player)
			if root and flatDistance(root.Position, to) <= radius and math.abs(root.Position.Y - to.Y) < 8 then
				hurt(player, character, damage)
			end
		end
	end)
end

local function attack(mob, player, targetRoot)
	local def = mob.Def
	mob.Attacking = true
	mob.NextAttack = os.clock() + def.AttackCooldown
	facePosition(mob, targetRoot.Position)
	Remotes.FX:FireAllClients("MobAttack", mob.Model, mob.Id, pickClip(mob))
	task.delay(def.AttackWindup, function()
		mob.Attacking = false
		if mob.Dead or not mob.Model.Parent then
			return
		end
		local character, root = aliveCharacter(player)
		if not character or root ~= targetRoot then
			return
		end
		if def.Ranged then
			if flatDistance(root.Position, mob.Root.Position) <= def.AttackRange + 8 then
				fireProjectile(mob, root)
			end
			return
		end
		local amount = math.floor(def.Damage * phaseScale(mob, 0.25))
		if def.SlamRadius then
			-- Тяжёлый удар бьёт всех рядом с точкой перед мобом.
			local center = mob.Root.Position
			for _, other in ipairs(Players:GetPlayers()) do
				local otherCharacter, otherRoot = aliveCharacter(other)
				if otherRoot and flatDistance(otherRoot.Position, center) <= def.SlamRadius and math.abs(otherRoot.Position.Y - center.Y) < 12 then
					hurt(other, otherCharacter, amount)
				end
			end
			Remotes.FX:FireAllClients("BossImpact", Vector3.new(center.X, mob.Home.Y + 0.3, center.Z), def.SlamRadius * 0.6)
			return
		end
		-- Уклонение: если игрок отбежал за время замаха — промах.
		if math.abs(root.Position.Y - mob.Root.Position.Y) < (def.Boss and 18 or 10) and flatDistance(root.Position, mob.Root.Position) - def.Radius <= def.AttackRange + 1.5 then
			hurt(player, character, amount)
		end
	end)
end

-- Телеграф — серверная деталь: поздно подключившиеся клиенты видят ровно ту зону, что нанесёт урон.
local function warningDisk(parent, center, radius, windup, color, text)
	local marker = Instance.new("Part")
	marker.Name = "BossWarning"
	marker.Shape = Enum.PartType.Cylinder
	marker.Anchored, marker.CanCollide, marker.CanTouch, marker.CanQuery = true, false, false, false
	marker.Size = Vector3.new(0.15, radius * 2, radius * 2)
	marker.CFrame = CFrame.new(center) * Models.UPRIGHT
	marker.Color, marker.Material, marker.Transparency = color, Enum.Material.Neon, 0.45
	marker.Parent = parent
	if text then
		local labelGui = Instance.new("BillboardGui")
		labelGui.Size, labelGui.AlwaysOnTop = UDim2.fromOffset(220, 36), true
		labelGui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
		labelGui.MaxDistance = 110
		labelGui.Parent = marker
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
		label.Text, label.TextColor3 = text, Color3.new(1, 1, 1)
		label.TextSize, label.Font, label.TextStrokeTransparency = 16, Enum.Font.GothamBold, 0.2
		label.Parent = labelGui
	end
	TweenService:Create(marker, TweenInfo.new(windup), { Transparency = 0.12 }):Play()
	Debris:AddItem(marker, windup + 0.2)
	return marker
end

local function damageArea(center, radius, amount)
	for _, player in ipairs(Players:GetPlayers()) do
		local character, root = aliveCharacter(player)
		if root and flatDistance(root.Position, center) <= radius and math.abs(root.Position.Y - center.Y) < 16 then
			hurt(player, character, amount)
		end
	end
end

local function bossAoE(mob)
	local def = mob.Def
	local center = Vector3.new(mob.Root.Position.X, mob.Home.Y + 0.38, mob.Root.Position.Z)
	local radius = def.AoERadius * phaseScale(mob, 0.2)
	local windup = def.AoEWindup
	local amount = math.floor(def.AoEDamage * phaseScale(mob, 0.3))
	mob.Attacking = true
	mob.NextAoE = os.clock() + def.AoECooldown * (0.7 ^ (mob.Phase - 1))
	mob.NextAttack = os.clock() + windup + 0.9
	mob.Humanoid:MoveTo(mob.Root.Position)
	local marker = warningDisk(mob.Model, center, radius, windup, Color3.fromRGB(255, 40, 55), "ОТОЙДИ ОТ КРАСНОЙ ЗОНЫ!")
	Remotes.FX:FireAllClients("MobAttack", mob.Model, mob.Id, "BossSlam")
	task.delay(windup, function()
		if marker.Parent then
			marker:Destroy()
		end
		if mob.Dead or not mob.Model.Parent then
			return
		end
		damageArea(center, radius, amount)
		Remotes.FX:FireAllClients("BossImpact", center, radius)
		task.delay(0.55, function()
			if not mob.Dead then
				mob.Attacking = false
			end
		end)
	end)
end

-- Метеоры: красные круги под ногами игроков в бою с боссом, в последней фазе — несколько на каждого.
local function bossMeteors(mob)
	local def = mob.Def
	local spec = def.Meteors
	local lastPhase = #(def.PhaseThresholds or {}) + 1
	local perPlayer = mob.Phase >= lastPhase and (spec.LastPhasePerPlayer or spec.PerPlayer) or spec.PerPlayer
	mob.Attacking = true
	mob.NextMeteor = os.clock() + spec.Cooldown * (mob.Phase >= lastPhase and 0.75 or 1)
	mob.NextAttack = os.clock() + 1.1
	mob.Humanoid:MoveTo(mob.Root.Position)
	Remotes.FX:FireAllClients("MobAttack", mob.Model, mob.Id, "BossCast")
	local floorY = mob.Home.Y + 0.4
	local targets = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local _, root = aliveCharacter(player)
		if root and flatDistance(root.Position, mob.Home) <= mob.Leash and math.abs(root.Position.Y - mob.Home.Y) < 40 then
			for i = 1, perPlayer do
				local offset = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
				table.insert(targets, Vector3.new(root.Position.X + offset.X, floorY, root.Position.Z + offset.Z))
			end
		end
	end
	local amount = math.floor(spec.Damage * phaseScale(mob, 0.2))
	for index, center in ipairs(targets) do
		local delay = (index - 1) * 0.12
		task.delay(delay, function()
			if mob.Dead then
				return
			end
			warningDisk(mob.Model, center, spec.Radius, spec.Windup, spec.Color or Color3.fromRGB(255, 60, 60), nil)
			task.delay(spec.Windup, function()
				if mob.Dead or not mob.Model.Parent then
					return
				end
				damageArea(center, spec.Radius, amount)
				Remotes.FX:FireAllClients("BossImpact", center, spec.Radius)
			end)
		end)
	end
	task.delay(1.1, function()
		if not mob.Dead then
			mob.Attacking = false
		end
	end)
end

local function aliveMinions(mob)
	local alive = 0
	for minion in pairs(mob.Minions) do
		if minion.Dead or not minion.Model.Parent then
			mob.Minions[minion] = nil
		else
			alive = alive + 1
		end
	end
	return alive
end

local function bossSummon(mob)
	local def = mob.Def
	local spec = def.Summon
	mob.NextSummon = os.clock() + spec.Cooldown
	local room = spec.Max - aliveMinions(mob)
	if room <= 0 then
		return false
	end
	mob.Attacking = true
	mob.NextAttack = os.clock() + 1.3
	mob.Humanoid:MoveTo(mob.Root.Position)
	Remotes.FX:FireAllClients("MobAttack", mob.Model, mob.Id, "BossSummon")
	local color = (def.Meteors and def.Meteors.Color) or Color3.fromRGB(200, 120, 255)
	for i = 1, math.min(spec.Count, room) do
		local angle = (i / spec.Count) * math.pi * 2 + rng:NextNumber(0, 1)
		local point = Vector3.new(mob.Root.Position.X + math.cos(angle) * (def.Radius + 6), mob.Home.Y, mob.Root.Position.Z + math.sin(angle) * (def.Radius + 6))
		Remotes.FX:FireAllClients("Summon", point, color)
		task.delay(0.8, function()
			if mob.Dead then
				return
			end
			local minion = spawnMob(spec.Mob, {
				Position = point, NoRespawn = true, NoReward = true, AggroRange = 70, LeashRange = mob.Leash,
				Tag = mob.Opts.Tag, Owner = mob,
			})
			if minion then
				mob.Minions[minion] = true
				minion.Home = mob.Home
				if mob.Opts.OnMinion then
					pcall(mob.Opts.OnMinion, minion)
				end
			end
		end)
	end
	task.delay(1.2, function()
		if not mob.Dead then
			mob.Attacking = false
		end
	end)
	return true
end

local function phaseFor(mob)
	local ratio = mob.Humanoid.Health / mob.Humanoid.MaxHealth
	local phase = 1
	for _, threshold in ipairs(mob.Def.PhaseThresholds or { 0.5 }) do
		if ratio <= threshold then
			phase = phase + 1
		end
	end
	return phase
end

local function resetBoss(mob, now)
	local def = mob.Def
	mob.Humanoid.Health = mob.Humanoid.MaxHealth
	mob.Hits = {}
	mob.Phase = 1
	mob.Model:SetAttribute("Phase", 1)
	mob.Humanoid.WalkSpeed = def.WalkSpeed
	mob.NextAoE = now + 4
	mob.NextSummon = now + 6
	mob.NextMeteor = now + 5
	updateBar(mob)
end

local function think(mob, now)
	if mob.Dead or mob.Attacking or not mob.Model.Parent then
		return
	end
	local def = mob.Def
	local position = mob.Root.Position
	if def.Boss then
		local phase = phaseFor(mob)
		if phase ~= mob.Phase then
			mob.Phase = phase
			mob.Model:SetAttribute("Phase", phase)
			mob.Humanoid.WalkSpeed = def.WalkSpeed * phaseScale(mob, 0.3)
			Remotes.FX:FireAllClients("Summon", Vector3.new(position.X, mob.Home.Y, position.Z), Color3.fromRGB(255, 90, 90))
		end
	end
	local player, targetRoot = findTarget(mob)
	if player then
		mob.LastEngaged = now
		local flat = flatDistance(targetRoot.Position, position)
		if def.Boss then
			if def.Summon and mob.Phase >= (def.Summon.FromPhase or 1) and now >= mob.NextSummon and bossSummon(mob) then
				return
			end
			if def.Meteors and mob.Phase >= (def.Meteors.FromPhase or 1) and now >= mob.NextMeteor then
				bossMeteors(mob)
				return
			end
			if def.AoERadius and now >= mob.NextAoE and flat < def.AoERadius + 10 then
				bossAoE(mob)
				return
			end
		end
		local distance = flat - def.Radius
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
	if def.Boss and now - mob.LastEngaged > 10 and mob.Humanoid.Health < mob.Humanoid.MaxHealth then
		resetBoss(mob, now)
	end
	local fromHome = flatDistance(position, mob.Home)
	if fromHome > mob.Leash * 0.5 then
		-- Возврат домой с полным восстановлением ХП (без «выбивания» моба по одному удару).
		mob.Humanoid:MoveTo(mob.Home)
		if mob.Humanoid.Health < mob.Humanoid.MaxHealth then
			mob.Humanoid.Health = mob.Humanoid.MaxHealth
			mob.Hits = {}
			updateBar(mob)
		end
	elseif now >= mob.NextWander then
		mob.NextWander = now + rng:NextNumber(3, 7)
		local zone = def.Zone and Config.Zones[def.Zone]
		local point = mob.Home + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		if not zone or mob.Opts.Position or flatDistance(point, zone.Center) <= zone.Radius then
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
MobService.ItemNames = itemNames

local function reward(mob, killer)
	if mob.Opts.NoReward then
		return
	end
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
				DataService.Toast(player, "Новый уровень " .. profile.Level .. "! +" .. result.Points .. " очков навыков (K — прокачка)", "success")
			end
			if MobService.OnKill then
				local ok, err = pcall(MobService.OnKill, player, profile, mob.Id)
				if not ok then
					warn("[GladeSlayer] OnKill: " .. tostring(err))
				end
			end
			DataService.Changed(player)
		end
	end
end

local function removeModel(mob, delay)
	task.delay(delay, function()
		byModel[mob.Model] = nil
		mob.Model:Destroy()
	end)
end

local function die(mob, killer)
	if mob.Dead then
		return
	end
	mob.Dead = true
	mob.Model:SetAttribute("MobDead", true)
	mobs[mob] = nil
	if mob.Opts.Owner then
		mob.Opts.Owner.Minions[mob] = nil
	end
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
	removeModel(mob, 1.2)
	if mob.Opts.OnDeath then
		local okDeath, errDeath = pcall(mob.Opts.OnDeath, mob, killer)
		if not okDeath then
			warn("[GladeSlayer] OnDeath: " .. tostring(errDeath))
		end
	end
	if not mob.Opts.NoRespawn then
		task.delay(mob.Def.RespawnSeconds, function()
			spawnMob(mob.Id)
		end)
	end
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
	player:SetAttribute("GladeCombatAt", os.clock())
	if mob.Def.DamageReduction then
		amount = math.max(1, math.floor(amount * (1 - mob.Def.DamageReduction) + 0.5))
	end
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

-- Публичный спавн для подземелий: моб появляется в точке Position и не респавнится.
function MobService.Spawn(mobId, opts)
	return spawnMob(mobId, opts)
end

-- Тихое удаление без награды (выход из подземелья, провал по таймеру).
function MobService.Despawn(mob)
	if mob.Dead then
		return
	end
	mob.Dead = true
	mobs[mob] = nil
	mob.Model:SetAttribute("MobDead", true)
	removeModel(mob, 0)
end

function MobService.DespawnTag(tag)
	if tag == nil then
		return
	end
	local list = {}
	for mob in pairs(mobs) do
		if mob.Opts.Tag == tag then
			table.insert(list, mob)
		end
	end
	for _, mob in ipairs(list) do
		MobService.Despawn(mob)
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
				if not mob.Dead and mob.Root.Position.Y < mob.Home.Y + Config.FallResetY - Config.GroundY then
					mob.Model:PivotTo(CFrame.new(mob.Home + Vector3.new(0, mob.Def.HipHeight + 3, 0)))
				end
			end
		end
	end)
end

return MobService
