-- GladeSlayer: персонаж игрока на сервере — MaxHealth/WalkSpeed из прокачки и снаряжения,
-- регенерация ХП (стандартный скрипт Health заменён пустым), 3D-снаряжение на теле, урон от мобов.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Models = require(Shared:WaitForChild("Models"))

local CharacterService = {}
local DataService = nil

local function parts(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, root
end

local function limb(character, slot)
	if slot == "Weapon" then
		return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	end
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function gearFolder(character)
	local folder = character:FindFirstChild("GladeGear")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GladeGear"
		folder.Parent = character
	end
	return folder
end

-- Пересобирает 3D-модель в слоте, только если предмет поменялся.
local function attach(character, slot, itemId)
	local folder = gearFolder(character)
	local current = folder:FindFirstChild(slot)
	if current and current:GetAttribute("ItemId") == itemId then
		return
	end
	if current then
		current:Destroy()
	end
	if not itemId then
		return
	end
	local part0 = limb(character, slot)
	if not part0 then
		return
	end
	local model = Models.BuildItem(itemId, part0.Size)
	if not model or not model.PrimaryPart then
		return
	end
	model.Name = slot
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	local offset = CFrame.new()
	if slot == "Weapon" then
		-- Рукоять в кулаке, клинок вперёд: при взмахе рукой клинок описывает дугу.
		offset = CFrame.new(0, -part0.Size.Y * 0.45, 0)
	end
	model:PivotTo(part0.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Name = "GladeGearWeld"
	weld.Part0 = part0
	weld.Part1 = model.PrimaryPart
	weld.C0 = offset
	weld.Parent = model.PrimaryPart
	model.Parent = folder
end

function CharacterService.Apply(player, heal)
	local profile = DataService.Get(player)
	local character = player.Character
	local humanoid = parts(character)
	if not profile or not humanoid then
		return
	end
	local derived = Rules.Derived(profile)
	local ratio = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
	humanoid.MaxHealth = derived.MaxHealth
	if heal then
		humanoid.Health = derived.MaxHealth
	elseif humanoid.Health > 0 then
		humanoid.Health = math.clamp(derived.MaxHealth * ratio, 1, derived.MaxHealth)
	end
	humanoid.WalkSpeed = derived.WalkSpeed
	character:SetAttribute("Weapon", profile.Equipped.Weapon or "")
	character:SetAttribute("Level", profile.Level)
	for _, slot in ipairs(Config.Slots) do
		attach(character, slot, profile.Equipped[slot])
	end
end

-- Урон игроку от моба. Возвращает true, если удар прошёл.
function CharacterService.Damage(player, amount)
	local humanoid = parts(player.Character)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	humanoid:TakeDamage(amount)
	return true
end

function CharacterService.Init(dataService)
	DataService = dataService
	DataService.OnChanged(function(player)
		CharacterService.Apply(player, false)
	end)
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	-- Ждём R15/R6-части, чтобы снаряжение было к чему приварить.
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.2)
	if DataService.Get(player) then
		CharacterService.Apply(player, true)
	end
	humanoid.Died:Connect(function()
		DataService.Toast(player, "Ты пал! Возрождение через " .. Players.RespawnTime .. " с.", "error")
	end)
end

function CharacterService.Start()
	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end

	-- Регенерация и защита от падения за карту: раз в секунду.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.Get(player)
				local humanoid, root = parts(player.Character)
				if profile and humanoid and humanoid.Health > 0 then
					if humanoid.Health < humanoid.MaxHealth then
						local regen = Rules.Derived(profile).Regen
						humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + regen)
					end
					if root and root.Position.Y < Config.FallResetY then
						root.AssemblyLinearVelocity = Vector3.zero
						player.Character:PivotTo(CFrame.new(Config.SpawnPosition + Vector3.new(0, 4, 0)))
					end
				end
			end
		end
	end)
end

return CharacterService
