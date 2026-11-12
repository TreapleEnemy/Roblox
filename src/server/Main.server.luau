-- GladeSlayer: точка входа сервера. Создаёт Remotes, строит карту, запускает сервисы и синхронизацию состояния.
-- Структура: ServerScriptService.GladeSlayerServer (этот Script + модули сервисов),
-- ReplicatedStorage.GladeSlayer (Config, Rules, Models, Animator + папка Remotes, которую создаёт этот скрипт).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Rules = require(Shared:WaitForChild("Rules"))

local Server = script.Parent
local WorldBuilder = require(Server:WaitForChild("WorldBuilder"))
local DataService = require(Server:WaitForChild("DataService"))
local CharacterService = require(Server:WaitForChild("CharacterService"))
local MobService = require(Server:WaitForChild("MobService"))
local CombatService = require(Server:WaitForChild("CombatService"))
local EconomyService = require(Server:WaitForChild("EconomyService"))
local NPCService = require(Server:WaitForChild("NPCService"))

local REMOTE_EVENTS = { "Attack", "State", "FX", "OpenShop", "Toast" }

-- Папка Remotes попадает в ReplicatedStorage только полностью собранной: клиент не увидит половину.
local function createRemotes()
	local old = Shared:FindFirstChild("Remotes")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	local remotes = {}
	for _, name in ipairs(REMOTE_EVENTS) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	local request = Instance.new("RemoteFunction")
	request.Name = "Request"
	request.Parent = folder
	remotes.Request = request
	folder.Parent = Shared
	return remotes
end

local Remotes = createRemotes()
Players.RespawnTime = 3

local built, buildError = pcall(WorldBuilder.Build)
if not built then
	warn("[GladeSlayer] Ошибка генерации карты: " .. tostring(buildError))
end

local function toast(player, text, kind)
	if player and player.Parent then
		Remotes.Toast:FireClient(player, text, kind or "info")
	end
end

DataService.Init({ Toast = toast })
CharacterService.Init(DataService)
MobService.Init(DataService, CharacterService, Remotes)
CombatService.Init(DataService, MobService, Remotes)
EconomyService.Init(DataService, Remotes)
NPCService.Start(Remotes)
require(Server:WaitForChild("TravelService")).Init(DataService, Remotes)
MobService.Start()
CharacterService.Start()
DataService.Start()

-- Синхронизация: изменения профиля собираются и уходят клиенту не чаще раза в 0.15 с.
local dirty = {}

local function sendState(player)
	local profile = DataService.Get(player)
	if profile and player.Parent then
		dirty[player] = nil
		Remotes.State:FireClient(player, Rules.ClientState(profile, os.clock()))
	end
end

DataService.OnChanged(function(player)
	dirty[player] = true
end)
EconomyService.OnSync = sendState

local function onPlayerAdded(player)
	if DataService.Load(player) and player.Parent then
		CharacterService.Apply(player, true)
		sendState(player)
		toast(player, "Добро пожаловать на Поляну! ЛКМ — удар, C — прокачка, B — инвентарь, E — торговцы.", "info")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	dirty[player] = nil
	DataService.Unload(player)
end)

game:BindToClose(function()
	DataService.Shutdown()
end)

task.spawn(function()
	while true do
		task.wait(0.15)
		local due = {}
		for player in pairs(dirty) do
			table.insert(due, player)
		end
		for _, player in ipairs(due) do
			if player.Parent then
				sendState(player)
			else
				dirty[player] = nil
			end
		end
	end
end)
