-- GladeSlayer: процедурный аниматор. Твинит Motor6D.C0 через TweenService — без AnimationId и ассетов.
-- Работает с R6 (Right Shoulder, RootJoint...), R15 (RightShoulder, Waist, RightElbow...)
-- и с ригами мобов/NPC из Models. Запускается на клиентах: каждый клиент анимирует локально.
--
-- Поза сустава = { pitch, yaw, roll, twist } в градусах + необязательное смещение P.
-- Вращение задаётся в пространстве родительской детали вокруг шарнира, поэтому одни и те же клипы
-- подходят для R6 и R15: pitch +90 поднимает руку вперёд, roll +90 отводит правую руку в сторону
-- (для левой — roll -90), yaw + поворачивает влево, pitch торса + отклоняет назад.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Animator = {}
Animator.__index = Animator

local JOINTS = {
	Torso = { "RootJoint", "Waist" },
	Head = { "Neck" },
	RightArm = { "Right Shoulder", "RightShoulder" },
	LeftArm = { "Left Shoulder", "LeftShoulder" },
	RightForearm = { "RightElbow" },
	LeftForearm = { "LeftElbow" },
	RightLeg = { "Right Hip", "RightHip" },
	LeftLeg = { "Left Hip", "LeftHip" },
	Body = { "Body" },
}
Animator.JointNames = JOINTS

-- Суставы, которые мы забираем у стандартной анимации ходьбы игрока на время удара.
local OVERRIDE = { Torso = true, Head = true, RightArm = true, LeftArm = true, RightForearm = true, LeftForearm = true }

local function deg(value)
	return math.rad(value or 0)
end

function Animator.PoseCFrame(base, pose)
	if not pose then
		return base
	end
	local rotation = CFrame.Angles(0, deg(pose[2]), 0)
		* CFrame.Angles(deg(pose[1]), 0, 0)
		* CFrame.Angles(0, 0, deg(pose[3]))
		* CFrame.Angles(0, deg(pose[4]), 0)
	local offset = pose.P or Vector3.new(0, 0, 0)
	return CFrame.new(base.Position + offset) * rotation * (base - base.Position)
end

local function key(time, style, direction, pose, scale)
	return { Time = time, Style = style, Direction = direction, Pose = pose or {}, Scale = scale }
end

local function hold(time)
	return { Time = time, Hold = true }
end

local V3 = Vector3.new

