-- GladeSlayer: процедурная стартовая локация «Поляна» — луг, тропы, лес, руины Стражей, лавки торговцев,
-- фонари, пруд и освещение (Lighting + Atmosphere + пост-эффекты). Всё из Part/материалов, без ассетов.
-- Соглашение: верхняя поверхность земли = Config.GroundY; позиции из Config с Y = GroundY стоят на полу.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))

local WorldBuilder = {}

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local M = Enum.Material
local rgb = Color3.fromRGB
local G = Config.GroundY

local world = nil
local rng = Random.new(1337)

local function part(parent, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function wedge(parent, name, size, cframe, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Parent = parent
	return p
end

local function cylinder(parent, name, height, diameter, position, color, material)
	return part(parent, name, V3(height, diameter, diameter), CF(position) * Models.UPRIGHT, color, material, Enum.PartType.Cylinder)
end

local function ball(parent, name, diameter, position, color, material)
	return part(parent, name, V3(diameter, diameter, diameter), CF(position), color, material, Enum.PartType.Ball)
end

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = world
	return f
end

local function decor(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function sign(parent, text, cframe, color)
	-- Таблички — чистый декор: без коллизии, чтобы никогда не перегораживать тропы.
	local board = decor(part(parent, "Sign", V3(9, 3, 0.4), cframe, rgb(120, 84, 50), M.WoodPlanks))
	for _, side in ipairs({ -1, 1 }) do
		decor(part(parent, "SignPost", V3(0.5, 5.5, 0.5), cframe * CF(side * 3.6, -2.2, 0.3), rgb(96, 66, 40), M.Wood))
	end
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.6
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = color or rgb(255, 236, 190)
		label.TextStrokeTransparency = 0.2
		label.Text = text
		label.Parent = gui
		gui.Parent = board
	end
	return board
end

-- Запретные для декора области: зоны мобов, спавн, лавки и тропы.
local function blocked(x, z, margin)
	local point = V3(x, G, z)
	for _, zone in pairs(Config.Zones) do
		if (V3(zone.Center.X, G, zone.Center.Z) - point).Magnitude < zone.Radius + margin then
			return true
		end
	end
	if (V3(Config.SpawnPosition.X, G, Config.SpawnPosition.Z) - point).Magnitude < 20 + margin then
		return true
	end
	for _, npc in pairs(Config.NPC) do
		if (V3(npc.Position.X, G, npc.Position.Z) - point).Magnitude < 16 + margin then
			return true
		end
	end
	if math.abs(x) < 8 + margin then
		return true
	end
	if math.abs(z - 74) < 6 + margin and math.abs(x) < 50 then
		return true
	end
	return false
end

-- Земля, границы, тропы ---------------------------------------------------------------------
local function buildGround()
	local f = folder("Ground")
	local size = Config.MapHalfSize * 2
	part(f, "Meadow", V3(size, 4, size), CF(0, G - 2, 0), rgb(98, 160, 72), M.Grass)
	-- Холмистая кромка вокруг поляны. Холмы не должны залезать в порталы и вход в подземелья.
	local keepClear = { V3(-94, G, 106), V3(94, G, 106), V3(40, G, 134) }
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local radius = Config.MapHalfSize - 6
		local height = rng:NextNumber(10, 22)
		local diameter = rng:NextNumber(30, 46)
		for _, point in ipairs(keepClear) do
			local center = V3(math.cos(angle) * radius, G, math.sin(angle) * radius)
			if (center - point).Magnitude < diameter / 2 + 12 then
				radius = Config.MapHalfSize + 8
				diameter = 24
			end
		end
		ball(f, "Hill", diameter, V3(math.cos(angle) * radius, G - 30 + height, math.sin(angle) * radius), rgb(84, 140, 62), M.Grass)
	end
	for _, data in ipairs({ { V3(0, 30, Config.MapHalfSize), V3(size, 60, 2) }, { V3(0, 30, -Config.MapHalfSize), V3(size, 60, 2) }, { V3(Config.MapHalfSize, 30, 0), V3(2, 60, size) }, { V3(-Config.MapHalfSize, 30, 0), V3(2, 60, size) } }) do
		local wall = part(f, "Boundary", data[2], CF(data[1]), rgb(255, 255, 255), M.SmoothPlastic)
		wall.Transparency = 1
	end
	local path = rgb(150, 118, 80)
	local function strip(name, from, to, width)
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		local p = part(f, name, V3(width, 0.2, length), CF(V3(mid.X, G + 0.05, mid.Z), V3(to.X, G + 0.05, to.Z)), path, M.Ground)
		decor(p)
		p.CanCollide = false
	end
	strip("PathMain", V3(0, 0, Config.SpawnPosition.Z), V3(0, 0, Config.Zones.Ruins.Center.Z + 26), 9)
	strip("PathShops", V3(-40, 0, 74), V3(40, 0, 74), 7)
	-- Площадь спавна.
	local plaza = cylinder(f, "SpawnPlaza", 0.4, 30, V3(Config.SpawnPosition.X, G + 0.1, Config.SpawnPosition.Z), rgb(150, 146, 136), M.Cobblestone)
	plaza.CanCollide = true
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GladeSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V3(8, 0.4, 8)
	spawn.CFrame = CF(Config.SpawnPosition.X, G + 0.3, Config.SpawnPosition.Z)
	spawn.Color = rgb(120, 200, 255)
	spawn.Material = M.Neon
	spawn.Transparency = 0.35
	spawn.Parent = f
	-- Фонтан-обелиск у спавна.
	cylinder(f, "Obelisk", 6, 1.6, V3(0, G + 3.2, Config.SpawnPosition.Z - 10), rgb(170, 166, 156), M.Marble)
	decor(ball(f, "ObeliskGem", 1.4, V3(0, G + 7, Config.SpawnPosition.Z - 10), rgb(120, 220, 255), M.Neon))
	-- Табличка на обочине справа от центральной тропы (тропа шириной 9 по оси X = 0), развёрнута к дорожке.
	sign(f, Config.GameName, CF(11, G + 5, Config.SpawnPosition.Z - 17) * ANG(0, RAD(160), 0), rgb(255, 230, 150))
end

-- Лес и мелкий декор ---------------------------------------------------------------------------
local function tree(f, x, z, scale)
	local trunkHeight = 7 * scale
	cylinder(f, "Trunk", trunkHeight, 1.6 * scale, V3(x, G + trunkHeight / 2, z), rgb(104, 72, 46), M.Wood)
	local leaf = rgb(rng:NextInteger(52, 78), rng:NextInteger(120, 160), rng:NextInteger(48, 66))
	local top = G + trunkHeight
	decor(ball(f, "Leaves", 7 * scale, V3(x, top + 1.5 * scale, z), leaf, M.Grass))
	decor(ball(f, "Leaves", 5 * scale, V3(x + 2 * scale, top, z + 1 * scale), Models.Shade(leaf, 1.1), M.Grass))
	decor(ball(f, "Leaves", 5 * scale, V3(x - 1.8 * scale, top + 0.5 * scale, z - 1.2 * scale), Models.Shade(leaf, 0.9), M.Grass))
	decor(ball(f, "Leaves", 4 * scale, V3(x, top + 4.2 * scale, z), Models.Shade(leaf, 1.15), M.Grass))
end

local function pine(f, x, z, scale)
	cylinder(f, "Trunk", 4 * scale, 1.2 * scale, V3(x, G + 2 * scale, z), rgb(94, 64, 40), M.Wood)
	local color = rgb(46, 104, 64)
	for i = 0, 2 do
		local width = (7 - i * 2) * scale
		local y = G + (3.5 + i * 3) * scale
		for _, yaw in ipairs({ 0, 90, 180, 270 }) do
			decor(wedge(f, "Needles", V3(width, 3.4 * scale, width / 2), CF(x, y, z) * ANG(0, RAD(yaw), 0) * CF(0, 0, -width / 4) * ANG(0, RAD(180), 0), Models.Shade(color, 1 - i * 0.06), M.Grass))
		end
	end
end

local function buildForest()
	local f = folder("Forest")
	local placed = 0
	local attempts = 0
	while placed < 85 and attempts < 2000 do
		attempts = attempts + 1
		local x = rng:NextNumber(-Config.MapHalfSize + 14, Config.MapHalfSize - 14)
		local z = rng:NextNumber(-Config.MapHalfSize + 14, Config.MapHalfSize - 14)
		if not blocked(x, z, 6) then
			local scale = rng:NextNumber(0.85, 1.35)
			if rng:NextNumber() < 0.35 then
				pine(f, x, z, scale)
			else
				tree(f, x, z, scale)
			end
			placed = placed + 1
		end
	end
	local d = folder("Details")
	local flowerColors = { rgb(255, 120, 150), rgb(255, 220, 90), rgb(180, 140, 255), rgb(255, 255, 255) }
	for _ = 1, 220 do
		local x = rng:NextNumber(-150, 150)
		local z = rng:NextNumber(-150, 150)
		if not blocked(x, z, 0) or rng:NextNumber() < 0.15 then
			local roll = rng:NextNumber()
			if roll < 0.55 then
				local stem = decor(part(d, "Stem", V3(0.15, 0.8, 0.15), CF(x, G + 0.4, z), rgb(70, 140, 60), M.Grass))
				stem.CastShadow = false
				decor(ball(d, "Flower", 0.5, V3(x, G + 0.9, z), flowerColors[rng:NextInteger(1, #flowerColors)], M.SmoothPlastic)).CastShadow = false
			elseif roll < 0.8 then
				decor(ball(d, "Bush", rng:NextNumber(2, 3.4), V3(x, G + 0.6, z), rgb(70, 132, 58), M.Grass))
			else
				local size = rng:NextNumber(1.5, 3.2)
				part(d, "Rock", V3(size, size * 0.6, size * 0.8), CF(x, G + size * 0.2, z) * ANG(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)), rgb(128, 128, 122), M.Slate)
			end
		end
	end
	-- Пруд.
	local pond = folder("Pond")
	cylinder(pond, "Shore", 0.3, 30, V3(78, G + 0.02, -20), rgb(160, 140, 100), M.Sand)
	local water = cylinder(pond, "Water", 0.3, 26, V3(78, G + 0.08, -20), rgb(70, 150, 200), M.Glass)
	water.Transparency = 0.25
	water.CanCollide = false
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		decor(cylinder(pond, "LilyPad", 0.1, 2, V3(78 + math.cos(angle) * 7, G + 0.25, -20 + math.sin(angle) * 7), rgb(70, 160, 70), M.Grass))
	end
end

-- Зоны мобов ---------------------------------------------------------------------------------
local function buildMeadow()
	local f = folder("SlimeMeadow")
	local zone = Config.Zones.Meadow
	local ring = cylinder(f, "MeadowGrass", 0.15, zone.Radius * 2 + 4, V3(zone.Center.X, G + 0.02, zone.Center.Z), rgb(120, 182, 82), M.Grass)
	decor(ring)
	for i = 0, 17 do
		local angle = i / 18 * math.pi * 2
		local x = zone.Center.X + math.cos(angle) * (zone.Radius + 3)
		local z = zone.Center.Z + math.sin(angle) * (zone.Radius + 3)
		if math.abs(x) > 6 then
			part(f, "FencePost", V3(0.6, 3, 0.6), CF(x, G + 1.5, z), rgb(120, 86, 52), M.Wood)
			local nextAngle = (i + 1) / 18 * math.pi * 2
			local nx = zone.Center.X + math.cos(nextAngle) * (zone.Radius + 3)
			local nz = zone.Center.Z + math.sin(nextAngle) * (zone.Radius + 3)
			if math.abs(nx) > 6 then
				local a, b = V3(x, G + 2.2, z), V3(nx, G + 2.2, nz)
				decor(part(f, "FenceRail", V3(0.3, 0.3, (b - a).Magnitude), CF((a + b) / 2, b), rgb(140, 100, 60), M.Wood))
			end
		end
	end
	sign(f, zone.Name .. "  •  ур. 1", CF(7, G + 4.5, zone.Center.Z + zone.Radius + 6) * ANG(0, RAD(180), 0) * ANG(0, RAD(180), 0))
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(6, zone.Radius - 4)
		decor(ball(f, "SlimePuddle", rng:NextNumber(1.5, 3), V3(zone.Center.X + math.cos(angle) * r, G - 0.3, zone.Center.Z + math.sin(angle) * r), rgb(110, 220, 90), M.Glass)).Transparency = 0.3
	end
end

local function buildRuins()
	local f = folder("GuardianRuins")
	local zone = Config.Zones.Ruins
	local c = zone.Center
	local stone = rgb(140, 138, 132)
	local floor = cylinder(f, "RuinsFloor", 0.4, zone.Radius * 2 + 8, V3(c.X, G + 0.05, c.Z), rgb(120, 118, 112), M.Cobblestone)
	floor.CanCollide = true
	-- Кольцо колонн: часть целые, часть сломаны, одна лежит.
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2 + 0.15
		local x = c.X + math.cos(angle) * (zone.Radius + 2)
		local z = c.Z + math.sin(angle) * (zone.Radius + 2)
		local entrance = z > c.Z and math.abs(x - c.X) < 8
		if not entrance then
			local height = (i % 3 == 0) and rng:NextNumber(3, 6) or rng:NextNumber(10, 16)
			part(f, "PillarBase", V3(3.4, 1, 3.4), CF(x, G + 0.5, z), Models.Shade(stone, 0.85), M.Slate)
			cylinder(f, "Pillar", height, 2.4, V3(x, G + 1 + height / 2, z), stone, M.Slate)
			if height > 9 then
				part(f, "Capital", V3(3.2, 0.8, 3.2), CF(x, G + 1.4 + height, z), Models.Shade(stone, 0.9), M.Slate)
				decor(part(f, "Moss", V3(3.3, 0.3, 3.3), CF(x, G + 1.9 + height, z), rgb(86, 140, 60), M.Grass))
			else
				part(f, "Rubble", V3(2, 1.2, 1.6), CF(x + 2, G + 0.6, z + 1) * ANG(0.3, 0.5, 0.2), stone, M.Slate)
			end
		end
	end
	part(f, "FallenPillar", V3(12, 2.4, 2.4), CF(c.X + 12, G + 1.2, c.Z - 8) * ANG(0, RAD(30), 0), stone, M.Slate).Shape = Enum.PartType.Cylinder
	-- Арка входа.
	local gateZ = c.Z + zone.Radius + 4
	for _, side in ipairs({ -1, 1 }) do
		part(f, "GatePillar", V3(3, 14, 3), CF(c.X + side * 7, G + 7, gateZ), stone, M.Slate)
	end
	part(f, "GateLintel", V3(18, 2.5, 3.4), CF(c.X, G + 15, gateZ), Models.Shade(stone, 0.9), M.Slate)
	decor(part(f, "GateRune", V3(3, 1.2, 0.2), CF(c.X, G + 15, gateZ + 1.75), rgb(90, 220, 255), M.Neon))
	-- Алтарь с руной.
	part(f, "AltarBase", V3(8, 1, 8), CF(c.X, G + 0.5, c.Z), Models.Shade(stone, 0.8), M.Slate)
	part(f, "Altar", V3(4, 2.4, 4), CF(c.X, G + 2.2, c.Z), stone, M.Marble)
	local rune = decor(ball(f, "RuneOrb", 2, V3(c.X, G + 5, c.Z), rgb(90, 220, 255), M.Neon))
	local light = Instance.new("PointLight")
	light.Color = rgb(90, 220, 255)
	light.Range = 22
	light.Brightness = 2
	light.Parent = rune
	sign(f, zone.Name .. "  •  ур. 8", CF(c.X + 12, G + 4.5, gateZ + 6) * ANG(0, RAD(180), 0) * ANG(0, RAD(180), 0), rgb(150, 230, 255))
end

-- Лавки торговцев -------------------------------------------------------------------------------
local function stall(f, npc, canopyA, canopyB, title)
	local pos = npc.Position
	local facing = npc.Facing
	local base = CF(V3(pos.X, G, pos.Z), V3(pos.X, G, pos.Z) + facing)
	-- Платформа и столбы.
	part(f, "Deck", V3(14, 0.6, 12), base * CF(0, 0.3, 2), rgb(130, 92, 58), M.WoodPlanks)
	for _, offset in ipairs({ V3(-6.5, 0, -3.5), V3(6.5, 0, -3.5), V3(-6.5, 0, 7.5), V3(6.5, 0, 7.5) }) do
		part(f, "Post", V3(0.8, 9, 0.8), base * CF(offset + V3(0, 4.5, 0)), rgb(110, 76, 46), M.Wood)
	end
	-- Полосатый навес из клиньев.
	for i = 0, 6 do
		local color = (i % 2 == 0) and canopyA or canopyB
		wedge(f, "Canopy", V3(2, 2.2, 6.5), base * CF(-6 + i * 2, 10.1, -0.8) * ANG(0, RAD(180), 0), color, M.Fabric)
		part(f, "CanopyBack", V3(2, 0.3, 6), base * CF(-6 + i * 2, 9.1, 4.8), color, M.Fabric)
	end
	-- Прилавок перед NPC.
	part(f, "Counter", V3(10, 3, 1.6), base * CF(0, 1.5 + 0.6, -3), rgb(150, 106, 66), M.WoodPlanks)
	part(f, "CounterTop", V3(10.6, 0.3, 2.2), base * CF(0, 3.75, -3), rgb(110, 76, 46), M.Wood)
	sign(f, title, base * CF(0, 12.6, -3.2) * ANG(0, RAD(180), 0), canopyA)
	return base
end

local function crate(f, cframe, size)
	part(f, "Crate", V3(size, size, size), cframe, rgb(160, 120, 70), M.WoodPlanks)
	decor(part(f, "CrateBand", V3(size + 0.1, 0.25, size + 0.1), cframe * CF(0, size * 0.3, 0), rgb(90, 64, 40), M.Wood))
end

local function buildShops()
	local f = folder("Shops")
	-- Скупщик.
	local merchant = Config.NPC.Merchant
	local mBase = stall(f, merchant, rgb(230, 190, 70), rgb(250, 245, 230), "СКУПЩИК")
	crate(f, mBase * CF(-4.5, 1.6, 4), 2)
	crate(f, mBase * CF(-4.2, 3.6, 4.2) * ANG(0, 0.4, 0), 1.6)
	cylinder(f, "Barrel", 2.8, 2.2, (mBase * CF(4.5, 2, 4)).Position, rgb(120, 80, 44), M.Wood)
	for i = 1, 3 do
		decor(ball(f, "Sack", 1.6, (mBase * CF(-2 + i * 1.3, 4.6, -3)).Position, rgb(200, 170, 110), M.Fabric))
	end
	local coins = decor(cylinder(f, "CoinPile", 0.5, 1.4, (mBase * CF(3, 4.15, -3)).Position, rgb(255, 210, 80), M.Metal))
	coins.Reflectance = 0.2
	-- Кузнец: горн с огнём, наковальня и стойка с оружием.
	local smith = Config.NPC.Blacksmith
	local sBase = stall(f, smith, rgb(180, 60, 50), rgb(60, 50, 50), "КУЗНИЦА")
	part(f, "Forge", V3(4, 4, 4), sBase * CF(-4, 2.6, 4.5), rgb(110, 100, 96), M.Brick)
	part(f, "Chimney", V3(2, 8, 2), sBase * CF(-4, 8.6, 5.5), rgb(100, 90, 86), M.Brick)
	local coal = decor(part(f, "Coals", V3(2.8, 0.4, 2.8), sBase * CF(-4, 4.8, 4.5), rgb(255, 120, 40), M.Neon))
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = rgb(255, 140, 50)
	fire.SecondaryColor = rgb(255, 60, 30)
	fire.Parent = coal
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 140, 60)
	glow.Range = 16
	glow.Brightness = 2.5
	glow.Parent = coal
	part(f, "AnvilBase", V3(1.4, 1.8, 1.4), sBase * CF(3.5, 1.5, 3), rgb(70, 66, 64), M.Slate)
	part(f, "Anvil", V3(1.6, 0.8, 3.2), sBase * CF(3.5, 2.8, 3), rgb(60, 62, 70), M.Metal)
	wedge(f, "AnvilHorn", V3(1.2, 0.8, 1.4), sBase * CF(3.5, 2.8, 1.0) * ANG(0, RAD(180), 0), rgb(60, 62, 70), M.Metal)
	-- Витрина: настоящие модели мечей из Models на прилавке и стойке.
	local display = { "IronSword", "KnightBlade" }
	for i, itemId in ipairs(display) do
		local model = Models.BuildItem(itemId)
		if model then
			Models.Anchor(model)
			model:PivotTo(sBase * CF(-2.5 + i * 2.5, 4.05, -3) * ANG(RAD(90), 0, RAD(90)) * ANG(0, RAD(90), 0))
			model.Parent = f
		end
	end
	local rack = part(f, "WeaponRack", V3(6, 0.4, 0.6), sBase * CF(1, 6.5, 7.2), rgb(110, 76, 46), M.Wood)
	rack.Name = "WeaponRack"
	for i, itemId in ipairs({ "OldSword", "IronSword", "KnightBlade" }) do
		local model = Models.BuildItem(itemId)
		if model then
			Models.Anchor(model)
			model:PivotTo(sBase * CF(-1 + i * 1.6, 6.8, 7) * ANG(RAD(-90), 0, 0))
			model.Parent = f
		end
	end
	for i, itemId in ipairs({ "CoinPotion", "RagePotion", "WisdomPotion" }) do
		local model = Models.BuildItem(itemId)
		if model then
			Models.Anchor(model)
			model:PivotTo(sBase * CF(-4.5 + i * 1.1, 4.45, -2.6))
			model.Parent = f
		end
	end
end

local function buildLanterns()
	local f = folder("Lanterns")
	local spots = {}
	for z = Config.SpawnPosition.Z - 22, Config.Zones.Ruins.Center.Z + 30, -26 do
		table.insert(spots, V3(-6.5, G, z))
		table.insert(spots, V3(6.5, G, z + 13))
	end
	table.insert(spots, V3(-24, G, 78.5))
	table.insert(spots, V3(24, G, 78.5))
	for _, spot in ipairs(spots) do
		cylinder(f, "LanternPost", 7, 0.5, spot + V3(0, 3.5, 0), rgb(50, 46, 44), M.Metal)
		part(f, "LanternCap", V3(1.4, 0.3, 1.4), CF(spot + V3(0, 7.9, 0)), rgb(50, 46, 44), M.Metal)
		local lamp = decor(part(f, "Lamp", V3(1, 1.2, 1), CF(spot + V3(0, 7.2, 0)), rgb(255, 214, 140), M.Neon))
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 200, 130)
		light.Range = 14
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = lamp
	end
end

-- Остров: океан (Terrain-вода), песчаный пляж, скалистые обрывы, водопад, островки, облака и цветочные поляны.
local function buildIsland()
	local f = folder("Island")
	local half = Config.MapHalfSize
	local waterY = G - 12
	-- Океан из воды Terrain — настоящие волны и отражения без ассетов.
	local terrain = workspace.Terrain
	pcall(function()
		terrain.WaterColor = rgb(40, 150, 170)
		terrain.WaterTransparency = 0.55
		terrain.WaterWaveSize = 0.25
		terrain.WaterWaveSpeed = 8
		terrain.WaterReflectance = 0.6
		terrain:FillBlock(CF(720, waterY - 10, 0), V3(2400, 20, 1600), M.Water)
		terrain:FillBlock(CF(720, waterY - 26, 0), V3(2400, 12, 1600), M.Sand)
	end)
	-- Пляж: песчаная кромка чуть ниже луга и уходящая под воду отмель.
	part(f, "Beach", V3(half * 2 + 24, 2, half * 2 + 24), CF(0, G - 1.6, 0), rgb(226, 206, 150), M.Sand)
	part(f, "Shallows", V3(half * 2 + 60, 2, half * 2 + 60), CF(0, waterY + 0.2, 0), rgb(214, 196, 140), M.Sand)
	-- Скалы-обрывы между пляжем и водой.
	local cliff = rgb(122, 116, 104)
	for i = 0, 63 do
		local angle = i / 64 * math.pi * 2
		local r = half + 16 + rng:NextNumber(-3, 4)
		local edge = math.max(math.abs(math.cos(angle)), math.abs(math.sin(angle)))
		local x, z = math.cos(angle) / edge * r, math.sin(angle) / edge * r
		local size = rng:NextNumber(9, 16)
		local rock = part(f, "Cliff", V3(size, rng:NextNumber(8, 13), size * 0.8), CF(x, waterY + 4, z) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), Models.Shade(cliff, rng:NextNumber(0.85, 1.1)), M.Rock)
		rock.CanCollide = false
		if i % 3 == 0 then
			decor(part(f, "CliffMoss", V3(size * 0.8, 0.6, size * 0.6), rock.CFrame * CF(0, rock.Size.Y / 2, 0), rgb(96, 150, 70), M.Grass))
		end
		-- Пальмы на пляже через одну.
		if i % 5 == 0 then
			local px, pz = math.cos(angle) / edge * (half + 6), math.sin(angle) / edge * (half + 6)
			local lean = ANG(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))
			local trunk = part(f, "PalmTrunk", V3(1, 12, 1), CF(px, G + 5, pz) * lean, rgb(150, 112, 70), M.Wood)
			local top = trunk.CFrame * CF(0, 6, 0)
			for k = 0, 5 do
				decor(wedge(f, "PalmLeaf", V3(0.3, 1.2, 6), top * ANG(0, k / 6 * math.pi * 2, 0) * CF(0, 0, -3) * ANG(RAD(-18), 0, 0), rgb(60, 150, 70), M.Grass))
			end
			decor(ball(f, "Coconut", 0.9, (top * CF(0.5, -0.6, 0.3)).Position, rgb(110, 76, 44), M.Wood))
		end
	end
	-- Водопад с утёса на северо-востоке в океан.
	local fallX, fallZ = half - 30, -half + 30
	part(f, "FallCliff", V3(26, 24, 18), CF(fallX, G + 8, fallZ) * ANG(0, RAD(45), 0), cliff, M.Rock)
	-- Ручей идёт по диагонали к краю острова (+X, -Z), там срывается вниз водопадом.
	local flow = ANG(0, RAD(-45), 0)
	local stream = decor(part(f, "Stream", V3(5, 0.4, 62), CF(fallX + 22, G + 20.3, fallZ - 22) * flow, rgb(110, 200, 230), M.Glass))
	stream.Transparency = 0.3
	part(f, "FallLedge", V3(12, G + 20 - waterY, 12), CF(fallX + 40, (G + 20 + waterY) / 2, fallZ - 40) * flow, cliff, M.Rock)
	local fall = decor(part(f, "Waterfall", V3(5, G + 20 - waterY, 1), CF(fallX + 44.5, (G + 20 + waterY) / 2, fallZ - 44.5) * flow, rgb(200, 240, 255), M.Glass))
	fall.Transparency = 0.25
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(rgb(240, 250, 255))
	mist.Size = NumberSequence.new(2, 6)
	mist.Transparency = NumberSequence.new(0.5, 1)
	mist.Lifetime = NumberRange.new(1, 2)
	mist.Rate = 18
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Parent = fall
	-- Маленькие островки в океане.
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2 + 0.4
		local r = half + rng:NextNumber(70, 140)
		local pos = V3(math.cos(angle) * r, waterY, math.sin(angle) * r)
		local d = rng:NextNumber(18, 34)
		local islet = part(f, "Islet", V3(d * 0.35, d, d), CF(pos) * Models.UPRIGHT, rgb(222, 200, 146), M.Sand, Enum.PartType.Cylinder)
		islet.CanCollide = false
		local topY = waterY + d * 0.175
		decor(ball(f, "IsletRock", d * 0.4, V3(pos.X + d * 0.2, topY, pos.Z), cliff, M.Rock))
		decor(part(f, "IsletTrunk", V3(1, 8, 1), CF(pos.X - d * 0.1, topY + 4, pos.Z) * ANG(0, 0, 0.2), rgb(150, 112, 70), M.Wood))
		decor(ball(f, "IsletLeaves", 6, V3(pos.X - d * 0.1 - 0.8, topY + 8.5, pos.Z), rgb(70, 160, 72), M.Grass))
	end
	-- Цветочные поляны и высокая трава на открытых местах.
	local colors = { rgb(255, 130, 170), rgb(255, 230, 110), rgb(170, 140, 255), rgb(255, 255, 255), rgb(255, 160, 80) }
	for _ = 1, 26 do
		local cx, cz = rng:NextNumber(-half + 20, half - 20), rng:NextNumber(-half + 20, half - 20)
		if not blocked(cx, cz, 2) then
			local color = colors[rng:NextInteger(1, #colors)]
			for _ = 1, 9 do
				local x, z = cx + rng:NextNumber(-4, 4), cz + rng:NextNumber(-4, 4)
				decor(wedge(f, "Grass", V3(0.2, rng:NextNumber(1, 1.8), 0.6), CF(x, G + 0.6, z) * ANG(0, rng:NextNumber(0, 6.28), 0), rgb(90, 170, 70), M.Grass)).CastShadow = false
				decor(ball(f, "Bloom", 0.45, V3(x + 0.3, G + 1, z), color, M.SmoothPlastic)).CastShadow = false
			end
		end
	end
	-- Процедурные облака Terrain (без текстур).
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = rgb(255, 252, 245)
	clouds.Parent = terrain
end

function WorldBuilder.ApplyLighting()
	Lighting.ClockTime = 16.1
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = rgb(70, 74, 86)
	Lighting.OutdoorAmbient = rgb(128, 132, 140)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	for _, name in ipairs({ "GladeAtmosphere", "GladeBloom", "GladeColor", "GladeSunRays", "GladeSky" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "GladeAtmosphere"
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(199, 214, 230)
	atmosphere.Decay = rgb(106, 128, 150)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GladeBloom"
	bloom.Intensity = 0.38
	bloom.Size = 28
	bloom.Threshold = 1.35
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "GladeColor"
	color.Saturation = 0.14
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = rgb(255, 250, 240)
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "GladeSunRays"
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

function WorldBuilder.Build()
	-- Убираем стандартные Baseplate/SpawnLocation шаблона, чтобы игрок появлялся на нашей площади.
	for _, name in ipairs({ "Baseplate", "SpawnLocation", "GladeSlayerWorld" }) do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	world = Instance.new("Folder")
	world.Name = "GladeSlayerWorld"
	buildGround()
	buildForest()
	buildMeadow()
	buildRuins()
	buildShops()
	buildLanterns()
	buildIsland()
	require(script.Parent:WaitForChild("ExpansionWorld")).Build(world)
	world.Parent = workspace
	WorldBuilder.ApplyLighting()
	return world
end

return WorldBuilder
