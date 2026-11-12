-- GladeSlayer: навигация гайда новичка. Светящийся 3D-луч (Beam) от персонажа к цели текущего шага
-- и парящая стрелка-маркер над целью. Всё создаётся только на клиенте и не влияет на сервер.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))

local Guide = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local BEAM_COLOR = rgb(255, 214, 90)
local MAX_DISTANCE = 600 -- дальше (другой остров, подземелье) луч не показываем

local target = nil
local holder = nil
local beam, playerAttachment, goalAttachment, marker, markerParts = nil, nil, nil, nil, {}

local function neon(parent, name, size, color, shape, className)
	local p = Instance.new(className or "Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function ensureWorld()
	if holder and holder.Parent then
		return
	end
	holder = Instance.new("Folder")
	holder.Name = "GladeGuide"
	holder.Parent = workspace
	local anchor = neon(holder, "GuideGoal", Vector3.new(0.2, 0.2, 0.2), BEAM_COLOR)
	anchor.Transparency = 1
	goalAttachment = Instance.new("Attachment")
	goalAttachment.Parent = anchor
	-- Маркер: светящееся кольцо на земле и стрелка-«наконечник» над целью.
	marker = Instance.new("Model")
	marker.Name = "GuideMarker"
	marker.Parent = holder
	markerParts = {
		Ring = neon(marker, "Ring", Vector3.new(0.2, 9, 9), BEAM_COLOR, Enum.PartType.Cylinder),
		Shaft = neon(marker, "Shaft", Vector3.new(0.9, 3, 0.9), BEAM_COLOR),
		HeadA = neon(marker, "HeadA", Vector3.new(0.9, 1.6, 1.4), BEAM_COLOR, nil, "WedgePart"),
		HeadB = neon(marker, "HeadB", Vector3.new(0.9, 1.6, 1.4), BEAM_COLOR, nil, "WedgePart"),
	}
	markerParts.Ring.Transparency = 0.45
	local light = Instance.new("PointLight")
	light.Color = BEAM_COLOR
	light.Range = 14
	light.Brightness = 2
	light.Parent = markerParts.Shaft
end

local function ensureBeam(root)
	if beam and beam.Parent and playerAttachment and playerAttachment.Parent == root then
		return
	end
	if beam then
		beam:Destroy()
	end
	if playerAttachment then
		playerAttachment:Destroy()
	end
	playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = "GuideFrom"
	playerAttachment.Position = Vector3.new(0, -2.4, 0)
	playerAttachment.Parent = root
	beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Attachment0 = playerAttachment
	beam.Attachment1 = goalAttachment
	beam.Color = ColorSequence.new(BEAM_COLOR, rgb(255, 255, 255))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.Segments = 24
	beam.CurveSize0 = 6
	beam.CurveSize1 = -6
	-- Текстура «искры» прокручивается вдоль луча: получается бегущий пунктир к цели.
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 3
	beam.TextureSpeed = 1.6
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.15, 0.1),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	beam.Parent = root
end

local function hide()
	if beam then
		beam.Enabled = false
	end
	if marker then
		for _, p in pairs(markerParts) do
			p.Transparency = 1
		end
		local light = markerParts.Shaft and markerParts.Shaft:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end
	end
end

-- Принимает состояние профиля от сервера и выбирает цель текущего шага гайда.
function Guide.SetState(state)
	if type(state) ~= "table" then
		return
	end
	local step = Config.Tutorial.Steps[state.Tutorial or 0]
	target = step and step.Target or nil
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not root or (root.Position - target).Magnitude > MAX_DISTANCE then
		hide()
		return
	end
	ensureWorld()
	ensureBeam(root)
	local t = os.clock()
	local ground = Vector3.new(target.X, Config.GroundY, target.Z)
	goalAttachment.Parent.CFrame = CFrame.new(ground + Vector3.new(0, 1, 0))
	local near = (Vector3.new(root.Position.X, Config.GroundY, root.Position.Z) - ground).Magnitude < 10
	beam.Enabled = not near
	local bob = math.sin(t * 3) * 0.8
	local top = ground + Vector3.new(0, 9 + bob, 0)
	markerParts.Ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(t, 0, 0)
	markerParts.Ring.Transparency = 0.35 + 0.25 * math.sin(t * 4)
	local spin = CFrame.Angles(0, t * 2, 0)
	markerParts.Shaft.CFrame = CFrame.new(top + Vector3.new(0, 1.5, 0)) * spin
	-- Наконечник смотрит вниз: два клина спинами друг к другу, острием к земле.
	local head = CFrame.new(top - Vector3.new(0, 0.8, 0)) * spin * CFrame.Angles(math.rad(180), 0, 0)
	markerParts.HeadA.CFrame = head * CFrame.new(0, 0, -0.7)
	markerParts.HeadB.CFrame = head * CFrame.new(0, 0, 0.7) * CFrame.Angles(0, math.rad(180), 0)
	for _, name in ipairs({ "Shaft", "HeadA", "HeadB" }) do
		markerParts[name].Transparency = 0
	end
	local light = markerParts.Shaft:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = true
	end
end)

return Guide