local CLIPS = {
	-- Правый хук: замах с разворотом корпуса → удар по дуге → возврат в стойку, левая рука держит блок.
	PunchRight = {
		key(0.08, "Quad", "Out", {
			Torso = { 0, -18, 0 }, Head = { 0, 12, 0 },
			RightArm = { 70, -20, 35 }, RightForearm = { 55 },
			LeftArm = { 60, 22, -12 }, LeftForearm = { 75 },
		}),
		key(0.09, "Back", "Out", {
			Torso = { -4, 24, 0 }, Head = { 0, -10, 0 },
			RightArm = { 88, 35, 20 }, RightForearm = { 25 },
			LeftArm = { 55, 18, -12 }, LeftForearm = { 80 },
		}),
		hold(0.06),
		key(0.2, "Quad", "InOut"),
	},
	PunchLeft = {
		key(0.08, "Quad", "Out", {
			Torso = { 0, 18, 0 }, Head = { 0, -12, 0 },
			LeftArm = { 70, 20, -35 }, LeftForearm = { 55 },
			RightArm = { 60, -22, 12 }, RightForearm = { 75 },
		}),
		key(0.09, "Back", "Out", {
			Torso = { -4, -24, 0 }, Head = { 0, 10, 0 },
			LeftArm = { 88, -35, -20 }, LeftForearm = { 25 },
			RightArm = { 55, -18, 12 }, RightForearm = { 80 },
		}),
		hold(0.06),
		key(0.2, "Quad", "InOut"),
	},
	-- Рубящий удар сверху по диагонали.
	SwordSlash1 = {
		key(0.12, "Quad", "Out", {
			Torso = { 6, -20, 0 }, Head = { -4, 10, 0 },
			RightArm = { 165, -25, 20 }, RightForearm = { 20 },
			LeftArm = { 30, 0, -20 },
		}),
		key(0.1, "Quad", "In", {
			Torso = { -10, 28, 0 }, Head = { -6, -12, 0 },
			RightArm = { 35, 40, -15 }, RightForearm = { 5 },
			LeftArm = { 20, 0, -25 },
		}),
		hold(0.06),
		key(0.22, "Quad", "InOut"),
	},
	-- Восходящий удар с обратной стороны (для комбо).
	SwordSlash2 = {
		key(0.12, "Quad", "Out", {
			Torso = { -4, 26, 0 }, Head = { 0, -10, 0 },
			RightArm = { 40, 70, -25 }, RightForearm = { 30 },
			LeftArm = { 25, 0, -30 },
		}),
		key(0.1, "Quad", "In", {
			Torso = { 8, -30, 0 }, Head = { 4, 12, 0 },
			RightArm = { 140, -45, 35 }, RightForearm = { 10 },
			LeftArm = { 35, 0, -35 },
		}),
		hold(0.06),
		key(0.22, "Quad", "InOut"),
	},
	-- Отдача при получении урона (вспышку Highlight делает Effects).
	HitReact = {
		key(0.07, "Quad", "Out", {
			Torso = { 14, 6, 0 }, Head = { 18, 0, 0 },
			RightArm = { 20, 0, 18 }, LeftArm = { 20, 0, -18 },
		}),
		key(0.24, "Quad", "InOut"),
	},
	Cheer = {
		key(0.22, "Back", "Out", {
			Torso = { 6, 0, 0 }, Head = { 10, 0, 0 },
			RightArm = { 0, 0, 160 }, LeftArm = { 0, 0, -160 },
		}),
		hold(0.45),
		key(0.3, "Quad", "InOut"),
	},
	-- Страж: удар двумя кулаками сверху (удар приходится на 0.54 с, как AttackWindup).
	GuardianSlam = {
		key(0.42, "Quad", "Out", {
			Torso = { 14, 0, 0 }, Head = { 8, 0, 0 },
			RightArm = { 170, 0, 12 }, LeftArm = { 170, 0, -12 },
			RightLeg = { -14, 0, 0 }, LeftLeg = { -14, 0, 0 },
		}),
		key(0.12, "Quad", "In", {
			Torso = { -22, 0, 0 }, Head = { -10, 0, 0 },
			RightArm = { 50, 0, 8 }, LeftArm = { 50, 0, -8 },
			RightLeg = { 22, 0, 0 }, LeftLeg = { 22, 0, 0 },
		}),
		hold(0.14),
		key(0.35, "Quad", "InOut"),
	},
	GuardianPunch = {
		key(0.38, "Quad", "Out", {
			Torso = { 0, -30, 0 }, Head = { 0, 14, 0 },
			RightArm = { 70, -30, 50 }, LeftArm = { 40, 20, -10 },
		}),
		key(0.14, "Back", "Out", {
			Torso = { -8, 25, 0 }, Head = { 0, -10, 0 },
			RightArm = { 92, 15, 10 }, LeftArm = { 20, 0, -10 },
		}),
		hold(0.1),
		key(0.3, "Quad", "InOut"),
	},
	-- Слизень: сжатие → рывок вперёд с растяжением → возврат (Scale твинит SpecialMesh).
	SlimeLunge = {
		key(0.22, "Quad", "Out", { Body = { 0, 0, 0, P = V3(0, -0.25, 0.5) } }, V3(1.18, 0.8, 1.18)),
		key(0.1, "Back", "Out", { Body = { -15, 0, 0, P = V3(0, 0.6, -2.0) } }, V3(0.86, 1.18, 0.86)),
		hold(0.08),
		key(0.28, "Quad", "InOut", {}, V3(1, 1, 1)),
	},
	SlimeHit = {
		key(0.06, "Quad", "Out", { Body = { 8, 0, 0, P = V3(0, -0.15, 0.35) } }, V3(1.15, 0.82, 1.15)),
		key(0.22, "Back", "Out", {}, V3(1, 1, 1)),
	},
	-- Передвижение мобов (Effects включает клип, пока моб движется): слизень пружинит, Страж шагает.
	SlimeBounce = {
		-- Мягкое «желе»: небольшая высота, тело не отрывается от земли рывком.
		key(0.18, "Sine", "InOut", { Body = { 0, 0, 0, P = V3(0, -0.08, 0) } }, V3(1.08, 0.92, 1.08)),
		key(0.22, "Sine", "InOut", { Body = { -4, 0, 0, P = V3(0, 0.22, 0) } }, V3(0.96, 1.06, 0.96)),
		key(0.2, "Sine", "InOut", {}, V3(1, 1, 1)),
	},
	GuardianWalk = {
		key(0.32, "Sine", "InOut", {
			Torso = { 0, 4, 0 }, RightLeg = { 24, 0, 0 }, LeftLeg = { -24, 0, 0 },
			RightArm = { -16, 0, 6 }, LeftArm = { 16, 0, -6 },
		}),
		key(0.32, "Sine", "InOut", {
			Torso = { 0, -4, 0 }, RightLeg = { -24, 0, 0 }, LeftLeg = { 24, 0, 0 },
			RightArm = { 16, 0, 6 }, LeftArm = { -16, 0, -6 },
		}),
	},
	-- NPC
	Hammer = {
		key(0.45, "Quad", "Out", {
			Torso = { 6, 0, 0 }, Head = { -8, 0, 0 },
			RightArm = { 150, 0, 10 }, LeftArm = { 20, 0, -8 },
		}),
		key(0.14, "Quad", "In", {
			Torso = { -8, 0, 0 }, Head = { -14, 0, 0 },
			RightArm = { 55, 0, 5 }, LeftArm = { 15, 0, -8 },
		}),
		hold(0.12),
		key(0.5, "Quad", "InOut"),
	},
	Wave = {
		key(0.25, "Back", "Out", { RightArm = { 10, 0, 150 }, Head = { 0, 10, 0 } }),
		key(0.18, "Sine", "InOut", { RightArm = { 10, 0, 125 }, Head = { 0, 10, 0 } }),
		key(0.18, "Sine", "InOut", { RightArm = { 10, 0, 150 }, Head = { 0, 10, 0 } }),
		key(0.18, "Sine", "InOut", { RightArm = { 10, 0, 125 }, Head = { 0, 10, 0 } }),
		key(0.3, "Quad", "InOut"),
	},
}
CLIPS.MobIdle = {
 key(0.9, "Sine", "InOut", { Torso = {2, 0, 0}, Head = {-2, 3, 0}, RightArm = {0, 0, 4}, LeftArm = {0, 0, -4} }),
 key(0.9, "Sine", "InOut", { Torso = {-1, 0, 0}, Head = {1, -3, 0}, RightArm = {0, 0, 2}, LeftArm = {0, 0, -2} }),
}
CLIPS.SlimeIdle = {
 key(0.9, "Sine", "InOut", { Body = {0,0,0} }, V3(1.025,0.97,1.025)),
 key(0.9, "Sine", "InOut", {}, V3(1,1,1)),
}
CLIPS.BossSlam = {
 key(1.45, "Sine", "Out", { Torso = {12,0,0}, RightArm = {170,0,18}, LeftArm = {170,0,-18} }),
 key(0.2, "Quad", "In", { Torso = {-22,0,0}, RightArm = {45,0,8}, LeftArm = {45,0,-8} }),
 hold(0.15), key(0.35, "Quad", "Out"),
}
CLIPS.MobDeath = {
 key(0.25, "Quad", "Out", { Torso = {15,0,12}, Head = {-20,0,0}, RightArm = {20,0,30}, LeftArm = {-10,0,-40} }),
 key(0.55, "Quad", "In", { Torso = {72,0,25,P=V3(0,-1.5,0)}, Head = {10,0,0}, RightLeg = {-20}, LeftLeg = {15} }),
 hold(0.3),
}
Animator.Clips = CLIPS

