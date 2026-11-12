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

function Models.BuildMob(mobId)
	if mobId == "Slime" then
		return buildSlime()
	elseif mobId == "Guardian" then
		return buildGuardian()
 elseif Config.Mobs[mobId] then
  return buildExpansionMob(mobId)
	end
	return nil
end

function Models.BuildNPC(kind)
	if kind == "Merchant" then
		return buildMerchant()
	end
	return buildBlacksmith()
end

return Models
