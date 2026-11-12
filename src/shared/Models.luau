-- GladeSlayer: процедурные 3D-модели из Part/WedgePart/WeldConstraint — без мешей и ассетов.
-- Предметы (мечи, броня, амулеты, зелья, хлам), мобы (Слизень, Страж руин) и NPC (Скупщик, Кузнец).
-- Риги мобов/NPC используют имена суставов R6 (RootJoint, Neck, Right Shoulder...), поэтому их
-- анимирует тот же Animator, что и игроков. Все суставы без поворота в C0: поза задаётся в пространстве торса.
local Config = require(script.Parent:WaitForChild("Config"))

local Models = {}

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local M = Enum.Material
local rgb = Color3.fromRGB

local function shade(color, factor)
	return Color3.new(math.clamp(color.R * factor, 0, 1), math.clamp(color.G * factor, 0, 1), math.clamp(color.B * factor, 0, 1))
end
Models.Shade = shade

-- Цилиндр Roblox вытянут по X: UPRIGHT ставит его вертикально, FACING — вдоль Z (вперёд).
local UPRIGHT = ANG(0, 0, RAD(90))
local FACING = ANG(0, RAD(90), 0)
Models.UPRIGHT = UPRIGHT
Models.FACING = FACING

local function make(className, model, name, size, cframe, color, material, props)
	local p = Instance.new(className)
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	if props then
		for key, value in pairs(props) do
			p[key] = value
		end
	end
	p.Parent = model
	return p
end

local function block(model, name, size, cframe, color, material, props)
	return make("Part", model, name, size, cframe, color, material, props)
end

local function wedge(model, name, size, cframe, color, material, props)
	return make("WedgePart", model, name, size, cframe, color, material, props)
end