function Animator.ClipLength(name, speed)
	local clip = CLIPS[name]
	if not clip then
		return 0
	end
	local total = 0
	for _, frame in ipairs(clip) do
		total = total + frame.Time
	end
	return total / (speed or 1)
end

local controllers = setmetatable({}, { __mode = "k" })
local active = {}

function Animator.Get(model)
	local existing = controllers[model]
	if existing then
		return existing
	end
	local self = setmetatable({
		Model = model,
		Joints = {},
		Base = {},
		Tweens = {},
		Token = 0,
		BusyUntil = 0,
		Clip = nil,
	}, Animator)
	local found = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Motor6D") and not found[item.Name] then
			found[item.Name] = item
		end
	end
	for jointKey, names in pairs(JOINTS) do
		for _, name in ipairs(names) do
			local motor = found[name]
			if motor then
				self.Joints[jointKey] = motor
				self.Base[jointKey] = motor.C0
				break
			end
		end
	end
	local mesh = model:FindFirstChild("SquashMesh", true)
	if mesh and mesh:IsA("SpecialMesh") then
		self.Mesh = mesh
		self.MeshBase = mesh.Scale
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	self.Override = humanoid ~= nil and humanoid:FindFirstChildOfClass("Animator") ~= nil
	controllers[model] = self
	-- Слабые ключи не освободят модель (контроллер ссылается на неё), поэтому чистим явно.
	pcall(function()
		model.Destroying:Connect(function()
			controllers[model] = nil
			active[self] = nil
			self.Token = self.Token + 1
		end)
	end)
	return self
