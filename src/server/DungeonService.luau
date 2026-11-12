-- GladeSlayer: подземелья. Каждый забег — отдельная арена (DungeonWorld) в своём слоте далеко от островов:
-- обратный отсчёт → 3 волны усиленных мобов → босс подземелья → сундук с наградой и портал на Поляну.
-- Общий таймер забега; смерть, выход из игры или истечение времени — провал. Всё решает сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local DungeonWorld = require(script.Parent:WaitForChild("DungeonWorld"))

local DungeonService = {}
local DataService, MobService, Remotes
local byPlayer = {}
local slots = {}
local container = nil
local nextRun = 0
local rng = Random.new()

local MAX_SLOTS = 8
local VICTORY_STAY = 120

function DungeonService.InDungeon(player)
	return byPlayer[player] ~= nil
end

local function payload(run)
	local def = Config.Dungeons[run.Id]
	return {
		Active = true,
		Id = run.Id,
		Name = def.Name,
		Stage = run.Stage,
		Wave = run.Wave,
		Waves = #def.Waves + 1,
		Remaining = run.Remaining,
		Total = run.Total,
		TimeLeft = math.max(0, math.floor((run.Deadline - os.clock()) + 0.5)),
	}
end

local function sendState(run)
	if run.Player.Parent then
		Remotes.Dungeon:FireClient(run.Player, payload(run))
	end
end

local function toast(player, text, kind)
	if player.Parent then
		Remotes.Toast:FireClient(player, text, kind or "info")
	end
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, character
	end
	return nil
end

local function sendHome(player)
	local root, character = rootOf(player)
	if root then
		character:PivotTo(CFrame.new(Config.Islands.Glade.Arrival))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function finish(run, success, message)
	if run.Ended then
		return
	end
	run.Ended = true
	for _, connection in ipairs(run.Connections) do
		connection:Disconnect()
	end
	MobService.DespawnTag(run.Tag)
	byPlayer[run.Player] = nil
	if run.Player.Parent then
		Remotes.Dungeon:FireClient(run.Player, { Active = false, Success = success, Message = message })
		if message then
			toast(run.Player, message, success and "success" or "error")
		end
		local root = rootOf(run.Player)
		if root and (root.Position - run.Info.Center).Magnitude < run.Info.Radius + 60 then
			sendHome(run.Player)
		end
	end
	task.delay(2, function()
		run.Info.Folder:Destroy()
		slots[run.Slot] = nil
	end)
end