local function ball(model, name, d, cframe, color, material, props)
	local p = make("Part", model, name, V3(d, d, d), cframe, color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

local function cylinder(model, name, length, d, cframe, color, material, props)
	local p = make("Part", model, name, V3(length, d, d), cframe, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
	return w
end
Models.Weld = weld

-- Приваривает все детали модели к опорной детали.
local function weldAll(model, root)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item ~= root then
			weld(root, item)
		end
	end
end

-- Приваривает список деталей к одной (для частей рига, двигающихся вместе с конечностью).
local function weldGroup(list, anchor)
	for _, item in ipairs(list) do
		if item ~= anchor then
			weld(anchor, item)
		end
	end
end

local function motor(name, part0, part1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

-- Предметы -------------------------------------------------------------------------------------
local SWORDS = {
	OldSword = { Blade = rgb(132, 120, 104), Edge = rgb(160, 128, 96), Guard = rgb(92, 74, 56), Grip = rgb(88, 58, 38), Length = 3.2, Width = 0.32, Trail = rgb(200, 160, 120), Rust = true },
	IronSword = { Blade = rgb(196, 204, 214), Edge = rgb(236, 240, 246), Guard = rgb(110, 114, 124), Grip = rgb(70, 46, 30), Length = 3.8, Width = 0.36, Trail = rgb(220, 232, 255) },
	KnightBlade = { Blade = rgb(214, 224, 238), Edge = rgb(250, 252, 255), Guard = rgb(230, 186, 80), Grip = rgb(40, 52, 110), Length = 4.6, Width = 0.4, Trail = rgb(120, 180, 255), Gem = rgb(70, 140, 255) },
}

function Models.SwordTrailColor(itemId)
	local spec = SWORDS[itemId]
	return spec and spec.Trail or rgb(255, 255, 255)
end

-- Меч: рукоять в начале координат, клинок смотрит вдоль -Z (вперёд от кисти).
local function buildSword(itemId)
	local spec = SWORDS[itemId] or SWORDS.OldSword
	local model = Instance.new("Model")
	model.Name = itemId
	local handle = cylinder(model, "Handle", 1.1, 0.26, CF(0, 0, 0.1) * FACING, spec.Grip, M.Fabric)
	ball(model, "Pommel", 0.38, CF(0, 0, 0.72), spec.Guard, M.Metal)
	block(model, "Guard", V3(1.3, 0.22, 0.26), CF(0, 0, -0.5), spec.Guard, M.Metal)
	block(model, "GuardCore", V3(0.4, 0.34, 0.34), CF(0, 0, -0.5), shade(spec.Guard, 0.8), M.Metal)
	local length = spec.Length
	local bladeZ = -0.62 - length / 2
	local bladeMat = spec.Material or M.Metal
	local edgeMat = spec.EdgeMaterial or M.Metal
	local bladeProps = spec.Transparency and { Transparency = spec.Transparency } or nil
	if spec.Curve then
		-- Хопеш: клинок из наклонных сегментов, изгибающихся в сторону.
		local segs = 5
		local segLen = length / segs
		for i = 1, segs do
			local bend = (i / segs) ^ 2 * 0.9
			local z = -0.62 - segLen * (i - 0.5)
			local angle = RAD(-8 - i * 3)
			block(model, "Blade", V3(spec.Width, 0.08, segLen * 1.15), CF(bend, 0, z) * ANG(0, angle, 0), spec.Blade, bladeMat, bladeProps)
			block(model, "EdgeR", V3(0.06, 0.06, segLen * 1.15), CF(bend + spec.Width / 2, 0, z) * ANG(0, angle, 0), spec.Edge, edgeMat)
		end
		block(model, "CurveTip", V3(spec.Width * 0.7, 0.08, 0.5), CF(1.05, 0, -0.62 - length - 0.1) * ANG(0, RAD(-52), 0), spec.Edge, edgeMat)
	else
		block(model, "Blade", V3(spec.Width, 0.08, length), CF(0, 0, bladeZ), spec.Blade, bladeMat, bladeProps)
		block(model, "Fuller", V3(spec.Width * 0.3, 0.1, length * 0.8), CF(0, 0, bladeZ + length * 0.05), shade(spec.Blade, 0.75), bladeMat, bladeProps)
		block(model, "EdgeL", V3(0.06, 0.06, length), CF(-spec.Width / 2, 0, bladeZ), spec.Edge, edgeMat)
		block(model, "EdgeR", V3(0.06, 0.06, length), CF(spec.Width / 2, 0, bladeZ), spec.Edge, edgeMat)
	end
	if spec.Glow then
		block(model, "GlowCore", V3(spec.Width * 0.22, 0.12, length * 0.9), CF(0, 0, bladeZ), spec.Glow, M.Neon)
	end
	if spec.Teeth then
		for i = 1, 4 do
			block(model, "Tooth", V3(0.12, 0.1, 0.28), CF(spec.Width / 2 + 0.07, 0, -0.9 - i * length / 5) * ANG(0, RAD(30), 0), spec.Blade, bladeMat)
		end
	end
	if spec.Runes then
		for i = 1, 5 do
			block(model, "Rune", V3(spec.Width * 0.5, 0.13, 0.16), CF(0, 0, -1.0 - i * length / 6.5) * ANG(0, RAD(i % 2 * 40 - 20), 0), spec.Runes[i % #spec.Runes + 1], M.Neon)
		end
		for _, side in ipairs({ -1, 1 }) do
			wedge(model, "Wing", V3(0.1, 0.5, 0.9), CF(side * 0.85, 0, -0.5) * ANG(0, 0, RAD(side * 90)), spec.Edge, spec.EdgeMaterial or M.Metal)
		end
	end
	if not spec.Curve then
		wedge(model, "TipL", V3(0.08, spec.Width / 2, 0.6), CF(-spec.Width / 4, 0, -0.62 - length - 0.3) * ANG(0, 0, RAD(90)), spec.Edge, edgeMat)
		wedge(model, "TipR", V3(0.08, spec.Width / 2, 0.6), CF(spec.Width / 4, 0, -0.62 - length - 0.3) * ANG(0, 0, RAD(-90)), spec.Edge, edgeMat)
	end
	if spec.Rust then
		for i = 1, 3 do
			block(model, "Rust", V3(spec.Width * 0.55, 0.1, 0.35), CF((i % 2 - 0.5) * 0.08, 0, -1.0 - i * 0.75), rgb(140, 78, 40), M.CorrodedMetal)
		end
		wedge(model, "Notch", V3(0.1, 0.16, 0.22), CF(spec.Width / 2, 0, -2.1) * ANG(0, 0, RAD(90)), rgb(60, 50, 44), M.Metal)
	end
	if spec.Gem then
		ball(model, "Gem", 0.3, CF(0, 0, -0.5), spec.Gem, M.Neon)
		block(model, "GuardTipL", V3(0.24, 0.24, 0.24), CF(-0.66, 0, -0.5) * ANG(0, RAD(45), 0), spec.Guard, M.Metal)
		block(model, "GuardTipR", V3(0.24, 0.24, 0.24), CF(0.66, 0, -0.5) * ANG(0, RAD(45), 0), spec.Guard, M.Metal)
	end
	model.PrimaryPart = handle
	weldAll(model, handle)
	model:SetAttribute("ItemId", itemId)
	return model
end

SWORDS.DuneBlade = { Blade = rgb(240, 208, 135), Edge = rgb(255, 245, 210), Guard = rgb(170, 116, 42), Grip = rgb(85, 60, 40), Length = 4.7, Width = 0.48, Trail = rgb(255, 221, 105), Gem = rgb(255, 216, 90) }
SWORDS.ObsidianBlade = { Blade = rgb(45, 35, 63), Edge = rgb(235, 96, 62), Guard = rgb(85, 65, 100), Grip = rgb(40, 28, 35), Length = 5, Width = 0.52, Trail = rgb(255, 100, 55), Gem = rgb(255, 80, 30) }
SWORDS.Cataclysm = { Blade = rgb(94, 48, 40), Edge = rgb(255, 211, 92), Guard = rgb(246, 181, 52), Grip = rgb(64, 26, 35), Length = 5.4, Width = 0.6, Trail = rgb(255, 194, 54), Gem = rgb(255, 234, 126) }
SWORDS.BoneCleaver = { Blade = rgb(228, 222, 204), Edge = rgb(250, 246, 232), Guard = rgb(120, 108, 92), Grip = rgb(70, 54, 40), Length = 3.6, Width = 0.95, Trail = rgb(235, 230, 210), Teeth = true }
SWORDS.PharaohKhopesh = { Blade = rgb(236, 190, 60), Edge = rgb(255, 240, 160), Guard = rgb(40, 90, 160), Grip = rgb(60, 40, 90), Length = 4.2, Width = 0.5, Trail = rgb(255, 214, 90), Curve = true, Gem = rgb(60, 200, 255) }
SWORDS.ForgeBlade = { Blade = rgb(40, 36, 44), Edge = rgb(255, 120, 30), Guard = rgb(70, 60, 66), Grip = rgb(34, 24, 24), Length = 5.0, Width = 0.58, Trail = rgb(255, 130, 40), EdgeMaterial = M.Neon, Gem = rgb(255, 150, 40) }
SWORDS.FrostBlade = { Blade = rgb(150, 215, 255), Edge = rgb(225, 248, 255), Guard = rgb(110, 170, 220), Grip = rgb(36, 60, 100), Length = 5.2, Width = 0.58, Trail = rgb(140, 220, 255), Material = M.Glass, Transparency = 0.35, EdgeMaterial = M.Neon, Glow = rgb(120, 220, 255), Gem = rgb(160, 240, 255) }
SWORDS.EternalWinter = { Blade = rgb(214, 240, 255), Edge = rgb(255, 255, 255), Guard = rgb(130, 200, 255), Grip = rgb(30, 40, 90), Length = 6.2, Width = 0.7, Trail = rgb(255, 150, 240), Material = M.Glass, Transparency = 0.25, EdgeMaterial = M.Neon, Glow = rgb(150, 235, 255), Gem = rgb(255, 110, 220), Runes = { rgb(255, 110, 220), rgb(110, 240, 255) } }
local ARMORS = {
	BeggarRags = { Main = rgb(150, 126, 96), Trim = rgb(110, 84, 56), Material = M.Fabric, Belt = rgb(170, 140, 90), Patches = true },
	LeatherVest = { Main = rgb(120, 74, 42), Trim = rgb(84, 50, 28), Material = M.Leather, Belt = rgb(60, 40, 26), Pads = rgb(100, 62, 36) },
	ChainMail = { Main = rgb(150, 156, 166), Trim = rgb(110, 116, 128), Material = M.DiamondPlate, Belt = rgb(70, 50, 34), Pads = rgb(190, 196, 206) },
	AshenPlate = { Main = rgb(30, 28, 34), Trim = rgb(60, 52, 58), Material = M.Basalt, Belt = rgb(255, 110, 30), Pads = rgb(48, 42, 52), Glow = rgb(255, 110, 30), Spikes = true },
	CitadelPlate = { Main = rgb(70, 110, 170), Trim = rgb(150, 190, 235), Material = M.DiamondPlate, Belt = rgb(40, 56, 96), Pads = rgb(110, 160, 220), Glow = rgb(120, 220, 255), Emblem = true },
}

-- Броня: «Handle» совпадает с центром торса (torsoSize — размер торса/UpperTorso носителя).
local function buildArmor(itemId, torsoSize)
	local spec = ARMORS[itemId] or ARMORS.BeggarRags
	local t = torsoSize or V3(2, 2, 1)
	local model = Instance.new("Model")
	model.Name = itemId
	local handle = block(model, "Handle", V3(t.X + 0.12, t.Y * 0.92, t.Z + 0.12), CF(0, 0, 0), spec.Main, spec.Material)
	block(model, "Belt", V3(t.X + 0.18, t.Y * 0.14, t.Z + 0.18), CF(0, -t.Y * 0.32, 0), spec.Belt, M.Leather)
	block(model, "Buckle", V3(0.36, t.Y * 0.16, 0.1), CF(0, -t.Y * 0.32, -t.Z / 2 - 0.1), rgb(200, 170, 90), M.Metal)
	block(model, "Collar", V3(t.X * 0.6, t.Y * 0.1, t.Z + 0.16), CF(0, t.Y * 0.44, 0), spec.Trim, spec.Material)
	if spec.Patches then
		block(model, "Patch", V3(0.5, 0.5, 0.06), CF(-t.X * 0.22, t.Y * 0.1, -t.Z / 2 - 0.08) * ANG(0, 0, RAD(12)), rgb(120, 140, 110), M.Fabric)
		block(model, "Patch", V3(0.4, 0.36, 0.06), CF(t.X * 0.25, -t.Y * 0.08, -t.Z / 2 - 0.08) * ANG(0, 0, RAD(-8)), rgb(170, 110, 90), M.Fabric)
		block(model, "Rope", V3(0.1, t.Y * 0.4, 0.08), CF(t.X * 0.1, -t.Y * 0.5, -t.Z / 2 - 0.12), rgb(196, 170, 120), M.Fabric)
	end
	if spec.Pads then
		for _, side in ipairs({ -1, 1 }) do
			block(model, "Pauldron", V3(t.X * 0.42, t.Y * 0.2, t.Z + 0.4), CF(side * t.X * 0.52, t.Y * 0.46, 0) * ANG(0, 0, RAD(-side * 14)), spec.Pads, M.Metal)
		end
	end
	if spec.Spikes then
		for _, side in ipairs({ -1, 1 }) do
			wedge(model, "Spike", V3(0.2, t.Y * 0.32, 0.3), CF(side * t.X * 0.6, t.Y * 0.66, 0) * ANG(0, 0, RAD(-side * 20)), spec.Trim, M.Metal)
		end
	end
	if spec.Glow then
		block(model, "GlowVein", V3(0.1, t.Y * 0.5, 0.06), CF(0, t.Y * 0.05, -t.Z / 2 - 0.1), spec.Glow, M.Neon)
		block(model, "GlowBar", V3(t.X * 0.55, 0.1, 0.06), CF(0, t.Y * 0.18, -t.Z / 2 - 0.1), spec.Glow, M.Neon)
	end
	if spec.Emblem then
		for _, side in ipairs({ -1, 1 }) do
			block(model, "Plate", V3(t.X * 0.38, t.Y * 0.4, 0.08), CF(side * t.X * 0.24, -t.Y * 0.05, -t.Z / 2 - 0.1), spec.Trim, M.Metal)
		end
	end
	model.PrimaryPart = handle
	weldAll(model, handle)
	model:SetAttribute("ItemId", itemId)
	return model
end

local AMULETS = {
	BeggarAmulet = { Chain = rgb(150, 120, 80), Medal = rgb(120, 100, 70), Stone = rgb(90, 110, 80) },
	HunterCharm = { Chain = rgb(230, 190, 80), Medal = rgb(240, 206, 110), Stone = rgb(170, 90, 255), Fang = true },
	BoneCharm = { Chain = rgb(150, 130, 100), Medal = rgb(200, 190, 170), Stone = rgb(110, 255, 140), Skull = true },
	SandKingMask = { Chain = rgb(230, 190, 80), Medal = rgb(240, 200, 90), Stone = rgb(80, 220, 255), Mask = true },
	WinterRune = { Chain = rgb(170, 210, 240), Medal = rgb(120, 170, 220), Stone = rgb(150, 235, 255), Crystal = true },
}

-- Амулет висит на груди: «Handle» — центр торса, медальон спереди.
local function buildAccessory(itemId, torsoSize)
	local spec = AMULETS[itemId] or AMULETS.BeggarAmulet
	local t = torsoSize or V3(2, 2, 1)
	local model = Instance.new("Model")
	model.Name = itemId
	local handle = block(model, "Handle", V3(0.2, 0.2, 0.2), CF(0, 0, 0), spec.Chain, M.Metal, { Transparency = 1 })
	local front = -t.Z / 2 - 0.12
	block(model, "ChainL", V3(0.08, t.Y * 0.45, 0.08), CF(-t.X * 0.16, t.Y * 0.22, front) * ANG(0, 0, RAD(-24)), spec.Chain, M.Metal)
	block(model, "ChainR", V3(0.08, t.Y * 0.45, 0.08), CF(t.X * 0.16, t.Y * 0.22, front) * ANG(0, 0, RAD(24)), spec.Chain, M.Metal)
	cylinder(model, "Medal", 0.1, 0.62, CF(0, -0.02, front) * FACING, spec.Medal, M.Metal)
	ball(model, "Stone", 0.26, CF(0, -0.02, front - 0.08), spec.Stone, M.Neon)
	if spec.Skull then
		ball(model, "Skull", 0.5, CF(0, -0.02, front - 0.2), rgb(236, 230, 212), M.SmoothPlastic)
		block(model, "Jaw", V3(0.3, 0.14, 0.26), CF(0, -0.26, front - 0.2), rgb(220, 214, 196), M.SmoothPlastic)
		block(model, "SocketL", V3(0.12, 0.12, 0.06), CF(-0.1, 0, front - 0.43), rgb(20, 18, 20), M.SmoothPlastic)
		block(model, "SocketR", V3(0.12, 0.12, 0.06), CF(0.1, 0, front - 0.43), rgb(20, 18, 20), M.SmoothPlastic)
	end
	if spec.Mask then
		block(model, "MaskFace", V3(0.9, 1.0, 0.1), CF(0, -0.1, front - 0.1), spec.Medal, M.Metal)
		block(model, "MaskStripeA", V3(0.9, 0.12, 0.12), CF(0, 0.2, front - 0.16), rgb(40, 90, 170), M.Metal)
		block(model, "MaskStripeB", V3(0.9, 0.12, 0.12), CF(0, -0.15, front - 0.16), rgb(40, 90, 170), M.Metal)
		block(model, "EyeL", V3(0.16, 0.08, 0.06), CF(-0.2, 0.05, front - 0.2), spec.Stone, M.Neon)
		block(model, "EyeR", V3(0.16, 0.08, 0.06), CF(0.2, 0.05, front - 0.2), spec.Stone, M.Neon)
		wedge(model, "Beard", V3(0.2, 0.6, 0.12), CF(0, -0.8, front - 0.12) * ANG(RAD(180), 0, 0), spec.Medal, M.Metal)
	end
	if spec.Crystal then
		for i = -1, 1 do
			wedge(model, "IceShard", V3(0.16, 0.5 + (1 - math.abs(i)) * 0.35, 0.2), CF(i * 0.2, 0.05 + (1 - math.abs(i)) * 0.1, front - 0.2) * ANG(0, 0, RAD(-i * 14)), spec.Stone, M.Glass, { Transparency = 0.25 })
		end
	end
	if spec.Fang then
		wedge(model, "Fang", V3(0.12, 0.42, 0.16), CF(0, -0.46, front) * ANG(RAD(180), 0, 0), rgb(240, 236, 220), M.SmoothPlastic)
		cylinder(model, "Inner", 0.15, 0.66, CF(0, -0.02, front + 0.02) * FACING, rgb(190, 146, 52), M.Metal)
	end
	model.PrimaryPart = handle
	weldAll(model, handle)
	model:SetAttribute("ItemId", itemId)
	return model
end

local POTIONS = {
	CoinPotion = rgb(255, 204, 70),
	RagePotion = rgb(255, 70, 70),
	WisdomPotion = rgb(90, 140, 255),
}

local function buildPotion(itemId)
	local color = POTIONS[itemId] or rgb(200, 200, 200)
	local model = Instance.new("Model")
	model.Name = itemId
	local handle = ball(model, "Handle", 0.9, CF(0, 0, 0), rgb(220, 240, 255), M.Glass, { Transparency = 0.45 })
	ball(model, "Liquid", 0.72, CF(0, -0.05, 0), color, M.Neon)
	cylinder(model, "Neck", 0.4, 0.3, CF(0, 0.55, 0) * UPRIGHT, rgb(220, 240, 255), M.Glass, { Transparency = 0.45 })
	cylinder(model, "Cork", 0.22, 0.26, CF(0, 0.82, 0) * UPRIGHT, rgb(150, 100, 60), M.Wood)
	model.PrimaryPart = handle
	weldAll(model, handle)
	model:SetAttribute("ItemId", itemId)
	return model
end

local function buildTrash(itemId)
	local model = Instance.new("Model")
	model.Name = itemId
	local handle
	if itemId == "SlimeGel" then
		handle = ball(model, "Handle", 0.7, CF(0, 0, 0), rgb(110, 220, 90), M.Glass, { Transparency = 0.2 })
		ball(model, "Drop", 0.36, CF(0.28, -0.12, 0.1), rgb(130, 240, 110), M.Glass, { Transparency = 0.2 })
	elseif itemId == "MossyPebble" then
		handle = ball(model, "Handle", 0.7, CF(0, 0, 0), rgb(120, 120, 116), M.Slate)
		block(model, "Moss", V3(0.5, 0.12, 0.5), CF(0, 0.3, 0), rgb(90, 150, 60), M.Grass)
	elseif itemId == "GuardianShard" then
		handle = wedge(model, "Handle", V3(0.3, 0.9, 0.6), CF(0, 0, 0), rgb(110, 116, 126), M.Slate)
		block(model, "Rune", V3(0.32, 0.3, 0.08), CF(0, -0.1, 0.05), rgb(90, 220, 255), M.Neon)
	elseif itemId == "BoneDust" then
		handle = ball(model, "Handle", 0.7, CF(0, -0.1, 0), rgb(170, 168, 162), M.Sand)
		ball(model, "Mound", 0.5, CF(0.25, -0.2, 0.1), rgb(150, 148, 142), M.Sand)
		ball(model, "Mound", 0.4, CF(-0.25, -0.22, -0.1), rgb(186, 184, 176), M.Sand)
		block(model, "Splinter", V3(0.08, 0.08, 0.4), CF(0, 0.25, 0) * ANG(RAD(20), RAD(40), 0), rgb(232, 226, 210), M.SmoothPlastic)
	elseif itemId == "FrostShard" then
		handle = wedge(model, "Handle", V3(0.36, 1.0, 0.36), CF(0, 0, 0), rgb(160, 225, 255), M.Glass, { Transparency = 0.2 })
		wedge(model, "Side", V3(0.26, 0.6, 0.26), CF(0.22, -0.2, 0.05) * ANG(0, RAD(60), RAD(-18)), rgb(190, 240, 255), M.Glass, { Transparency = 0.25 })
		block(model, "Glint", V3(0.1, 0.4, 0.1), CF(0, 0, -0.15), rgb(220, 250, 255), M.Neon, { Transparency = 0.3 })
	elseif itemId == "GlacialHeart" then
		handle = ball(model, "Handle", 0.95, CF(0, 0, 0), rgb(180, 230, 255), M.Ice, { Transparency = 0.45 })
		ball(model, "Core", 0.5, CF(0, 0, 0), rgb(60, 150, 255), M.Neon)
		wedge(model, "Spike", V3(0.2, 0.5, 0.2), CF(0, 0.6, 0), rgb(200, 240, 255), M.Ice, { Transparency = 0.3 })
		wedge(model, "Spike", V3(0.2, 0.4, 0.2), CF(0.45, 0.3, 0) * ANG(0, 0, RAD(-50)), rgb(200, 240, 255), M.Ice, { Transparency = 0.3 })
	elseif itemId == "VoidEssence" then
		handle = ball(model, "Handle", 0.95, CF(0, 0, 0), rgb(220, 200, 255), M.Glass, { Transparency = 0.55 })
		ball(model, "Orb", 0.52, CF(0, 0, 0), rgb(150, 50, 230), M.Neon)
		ball(model, "Mote", 0.14, CF(0.25, 0.2, 0.15), rgb(230, 170, 255), M.Neon)
		cylinder(model, "Base", 0.14, 0.7, CF(0, -0.5, 0) * UPRIGHT, rgb(60, 40, 90), M.Metal)
	else
		handle = cylinder(model, "Handle", 0.12, 0.66, CF(0, 0, 0) * FACING, rgb(214, 170, 60), M.Metal)
		cylinder(model, "Inner", 0.15, 0.66, CF() * FACING, rgb(190, 146, 52), M.Metal)
		block(model, "CrownBase", V3(0.34, 0.08, 0.17), CF(0, -0.06, 0), rgb(240, 206, 110), M.Metal)
		for i = -1, 1 do
			block(model, "CrownTooth", V3(0.07, 0.16, 0.17), CF(i * 0.13, 0.05, 0), rgb(240, 206, 110), M.Metal)
		end
	end
	model.PrimaryPart = handle
	weldAll(model, handle)
	model:SetAttribute("ItemId", itemId)
	return model
end

-- Публичный API предметов ----------------------------------------------------------------
function Models.BuildItem(itemId, torsoSize)
	local def = Config.Items[itemId]
	if not def then
		return nil
	end
	if def.Kind == "Gear" then
		if def.Slot == "Weapon" then
			return buildSword(itemId)
		elseif def.Slot == "Armor" then
			return buildArmor(itemId, torsoSize)
		end
		return buildAccessory(itemId, torsoSize)
	end
	if def.Kind == "Potion" then
		return buildPotion(itemId)
	end
	return buildTrash(itemId)
end

-- Все части модели неподвижные и не мешают физике (для витрин и декора).
function Models.Anchor(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	return model
end

-- Риги ----------------------------------------------------------------------------------------
local function newRig(name, rootSize)
	local model = Instance.new("Model")
	model.Name = name
	local root = block(model, "HumanoidRootPart", rootSize, CF(0, 0, 0), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, Massless = false, CanCollide = true })
	model.PrimaryPart = root
	return model, root
end

local function addHumanoid(model, hipHeight, displayName)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hipHeight
	humanoid.DisplayName = displayName or model.Name
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	return humanoid
end

-- Гуманоидный риг с суставами R6. spec: Scale, Skin, Shirt, Pants, Name. Возвращает model, parts.
local function humanoidRig(name, spec)
	local s = spec.Scale or 1
	local torsoSize = V3(2, 2, 1) * s
	local model, root = newRig(name, torsoSize)
	local torso = block(model, "Torso", torsoSize, CF(0, 0, 0), spec.Shirt, spec.ShirtMaterial or M.Fabric)
	local head = block(model, "Head", V3(1.2, 1.2, 1.2) * s, CF(0, 1.6 * s, 0), spec.Skin, spec.SkinMaterial or M.SmoothPlastic)
	local armSize = V3(1, 2, 1) * s
	local legSize = V3(1, 2, 1) * s
	local rightArm = block(model, "Right Arm", armSize, CF(1.5 * s, 0, 0), spec.Sleeve or spec.Shirt, spec.ShirtMaterial or M.Fabric)
	local leftArm = block(model, "Left Arm", armSize, CF(-1.5 * s, 0, 0), spec.Sleeve or spec.Shirt, spec.ShirtMaterial or M.Fabric)
	local rightLeg = block(model, "Right Leg", legSize, CF(0.5 * s, -2 * s, 0), spec.Pants, spec.PantsMaterial or M.Fabric)
	local leftLeg = block(model, "Left Leg", legSize, CF(-0.5 * s, -2 * s, 0), spec.Pants, spec.PantsMaterial or M.Fabric)
	motor("RootJoint", root, torso, CF(), CF())
	motor("Neck", torso, head, CF(0, 1 * s, 0), CF(0, -0.6 * s, 0))
	motor("Right Shoulder", torso, rightArm, CF(1 * s, 0.5 * s, 0), CF(-0.5 * s, 0.5 * s, 0))
	motor("Left Shoulder", torso, leftArm, CF(-1 * s, 0.5 * s, 0), CF(0.5 * s, 0.5 * s, 0))
	motor("Right Hip", torso, rightLeg, CF(0.5 * s, -1 * s, 0), CF(0, 1 * s, 0))
	motor("Left Hip", torso, leftLeg, CF(-0.5 * s, -1 * s, 0), CF(0, 1 * s, 0))
	return model, {
		Root = root, Torso = torso, Head = head, RightArm = rightArm, LeftArm = leftArm,
		RightLeg = rightLeg, LeftLeg = leftLeg, Scale = s,
	}
end

local function face(head, s, eyeColor, browColor)
	local eyes = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(eyes, block(head.Parent, "Eye", V3(0.16, 0.2, 0.05) * s, head.CFrame * CF(side * 0.25 * s, 0.1 * s, -0.6 * s), eyeColor, M.SmoothPlastic))
		if browColor then
			table.insert(eyes, block(head.Parent, "Brow", V3(0.3, 0.08, 0.05) * s, head.CFrame * CF(side * 0.25 * s, 0.3 * s, -0.6 * s) * ANG(0, 0, RAD(side * -10)), browColor, M.SmoothPlastic))
		end
	end
	return eyes
end

-- Мобы ----------------------------------------------------------------------------------------
-- Слизень: невидимый корень + желейное тело на суставе «Body» со SpecialMesh «SquashMesh» (сжатие/растяжение).
local function buildSlime(modelId, def, scale)
	local k = scale or 1
	local model, root = newRig(modelId, V3(2.6, 2.2, 2.6) * k)
	local green = rgb(96, 206, 92)
	local king = def.Boss == true
	if king then
		green = rgb(110, 214, 120)
	end
	local body = block(model, "Body", V3(3.4, 2.6, 3.4) * k, CF(0, 0.1 * k, 0), green, M.Glass, { Transparency = 0.18 })
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "SquashMesh"
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	motor("Body", root, body, CF(0, 0.1 * k, 0), CF())
	local coreColor = king and rgb(255, 214, 80) or shade(green, 0.6)
	local parts = {
		ball(model, "Core", 1.2 * k, CF(0, -0.1 * k, 0.2 * k), coreColor, M.Neon, { Transparency = king and 0.15 or 0.4 }),
		ball(model, "EyeL", 0.62 * k, CF(-0.55 * k, 0.45 * k, -1.35 * k), rgb(255, 255, 255), M.SmoothPlastic),
		ball(model, "EyeR", 0.62 * k, CF(0.55 * k, 0.45 * k, -1.35 * k), rgb(255, 255, 255), M.SmoothPlastic),
		ball(model, "PupilL", 0.3 * k, CF(-0.55 * k, 0.42 * k, -1.62 * k), rgb(20, 24, 20), M.SmoothPlastic),
		ball(model, "PupilR", 0.3 * k, CF(0.55 * k, 0.42 * k, -1.62 * k), rgb(20, 24, 20), M.SmoothPlastic),
		block(model, "Mouth", V3(0.7, 0.12, 0.1) * k, CF(0, -0.15 * k, -1.62 * k), rgb(30, 70, 30), M.SmoothPlastic),
	}
	if king then
		local gold = rgb(255, 205, 60)
		table.insert(parts, cylinder(model, "CrownBand", 0.5 * k, 1.9 * k, CF(0, 1.35 * k, 0) * UPRIGHT, gold, M.Metal))
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			table.insert(parts, wedge(model, "CrownSpike", V3(0.3, 0.7, 0.3) * k, CF(math.cos(a) * 0.85 * k, 1.95 * k, math.sin(a) * 0.85 * k) * ANG(0, -a, 0), gold, M.Metal))
		end
		table.insert(parts, ball(model, "CrownGem", 0.4 * k, CF(0, 1.4 * k, -0.95 * k), rgb(255, 60, 90), M.Neon))
	else
		table.insert(parts, ball(model, "Leaf", 0.5 * k, CF(0.3 * k, 1.3 * k, 0.1 * k), rgb(70, 140, 50), M.Grass))
		table.insert(parts, block(model, "Stem", V3(0.12, 0.4, 0.12) * k, CF(0.2 * k, 1.25 * k, 0.1 * k) * ANG(0, 0, RAD(20)), rgb(90, 70, 40), M.Wood))
	end
	weldGroup(parts, body)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- Страж руин: каменный голем с мхом и светящимися рунами.
local function buildGuardian(modelId, def, scale)
	local stone = rgb(118, 122, 128)
	local model, p = humanoidRig(modelId, {
		Scale = 1.5 * (scale or 1),
		Skin = shade(stone, 1.05), SkinMaterial = M.Slate,
		Shirt = stone, ShirtMaterial = M.Slate,
		Pants = shade(stone, 0.85), PantsMaterial = M.Slate,
	})
	local s = p.Scale
	local rune = rgb(90, 220, 255)
	local moss = rgb(86, 140, 60)
	local torsoParts = {
		block(model, "Chest", V3(2.3, 1.2, 1.3) * s, p.Torso.CFrame * CF(0, 0.4 * s, 0), shade(stone, 1.1), M.Slate),
		block(model, "RuneChest", V3(0.5, 0.5, 0.06) * s, p.Torso.CFrame * CF(0, 0.35 * s, -0.66 * s) * ANG(0, 0, RAD(45)), rune, M.Neon),
		block(model, "MossBack", V3(1.6, 0.3, 0.6) * s, p.Torso.CFrame * CF(0, 1.0 * s, 0.4 * s), moss, M.Grass),
		block(model, "Belt", V3(2.1, 0.3, 1.1) * s, p.Torso.CFrame * CF(0, -0.85 * s, 0), shade(stone, 0.7), M.Cobblestone),
	}
	weldGroup(torsoParts, p.Torso)
	local headParts = {
		block(model, "Brow", V3(1.3, 0.3, 0.4) * s, p.Head.CFrame * CF(0, 0.3 * s, -0.5 * s), shade(stone, 0.8), M.Slate),
		block(model, "EyeL", V3(0.3, 0.14, 0.08) * s, p.Head.CFrame * CF(-0.28 * s, 0.05 * s, -0.62 * s), rune, M.Neon),
		block(model, "EyeR", V3(0.3, 0.14, 0.08) * s, p.Head.CFrame * CF(0.28 * s, 0.05 * s, -0.62 * s), rune, M.Neon),
		wedge(model, "HornL", V3(0.2, 0.6, 0.3) * s, p.Head.CFrame * CF(-0.5 * s, 0.75 * s, 0) * ANG(0, 0, RAD(20)), shade(stone, 0.7), M.Slate),
		wedge(model, "HornR", V3(0.2, 0.6, 0.3) * s, p.Head.CFrame * CF(0.5 * s, 0.75 * s, 0) * ANG(0, 0, RAD(-20)), shade(stone, 0.7), M.Slate),
	}
	weldGroup(headParts, p.Head)
	for _, arm in ipairs({ p.RightArm, p.LeftArm }) do
		local side = arm == p.RightArm and 1 or -1
		weldGroup({
			block(model, "Shoulder", V3(1.4, 0.8, 1.4) * s, arm.CFrame * CF(side * 0.1 * s, 0.75 * s, 0), shade(stone, 1.1), M.Slate),
			block(model, "Fist", V3(1.4, 1.0, 1.4) * s, arm.CFrame * CF(0, -1.05 * s, 0), shade(stone, 0.9), M.Slate),
			block(model, "RuneArm", V3(0.06, 0.4, 0.4) * s, arm.CFrame * CF(side * 0.52 * s, 0, 0), rune, M.Neon),
			block(model, "Moss", V3(0.9, 0.2, 0.9) * s, arm.CFrame * CF(0, 1.2 * s, 0), moss, M.Grass),
		}, arm)
	end
	for _, leg in ipairs({ p.RightLeg, p.LeftLeg }) do
		weldGroup({ block(model, "Foot", V3(1.2, 0.5, 1.5) * s, leg.CFrame * CF(0, -0.8 * s, -0.15 * s), shade(stone, 0.75), M.Slate) }, leg)
	end
	local glow = Instance.new("PointLight")
	glow.Color = rune
	glow.Range = 8
	glow.Brightness = 1.2
	glow.Parent = p.Torso
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- NPC -----------------------------------------------------------------------------------------
local function buildMerchant()
	local model, p = humanoidRig("Merchant", {
		Skin = rgb(234, 190, 150),
		Shirt = rgb(70, 110, 80), Sleeve = rgb(60, 96, 70),
		Pants = rgb(80, 64, 52),
	})
	face(p.Head, 1, rgb(30, 30, 30), rgb(120, 80, 50))
	local headParts = {
		cylinder(model, "HatBrim", 0.12, 2.0, p.Head.CFrame * CF(0, 0.62, 0) * UPRIGHT, rgb(110, 76, 44), M.Fabric),
		cylinder(model, "HatTop", 0.6, 1.2, p.Head.CFrame * CF(0, 0.95, 0) * UPRIGHT, rgb(120, 84, 50), M.Fabric),
		block(model, "HatBand", V3(1.22, 0.14, 1.22), p.Head.CFrame * CF(0, 0.75, 0), rgb(200, 60, 50), M.Fabric),
		block(model, "Beard", V3(1.0, 0.6, 0.3), p.Head.CFrame * CF(0, -0.45, -0.5), rgb(130, 90, 60), M.Fabric),
	}
	for _, item in ipairs(p.Head.Parent:GetChildren()) do
		if item.Name == "Eye" or item.Name == "Brow" then
			table.insert(headParts, item)
		end
	end
	weldGroup(headParts, p.Head)
	weldGroup({
		block(model, "Vest", V3(2.1, 1.6, 1.1), p.Torso.CFrame * CF(0, 0.15, 0), rgb(150, 100, 60), M.Leather),
		block(model, "CoinPouch", V3(0.6, 0.6, 0.4), p.Torso.CFrame * CF(0.6, -0.8, -0.6), rgb(200, 160, 70), M.Fabric),
		block(model, "Sash", V3(2.15, 0.3, 1.15), p.Torso.CFrame * CF(0, -0.75, 0), rgb(200, 60, 50), M.Fabric),
	}, p.Torso)
	-- Якорим только корень: конечности должны оставаться подвижными для Motor6D-анимаций.
	p.Root.Anchored = true
	p.Root.CanCollide = false
	model:SetAttribute("NPC", "Merchant")
	return model
end

local function buildBlacksmith()
	local model, p = humanoidRig("Blacksmith", {
		Scale = 1.1,
		Skin = rgb(206, 156, 116),
		Shirt = rgb(150, 70, 50), Sleeve = rgb(206, 156, 116),
		Pants = rgb(60, 54, 50),
	})
	local s = p.Scale
	face(p.Head, s, rgb(30, 30, 30), rgb(60, 40, 30))
	local headParts = {
		block(model, "Beard", V3(1.1, 0.8, 0.35) * s, p.Head.CFrame * CF(0, -0.5 * s, -0.5 * s), rgb(70, 46, 30), M.Fabric),
		block(model, "Bandana", V3(1.26, 0.3, 1.26) * s, p.Head.CFrame * CF(0, 0.5 * s, 0), rgb(40, 40, 46), M.Fabric),
	}
	for _, item in ipairs(model:GetChildren()) do
		if item.Name == "Eye" or item.Name == "Brow" then
			table.insert(headParts, item)
		end
	end
	weldGroup(headParts, p.Head)
	weldGroup({
		block(model, "Apron", V3(1.8, 2.4, 0.12) * s, p.Torso.CFrame * CF(0, -0.3 * s, -0.56 * s), rgb(90, 60, 40), M.Leather),
		block(model, "ApronPocket", V3(0.8, 0.5, 0.06) * s, p.Torso.CFrame * CF(0, -0.6 * s, -0.64 * s), rgb(70, 46, 30), M.Leather),
	}, p.Torso)
	-- Молот в правой руке: рукоять вдоль руки, боёк на конце.
	local a = p.RightArm
	weldGroup({
		block(model, "HammerHandle", V3(0.22, 0.22, 2.2) * s, a.CFrame * CF(0, -1.0 * s, -0.9 * s), rgb(110, 76, 44), M.Wood),
		block(model, "HammerHead", V3(0.6, 0.6, 1.0) * s, a.CFrame * CF(0, -1.0 * s, -2.0 * s) * ANG(0, RAD(90), 0), rgb(70, 72, 80), M.Metal),
		block(model, "Glove", V3(1.05, 0.5, 1.05) * s, a.CFrame * CF(0, -0.8 * s, 0), rgb(80, 56, 36), M.Leather),
	}, a)
	-- Якорим только корень: конечности должны оставаться подвижными для Motor6D-анимаций.
	p.Root.Anchored = true
	p.Root.CanCollide = false
	model:SetAttribute("NPC", "Blacksmith")
	return model
end

local function buildExpansionMob(mobId, def)
 local volcanic = mobId == "EmberKnight" or mobId == "ObsidianGuard" or mobId == "AshOverlord"
 local s = def.Scale or (def.Boss and 3.5 or 1.25)
 local stone = volcanic and rgb(46, 38, 57) or rgb(196, 160, 104)
 local glowColor = volcanic and rgb(255, 92, 38) or rgb(255, 222, 106)
 local model, p = humanoidRig(mobId, {
  Scale = s, Skin = shade(stone, 1.1), SkinMaterial = M.Slate,
  Shirt = stone, ShirtMaterial = volcanic and M.Basalt or M.Sandstone,
  Pants = shade(stone, 0.75), PantsMaterial = M.Slate,
 })
 weldGroup({
  block(model, "ChestPlate", V3(2.2, 1.4, 1.25)*s, p.Torso.CFrame*CF(0, 0.15*s, 0), shade(stone, 1.2), M.Metal),
  block(model, "HeartRune", V3(0.6, 0.6, 0.14)*s, p.Torso.CFrame*CF(0, 0.3*s, -0.69*s)*ANG(0,0,RAD(45)), glowColor, M.Neon),
  block(model, "Belt", V3(2.15, 0.25, 1.15)*s, p.Torso.CFrame*CF(0,-0.85*s,0), glowColor, M.Metal),
 }, p.Torso)
 local headParts = face(p.Head, s, glowColor, shade(stone, 0.6))
 table.insert(headParts, block(model, "CrownBand", V3(1.4,0.25,1.4)*s, p.Head.CFrame*CF(0,0.5*s,0), glowColor, M.Metal))
 for i=-1,1 do
  table.insert(headParts, wedge(model, "CrownSpike", V3(0.3,def.Boss and 1.4 or 0.6,0.4)*s, p.Head.CFrame*CF(i*0.45*s,1*s,0), glowColor, M.Neon))
 end
 weldGroup(headParts, p.Head)
 for _, arm in ipairs({p.RightArm,p.LeftArm}) do
  weldGroup({
   block(model, "Pauldron", V3(1.45,0.65,1.45)*s, arm.CFrame*CF(0,0.8*s,0), shade(stone,1.4), M.Metal),
   block(model, "FistGuard", V3(1.15,0.6,1.15)*s, arm.CFrame*CF(0,-0.8*s,0), glowColor, M.Metal),
  }, arm)
 end
 if mobId == "SandSentinel" or mobId == "EmberKnight" then
  local blade = block(model,"ArmBlade",V3(0.18,2.8,0.7)*s,p.RightArm.CFrame*CF(0,-1.6*s,-0.55*s),glowColor,M.Metal)
  weld(p.RightArm,blade)
 end
 local light = Instance.new("PointLight")
 light.Color = glowColor
 light.Brightness = def.Boss and 2 or 0.8
 light.Range = def.Boss and 22 or 8
 light.Parent = p.Torso
 addHumanoid(model, def.HipHeight, def.Name)
 return model
end

local function addLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = parent
	return light
end

local function setTransparency(list, value)
	for _, item in ipairs(list) do
		item.Transparency = value
	end
end

-- Ледяной призрак: парящее полупрозрачное тело, рваный хвост мантии вместо ног, длинные когти.
local function buildFrostWraith(modelId, def)
	local s = def.Scale or 1
	local ice = rgb(170, 220, 255)
	local model, p = humanoidRig(modelId, {
		Scale = s, Skin = rgb(205, 238, 255), SkinMaterial = M.Glass,
		Shirt = ice, ShirtMaterial = M.Glass, Pants = shade(ice, 0.8), PantsMaterial = M.Glass,
	})
	setTransparency({ p.Torso, p.Head, p.RightArm, p.LeftArm }, 0.4)
	setTransparency({ p.RightLeg, p.LeftLeg }, 1)
	p.RightLeg.Size = p.RightLeg.Size * 0.3
	p.LeftLeg.Size = p.LeftLeg.Size * 0.3
	local cyan = rgb(90, 240, 255)
	local tail = {}
	for i = 1, 5 do
		local w = (2.1 - i * 0.32) * s
		table.insert(tail, block(model, "RobeTail", V3(w, 0.8 * s, 0.9 * s * (1 - i * 0.12)), p.Torso.CFrame * CF((i % 2 - 0.5) * 0.15 * s, (-1.2 - i * 0.7) * s, 0.12 * i * s) * ANG(RAD(8 * i), 0, RAD((i % 2 - 0.5) * 12)), ice, M.Glass, { Transparency = 0.35 + i * 0.1 }))
	end
	for _, side in ipairs({ -1, 1 }) do
		table.insert(tail, wedge(model, "Rag", V3(0.15, 1.6, 0.8) * s, p.Torso.CFrame * CF(side * 0.8 * s, (-1.4) * s, 0.2 * s) * ANG(RAD(180), 0, RAD(side * 10)), shade(ice, 0.9), M.Glass, { Transparency = 0.5 }))
	end
	weldGroup(tail, p.Torso)
	local headParts = {
		block(model, "EyeL", V3(0.2, 0.12, 0.06) * s, p.Head.CFrame * CF(-0.25 * s, 0.1 * s, -0.62 * s), cyan, M.Neon),
		block(model, "EyeR", V3(0.2, 0.12, 0.06) * s, p.Head.CFrame * CF(0.25 * s, 0.1 * s, -0.62 * s), cyan, M.Neon),
		block(model, "Mouth", V3(0.4, 0.3, 0.06) * s, p.Head.CFrame * CF(0, -0.28 * s, -0.62 * s), rgb(20, 60, 90), M.SmoothPlastic),
		wedge(model, "IceCrown", V3(0.25, 0.8, 0.3) * s, p.Head.CFrame * CF(0, 0.95 * s, 0), cyan, M.Glass, { Transparency = 0.3 }),
		wedge(model, "IceCrown", V3(0.2, 0.55, 0.25) * s, p.Head.CFrame * CF(0.4 * s, 0.85 * s, 0) * ANG(0, 0, RAD(-20)), cyan, M.Glass, { Transparency = 0.3 }),
		wedge(model, "IceCrown", V3(0.2, 0.55, 0.25) * s, p.Head.CFrame * CF(-0.4 * s, 0.85 * s, 0) * ANG(0, 0, RAD(20)), cyan, M.Glass, { Transparency = 0.3 }),
	}
	weldGroup(headParts, p.Head)
	for _, arm in ipairs({ p.RightArm, p.LeftArm }) do
		local claws = {}
		for i = -1, 1 do
			table.insert(claws, wedge(model, "Claw", V3(0.1, 1.3, 0.14) * s, arm.CFrame * CF(i * 0.3 * s, -1.55 * s, -0.1 * s) * ANG(RAD(180), 0, RAD(i * -8)), rgb(225, 248, 255), M.Glass, { Transparency = 0.15 }))
		end
		table.insert(claws, block(model, "Frost", V3(1.1, 0.35, 1.1) * s, arm.CFrame * CF(0, -0.9 * s, 0), cyan, M.Neon, { Transparency = 0.6 }))
		weldGroup(claws, arm)
	end
	weldGroup({ block(model, "Core", V3(0.6, 0.6, 0.2) * s, p.Torso.CFrame * CF(0, 0.3 * s, -0.5 * s) * ANG(0, 0, RAD(45)), cyan, M.Neon, { Transparency = 0.2 }) }, p.Torso)
	addLight(p.Torso, cyan, 12, 1.6)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- Морозный маг: мантия с капюшоном, ледяной посох с кристаллом «CastPoint» на конце.
local function buildFrostMage(modelId, def)
	local s = def.Scale or 1
	local robe = rgb(52, 78, 150)
	local model, p = humanoidRig(modelId, {
		Scale = s, Skin = rgb(190, 214, 235),
		Shirt = robe, ShirtMaterial = M.Fabric, Sleeve = shade(robe, 0.85),
		Pants = shade(robe, 0.7), PantsMaterial = M.Fabric,
	})
	local cyan = rgb(110, 230, 255)
	weldGroup({
		block(model, "RobeSkirt", V3(2.3, 2.4, 1.4) * s, p.Torso.CFrame * CF(0, -1.5 * s, 0), shade(robe, 0.9), M.Fabric),
		block(model, "RobeHem", V3(2.5, 0.25, 1.55) * s, p.Torso.CFrame * CF(0, -2.6 * s, 0), cyan, M.Fabric),
		block(model, "Sash", V3(2.1, 0.3, 1.1) * s, p.Torso.CFrame * CF(0, -0.75 * s, 0), rgb(220, 235, 255), M.Fabric),
		block(model, "RuneA", V3(0.5, 0.12, 0.06) * s, p.Torso.CFrame * CF(0, 0.5 * s, -0.52 * s), cyan, M.Neon),
		block(model, "RuneB", V3(0.12, 0.7, 0.06) * s, p.Torso.CFrame * CF(0, 0.2 * s, -0.52 * s), cyan, M.Neon),
		block(model, "RuneC", V3(0.4, 0.4, 0.06) * s, p.Torso.CFrame * CF(0, -1.7 * s, -0.72 * s) * ANG(0, 0, RAD(45)), cyan, M.Neon),
		block(model, "Mantle", V3(2.5, 0.5, 1.4) * s, p.Torso.CFrame * CF(0, 1.0 * s, 0), shade(robe, 1.2), M.Fabric),
	}, p.Torso)
	local headParts = {
		block(model, "HoodBack", V3(1.4, 1.4, 0.4) * s, p.Head.CFrame * CF(0, 0.05 * s, 0.55 * s), shade(robe, 0.8), M.Fabric),
		block(model, "HoodTop", V3(1.4, 0.35, 1.4) * s, p.Head.CFrame * CF(0, 0.7 * s, 0), shade(robe, 0.8), M.Fabric),
		block(model, "HoodL", V3(0.25, 1.3, 1.3) * s, p.Head.CFrame * CF(-0.68 * s, 0.05 * s, 0), shade(robe, 0.8), M.Fabric),
		block(model, "HoodR", V3(0.25, 1.3, 1.3) * s, p.Head.CFrame * CF(0.68 * s, 0.05 * s, 0), shade(robe, 0.8), M.Fabric),
		wedge(model, "HoodTip", V3(0.5, 0.7, 0.6) * s, p.Head.CFrame * CF(0, 1.0 * s, 0.35 * s) * ANG(0, RAD(180), 0), shade(robe, 0.7), M.Fabric),
		block(model, "Shadow", V3(1.0, 0.9, 0.1) * s, p.Head.CFrame * CF(0, 0, -0.58 * s), rgb(14, 20, 40), M.SmoothPlastic),
		block(model, "EyeL", V3(0.2, 0.1, 0.05) * s, p.Head.CFrame * CF(-0.25 * s, 0.08 * s, -0.64 * s), cyan, M.Neon),
		block(model, "EyeR", V3(0.2, 0.1, 0.05) * s, p.Head.CFrame * CF(0.25 * s, 0.08 * s, -0.64 * s), cyan, M.Neon),
	}
	weldGroup(headParts, p.Head)
	local a = p.RightArm
	local staffParts = {
		block(model, "Staff", V3(0.2, 5.2, 0.2) * s, a.CFrame * CF(0, 0.7 * s, -0.6 * s), rgb(120, 160, 200), M.Ice),
		block(model, "StaffRing", V3(0.5, 0.2, 0.5) * s, a.CFrame * CF(0, 3.1 * s, -0.6 * s), rgb(220, 240, 255), M.Metal),
		wedge(model, "StaffClawL", V3(0.12, 0.7, 0.2) * s, a.CFrame * CF(-0.25 * s, 3.45 * s, -0.6 * s) * ANG(0, 0, RAD(15)), rgb(200, 235, 255), M.Ice),
		wedge(model, "StaffClawR", V3(0.12, 0.7, 0.2) * s, a.CFrame * CF(0.25 * s, 3.45 * s, -0.6 * s) * ANG(0, 0, RAD(-15)), rgb(200, 235, 255), M.Ice),
		block(model, "Glove", V3(1.05, 0.5, 1.05) * s, a.CFrame * CF(0, -0.8 * s, 0), shade(robe, 0.7), M.Fabric),
		ball(model, "CastPoint", 0.8 * s, a.CFrame * CF(0, 3.5 * s, -0.6 * s), cyan, M.Neon),
	}
	weldGroup(staffParts, a)
	addLight(p.Torso, cyan, 10, 1.1)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- Морозный голем: глыба льда и камня с огромными кулаками, кристаллами на спине и светящимся ядром.
local function buildFrostGolem(modelId, def)
	local s = def.Scale or 1
	local rock = rgb(98, 128, 160)
	local iceColor = rgb(170, 225, 255)
	local cyan = rgb(80, 220, 255)
	local model, p = humanoidRig(modelId, {
		Scale = s, Skin = shade(rock, 1.1), SkinMaterial = M.Glacier,
		Shirt = rock, ShirtMaterial = M.Slate, Sleeve = shade(rock, 0.95),
		Pants = shade(rock, 0.8), PantsMaterial = M.Slate,
	})
	local torsoParts = {
		block(model, "Chest", V3(2.5, 1.5, 1.4) * s, p.Torso.CFrame * CF(0, 0.35 * s, 0), iceColor, M.Ice, { Transparency = 0.15 }),
		block(model, "Core", V3(0.7, 0.7, 0.16) * s, p.Torso.CFrame * CF(0, 0.35 * s, -0.74 * s) * ANG(0, 0, RAD(45)), cyan, M.Neon),
		block(model, "CoreFrame", V3(1.0, 1.0, 0.1) * s, p.Torso.CFrame * CF(0, 0.35 * s, -0.7 * s) * ANG(0, 0, RAD(45)), shade(rock, 0.6), M.Slate),
		block(model, "Belt", V3(2.2, 0.4, 1.2) * s, p.Torso.CFrame * CF(0, -0.85 * s, 0), shade(rock, 0.65), M.Slate),
	}
	for i = -2, 2 do
		table.insert(torsoParts, wedge(model, "BackCrystal", V3(0.4, 1.4 + (2 - math.abs(i)) * 0.5, 0.45) * s, p.Torso.CFrame * CF(i * 0.45 * s, (1.2 + (2 - math.abs(i)) * 0.15) * s, 0.7 * s) * ANG(RAD(-14), RAD(i * 12), RAD(-i * 9)), iceColor, M.Glass, { Transparency = 0.2 }))
	end
	weldGroup(torsoParts, p.Torso)
	local headParts = {
		block(model, "Brow", V3(1.4, 0.3, 0.5) * s, p.Head.CFrame * CF(0, 0.3 * s, -0.5 * s), shade(rock, 0.7), M.Slate),
		block(model, "EyeL", V3(0.3, 0.14, 0.08) * s, p.Head.CFrame * CF(-0.28 * s, 0.05 * s, -0.64 * s), cyan, M.Neon),
		block(model, "EyeR", V3(0.3, 0.14, 0.08) * s, p.Head.CFrame * CF(0.28 * s, 0.05 * s, -0.64 * s), cyan, M.Neon),
		wedge(model, "IceHornL", V3(0.3, 0.9, 0.35) * s, p.Head.CFrame * CF(-0.45 * s, 0.9 * s, 0) * ANG(0, 0, RAD(18)), iceColor, M.Ice),
		wedge(model, "IceHornR", V3(0.3, 0.9, 0.35) * s, p.Head.CFrame * CF(0.45 * s, 0.9 * s, 0) * ANG(0, 0, RAD(-18)), iceColor, M.Ice),
	}
	weldGroup(headParts, p.Head)
	for _, arm in ipairs({ p.RightArm, p.LeftArm }) do
		local side = arm == p.RightArm and 1 or -1
		weldGroup({
			block(model, "Boulder", V3(1.8, 1.2, 1.8) * s, arm.CFrame * CF(side * 0.1 * s, 0.85 * s, 0) * ANG(0, RAD(20), RAD(side * 10)), shade(rock, 1.15), M.Glacier),
			block(model, "Fist", V3(1.9, 1.5, 1.9) * s, arm.CFrame * CF(0, -1.2 * s, 0), iceColor, M.Ice, { Transparency = 0.1 }),
			wedge(model, "Knuckle", V3(0.3, 0.5, 0.4) * s, arm.CFrame * CF(-0.5 * s, -2.1 * s, -0.7 * s) * ANG(RAD(180), 0, 0), cyan, M.Neon),
			wedge(model, "Knuckle", V3(0.3, 0.5, 0.4) * s, arm.CFrame * CF(0.5 * s, -2.1 * s, -0.7 * s) * ANG(RAD(180), 0, 0), cyan, M.Neon),
			block(model, "RuneArm", V3(0.06, 0.5, 0.4) * s, arm.CFrame * CF(side * 0.52 * s, 0, 0), cyan, M.Neon),
		}, arm)
	end
	for _, leg in ipairs({ p.RightLeg, p.LeftLeg }) do
		weldGroup({
			block(model, "Foot", V3(1.5, 0.7, 1.8) * s, leg.CFrame * CF(0, -0.8 * s, -0.2 * s), shade(rock, 0.75), M.Glacier),
			wedge(model, "ShinSpike", V3(0.25, 0.7, 0.3) * s, leg.CFrame * CF(0, 0.3 * s, -0.6 * s) * ANG(RAD(-90), 0, 0), iceColor, M.Ice),
		}, leg)
	end
	addLight(p.Torso, cyan, 14, 1.4)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- Страж цитадели: тяжёлый рыцарь в синей стали, башенный щит слева, алебарда справа.
local function buildCitadelSentinel(modelId, def)
	local s = def.Scale or 1
	local steel = rgb(72, 104, 156)
	local trim = rgb(190, 215, 245)
	local cyan = rgb(110, 225, 255)
	local model, p = humanoidRig(modelId, {
		Scale = s, Skin = steel, SkinMaterial = M.Metal,
		Shirt = steel, ShirtMaterial = M.DiamondPlate, Sleeve = shade(steel, 0.9),
		Pants = shade(steel, 0.7), PantsMaterial = M.Metal,
	})
	weldGroup({
		block(model, "Breastplate", V3(2.2, 1.5, 1.25) * s, p.Torso.CFrame * CF(0, 0.15 * s, 0), shade(steel, 1.2), M.Metal),
		block(model, "Tabard", V3(1.1, 1.8, 0.1) * s, p.Torso.CFrame * CF(0, -0.4 * s, -0.68 * s), rgb(230, 238, 250), M.Fabric),
		block(model, "TabardEmblem", V3(0.4, 0.4, 0.06) * s, p.Torso.CFrame * CF(0, 0.1 * s, -0.75 * s) * ANG(0, 0, RAD(45)), cyan, M.Neon),
		block(model, "Belt", V3(2.15, 0.28, 1.15) * s, p.Torso.CFrame * CF(0, -0.85 * s, 0), trim, M.Metal),
	}, p.Torso)
	local headParts = {
		block(model, "Helm", V3(1.45, 1.45, 1.45) * s, p.Head.CFrame * CF(0, 0.1 * s, 0), shade(steel, 1.15), M.Metal),
		block(model, "Visor", V3(1.2, 0.18, 0.1) * s, p.Head.CFrame * CF(0, 0.05 * s, -0.74 * s), rgb(10, 14, 26), M.SmoothPlastic),
		block(model, "VisorGlow", V3(0.9, 0.06, 0.06) * s, p.Head.CFrame * CF(0, 0.05 * s, -0.76 * s), cyan, M.Neon),
		block(model, "Crest", V3(0.2, 0.3, 1.2) * s, p.Head.CFrame * CF(0, 0.9 * s, 0), trim, M.Metal),
	}
	for i = 0, 3 do
		table.insert(headParts, wedge(model, "Plume", V3(0.22, 0.7, 0.5) * s, p.Head.CFrame * CF(0, (1.15 + i * 0.05) * s, (0.45 + i * 0.3) * s) * ANG(RAD(-15 * i), RAD(180), 0), rgb(235, 245, 255), M.Fabric))
	end
	weldGroup(headParts, p.Head)
	for _, arm in ipairs({ p.RightArm, p.LeftArm }) do
		weldGroup({
			block(model, "Pauldron", V3(1.6, 0.7, 1.6) * s, arm.CFrame * CF(0, 0.8 * s, 0), trim, M.Metal),
			block(model, "Gauntlet", V3(1.2, 0.7, 1.2) * s, arm.CFrame * CF(0, -0.75 * s, 0), shade(steel, 0.8), M.Metal),
		}, arm)
	end
	for _, leg in ipairs({ p.RightLeg, p.LeftLeg }) do
		weldGroup({
			block(model, "Greave", V3(1.2, 0.9, 1.2) * s, leg.CFrame * CF(0, -0.3 * s, 0), shade(steel, 1.1), M.Metal),
			block(model, "Boot", V3(1.2, 0.5, 1.6) * s, leg.CFrame * CF(0, -0.8 * s, -0.2 * s), shade(steel, 0.6), M.Metal),
		}, leg)
	end
	local la = p.LeftArm
	weldGroup({
		block(model, "Shield", V3(0.3, 3.4, 2.1) * s, la.CFrame * CF(-0.75 * s, 0.1 * s, -0.2 * s), shade(steel, 1.1), M.DiamondPlate),
		block(model, "ShieldRim", V3(0.38, 3.6, 0.2) * s, la.CFrame * CF(-0.75 * s, 0.1 * s, -1.25 * s), trim, M.Metal),
		block(model, "ShieldRim", V3(0.38, 3.6, 0.2) * s, la.CFrame * CF(-0.75 * s, 0.1 * s, 0.85 * s), trim, M.Metal),
		block(model, "ShieldCrest", V3(0.12, 1.1, 0.8) * s, la.CFrame * CF(-0.95 * s, 0.4 * s, -0.2 * s), cyan, M.Neon),
		wedge(model, "ShieldTip", V3(0.3, 0.7, 2.1) * s, la.CFrame * CF(-0.75 * s, -1.95 * s, -0.2 * s) * ANG(RAD(180), 0, 0), trim, M.Metal),
	}, la)
	local ra = p.RightArm
	weldGroup({
		block(model, "HalberdPole", V3(0.2, 6.4, 0.2) * s, ra.CFrame * CF(0, 1.2 * s, -0.6 * s), rgb(110, 84, 60), M.Wood),
		block(model, "HalberdAxe", V3(0.14, 1.3, 1.5) * s, ra.CFrame * CF(0, 3.8 * s, -1.35 * s), trim, M.Metal),
		wedge(model, "HalberdBlade", V3(0.14, 0.9, 0.8) * s, ra.CFrame * CF(0, 3.9 * s, -2.4 * s) * ANG(0, RAD(180), 0), trim, M.Metal),
		wedge(model, "HalberdSpike", V3(0.2, 1.1, 0.2) * s, ra.CFrame * CF(0, 4.9 * s, -0.6 * s), trim, M.Metal),
		block(model, "HalberdGem", V3(0.3, 0.3, 0.3) * s, ra.CFrame * CF(0, 3.2 * s, -0.6 * s), cyan, M.Neon),
	}, ra)
	addLight(p.Torso, cyan, 8, 0.7)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- Колдун бездны: фиолетовая мантия, рога, парящие сферы пустоты вокруг головы и посох с «CastPoint».
local function buildVoidWarlock(modelId, def)
	local s = def.Scale or 1
	local robe = rgb(54, 24, 86)
	local void = rgb(190, 90, 255)
	local model, p = humanoidRig(modelId, {
		Scale = s, Skin = rgb(120, 96, 150),
		Shirt = robe, ShirtMaterial = M.Fabric, Sleeve = shade(robe, 0.8),
		Pants = shade(robe, 0.6), PantsMaterial = M.Fabric,
	})
	weldGroup({
		block(model, "RobeSkirt", V3(2.3, 2.4, 1.4) * s, p.Torso.CFrame * CF(0, -1.5 * s, 0), shade(robe, 0.85), M.Fabric),
		block(model, "RobeHem", V3(2.5, 0.25, 1.55) * s, p.Torso.CFrame * CF(0, -2.6 * s, 0), void, M.Neon),
		block(model, "Collar", V3(2.6, 0.9, 1.5) * s, p.Torso.CFrame * CF(0, 0.9 * s, 0.1 * s), shade(robe, 1.3), M.Fabric),
		block(model, "SigilA", V3(0.8, 0.1, 0.06) * s, p.Torso.CFrame * CF(0, 0.2 * s, -0.52 * s), void, M.Neon),
		block(model, "SigilB", V3(0.1, 0.8, 0.06) * s, p.Torso.CFrame * CF(0, 0.2 * s, -0.52 * s), void, M.Neon),
		block(model, "SigilC", V3(0.5, 0.5, 0.06) * s, p.Torso.CFrame * CF(0, 0.2 * s, -0.54 * s) * ANG(0, 0, RAD(45)), void, M.Neon),
	}, p.Torso)
	local headParts = {
		block(model, "Cowl", V3(1.35, 0.5, 1.35) * s, p.Head.CFrame * CF(0, 0.55 * s, 0.05 * s), shade(robe, 0.7), M.Fabric),
		block(model, "EyeL", V3(0.2, 0.12, 0.05) * s, p.Head.CFrame * CF(-0.25 * s, 0.05 * s, -0.62 * s), void, M.Neon),
		block(model, "EyeR", V3(0.2, 0.12, 0.05) * s, p.Head.CFrame * CF(0.25 * s, 0.05 * s, -0.62 * s), void, M.Neon),
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headParts, wedge(model, "HornLow", V3(0.3, 0.8, 0.4) * s, p.Head.CFrame * CF(side * 0.7 * s, 0.7 * s, 0) * ANG(0, 0, RAD(side * -35)), rgb(30, 20, 36), M.Slate))
		table.insert(headParts, wedge(model, "HornTip", V3(0.22, 0.7, 0.3) * s, p.Head.CFrame * CF(side * 1.0 * s, 1.25 * s, 0) * ANG(0, 0, RAD(side * 10)), rgb(30, 20, 36), M.Slate))
	end
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		table.insert(headParts, ball(model, "VoidOrb", 0.55 * s, p.Head.CFrame * CF(math.cos(angle) * 1.7 * s, (1.0 + i * 0.25) * s, math.sin(angle) * 1.7 * s), void, M.Neon, { Transparency = 0.2 }))
		table.insert(headParts, ball(model, "VoidCore", 0.25 * s, p.Head.CFrame * CF(math.cos(angle) * 1.7 * s, (1.0 + i * 0.25) * s, math.sin(angle) * 1.7 * s), rgb(20, 4, 36), M.SmoothPlastic))
	end
	weldGroup(headParts, p.Head)
	local a = p.RightArm
	weldGroup({
		block(model, "Staff", V3(0.22, 5.0, 0.22) * s, a.CFrame * CF(0, 0.6 * s, -0.6 * s), rgb(36, 28, 44), M.Wood),
		cylinder(model, "StaffRing", 0.15 * s, 0.9 * s, a.CFrame * CF(0, 3.2 * s, -0.6 * s) * UPRIGHT, rgb(150, 110, 190), M.Metal),
		wedge(model, "StaffHornL", V3(0.15, 0.8, 0.2) * s, a.CFrame * CF(-0.4 * s, 3.4 * s, -0.6 * s) * ANG(0, 0, RAD(20)), rgb(30, 20, 36), M.Slate),
		wedge(model, "StaffHornR", V3(0.15, 0.8, 0.2) * s, a.CFrame * CF(0.4 * s, 3.4 * s, -0.6 * s) * ANG(0, 0, RAD(-20)), rgb(30, 20, 36), M.Slate),
		block(model, "Glove", V3(1.05, 0.5, 1.05) * s, a.CFrame * CF(0, -0.8 * s, 0), shade(robe, 0.6), M.Fabric),
		ball(model, "CastPoint", 0.85 * s, a.CFrame * CF(0, 3.45 * s, -0.6 * s), void, M.Neon),
	}, a)
	addLight(p.Torso, void, 12, 1.4)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- Скелет-воин: тонкие кости вместо конечностей, рёбра, череп с зелёными глазами, ржавый меч и круглый щит.
local function buildSkeletonWarrior(modelId, def)
	local s = def.Scale or 1
	local bone = rgb(228, 222, 200)
	local green = rgb(110, 255, 130)
	local model, p = humanoidRig(modelId, {
		Scale = s, Skin = bone, Shirt = bone, ShirtMaterial = M.SmoothPlastic, Pants = bone, PantsMaterial = M.SmoothPlastic,
	})
	setTransparency({ p.Torso, p.RightArm, p.LeftArm, p.RightLeg, p.LeftLeg }, 1)
	local torsoParts = {
		block(model, "Spine", V3(0.22, 2.0, 0.22) * s, p.Torso.CFrame * CF(0, 0, 0.2 * s), bone, M.SmoothPlastic),
		block(model, "Sternum", V3(0.2, 1.3, 0.1) * s, p.Torso.CFrame * CF(0, 0.2 * s, -0.4 * s), bone, M.SmoothPlastic),
		block(model, "Pelvis", V3(1.5, 0.35, 0.8) * s, p.Torso.CFrame * CF(0, -0.9 * s, 0), shade(bone, 0.9), M.SmoothPlastic),
		block(model, "Collarbone", V3(2.0, 0.16, 0.2) * s, p.Torso.CFrame * CF(0, 0.85 * s, -0.1 * s), bone, M.SmoothPlastic),
	}
	for i = 0, 4 do
		local width = (1.9 - i * 0.12) * s
		table.insert(torsoParts, block(model, "Rib", V3(width, 0.1, 0.85) * s, p.Torso.CFrame * CF(0, (0.55 - i * 0.28) * s, -0.05 * s), bone, M.SmoothPlastic))
	end
	weldGroup(torsoParts, p.Torso)
	local headParts = {
		block(model, "Jaw", V3(0.9, 0.3, 0.9) * s, p.Head.CFrame * CF(0, -0.5 * s, -0.1 * s), shade(bone, 0.92), M.SmoothPlastic),
		block(model, "SocketL", V3(0.3, 0.3, 0.06) * s, p.Head.CFrame * CF(-0.28 * s, 0.1 * s, -0.61 * s), rgb(14, 12, 14), M.SmoothPlastic),
		block(model, "SocketR", V3(0.3, 0.3, 0.06) * s, p.Head.CFrame * CF(0.28 * s, 0.1 * s, -0.61 * s), rgb(14, 12, 14), M.SmoothPlastic),
		ball(model, "EyeL", 0.14 * s, p.Head.CFrame * CF(-0.28 * s, 0.1 * s, -0.64 * s), green, M.Neon),
		ball(model, "EyeR", 0.14 * s, p.Head.CFrame * CF(0.28 * s, 0.1 * s, -0.64 * s), green, M.Neon),
		block(model, "Nose", V3(0.12, 0.2, 0.06) * s, p.Head.CFrame * CF(0, -0.15 * s, -0.61 * s), rgb(14, 12, 14), M.SmoothPlastic),
	}
	for i = -2, 2 do
		table.insert(headParts, block(model, "Tooth", V3(0.1, 0.14, 0.06) * s, p.Head.CFrame * CF(i * 0.16 * s, -0.4 * s, -0.58 * s), rgb(245, 240, 225), M.SmoothPlastic))
	end
	weldGroup(headParts, p.Head)
	for _, arm in ipairs({ p.RightArm, p.LeftArm }) do
		weldGroup({
			block(model, "Humerus", V3(0.28, 1.0, 0.28) * s, arm.CFrame * CF(0, 0.5 * s, 0), bone, M.SmoothPlastic),
			ball(model, "Elbow", 0.4 * s, arm.CFrame * CF(0, 0, 0), bone, M.SmoothPlastic),
			block(model, "Forearm", V3(0.24, 0.9, 0.24) * s, arm.CFrame * CF(0, -0.5 * s, 0), bone, M.SmoothPlastic),
			block(model, "Hand", V3(0.4, 0.3, 0.3) * s, arm.CFrame * CF(0, -1.0 * s, 0), shade(bone, 0.92), M.SmoothPlastic),
			ball(model, "Shoulder", 0.45 * s, arm.CFrame * CF(0, 0.95 * s, 0), bone, M.SmoothPlastic),
		}, arm)
	end
	for _, leg in ipairs({ p.RightLeg, p.LeftLeg }) do
		weldGroup({
			block(model, "Femur", V3(0.3, 1.0, 0.3) * s, leg.CFrame * CF(0, 0.5 * s, 0), bone, M.SmoothPlastic),
			ball(model, "Knee", 0.42 * s, leg.CFrame * CF(0, 0, 0), bone, M.SmoothPlastic),
			block(model, "Shin", V3(0.24, 0.9, 0.24) * s, leg.CFrame * CF(0, -0.5 * s, 0), bone, M.SmoothPlastic),
			block(model, "Foot", V3(0.5, 0.2, 0.9) * s, leg.CFrame * CF(0, -0.95 * s, -0.25 * s), shade(bone, 0.9), M.SmoothPlastic),
		}, leg)
	end
	local rust = rgb(140, 90, 52)
	local ra = p.RightArm
	weldGroup({
		block(model, "SwordGrip", V3(0.16, 0.16, 0.7) * s, ra.CFrame * CF(0, -1.0 * s, -0.2 * s), rgb(70, 50, 36), M.Fabric),
		block(model, "SwordGuard", V3(0.8, 0.14, 0.14) * s, ra.CFrame * CF(0, -1.0 * s, -0.65 * s), rgb(100, 80, 60), M.CorrodedMetal),
		block(model, "SwordBlade", V3(0.3, 0.07, 2.4) * s, ra.CFrame * CF(0, -1.0 * s, -1.9 * s), rust, M.CorrodedMetal),
		block(model, "SwordEdge", V3(0.06, 0.07, 2.3) * s, ra.CFrame * CF(0.15 * s, -1.0 * s, -1.9 * s), rgb(170, 160, 150), M.Metal),
		wedge(model, "SwordTip", V3(0.07, 0.3, 0.5) * s, ra.CFrame * CF(0, -1.0 * s, -3.35 * s) * ANG(0, 0, RAD(90)), rust, M.CorrodedMetal),
	}, ra)
	local la = p.LeftArm
	weldGroup({
		cylinder(model, "Shield", 0.18 * s, 1.9 * s, la.CFrame * CF(-0.7 * s, -0.2 * s, 0), rgb(110, 76, 44), M.Wood),
		cylinder(model, "ShieldRim", 0.24 * s, 2.0 * s, la.CFrame * CF(-0.66 * s, -0.2 * s, 0), rgb(110, 100, 94), M.CorrodedMetal, { Transparency = 0.3 }),
		ball(model, "ShieldBoss", 0.5 * s, la.CFrame * CF(-0.85 * s, -0.2 * s, 0), rgb(150, 140, 130), M.Metal),
	}, la)
	addLight(p.Head, green, 6, 0.6)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

-- Император Вечной Мерзлоты (мировой босс): ледяная корона, плащ, наплечники с кристаллами и огромный ледяной двуручник.
local function buildFrostEmperor(modelId, def)
	local s = def.Scale or 1
	local iceColor = rgb(176, 230, 255)
	local deep = rgb(34, 58, 118)
	local cyan = rgb(100, 235, 255)
	local model, p = humanoidRig(modelId, {
		Scale = s, Skin = rgb(205, 232, 250), SkinMaterial = M.Ice,
		Shirt = deep, ShirtMaterial = M.DiamondPlate, Sleeve = shade(deep, 1.1),
		Pants = shade(deep, 0.8), PantsMaterial = M.Metal,
	})
	local torsoParts = {
		block(model, "Breastplate", V3(2.25, 1.5, 1.25) * s, p.Torso.CFrame * CF(0, 0.2 * s, 0), iceColor, M.Ice, { Transparency = 0.1 }),
		block(model, "ChestRune", V3(0.6, 0.6, 0.12) * s, p.Torso.CFrame * CF(0, 0.3 * s, -0.68 * s) * ANG(0, 0, RAD(45)), cyan, M.Neon),
		block(model, "RuneBarV", V3(0.1, 1.2, 0.08) * s, p.Torso.CFrame * CF(0, 0.3 * s, -0.66 * s), cyan, M.Neon),
		block(model, "Belt", V3(2.2, 0.35, 1.2) * s, p.Torso.CFrame * CF(0, -0.85 * s, 0), rgb(230, 245, 255), M.Metal),
		block(model, "BeltGem", V3(0.4, 0.4, 0.1) * s, p.Torso.CFrame * CF(0, -0.85 * s, -0.62 * s) * ANG(0, 0, RAD(45)), cyan, M.Neon),
		block(model, "Tasset", V3(1.6, 0.9, 1.2) * s, p.Torso.CFrame * CF(0, -1.35 * s, 0), deep, M.Fabric),
	}
	local capeColor = rgb(24, 44, 100)
	for i = 1, 4 do
		table.insert(torsoParts, block(model, "Cape", V3(2.5 - i * 0.12, 1.2, 0.14) * s, p.Torso.CFrame * CF(0, (1.0 - i * 1.15) * s, (0.72 + i * 0.12) * s) * ANG(RAD(-7 * i), 0, 0), capeColor, M.Fabric))
	end
	table.insert(torsoParts, block(model, "CapeTrim", V3(2.3, 0.2, 0.18) * s, p.Torso.CFrame * CF(0, -3.8 * s, 1.2 * s) * ANG(RAD(-28), 0, 0), iceColor, M.Ice))
	table.insert(torsoParts, block(model, "CapeCollar", V3(2.8, 0.8, 0.5) * s, p.Torso.CFrame * CF(0, 1.15 * s, 0.55 * s), shade(capeColor, 1.4), M.Fabric))
	weldGroup(torsoParts, p.Torso)
	local headParts = face(p.Head, s, cyan, rgb(120, 170, 210))
	table.insert(headParts, cylinder(model, "CrownBand", 0.3 * s, 1.5 * s, p.Head.CFrame * CF(0, 0.6 * s, 0) * UPRIGHT, rgb(225, 245, 255), M.Metal))
	local heights = { 1.1, 1.7, 2.3, 1.7, 1.1 }
	for i = -2, 2 do
		table.insert(headParts, wedge(model, "CrownSpike", V3(0.3, heights[i + 3], 0.34) * s, p.Head.CFrame * CF(i * 0.34 * s, (0.75 + heights[i + 3] / 2 - 0.1) * s, 0) * ANG(0, 0, RAD(-i * 6)), iceColor, M.Glass, { Transparency = 0.15 }))
	end
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headParts, wedge(model, "CrownSide", V3(0.26, 1.0, 0.3) * s, p.Head.CFrame * CF(side * 0.85 * s, 0.9 * s, 0.1 * s) * ANG(0, 0, RAD(side * -25)), iceColor, M.Glass, { Transparency = 0.15 }))
	end
	table.insert(headParts, cylinder(model, "FrostHalo", 0.1 * s, 3.6 * s, p.Head.CFrame * CF(0, 0.3 * s, 0.9 * s) * FACING, cyan, M.Neon, { Transparency = 0.55 }))
	table.insert(headParts, ball(model, "CrownGem", 0.35 * s, p.Head.CFrame * CF(0, 0.65 * s, -0.75 * s), rgb(255, 120, 230), M.Neon))
	weldGroup(headParts, p.Head)
	for _, arm in ipairs({ p.RightArm, p.LeftArm }) do
		local side = arm == p.RightArm and 1 or -1
		weldGroup({
			block(model, "Pauldron", V3(1.7, 0.75, 1.7) * s, arm.CFrame * CF(side * 0.1 * s, 0.8 * s, 0), rgb(220, 240, 255), M.Metal),
			wedge(model, "PauldronCrystal", V3(0.4, 1.3, 0.45) * s, arm.CFrame * CF(side * 0.45 * s, 1.5 * s, 0) * ANG(0, 0, RAD(-side * 22)), iceColor, M.Glass, { Transparency = 0.15 }),
			wedge(model, "PauldronCrystal", V3(0.3, 0.9, 0.35) * s, arm.CFrame * CF(side * -0.1 * s, 1.35 * s, 0.1 * s) * ANG(0, 0, RAD(side * 8)), cyan, M.Neon),
			block(model, "Vambrace", V3(1.2, 0.8, 1.2) * s, arm.CFrame * CF(0, -0.7 * s, 0), iceColor, M.Ice),
			block(model, "RuneArm", V3(0.06, 0.5, 0.4) * s, arm.CFrame * CF(side * 0.52 * s, 0.1 * s, 0), cyan, M.Neon),
		}, arm)
	end
	for _, leg in ipairs({ p.RightLeg, p.LeftLeg }) do
		weldGroup({
			block(model, "Greave", V3(1.2, 1.0, 1.2) * s, leg.CFrame * CF(0, -0.3 * s, 0), iceColor, M.Ice),
			block(model, "Boot", V3(1.25, 0.55, 1.7) * s, leg.CFrame * CF(0, -0.8 * s, -0.2 * s), shade(deep, 0.7), M.Metal),
			block(model, "RuneLeg", V3(0.4, 0.06, 0.4) * s, leg.CFrame * CF(0, 0.2 * s, -0.62 * s), cyan, M.Neon),
		}, leg)
	end
	local ra = p.RightArm
	weldGroup({
		block(model, "SwordGrip", V3(0.28, 0.28, 1.2) * s, ra.CFrame * CF(0, -1.0 * s, -0.1 * s), rgb(30, 40, 90), M.Fabric),
		block(model, "SwordGuard", V3(2.0, 0.3, 0.3) * s, ra.CFrame * CF(0, -1.0 * s, -0.85 * s), rgb(230, 245, 255), M.Metal),
		block(model, "SwordGem", V3(0.4, 0.4, 0.4) * s, ra.CFrame * CF(0, -1.0 * s, -0.85 * s), rgb(255, 120, 230), M.Neon),
		block(model, "SwordBlade", V3(0.7, 0.14, 4.4) * s, ra.CFrame * CF(0, -1.0 * s, -3.1 * s), iceColor, M.Glass, { Transparency = 0.2 }),
		block(model, "SwordCore", V3(0.2, 0.16, 4.2) * s, ra.CFrame * CF(0, -1.0 * s, -3.1 * s), cyan, M.Neon),
		block(model, "SwordEdgeL", V3(0.08, 0.1, 4.4) * s, ra.CFrame * CF(-0.36 * s, -1.0 * s, -3.1 * s), rgb(240, 252, 255), M.Neon),
		block(model, "SwordEdgeR", V3(0.08, 0.1, 4.4) * s, ra.CFrame * CF(0.36 * s, -1.0 * s, -3.1 * s), rgb(240, 252, 255), M.Neon),
		wedge(model, "SwordTipL", V3(0.14, 0.35, 1.0) * s, ra.CFrame * CF(-0.18 * s, -1.0 * s, -5.8 * s) * ANG(0, 0, RAD(90)), iceColor, M.Glass, { Transparency = 0.2 }),
		wedge(model, "SwordTipR", V3(0.14, 0.35, 1.0) * s, ra.CFrame * CF(0.18 * s, -1.0 * s, -5.8 * s) * ANG(0, 0, RAD(-90)), iceColor, M.Glass, { Transparency = 0.2 }),
		block(model, "Glove", V3(1.2, 0.55, 1.2) * s, ra.CFrame * CF(0, -0.8 * s, 0), deep, M.Metal),
	}, ra)
	addLight(p.Torso, cyan, 26, 2.5)
	addHumanoid(model, def.HipHeight, def.Name)
	return model
end

local SPECIAL_BUILDERS = {
	FrostWraith = buildFrostWraith,
	FrostMage = buildFrostMage,
	FrostGolem = buildFrostGolem,
	CitadelSentinel = buildCitadelSentinel,
	VoidWarlock = buildVoidWarlock,
	SkeletonWarrior = buildSkeletonWarrior,
	FrostEmperor = buildFrostEmperor,
}

-- Модель строится по def.Model (или самому id); Name модели = id модели, по нему клиент выбирает анимации.
function Models.BuildMob(mobId)
	local def = Config.Mobs[mobId]
	if not def then
		return nil
	end
	local modelId = def.Model or mobId
	if modelId == "Slime" then
		return buildSlime(modelId, def, def.Scale)
	elseif modelId == "Guardian" then
		return buildGuardian(modelId, def, def.Scale)
	elseif SPECIAL_BUILDERS[modelId] then
		return SPECIAL_BUILDERS[modelId](modelId, def)
	end
	return buildExpansionMob(modelId, def)
end

function Models.BuildNPC(kind)
	if kind == "Merchant" then
		return buildMerchant()
	end
	return buildBlacksmith()
end

return Models