end

function Animator:IsBusy()
	return os.clock() < self.BusyUntil
end

function Animator:CancelTweens()
	for jointKey, tween in pairs(self.Tweens) do
		tween:Cancel()
		self.Tweens[jointKey] = nil
	end
end

function Animator:_apply(frame, duration)
	local info = TweenInfo.new(duration, Enum.EasingStyle[frame.Style or "Quad"], Enum.EasingDirection[frame.Direction or "Out"])
	for jointKey, motor in pairs(self.Joints) do
		if motor.Parent then
			local target = Animator.PoseCFrame(self.Base[jointKey], frame.Pose[jointKey])
			local tween = TweenService:Create(motor, info, { C0 = target })
			self.Tweens[jointKey] = tween
			tween:Play()
		end
	end
	if self.Mesh and self.Mesh.Parent then
		local scale = frame.Scale or V3(1, 1, 1)
		local base = self.MeshBase
		local tween = TweenService:Create(self.Mesh, info, { Scale = V3(base.X * scale.X, base.Y * scale.Y, base.Z * scale.Z) })
		self.Tweens.Mesh = tween
		tween:Play()
	end
end

-- Запускает клип; новый клип плавно перехватывает текущую позу. Возвращает длительность.
function Animator:Play(name, speed)
	local clip = CLIPS[name]
	if not clip or not self.Model.Parent then
		return 0
	end
	speed = speed or 1
	self.Token = self.Token + 1
	local token = self.Token
	self:CancelTweens()
	local total = Animator.ClipLength(name, speed)
	self.BusyUntil = os.clock() + total
	self.Clip = name
	active[self] = true
	task.spawn(function()
		for _, frame in ipairs(clip) do
			if self.Token ~= token or not self.Model.Parent then
				return
			end
			local duration = frame.Time / speed
			if not frame.Hold then
				self:_apply(frame, duration)
			end
			task.wait(duration)
		end
		if self.Token == token then
			self.Clip = nil
		end
	end)
	return total
end

function Animator:Stop(fadeTime)
	self.Token = self.Token + 1
	self:CancelTweens()
	self.BusyUntil = 0
	self.Clip = nil
	self:_apply({ Pose = {}, Style = "Quad", Direction = "Out" }, fadeTime or 0.15)
end

-- Удобный вызов без контроллера: Animator.PlayOn(model, "PunchRight").
function Animator.PlayOn(model, name, speed)
	if not model or not model.Parent then
		return 0
	end
	return Animator.Get(model):Play(name, speed)
end

-- Пока идёт клип, гасим Transform стандартной анимации для рук/корпуса игрока,
-- чтобы удар не смешивался с раскачиванием рук при беге (ноги продолжают идти).
if RunService:IsClient() then
	local ok, signal = pcall(function()
		return RunService.PreSimulation
	end)
	if not ok or not signal then
		signal = RunService.Stepped
	end
	signal:Connect(function()
		local now = os.clock()
		for controller in pairs(active) do
			if now >= controller.BusyUntil or not controller.Model.Parent then
				active[controller] = nil
			elseif controller.Override then
				for jointKey, motor in pairs(controller.Joints) do
					if OVERRIDE[jointKey] then
						motor.Transform = CFrame.new()
					end
				end
			end
		end
	end)
end

return Animator