local function spawnGroup(run, group)
	local points = run.Info.MobSpawns
	local list = {}
	for mobId, amount in pairs(group) do
		for _ = 1, amount do
			table.insert(list, mobId)
		end
	end
	table.sort(list)
	local offset = rng:NextInteger(0, #points - 1)
	run.Remaining = #list
	run.Total = #list
	for index, mobId in ipairs(list) do
		local point = points[((index + offset - 1) % #points) + 1]
		MobService.Spawn(mobId, {
			Position = point, NoRespawn = true, AggroRange = 90, LeashRange = run.Info.Radius + 30, Tag = run.Tag,
			OnDeath = function()
				run.Remaining = math.max(0, run.Remaining - 1)
				sendState(run)
			end,
		})
	end
end

local function openChest(run, player, chest)
	if run.ChestOpened or player ~= run.Player then
		return
	end
	local profile = DataService.Get(player)
	local root = rootOf(player)
	if not profile or not root or (root.Position - chest.PrimaryPart.Position).Magnitude > 14 then
		return
	end
	run.ChestOpened = true
	local result = Rules.DungeonChest(profile, run.Id, function()
		return rng:NextNumber()
	end, os.clock())
	local lid = chest:FindFirstChild("ChestLid", true)
	if lid and lid:IsA("BasePart") then
		TweenService:Create(lid, TweenInfo.new(0.6, Enum.EasingStyle.Back), { CFrame = lid.CFrame * CFrame.new(0, 0.4, 0.6) * CFrame.Angles(math.rad(-70), 0, 0) }):Play()
	end
	Remotes.FX:FireClient(player, "Loot", chest.PrimaryPart.Position, { Coins = result.Coins, XP = result.XP, Items = result.Items })
	if #result.Items > 0 then
		toast(player, "Сундук: " .. MobService.ItemNames(result.Items), "loot")
	end
	if result.Levels > 0 and player.Character then
		Remotes.FX:FireAllClients("LevelUp", player.Character, profile.Level)
		toast(player, "Новый уровень " .. profile.Level .. "! +" .. result.Points .. " очков навыков (K — прокачка)", "success")
	end
	DataService.Changed(player)
	local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = false
	end
end

local function victory(run)
	local def = Config.Dungeons[run.Id]
	run.Stage = "Victory"
	run.Deadline = os.clock() + VICTORY_STAY
	run.Remaining = 0
	sendState(run)
	toast(run.Player, def.Name .. " зачищено! Открой сундук и войди в портал.", "success")
	local chest = DungeonWorld.BuildChest(run.Info.ChestCFrame, def.Color)
	chest.Parent = run.Info.Folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DungeonChest"
	prompt.ActionText, prompt.ObjectText = "Открыть", "Сундук подземелья"
	prompt.KeyboardKeyCode, prompt.HoldDuration = Enum.KeyCode.E, 0.5
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 12, false
	prompt.Parent = chest.PrimaryPart
	prompt.Triggered:Connect(function(player)
		openChest(run, player, chest)
	end)
	local portal = DungeonWorld.BuildReturnPortal(run.Info.PortalCFrame)
	portal.Parent = run.Info.Folder
	local core = portal:FindFirstChild("PortalCore", true)
	if core then
		local exit = Instance.new("ProximityPrompt")
		exit.Name = "DungeonExit"
		exit.ActionText, exit.ObjectText = "Вернуться", "Портал на Поляну"
		exit.KeyboardKeyCode, exit.HoldDuration = Enum.KeyCode.E, 0.3
		exit.MaxActivationDistance, exit.RequiresLineOfSight = 12, false
		exit.Parent = core
		exit.Triggered:Connect(function(player)
			local root = rootOf(player)
			if player == run.Player and root and (root.Position - core.Position).Magnitude <= 15 then
				if not run.ChestOpened then
					openChest(run, player, chest)
				end
				finish(run, true, "Ты вернулся на Поляну с добычей!")
			end
		end)
	end
end

local function spawnBoss(run)
	local def = Config.Dungeons[run.Id]
	run.Stage = "Boss"
	run.Wave = #def.Waves + 1
	run.Remaining = 1
	run.Total = 1
	toast(run.Player, "Финальная волна: " .. Config.Mobs[def.Boss].Name .. "!", "error")
	MobService.Spawn(def.Boss, {
		Position = run.Info.BossSpawn, NoRespawn = true, AggroRange = 120, LeashRange = run.Info.Radius + 30, Tag = run.Tag,
		OnDeath = function()
			if not run.Ended then
				victory(run)
			end
		end,
	})
end

local function loop(run)
	local def = Config.Dungeons[run.Id]
	local nextAt = os.clock() + Config.DungeonCountdown
	while not run.Ended do
		task.wait(0.5)
		if run.Ended then
			break
		end
		local now = os.clock()
		local root = run.Player.Parent and rootOf(run.Player)
		if not run.Player.Parent then
			finish(run, false, nil)
			break
		end
		if not root or (root.Position - run.Info.Center).Magnitude > run.Info.Radius + 60 then
			finish(run, false, "Подземелье провалено: ты покинул арену.")
			break
		end
		if now >= run.Deadline then
			if run.Stage == "Victory" then
				finish(run, true, "Портал закрылся — ты вернулся на Поляну.")
			else
				finish(run, false, "Время вышло! Подземелье провалено.")
			end
			break
		end
		if run.Stage == "Countdown" or run.Stage == "Break" then
			if now >= nextAt then
				if run.Wave < #def.Waves then
					run.Wave = run.Wave + 1
					run.Stage = "Wave"
					spawnGroup(run, def.Waves[run.Wave])
					toast(run.Player, "Волна " .. run.Wave .. " из " .. (#def.Waves + 1) .. "!", "info")
				else
					spawnBoss(run)
				end
			end
		elseif run.Stage == "Wave" and run.Remaining <= 0 then
			run.Stage = "Break"
			nextAt = now + Config.DungeonWaveDelay
		end
		sendState(run)
	end
end

-- Возвращает (ok, сообщение). Проверки: уровень, не в бою, не в другом данже, жив, есть свободная арена.
function DungeonService.Enter(player, profile, dungeonId)
	local ok, message = Rules.CanEnterDungeon(profile, dungeonId)
	if not ok then
		return false, message
	end
	if byPlayer[player] then
		return false, "Ты уже в подземелье."
	end
	local root, character = rootOf(player)
	if not root then
		return false, "Сейчас нельзя войти в подземелье."
	end
	local combatAt = player:GetAttribute("GladeCombatAt")
	if combatAt and os.clock() - combatAt < Config.TeleportCombatSeconds then
		return false, "Нельзя войти в подземелье в бою. Подожди 8 секунд."
	end
	local slot = nil
	for index = 1, MAX_SLOTS do
		if not slots[index] then
			slot = index
			break
		end
	end
	if not slot then
		return false, "Все арены заняты. Попробуй через минуту."
	end
	local origin = Config.DungeonOrigin + Vector3.new(0, 0, (slot - 1) * Config.DungeonSlotSpacing)
	local built, info = pcall(DungeonWorld.Build, dungeonId, origin)
	if not built then
		warn("[GladeSlayer] Арена подземелья: " .. tostring(info))
		return false, "Не удалось построить арену. Попробуй ещё раз."
	end
	info.Folder.Parent = container
	nextRun = nextRun + 1
	local def = Config.Dungeons[dungeonId]
	local run = {
		Id = dungeonId, Player = player, Slot = slot, Info = info, Tag = "Dungeon" .. nextRun,
		Stage = "Countdown", Wave = 0, Remaining = 0, Total = 0, Ended = false, ChestOpened = false,
		Deadline = os.clock() + Config.DungeonCountdown + def.TimeLimit, Connections = {},
	}
	slots[slot] = run
	byPlayer[player] = run
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	table.insert(run.Connections, humanoid.Died:Connect(function()
		finish(run, false, "Ты пал в подземелье. Прокачайся и попробуй снова!")
	end))
	character:PivotTo(info.PlayerSpawn)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	sendState(run)
	task.spawn(loop, run)
	return true, "Подземелье: " .. def.Name .. ". Приготовься!"
end

function DungeonService.Leave(player)
	local run = byPlayer[player]
	if not run then
		return false, "Ты не в подземелье."
	end
	finish(run, false, "Ты покинул подземелье.")
	return true, ""
end

function DungeonService.Init(dataService, mobService, remotes)
	DataService = dataService
	MobService = mobService
	Remotes = remotes
	local old = workspace:FindFirstChild("GladeSlayerDungeons")
	if old then
		old:Destroy()
	end
	container = Instance.new("Folder")
	container.Name = "GladeSlayerDungeons"
	container.Parent = workspace
	local world = workspace:FindFirstChild("GladeSlayerWorld")
	if world then
		for _, prompt in ipairs(world:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") and prompt.Name == "DungeonEntrance" then
				local core = prompt.Parent
				prompt.Triggered:Connect(function(player)
					local root = rootOf(player)
					-- Prompt можно подделать: дистанцию перепроверяем на сервере.
					if root and core:IsA("BasePart") and (root.Position - core.Position).Magnitude <= 18 then
						Remotes.OpenShop:FireClient(player, "Dungeons")
					end
				end)
			end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local run = byPlayer[player]
		if run then
			finish(run, false, nil)
		end
	end)
end

return DungeonService
