-- GladeSlayer: клиентские эффекты — анимации ударов (через Animator/Motor6D), след меча, всплывающий урон
-- (BillboardGui), вспышка Highlight при попадании, лут, повышение уровня, смерть мобов и «жизнь» NPC.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Models = require(Shared:WaitForChild("Models"))
local Animator = require(Shared:WaitForChild("Animator"))

local Effects = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local handlers = {}
local lastLocalSwing = 0
local popupStack = 0

local function tween(object, time, props, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function isLocal(character)
	return character ~= nil and character == player.Character
end

-- Всплывающий текст в 3D (урон, награды, уровень).
local function popup(position, text, color, size, rise, duration)
	local anchor = Instance.new("Part")
	anchor.Name = "GladePopup"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	-- Без случайного разброса: цифры выстраиваются лесенкой (каждая следующая чуть выше), а не скачут.
	popupStack = (popupStack + 1) % 4
	anchor.CFrame = CFrame.new(position + Vector3.new(0, popupStack * 0.7, 0))
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = rgb(20, 16, 24)
	label.Text = text
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	tween(scale, 0.18, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.18, function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	tween(gui, duration, { StudsOffsetWorldSpace = Vector3.new(0, rise * 0.6, 0) }, Enum.EasingStyle.Quart)
	task.delay(duration * 0.55, function()
		tween(label, duration * 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, duration + 0.1)
end

-- Красная вспышка Highlight поверх модели.
local function flash(model, color)
	if not model or not model.Parent then
		return
	end
	local old = model:FindFirstChild("GladeFlash")
	if old then
		old:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "GladeFlash"
	highlight.FillColor = color or rgb(255, 40, 40)
	highlight.OutlineColor = rgb(255, 255, 255)
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	tween(highlight, 0.35, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(highlight, 0.4)
end

-- Искры из неоновых кубиков в точке попадания.
local function sparks(position, color, count)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(0.25, 0.25, 0.25)
		p.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Parent = workspace
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * (2 + math.random() * 2)
		tween(p, 0.35, { CFrame = p.CFrame + dir, Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 })
		Debris:AddItem(p, 0.4)
	end
end

-- Кольцо-волна (уровень, удар Стража).
local function ring(position, color, diameter, duration)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.2
	p.Size = Vector3.new(0.2, 1, 1)
	p.CFrame = CFrame.new(position) * Models.UPRIGHT
	p.Parent = workspace
	tween(p, duration, { Size = Vector3.new(0.2, diameter, diameter), Transparency = 1 })
	Debris:AddItem(p, duration + 0.05)
end

-- След меча: Trail между двумя Attachment на клинке, включается на время взмаха.
local function swordTrail(character, duration)
	local gear = character:FindFirstChild("GladeGear")
	local weapon = gear and gear:FindFirstChild("Weapon")
	local blade = weapon and weapon:FindFirstChild("Blade")
	if not blade then
		return
	end
	local trail = blade:FindFirstChild("GladeTrail")
	if not trail then
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA"
		a0.Position = Vector3.new(0, 0, blade.Size.Z / 2)
		a0.Parent = blade
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailB"
		a1.Position = Vector3.new(0, 0, -blade.Size.Z / 2 - 0.5)
		a1.Parent = blade
		trail = Instance.new("Trail")
		trail.Name = "GladeTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.18
		trail.LightEmission = 0.8
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Color = ColorSequence.new(Models.SwordTrailColor(weapon:GetAttribute("ItemId")))
		trail.Enabled = false
		trail.Parent = blade
	end
	trail.Enabled = true
	task.delay(duration, function()
		if trail.Parent then
			trail.Enabled = false
		end
	end)
end

local function playSwing(character, style)
	if not character or not character.Parent then
		return
	end
	local length = Animator.PlayOn(character, style, 1) or 0.35
	if style == "SwordSlash1" or style == "SwordSlash2" then
		swordTrail(character, math.min(length, 0.4))
	end
end

-- Локальный предикт удара: анимация без ожидания сервера.
function Effects.LocalSwing(style)
	lastLocalSwing = os.clock()
	playSwing(player.Character, style)
end

function handlers.Swing(character, style)
	-- Свой удар уже проигран предиктом.
	if isLocal(character) and os.clock() - lastLocalSwing < 0.6 then
		return
	end
	playSwing(character, style)
end

function handlers.Damage(model, position, amount, crit, userId)
	if not model then
		return
	end
	local mine = userId == player.UserId
	local text = Rules.FormatNumber(amount)
	if crit then
		popup(position, "КРИТ! " .. text, rgb(255, 150, 40), mine and 34 or 22, 5, 1.1)
	else
		popup(position, text, mine and rgb(255, 240, 120) or rgb(210, 210, 210), mine and 26 or 18, 4, 0.9)
	end
	flash(model, rgb(255, 60, 60))
	sparks(position, crit and rgb(255, 170, 60) or rgb(255, 255, 200), crit and 10 or 5)
	local clip = model.Name == "Slime" and "SlimeHit" or "HitReact"
	local ctrl = Animator.Get(model)
	if ctrl and not (ctrl:IsBusy() and ctrl.Clip ~= clip and ctrl.Clip ~= "GuardianWalk" and ctrl.Clip ~= "SlimeBounce" and ctrl.Clip ~= "MobIdle" and ctrl.Clip ~= "SlimeIdle") then
		ctrl:Play(clip, 1)
	end
end

function handlers.Loot(position, reward)
	if type(reward) ~= "table" then
		return
	end
	local offset = 0
	if (reward.Coins or 0) > 0 then
		popup(position + Vector3.new(0, offset, 0), "+" .. Rules.FormatNumber(reward.Coins) .. " монет", rgb(255, 210, 70), 22, 5, 1.4)
		offset = offset + 1.2
		-- Монетки летят к игроку.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for i = 1, math.min(6, math.max(2, math.floor(reward.Coins / 5))) do
			local coin = Instance.new("Part")
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.15, 0.7, 0.7)
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.Material = Enum.Material.Neon
			coin.Color = rgb(255, 205, 60)
			coin.CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 3, 1, (math.random() - 0.5) * 3))
			coin.Parent = workspace
			local up = tween(coin, 0.3, { CFrame = coin.CFrame + Vector3.new(0, 2.5, 0) }, Enum.EasingStyle.Quad)
			up.Completed:Connect(function()
				if root and root.Parent then
					tween(coin, 0.25 + i * 0.04, { CFrame = root.CFrame, Size = Vector3.new(0.05, 0.2, 0.2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
			Debris:AddItem(coin, 0.9 + i * 0.05)
		end
	end
	if (reward.XP or 0) > 0 then
		popup(position + Vector3.new(0, offset, 0), "+" .. Rules.FormatNumber(reward.XP) .. " XP", rgb(130, 200, 255), 18, 5, 1.4)
		offset = offset + 1.1
	end
	if type(reward.Items) == "table" then
		for _, itemId in ipairs(reward.Items) do
			local def = Config.Items[itemId]
			if def then
				local rarity = Config.Rarities[def.Rarity]
				popup(position + Vector3.new(0, offset, 0), "📦 " .. def.Name, rarity and rarity.Color or rgb(255, 255, 255), 20, 6, 2)
				offset = offset + 1.2
			end
		end
	end
end

function handlers.LevelUp(character, level)
	if not character or not character.Parent then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		popup(root.Position + Vector3.new(0, 4, 0), "УРОВЕНЬ " .. tostring(level) .. "!", rgb(120, 255, 160), 32, 6, 2.2)
		ring(root.Position - Vector3.new(0, 2.8, 0), rgb(120, 255, 160), 16, 0.8)
		sparks(root.Position, rgb(120, 255, 160), 16)
	end
	flash(character, rgb(120, 255, 160))
	Animator.PlayOn(character, "Cheer", 1)
end

function handlers.MobDied(model)
	if not model or not model.Parent then
		return
	end
 model:SetAttribute("MobDead",true)
 Animator.PlayOn(model,"MobDeath",1)
 local root = model.PrimaryPart
 if root then
  sparks(root.Position, model.Name == "Slime" and rgb(120, 230, 100) or rgb(150, 220, 255), 14)
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Transparency < 1 then
			task.delay(0.35,function()
    if item.Parent then tween(item, 0.65, { Transparency = 1 }) end
   end)
   -- Independent local shards tumble without altering server collision or rewards.
   if item.Name ~= "HumanoidRootPart" and math.random() < 0.22 then
    local shard = Instance.new("Part")
    shard.Size, shard.CFrame, shard.Color, shard.Material = item.Size*0.35,item.CFrame,item.Color,item.Material
    shard.Anchored, shard.CanCollide, shard.CanQuery, shard.CanTouch = true,false,false,false
    shard.Parent = workspace
    tween(shard,0.9,{CFrame=shard.CFrame*CFrame.Angles(1.4,0.7,1.2)+Vector3.new(math.random(-4,4),-2,math.random(-4,4)),Transparency=1})
    Debris:AddItem(shard,1)
   end
		elseif item:IsA("BillboardGui") then
			item.Enabled = false
		end
	end
end

function handlers.MobAttack(model, mobId, clip)
	if not model or not model.Parent then
		return
	end
	Animator.PlayOn(model, clip, 1)
	if mobId == "Guardian" and clip == "GuardianSlam" and model.PrimaryPart then
		local def = Config.Mobs[mobId]
		task.delay(def and def.AttackWindup or 0.5, function()
			if model.PrimaryPart then
				ring(model.PrimaryPart.Position - Vector3.new(0, def.HipHeight or 3, 0), rgb(150, 220, 255), 14, 0.5)
			end
		end)
	end
end

function handlers.BossImpact(position, radius)
 ring(position,rgb(255,154,60),radius*2,0.55)
 sparks(position,rgb(255,186,92),24)
 local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if root and (root.Position-position).Magnitude<75 then Effects.Shake(0.4,0.8) end
end

function handlers.PlayerHit(character, damage)
	if not character or not character.Parent then
		return
	end
	flash(character, rgb(255, 40, 40))
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		popup(root.Position + Vector3.new(0, 2, 0), "-" .. Rules.FormatNumber(damage), rgb(255, 80, 80), isLocal(character) and 26 or 18, 4, 0.9)
	end
	Animator.PlayOn(character, "HitReact", 1)
	if isLocal(character) then
		Effects.Shake(0.25, 0.35)
	end
end

-- Лёгкая тряска камеры при получении урона.
function Effects.Shake(duration, strength)
	local camera = workspace.CurrentCamera
	local stop = os.clock() + duration
	task.spawn(function()
		while os.clock() < stop do
			local k = (stop - os.clock()) / duration * strength
			camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * 0.02 * k, (math.random() - 0.5) * 0.02 * k, 0)
			task.wait()
		end
	end)
end

function Effects.Handle(kind, ...)
	local handler = handlers[kind]
	if handler then
		local ok, err = pcall(handler, ...)
		if not ok then
			warn("[GladeSlayer] FX " .. tostring(kind) .. ": " .. tostring(err))
		end
	end
end

-- Фоновые анимации: ходьба мобов и «работа» NPC.
function Effects.Start()
	task.spawn(function()
		while true do
			task.wait(0.15)
			local mobs = workspace:FindFirstChild("GladeSlayerMobs")
			if mobs then
				for _, model in ipairs(mobs:GetChildren()) do
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					local root = model.PrimaryPart
					if humanoid and root and humanoid.Health > 0 and not model:GetAttribute("MobDead") then
      local localRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
      if localRoot and (localRoot.Position-root.Position).Magnitude<210 then
       local moving = (root.AssemblyLinearVelocity*Vector3.new(1,0,1)).Magnitude>1.5
       local ctrl = Animator.Get(model)
       local idle = ctrl.Clip == "MobIdle" or ctrl.Clip == "SlimeIdle"
       local walking = ctrl.Clip == "GuardianWalk" or ctrl.Clip == "SlimeBounce"
       if not ctrl:IsBusy() or (moving and idle) or (not moving and walking) then
        local clip = moving and (model.Name=="Slime" and "SlimeBounce" or "GuardianWalk") or (model.Name=="Slime" and "SlimeIdle" or "MobIdle")
        ctrl:Play(clip, model:GetAttribute("Phase")==2 and 1.2 or 1)
       end
      end
     end
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2.6)
			local npcs = workspace:FindFirstChild("GladeSlayerNPCs")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if npcs then
				for _, model in ipairs(npcs:GetChildren()) do
					local kind = model:GetAttribute("NPC")
					local ctrl = Animator.Get(model)
					if ctrl and not ctrl:IsBusy() then
						if kind == "Blacksmith" then
							ctrl:Play("Hammer", 1)
						elseif kind == "Merchant" and root and model.PrimaryPart and (root.Position - model.PrimaryPart.Position).Magnitude < 22 and math.random() < 0.5 then
							ctrl:Play("Wave", 1)
						end
					end
				end
			end
		end
	end)
end

return Effects
