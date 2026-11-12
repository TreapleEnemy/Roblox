-- GladeSlayer: точка входа клиента. Ввод (ЛКМ/тап — удар, C — прокачка, B — инвентарь),
-- подписка на Remotes, полоска ХП, автозакрытие магазина при уходе от NPC.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local player = Players.LocalPlayer
local remoteFolder = Shared:WaitForChild("Remotes")
local Remotes = {}
for _, name in ipairs({ "Attack", "State", "FX", "OpenShop", "Toast", "Request" }) do
	Remotes[name] = remoteFolder:WaitForChild(name)
end

-- Удар: локальная анимация сразу, урон считает сервер (он же проверяет кулдаун и дистанцию).
local lastAttack = 0
local comboIndex = 0
local function attack()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local armed = (character:GetAttribute("Weapon") or "") ~= ""
	local cooldown = armed and Config.Combat.SwordCooldown or Config.Combat.FistCooldown
	local now = os.clock()
	if now - lastAttack < cooldown then
		return
	end
	lastAttack = now
	comboIndex = comboIndex + 1
	local style
	if armed then
		style = comboIndex % 2 == 1 and "SwordSlash1" or "SwordSlash2"
	else
		style = comboIndex % 2 == 1 and "PunchRight" or "PunchLeft"
	end
	Effects.LocalSwing(style)
	Remotes.Attack:FireServer()
end

UI.Init(Remotes, attack)
Effects.Start()

Remotes.State.OnClientEvent:Connect(UI.SetState)
Remotes.Toast.OnClientEvent:Connect(UI.Toast)
Remotes.OpenShop.OnClientEvent:Connect(UI.OpenShop)
Remotes.FX.OnClientEvent:Connect(Effects.Handle)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
  local position=UserInputService:GetMouseLocation()
  for _, object in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(position.X,position.Y)) do
   if object:IsA("GuiButton") or object:IsA("ScrollingFrame") or object:IsA("TextBox") then return end
  end
  attack()
	elseif input.KeyCode == Enum.KeyCode.C then
		UI.Toggle("Stats")
	elseif input.KeyCode == Enum.KeyCode.B then
		UI.Toggle("Inventory")
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		attack()
	end
end)

-- Полоска ХП следует за текущим персонажем.
local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local function update()
		UI.SetHealth(humanoid.Health, humanoid.MaxHealth)
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- Магазин закрывается, если игрок отошёл от торговца (сервер всё равно проверяет дистанцию).
task.spawn(function()
	while true do
		task.wait(0.5)
		local shop = UI.CurrentShop()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local npc = shop and Config.NPC[shop]
		if npc and root and (root.Position - npc.Position).Magnitude > Config.ShopDistance then
			UI.Close()
		end
	end
end)

-- Первичная синхронизация (сервер ответит событием State).
task.spawn(function()
	pcall(function()
		Remotes.Request:InvokeServer("Sync")
	end)
end)
