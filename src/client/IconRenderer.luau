-- GladeSlayer: настоящие 3D-иконки через ViewportFrame + WorldModel + Camera.
-- Предметы рендерятся теми же процедурными моделями, что и в мире (Models.BuildItem);
-- для кнопок HUD собираются отдельные мини-модели: сундук, кристалл силы, тёмный портал с черепом, компас.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))

local IconRenderer = {}

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local M = Enum.Material
local rgb = Color3.fromRGB

local templates = {}
local spinning = {}

local function part(model, size, cframe, color, material, shape, className)
	local p = Instance.new(className or "Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- Равнобедренный треугольник (наконечник стрелы, шип короны) из двух клиньев: острие вверх, плоскость X-Y.
-- У WedgePart прямой угол на задней (+Z) грани, поэтому две половинки ставятся спинами к центру.
local function spike(model, width, height, cframe, color, material)
	local group = cframe * ANG(0, RAD(90), 0)
	part(model, V3(0.14, height, width / 2), group * CF(0, 0, -width / 4), color, material, nil, "WedgePart")
	part(model, V3(0.14, height, width / 2), group * CF(0, 0, width / 4) * ANG(0, RAD(180), 0), color, material, nil, "WedgePart")
end

local HUD_BUILDERS = {}

function HUD_BUILDERS.Inventory()
	local model = Instance.new("Model")
	local wood, trim, dark = rgb(150, 98, 52), rgb(255, 204, 80), rgb(96, 60, 32)
	part(model, V3(3.2, 1.8, 2), CF(0, 0, 0), wood, M.WoodPlanks)
	-- Цилиндр Roblox вытянут по X: полукруглая крышка вдоль сундука, нижняя половина спрятана в корпусе.
	part(model, V3(3.2, 2, 2), CF(0, 0.9, 0), wood, M.WoodPlanks, Enum.PartType.Cylinder)
	for _, x in ipairs({ -1.25, 0, 1.25 }) do
		part(model, V3(0.22, 1.86, 2.06), CF(x, 0, 0), trim, M.Metal)
		part(model, V3(0.24, 2.08, 2.08), CF(x, 0.9, 0), trim, M.Metal, Enum.PartType.Cylinder)
	end
	part(model, V3(3.26, 0.2, 2.06), CF(0, -0.85, 0), dark, M.Wood)
	part(model, V3(0.6, 0.7, 0.2), CF(0, 0.55, -1.05), trim, M.Metal)
	part(model, V3(0.18, 0.26, 0.08), CF(0, 0.5, -1.17), rgb(40, 30, 20), M.Metal)
	part(model, V3(0.5, 0.5, 0.5), CF(0, 1.2, -0.6), rgb(120, 230, 255), M.Neon, Enum.PartType.Ball)
	part(model, V3(0.35, 0.35, 0.35), CF(0.8, 1.05, -0.7), rgb(255, 220, 90), M.Neon, Enum.PartType.Ball)
	return model, V3(0.55, 0.45, -1)
end

function HUD_BUILDERS.Stats()
	local model = Instance.new("Model")
	local violet, green = rgb(170, 120, 255), rgb(110, 240, 140)
	-- Кристалл: два вытянутых ромба, повёрнутых друг к другу.
	part(model, V3(1.3, 1.3, 1.3), CF(-0.5, 0.2, 0) * ANG(0, RAD(45), 0) * ANG(RAD(45), 0, RAD(35)), violet, M.Neon)
	part(model, V3(1, 2.6, 1), CF(-0.5, 0.2, 0) * ANG(0, RAD(45), 0), violet, M.Glass).Transparency = 0.25
	part(model, V3(1.6, 0.4, 1.6), CF(-0.5, -1.3, 0) * ANG(0, RAD(45), 0), rgb(90, 80, 130), M.Slate)
	-- Стрелка вверх.
	part(model, V3(0.5, 1.9, 0.5), CF(1.2, -0.2, -0.2), green, M.Neon)
	spike(model, 1.5, 1.1, CF(1.2, 1.3, -0.2), green, M.Neon)
	local light = Instance.new("PointLight")
	light.Color = violet
	light.Parent = model:FindFirstChildWhichIsA("BasePart")
	return model, V3(0.25, 0.25, -1)
end

function HUD_BUILDERS.Dungeons()
	local model = Instance.new("Model")
	local stone, glow, bone, gold = rgb(70, 66, 84), rgb(170, 70, 255), rgb(236, 230, 214), rgb(255, 200, 70)
	for _, x in ipairs({ -1.5, 1.5 }) do
		part(model, V3(0.7, 3.6, 0.8), CF(x, 0, 0.5), stone, M.Slate)
	end
	part(model, V3(4, 0.7, 0.9), CF(0, 2, 0.5), stone, M.Slate)
	part(model, V3(2.3, 3.4, 0.2), CF(0, 0.1, 0.55), glow, M.Neon).Transparency = 0.15
	-- Череп с короной перед порталом.
	part(model, V3(1.6, 1.6, 1.6), CF(0, -0.4, -0.6), bone, M.SmoothPlastic, Enum.PartType.Ball)
	part(model, V3(1, 0.5, 0.9), CF(0, -1.15, -0.8), bone, M.SmoothPlastic)
	for _, x in ipairs({ -0.35, 0.35 }) do
		part(model, V3(0.42, 0.42, 0.2), CF(x, -0.3, -1.35), rgb(20, 10, 30), M.SmoothPlastic, Enum.PartType.Ball)
		part(model, V3(0.16, 0.16, 0.16), CF(x, -0.3, -1.45), rgb(255, 80, 80), M.Neon, Enum.PartType.Ball)
	end
	part(model, V3(1.5, 0.3, 1.4), CF(0, 0.45, -0.6), gold, M.Metal)
	for _, x in ipairs({ -0.55, 0, 0.55 }) do
		spike(model, 0.42, 0.6, CF(x, 0.88, -1.25), gold, M.Metal)
	end
	return model, V3(0.3, 0.2, -1)
end

function HUD_BUILDERS.Teleports()
	local model = Instance.new("Model")
	local gold, face = rgb(255, 196, 70), rgb(246, 240, 222)
	local facing = ANG(0, RAD(90), 0)
	part(model, V3(0.4, 3.4, 3.4), CF(0, 0, 0) * facing, gold, M.Metal, Enum.PartType.Cylinder)
	part(model, V3(0.42, 2.9, 2.9), CF(0, 0, -0.02) * facing, face, M.SmoothPlastic, Enum.PartType.Cylinder)
	part(model, V3(0.5, 0.5, 0.5), CF(0, 1.9, 0), gold, M.Metal, Enum.PartType.Ball)
	spike(model, 0.5, 1.2, CF(0, 0.6, -0.25), rgb(235, 60, 60), M.Neon)
	spike(model, 0.5, 1.2, CF(0, -0.6, -0.25) * ANG(0, 0, RAD(180)), rgb(70, 130, 255), M.Neon)
	part(model, V3(0.3, 0.3, 0.3), CF(0, 0, -0.3), gold, M.Metal, Enum.PartType.Ball)
	for i = 0, 3 do
		local a = i * math.pi / 2
		part(model, V3(0.12, 0.35, 0.05), CF(math.sin(a) * 1.2, math.cos(a) * 1.2, -0.25) * ANG(0, 0, -a), rgb(60, 50, 40), M.SmoothPlastic)
	end
	return model, V3(0.35, 0.3, -1)
end

function HUD_BUILDERS.Shop()
	local model = Instance.new("Model")
	local facing = ANG(0, RAD(90), 0)
	part(model, V3(0.4, 3, 3), CF(0, 0, 0) * facing, rgb(255, 200, 60), M.Metal, Enum.PartType.Cylinder)
	part(model, V3(0.44, 2.3, 2.3), CF(0, 0, 0) * facing, rgb(230, 170, 40), M.Metal, Enum.PartType.Cylinder)
	part(model, V3(0.4, 3, 3), CF(0.6, -0.7, 0.8) * facing * ANG(RAD(10), 0, 0), rgb(255, 214, 90), M.Metal, Enum.PartType.Cylinder)
	return model, V3(0.4, 0.3, -1)
end

local function makeViewport(parent, props)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon3D"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = rgb(140, 140, 156)
	viewport.LightColor = rgb(255, 246, 228)
	viewport.LightDirection = V3(-0.8, -1.3, 0.9)
	for key, value in pairs(props or {}) do
		viewport[key] = value
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
	return viewport, world, camera
end

-- Камера отъезжает так, чтобы описанная сфера модели целиком влезла в кадр.
local function frameCamera(model, camera, direction, zoom)
	local cframe, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(RAD(camera.FieldOfView / 2)) * (zoom or 1)
	camera.CFrame = CFrame.lookAt(cframe.Position + direction.Unit * distance, cframe.Position)
	return cframe.Position
end

local function anchorAll(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	return model
end

local function itemTemplate(itemId)
	local cached = templates[itemId]
	if cached then
		return cached.Model, cached.Direction
	end
	local def = Config.Items[itemId]
	local model = def and Models.BuildItem(itemId)
	if not model then
		return nil
	end
	anchorAll(model)
	local direction = V3(0.5, 0.4, -1)
	if def.Kind == "Gear" and def.Slot == "Weapon" then
		-- Клинок вдоль -Z: ставим его по диагонали остриём вверх-вправо, плашмя к камере.
		model:PivotTo(ANG(0, 0, RAD(-45)) * ANG(RAD(90), 0, 0))
		direction = V3(0.12, 0.08, -1)
	elseif def.Kind == "Gear" then
		model:PivotTo(ANG(0, RAD(-20), 0))
		direction = V3(0.2, 0.25, -1)
	end
	templates[itemId] = { Model = model, Direction = direction }
	return model, direction
end

-- 3D-иконка предмета. props — свойства ViewportFrame (Position, Size, ZIndex ...).
function IconRenderer.Item(parent, itemId, props)
	local template, direction = itemTemplate(itemId)
	local viewport, world, camera = makeViewport(parent, props)
	if template then
		local model = template:Clone()
		model.Parent = world
		frameCamera(model, camera, direction, 1.02)
	end
	return viewport
end

-- 3D-иконка кнопки HUD: Inventory, Stats, Dungeons, Teleports, Shop.
function IconRenderer.Hud(parent, kind, props)
	local builder = HUD_BUILDERS[kind] or HUD_BUILDERS.Inventory
	local model, direction = builder()
	local viewport, world, camera = makeViewport(parent, props)
	model.Parent = world
	frameCamera(model, camera, direction, 1)
	return viewport
end

-- Медленное вращение модели вокруг вертикали (превью в карточке предмета, наведение на кнопку HUD).
function IconRenderer.Spin(viewport, speed)
	if speed and speed ~= 0 then
		local world = viewport:FindFirstChildOfClass("WorldModel")
		local model = world and world:FindFirstChildOfClass("Model")
		if model then
			spinning[viewport] = { Model = model, Speed = speed, Base = model:GetPivot(), Center = model:GetBoundingBox().Position, Angle = 0 }
		end
	else
		local entry = spinning[viewport]
		if entry then
			entry.Model:PivotTo(entry.Base)
		end
		spinning[viewport] = nil
	end
end

RunService.RenderStepped:Connect(function(dt)
	for viewport, entry in pairs(spinning) do
		if not viewport.Parent or not entry.Model.Parent then
			spinning[viewport] = nil
		else
			entry.Angle = entry.Angle + dt * entry.Speed
			local center = CF(entry.Center)
			entry.Model:PivotTo(center * ANG(0, entry.Angle, 0) * center:Inverse() * entry.Base)
		end
	end
end)

return IconRenderer
