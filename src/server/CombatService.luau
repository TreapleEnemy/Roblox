-- GladeSlayer: серверная боёвка. Клиент сообщает только «я ударил» (без аргументов) — кулдаун, хитбокс,
-- дистанцию, линию видимости, урон и криты считает сервер. Подменить цель или урон с клиента нельзя.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local CombatService = {}
local DataService, MobService, Remotes
local rng = Random.new()
local buckets = {}
local lastSwing = {}
local combo = {}

-- Токен-бакет: не больше AttackBurst событий подряд и AttackRefillPerSecond в секунду.
local function allow(player)
	local combat = Config.Combat
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = combat.AttackBurst, Updated = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(combat.AttackBurst, bucket.Tokens + (now - bucket.Updated) * combat.AttackRefillPerSecond)
	bucket.Updated = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens = bucket.Tokens - 1
	return true
end

local function alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

local function clearLine(character, origin, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, MobService.GetFolder() }
	params.IgnoreWater = true
	pcall(function()
		params.RespectCanCollide = true
	end)
	local result = workspace:Raycast(origin, target - origin, params)
	return result == nil or not result.Instance.CanCollide
end

-- Разрешение удара в момент «импакта» анимации: бокс перед игроком только по папке мобов.
local function resolve(player, sword)
	local profile = DataService.Get(player)
	local character, _, root = alive(player)
	if not profile or not character then
		return
	end
	local combat = Config.Combat
	local reach = sword and combat.SwordReach or combat.FistReach
	local maxTargets = sword and combat.SwordMaxTargets or 1

	local boxCFrame = root.CFrame * CFrame.new(0, 0, -reach / 2)
	local boxSize = Vector3.new(combat.HitboxWidth, combat.HitboxHeight, reach + 2)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { MobService.GetFolder() }
	local parts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlap)

	local seen, candidates = {}, {}
	local origin = root.Position
	for _, part in ipairs(parts) do
		local mob = MobService.FromPart(part)
		if mob and not seen[mob] and not mob.Dead then
			seen[mob] = true
			local offset = mob.Root.Position - origin
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude - mob.Def.Radius
			-- Дистанция пересчитывается по корню моба: клиент не может «дотянуться» дальше разрешённого.
			if flat <= reach + combat.ExtraReachTolerance and math.abs(offset.Y) <= combat.HitboxHeight + mob.Def.HipHeight then
				if clearLine(character, origin, mob.Root.Position) then
					table.insert(candidates, { Mob = mob, Distance = flat })
				end
			end
		end
	end
	if #candidates == 0 then
		return
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)

	local now = os.clock()
	local derived = Rules.Derived(profile)
	local base = derived.Damage * Rules.BuffMultiplier(profile, "Damage", now)
	for index = 1, math.min(maxTargets, #candidates) do
		local crit = rng:NextNumber() < combat.CritChance
		local amount = base
		if crit then
			amount = amount * combat.CritMultiplier
		end
		amount = math.max(1, math.floor(amount + 0.5))
		MobService.Damage(candidates[index].Mob, player, amount, crit)
	end
end

local function onAttack(player)
	if not allow(player) then
		return
	end
	local profile = DataService.Get(player)
	local character = alive(player)
	if not profile or not character then
		return
	end
	local combat = Config.Combat
	local sword = profile.Equipped.Weapon ~= nil
	local cooldown = sword and combat.SwordCooldown or combat.FistCooldown
	local now = os.clock()
	local last = lastSwing[player]
	if last and now - last < cooldown * combat.CooldownTolerance then
		return
	end
	lastSwing[player] = now
	combo[player] = (combo[player] or 0) + 1
	local odd = combo[player] % 2 == 1
	local style
	if sword then
		style = odd and "SwordSlash1" or "SwordSlash2"
	else
		style = odd and "PunchRight" or "PunchLeft"
	end
	Remotes.FX:FireAllClients("Swing", character, style)
	task.delay(sword and combat.SwordImpactDelay or combat.FistImpactDelay, function()
		local ok, err = pcall(resolve, player, sword)
		if not ok then
			warn("[GladeSlayer] Удар: " .. tostring(err))
		end
	end)
end

function CombatService.Init(dataService, mobService, remotes)
	DataService = dataService
	MobService = mobService
	Remotes = remotes
	remotes.Attack.OnServerEvent:Connect(function(player)
		local ok, err = pcall(onAttack, player)
		if not ok then
			warn("[GladeSlayer] Атака: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		lastSwing[player] = nil
		combo[player] = nil
	end)
end

return CombatService
