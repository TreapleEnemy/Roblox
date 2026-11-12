-- GladeSlayer: NPC-торговцы (Скупщик и Кузнец) с табличкой над головой и ProximityPrompt.
-- Prompt только открывает окно на клиенте; все сделки отдельно проверяются EconomyService (дистанция, монеты).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))

local NPCService = {}

local KINDS = { "Merchant", "Blacksmith" }
local ACCENT = {
	Merchant = Color3.fromRGB(255, 204, 84),
	Blacksmith = Color3.fromRGB(255, 132, 72),
}

local function nameplate(root, def, kind, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(240, 54)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 22
	nameLabel.TextColor3 = ACCENT[kind]
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = def.Name
	nameLabel.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 28)
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(240, 240, 240)
	title.TextStrokeTransparency = 0.4
	title.Text = def.Title
	title.Parent = gui
	gui.Parent = root
end

function NPCService.Start(remotes)
	local old = workspace:FindFirstChild("GladeSlayerNPCs")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "GladeSlayerNPCs"
	folder.Parent = workspace
	for _, kind in ipairs(KINDS) do
		local def = Config.NPC[kind]
		local model = Models.BuildNPC(kind)
		local root = model.PrimaryPart
		-- Стопы на уровне пола: корень = половина торса + длина ног (обе = Size.Y корня).
		local position = def.Position + Vector3.new(0, root.Size.Y * 1.5, 0)
		model:PivotTo(CFrame.lookAt(position, position + def.Facing))
		nameplate(root, def, kind, root.Size.Y * 1.6)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.ActionText = def.Prompt
		prompt.ObjectText = def.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(player)
			remotes.OpenShop:FireClient(player, kind)
		end)
		model.Parent = folder
	end
end

return NPCService
