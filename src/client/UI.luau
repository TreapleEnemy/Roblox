-- GladeSlayer: весь интерфейс создаётся кодом — HUD (ХП с плавным «следом», XP, монеты, баффы),
-- окна Прокачки, Инвентаря, Скупщика и Кузницы, тосты. UICorner/UIStroke/UIGradient + анимации TweenService.
-- Клиент только отображает состояние и шлёт запросы; все проверки делает сервер.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local UI = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local remotes = nil
local state = nil
local gui = nil
local panels = {}
local currentPanel = nil
local currentShop = nil
local selectedItem = nil
local shopTab = Config.ShopTabs[1].Id
local refs = {}
local buffEnds = {}
local onAttack = nil
local lastCoins = nil
local lastLevel = nil
local lastHealth = nil
local hpRatio = 1
local inventoryFilter = "All"
local discardConfirmUntil = 0
local refreshDetails
local bossSmoothRatio = 1

local THEME = {
	Panel = rgb(26, 28, 40),
	PanelLight = rgb(38, 42, 58),
	Card = rgb(44, 48, 66),
	Stroke = rgb(90, 100, 140),
	Text = rgb(240, 242, 250),
	Muted = rgb(160, 166, 190),
	Accent = rgb(110, 170, 255),
	Gold = rgb(255, 205, 70),
	Green = rgb(90, 210, 120),
	Red = rgb(235, 80, 80),
	Gray = rgb(90, 94, 110),
}
local TOAST_COLORS = { info = THEME.Accent, success = THEME.Green, error = THEME.Red, loot = THEME.Gold }

-- Конструкторы ----------------------------------------------------------------------------------
local function new(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", { Color = color or THEME.Stroke, Thickness = thickness or 1.5, Transparency = transparency or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function gradient(parent, top, bottom, rotation)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

local function label(parent, text, size, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text or "",
		TextSize = size or 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
	for key, value in pairs(props or {}) do
		l[key] = value
	end
	return l
end

local function tween(object, time, props, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function button(parent, text, color, callback, props)
	local b = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color or THEME.Accent,
		Text = text,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = rgb(255, 255, 255),
	}, parent)
	for key, value in pairs(props or {}) do
		b[key] = value
	end
	corner(b, 8)
	gradient(b, rgb(255, 255, 255), rgb(200, 200, 210), 90)
	stroke(b, rgb(255, 255, 255), 1, 0.75)
	local scale = new("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.94 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.05 })
	end)
 b.Activated:Connect(function()
  if refs.ClickSound then refs.ClickSound:Play() end
  if callback then callback() end
 end)
	return b
end

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function itemColor(itemId)
	local def = Config.Items[itemId]
	local rarity = def and Config.Rarities[def.Rarity]
	return rarity and rarity.Color or THEME.Text, rarity and rarity.Name or ""
end

local function count(itemId)
	if not state then
		return 0
	end
	return state.Inventory[itemId] or 0
end

local function free(itemId)
	if not state then
		return 0
	end
	return Rules.FreeCount(state, itemId)
end

local function isEquipped(itemId)
	if not state then
		return nil
	end
	for _, slot in ipairs(Config.Slots) do
		if state.Equipped[slot] == itemId then
			return slot
		end
	end
	return nil
end

-- Запрос на сервер: ответ показывается тостом, новое состояние придёт через State.
local function request(action, a, b)
	task.spawn(function()
		local ok, okResult, message = pcall(function()
			return remotes.Request:InvokeServer(action, a, b)
		end)
		if not ok then
			UI.Toast("Нет связи с сервером.", "error")
			return
		end
		if type(message) == "string" and message ~= "" then
			UI.Toast(message, okResult and "success" or "error")
		end
	end)
end

-- Окна ------------------------------------------------------------------------------------------
local function makePanel(name, title, size, accent)
	local root = new("CanvasGroup", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = THEME.Panel,
		GroupTransparency = 1,
		Visible = false,
	}, gui)
	corner(root, 16)
	gradient(root, rgb(255, 255, 255), rgb(170, 176, 200), 90)
	local outline = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, root)
	corner(outline, 16)
	stroke(outline, accent or THEME.Accent, 2, 0.2)
	local scale = new("UIScale", { Scale = 0.85 }, root)
	local header = new("Frame", { BackgroundColor3 = accent or THEME.Accent, Size = UDim2.new(1, 0, 0, 48) }, root)
	gradient(header, rgb(255, 255, 255), rgb(150, 150, 170), 90)
	label(header, title, 22, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -80, 1, 0), TextStrokeTransparency = 0.6 })
	button(header, "✕", THEME.Red, function()
		UI.Close()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 34), TextSize = 18 })
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 1, -70) }, root)
	panels[name] = { Root = root, Scale = scale, Body = body }
	return body
end

local function scroller(parent, props, grid)
	local s = new("ScrollingFrame", {
		BackgroundColor3 = THEME.PanelLight,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = THEME.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, parent)
	for key, value in pairs(props or {}) do
		s[key] = value
	end
	corner(s, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, s)
	if grid then
		new("UIGridLayout", { CellSize = grid, CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	else
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	end
	return s
end

local function card(parent, height, order)
	local c = new("Frame", { BackgroundColor3 = THEME.Card, Size = UDim2.new(1, -4, 0, height), LayoutOrder = order or 0 }, parent)
	corner(c, 10)
	stroke(c, THEME.Stroke, 1, 0.6)
	return c
end

-- Прокачка ---------------------------------------------------------------------------------------
local function buildStats()
	local body = makePanel("Stats", "⚡ Прокачка", UDim2.fromOffset(560, 470), rgb(120, 110, 255))
	refs.StatPoints = label(body, "", 17, { Size = UDim2.new(1, 0, 0, 24), TextColor3 = THEME.Gold })
	label(body, "Очки навыков дают за каждый новый уровень. Стоимость растёт с уровнем характеристики.", 13, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 20), TextColor3 = THEME.Muted, Font = Enum.Font.GothamMedium })
	refs.StatList = scroller(body, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50) })
end

local function refreshStats()
	if not state or not refs.StatList then
		return
	end
	refs.StatPoints.Text = "Очки навыков: " .. state.SkillPoints .. "   •   Уровень " .. state.Level
	clear(refs.StatList)
	for index, statId in ipairs(Config.StatOrder) do
		local def = Config.Stats[statId]
		local level = state.Stats[statId] or 0
		local maxed = level >= def.MaxLevel
		local cost = Rules.UpgradeCost(level)
		local c = card(refs.StatList, 78, index)
		local icon = new("Frame", { BackgroundColor3 = def.Color, Position = UDim2.fromOffset(10, 13), Size = UDim2.fromOffset(52, 52) }, c)
		corner(icon, 12)
		gradient(icon, rgb(255, 255, 255), rgb(150, 150, 150), 45)
		Icons.Draw(icon,statId,def.Color)
		label(c, def.Name .. "  ур. " .. level .. "/" .. def.MaxLevel, 17, { Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -210, 0, 22) })
		local now = Rules.FormatStat(statId, Rules.StatValue(statId, level))
		local nextText = maxed and "МАКС" or Rules.FormatStat(statId, Rules.StatValue(statId, level + 1))
		label(c, now .. "  →  " .. nextText, 15, { Position = UDim2.fromOffset(74, 30), Size = UDim2.new(1, -210, 0, 20), TextColor3 = def.Color })
		label(c, def.Description, 12, { Position = UDim2.fromOffset(74, 50), Size = UDim2.new(1, -210, 0, 20), TextColor3 = THEME.Muted, Font = Enum.Font.GothamMedium })
		local affordable = not maxed and state.SkillPoints >= cost
		local b = button(c, maxed and "МАКС" or ("+  (" .. cost .. " оч.)"), affordable and THEME.Green or THEME.Gray, function()
			if maxed then
				return
			end
			request("Upgrade", statId)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(118, 42) })
		b.Active = not maxed
	end
end

-- Инвентарь -------------------------------------------------------------------------------------
local function buildInventory()
	local body = makePanel("Inventory", "🎒 Инвентарь", UDim2.fromOffset(700, 480), rgb(90, 180, 140))
	refs.SlotRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -230, 0, 64) }, body)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, refs.SlotRow)
	refs.Grid = scroller(body, { Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, -230, 1, -120) }, UDim2.fromOffset(96, 104))
	local details = new("Frame", { BackgroundColor3 = THEME.PanelLight, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 218, 1, 0) }, body)
	corner(details, 10)
	stroke(details, THEME.Stroke, 1, 0.5)
 refs.Details = details
 refs.Filter = button(body,"Фильтр: все",THEME.Gray,function()
  local order={"All","Gear","Potion","Junk","Rare"}
  inventoryFilter=order[(table.find(order,inventoryFilter) or 1)%#order+1]
  local names={All="все",Gear="экипировка",Potion="зелья",Junk="мусор",Rare="редкие+"}
  refs.Filter.Text="Фильтр: "..names[inventoryFilter]
  UI.Refresh()
 end,{Position=UDim2.fromOffset(0,72),Size=UDim2.fromOffset(202,36),TextSize=13})
 refs.Discard = button(body,"Удалить мусор",THEME.Red,function()
  if os.clock()>discardConfirmUntil then
   discardConfirmUntil=os.clock()+4
   refs.Discard.Text="Точно удалить?"
   UI.Toast("Ещё раз в течение 4 секунд: удалить дешёвый мусор без монет. Надетое и редкие материалы защищены.","info")
   task.delay(4,function() if os.clock()>=discardConfirmUntil and refs.Discard then refs.Discard.Text="Удалить мусор" end end)
  else
   discardConfirmUntil=0
   refs.Discard.Text="Удалить мусор"
   request("DiscardJunk")
  end
 end,{Position=UDim2.fromOffset(210,72),Size=UDim2.fromOffset(218,36),TextSize=13})
end

local function itemCell(parent, itemId, amount, order, equippedSlot)
	local color = itemColor(itemId)
	local def = Config.Items[itemId]
	local cell = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = color:Lerp(THEME.Panel,0.72), LayoutOrder = order }, parent)
	corner(cell, 10)
	local s = stroke(cell, color, selectedItem == itemId and 3 or 1.5, selectedItem == itemId and 0 or 0.25)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gradient(cell, rgb(255, 255, 255), rgb(175, 175, 190), 90)
	Icons.Draw(cell,Icons.ItemKind(def),color,UDim2.fromOffset(25,8),UDim2.fromOffset(46,46))
	label(cell, def and def.Name or itemId, 11, { Position = UDim2.fromOffset(4, 60), Size = UDim2.new(1, -8, 0, 38), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = color, TextStrokeTransparency = 0.5 })
	if amount and amount > 1 then
		label(cell, "x" .. amount, 13, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(36, 16), TextXAlignment = Enum.TextXAlignment.Right })
	end
	if equippedSlot then
		local badge = new("Frame", { BackgroundColor3 = THEME.Green, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(16, 16) }, cell)
		corner(badge, 5)
		label(badge, "E", 12, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	end
	cell.MouseEnter:Connect(function()
  selectedItem = itemId
  if refreshDetails then refreshDetails() end
 end)
 cell.Activated:Connect(function()
  selectedItem = itemId
  if refs.ClickSound then refs.ClickSound:Play() end
  if def and def.Kind=="Gear" then
   local slot=isEquipped(itemId)
   if slot then request("Unequip",slot) else request("Equip",itemId) end
  end
  UI.Refresh()
 end)
	return cell
end

refreshDetails = function()
	local d = refs.Details
	clear(d)
	local def = selectedItem and Config.Items[selectedItem]
	if not def or count(selectedItem) <= 0 then
		label(d, "Выбери предмет, чтобы увидеть описание.", 14, { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 60), TextColor3 = THEME.Muted, Font = Enum.Font.GothamMedium })
		return
	end
	local color, rarityName = itemColor(selectedItem)
	label(d, def.Name, 19, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 48), TextColor3 = color, TextYAlignment = Enum.TextYAlignment.Top })
	label(d, rarityName .. "  •  x" .. count(selectedItem), 13, { Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 18), TextColor3 = THEME.Muted })
	label(d, def.Description or "", 13, { Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(12, 80), Size = UDim2.new(1, -24, 0, 90), TextYAlignment = Enum.TextYAlignment.Top })
	label(d, Rules.BonusText(selectedItem), 14, { Position = UDim2.fromOffset(12, 172), Size = UDim2.new(1, -24, 0, 40), TextColor3 = THEME.Green, TextYAlignment = Enum.TextYAlignment.Top })
	label(d, "Скупщик даст: " .. Rules.FormatNumber(def.Sell or 0) .. " 🪙", 13, { Position = UDim2.fromOffset(12, 216), Size = UDim2.new(1, -24, 0, 18), TextColor3 = THEME.Gold })
	local equippedSlot = isEquipped(selectedItem)
	local actionProps = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 42) }
	if def.Kind == "Gear" then
		if equippedSlot then
			button(d, "Снять", THEME.Red, function()
				request("Unequip", equippedSlot)
			end, actionProps)
		else
			button(d, "Надеть", THEME.Green, function()
				request("Equip", selectedItem)
			end, actionProps)
		end
	elseif def.Kind == "Potion" then
		button(d, "Выпить", rgb(170, 110, 255), function()
			request("UsePotion", selectedItem)
		end, actionProps)
	else
		label(d, "Хлам: продай Скупщику на рынке.", 13, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 40), TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Center })
	end
end

local function refreshInventory()
	if not state or not refs.Grid then
		return
	end
	clear(refs.SlotRow)
	for _, slot in ipairs(Config.Slots) do
		local itemId = state.Equipped[slot]
		local holder = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = THEME.PanelLight, Size = UDim2.fromOffset(136, 60) }, refs.SlotRow)
		corner(holder, 10)
		stroke(holder, itemId and itemColor(itemId) or THEME.Gray, 1.5, 0.2)
		label(holder, Config.SlotNames[slot], 12, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16), TextColor3 = THEME.Muted })
		label(holder, itemId and Config.Items[itemId].Name or "— пусто —", 14, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 30), TextColor3 = itemId and itemColor(itemId) or THEME.Gray })
		holder.Activated:Connect(function()
			if itemId then
				selectedItem = itemId
				UI.Refresh()
			end
		end)
	end
	clear(refs.Grid)
	local order = 0
	for _, itemId in ipairs(Config.ItemOrder) do
		local amount = count(itemId)
  local def = Config.Items[itemId]
  local rarity = Config.Rarities[def.Rarity]
  local matches = inventoryFilter=="All" or (inventoryFilter=="Gear" and def.Kind=="Gear") or (inventoryFilter=="Potion" and def.Kind=="Potion") or (inventoryFilter=="Junk" and (def.Rarity=="Junk" or def.Junk)) or (inventoryFilter=="Rare" and rarity.Order>=4)
  if amount > 0 and matches then
   order = order + 1
			itemCell(refs.Grid, itemId, amount, order, isEquipped(itemId))
		end
	end
	if order == 0 then
		label(refs.Grid, "Пусто. Побей слизней!", 14, { Size = UDim2.fromOffset(200, 40), TextColor3 = THEME.Muted })
	end
	refreshDetails()
end

-- Скупщик ---------------------------------------------------------------------------------------
local function buildMerchant()
	local body = makePanel("Merchant", "💰 Скупщик", UDim2.fromOffset(580, 480), rgb(220, 170, 60))
	refs.JunkInfo = label(body, "", 15, { Size = UDim2.new(1, -230, 0, 44), TextColor3 = THEME.Gold })
	refs.SellAll = button(body, "Продать весь хлам", THEME.Green, function()
		request("SellAll")
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(220, 44) })
	refs.SellList = scroller(body, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) })
end

local function refreshMerchant()
	if not state or not refs.SellList then
		return
	end
	refs.JunkInfo.Text = "Хлам: " .. (state.JunkCount or 0) .. " шт. → " .. Rules.FormatNumber(state.JunkValue or 0) .. " 🪙\nНадетые вещи не продаются."
	clear(refs.SellList)
	local order = 0
	for _, itemId in ipairs(Config.ItemOrder) do
		local def = Config.Items[itemId]
		local amount = free(itemId)
		if def and amount > 0 and (def.Sell or 0) > 0 then
			order = order + 1
			local c = card(refs.SellList, 58, order)
			local color, rarityName = itemColor(itemId)
			label(c, def.Name .. "  x" .. amount, 16, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -250, 0, 24), TextColor3 = color })
			label(c, rarityName .. "  •  " .. Rules.FormatNumber(def.Sell) .. " 🪙 за шт.", 13, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -250, 0, 20), TextColor3 = THEME.Muted })
			button(c, "Продать 1", THEME.Accent, function()
				request("Sell", itemId, 1)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -124, 0.5, 0), Size = UDim2.fromOffset(104, 38) })
			button(c, "Все (" .. Rules.FormatNumber(def.Sell * amount) .. ")", THEME.Green, function()
				request("Sell", itemId, amount)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(108, 38) })
		end
	end
	if order == 0 then
		label(refs.SellList, "Нечего продавать. Возвращайся с добычей!", 14, { Size = UDim2.new(1, 0, 0, 40), TextColor3 = THEME.Muted })
	end
end

-- Кузница ----------------------------------------------------------------------------------------
local function tabMatches(tab, def)
	if tab.Filter == "Weapon" then
		return def.Kind == "Gear" and def.Slot == "Weapon"
	elseif tab.Filter == "Defense" then
		return def.Kind == "Gear" and def.Slot ~= "Weapon"
	end
	return def.Kind == "Potion"
end

local function buildBlacksmith()
	local body = makePanel("Blacksmith", "⚒ Кузница и Алхимия", UDim2.fromOffset(600, 500), rgb(230, 110, 60))
	refs.Tabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, body)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, refs.Tabs)
	refs.ShopList = scroller(body, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50) })
end

local function refreshBlacksmith()
	if not state or not refs.ShopList then
		return
	end
	clear(refs.Tabs)
	local activeTab = Config.ShopTabs[1]
	for _, tab in ipairs(Config.ShopTabs) do
		if tab.Id == shopTab then
			activeTab = tab
		end
		button(refs.Tabs, tab.Name, tab.Id == shopTab and rgb(230, 110, 60) or THEME.Gray, function()
			shopTab = tab.Id
			UI.Refresh()
		end, { Size = UDim2.fromOffset(150, 36) })
	end
	clear(refs.ShopList)
	local order = 0
	for _, itemId in ipairs(Config.ShopOrder) do
		local def = Config.Items[itemId]
		if def and tabMatches(activeTab, def) then
			order = order + 1
			local c = card(refs.ShopList, 72, order)
			local color, rarityName = itemColor(itemId)
			label(c, def.Name, 17, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 22), TextColor3 = color })
			label(c, rarityName .. "  •  " .. Rules.BonusText(itemId), 13, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -170, 0, 18), TextColor3 = THEME.Green })
			label(c, def.Description or "", 12, { Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -170, 0, 20), TextColor3 = THEME.Muted, Font = Enum.Font.GothamMedium, TextTruncate = Enum.TextTruncate.AtEnd })
			local affordable = state.Coins >= (def.Price or 0)
			local owned = count(itemId)
			button(c, Rules.FormatNumber(def.Price or 0) .. " 🪙", affordable and THEME.Green or THEME.Gray, function()
				request("Buy", itemId)
			end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(140, 36) })
			label(c, owned > 0 and ("есть: " .. owned) or "", 12, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -4), Size = UDim2.fromOffset(140, 18), TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Center })
		end
	end
end

-- HUD --------------------------------------------------------------------------------------------
-- Бегущий блик поверх полоски: белая полоса с прозрачными краями, Offset двигает animateHud.
local function shine(parent)
	local overlay = new("Frame", { Name = "Shine", BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, parent)
	corner(overlay, 9)
	return new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
	}, overlay)
end

-- «Пружинка»: резко увеличить UIScale и вернуть с отскоком.
local function pop(scale, amount)
	if not scale then
		return
	end
	scale.Scale = amount or 1.18
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Всплывающая «+N» рядом с элементом HUD.
local function floatText(parent, text, color)
	local l = label(parent, text, 18, { Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 8, 0.5, 0), Size = UDim2.fromOffset(120, 24), TextColor3 = color, TextStrokeTransparency = 0.3, TextWrapped = false })
	tween(l, 0.9, { Position = UDim2.new(1, 8, 0.5, -26), TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.95, function()
		l:Destroy()
	end)
end

-- Постоянные анимации HUD (один Heartbeat): блики полосок, пульс низкого ХП, мигание истекающих баффов.
local function animateHud()
	local t = os.clock()
	local sweep = (t * 0.45) % 2.2 - 1.1
	if refs.XPShine then
		refs.XPShine.Offset = Vector2.new(sweep, 0)
	end
	if refs.HPShine then
		refs.HPShine.Offset = Vector2.new(((t * 0.45 + 1.1) % 2.2) - 1.1, 0)
	end
	if refs.Vignette then
		local danger = hpRatio < 0.3 and hpRatio > 0
		local pulse = 0.5 + 0.5 * math.sin(t * (danger and 6 or 2))
		refs.Vignette.Transparency = danger and (0.25 + pulse * 0.45) or 1
	end
	if refs.Buffs then
		for _, chip in ipairs(refs.Buffs:GetChildren()) do
			local ends = buffEnds[chip.Name]
			local s = chip:FindFirstChildOfClass("UIStroke")
			if s and ends then
				s.Transparency = (ends - t < 10) and (0.5 + 0.5 * math.sin(t * 10)) or 0.1
			end
		end
	end
	if refs.LevelRing then
		refs.LevelRing.Rotation = (t * 60) % 360
	end
end

local function buildHud()
	-- Монеты и очки навыков (слева сверху, ниже кнопок Roblox).
	local coins = new("Frame", { BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(210, 46) }, gui)
	corner(coins, 12)
	stroke(coins, THEME.Gold, 2, 0.2)
	gradient(coins, rgb(255, 255, 255), rgb(170, 170, 190), 90)
	label(coins, "🪙", 26, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(34, 46) })
	refs.Coins = label(coins, "0", 24, { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -56, 1, 0), TextColor3 = THEME.Gold })
	refs.CoinFrame = coins
	refs.CoinScale = new("UIScale", { Scale = 1 }, coins)
	refs.CoinValue = new("NumberValue", { Value = 0 }, coins)
	refs.CoinValue.Changed:Connect(function(value)
		refs.Coins.Text = Rules.FormatNumber(math.floor(value + 0.5))
	end)
	local points = new("Frame", { BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(16, 116), Size = UDim2.fromOffset(210, 32) }, gui)
	corner(points, 10)
	stroke(points, rgb(140, 130, 255), 1.5, 0.3)
	refs.Points = label(points, "", 14, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -20, 1, 0), TextColor3 = rgb(190, 180, 255) })

	-- Кнопки меню (слева по центру).
	local menu = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(174, 222) }, gui)
 refs.Menu = menu
 refs.MenuScale = new("UIScale",{Scale=1},menu)
 new("UIListLayout", { Padding = UDim.new(0, 10) }, menu)
 for _, data in ipairs({
  {"Inventory","Инвентарь [B]","Inventory",rgb(70,170,130)},
  {"Stats","Прокачка [C]","Stats",rgb(120,110,220)},
  {"Shop","Магазин","Shop",rgb(188,133,55)},
  {"Teleport","Телепорты","Teleports",rgb(68,143,185)},
 }) do
  local target = data[3]
  local b = button(menu,"",data[4],function() UI.Toggle(target) end,{Size=UDim2.fromOffset(174,44)})
  Icons.Draw(b,data[1],data[4],UDim2.fromOffset(5,5),UDim2.fromOffset(34,34))
  label(b,data[2],14,{Position=UDim2.fromOffset(48,0),Size=UDim2.new(1,-54,1,0)})
 end

	-- ХП и опыт (снизу по центру).
	local bars = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(420, 64) }, gui)
	local level = new("Frame", { BackgroundColor3 = THEME.Panel, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(56, 56) }, bars)
	corner(level, 28)
	local ring = stroke(level, rgb(255, 255, 255), 3, 0)
	refs.LevelRing = new("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(130, 200, 255)),
		ColorSequenceKeypoint.new(0.5, rgb(190, 140, 255)),
		ColorSequenceKeypoint.new(1, rgb(130, 200, 255)),
	}) }, ring)
	refs.LevelScale = new("UIScale", { Scale = 1 }, level)
	refs.Level = label(level, "1", 22, { Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local xp = new("Frame", { BackgroundColor3 = THEME.Panel, Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -64, 0, 14) }, bars)
	corner(xp, 7)
	stroke(xp, THEME.Stroke, 1, 0.4)
	refs.XPFill = new("Frame", { BackgroundColor3 = rgb(110, 190, 255), Size = UDim2.fromScale(0, 1) }, xp)
	corner(refs.XPFill, 7)
	gradient(refs.XPFill, rgb(160, 220, 255), rgb(80, 140, 255), 0)
	refs.XPShine = shine(refs.XPFill)
	refs.XPText = label(xp, "", 11, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, ZIndex = 3 })
	local hp = new("Frame", { BackgroundColor3 = THEME.Panel, Position = UDim2.fromOffset(64, 28), Size = UDim2.new(1, -64, 0, 30) }, bars)
	corner(hp, 9)
	stroke(hp, rgb(255, 255, 255), 1.5, 0.6)
	refs.HPLag = new("Frame", { BackgroundColor3 = rgb(255, 240, 200), Size = UDim2.fromScale(1, 1) }, hp)
	corner(refs.HPLag, 9)
	refs.HPFill = new("Frame", { BackgroundColor3 = rgb(255, 255, 255), Size = UDim2.fromScale(1, 1) }, hp)
	corner(refs.HPFill, 9)
	refs.HPGradient = gradient(refs.HPFill, rgb(110, 230, 110), rgb(40, 160, 70), 90)
	refs.HPShine = shine(refs.HPFill)
	refs.HPFrame = hp
	refs.Bars = bars
	-- Красная пульсирующая рамка экрана при низком ХП.
	-- UIStroke рисуется снаружи рамки, поэтому рамка уменьшена на толщину обводки.
	local vignette = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 26), Size = UDim2.new(1, -52, 1, -52), ZIndex = 0 }, gui)
	refs.Vignette = new("UIStroke", { Color = rgb(220, 30, 40), Thickness = 26, Transparency = 1 }, vignette)
	refs.HPText = label(hp, "", 15, { Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 3 })

	-- Баффы (справа сверху).
	refs.Buffs = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 64), Size = UDim2.fromOffset(220, 200) }, gui)
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }, refs.Buffs)

	-- Тосты (сверху по центру).
	refs.Toasts = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(460, 220) }, gui)
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, refs.Toasts)

	-- Кнопка атаки для сенсорных экранов.
	if UserInputService.TouchEnabled then
		local attack = button(gui, "⚔", THEME.Red, function()
			if onAttack then
				onAttack()
			end
		end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -30, 1, -150), Size = UDim2.fromOffset(84, 84), TextSize = 40 })
		corner(attack, 42)
	end
end

local function buffChip(buffId)
	local def = Config.Buffs[buffId]
	local chip = new("Frame", { Name = buffId, BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(210, 34) }, refs.Buffs)
	corner(chip, 10)
	stroke(chip, def.Color, 2, 0.1)
	label(chip, def.Icon .. " " .. def.Short, 14, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -80, 1, 0), TextColor3 = def.Color })
	local timer = label(chip, "", 14, { Name = "Timer", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(64, 34), TextXAlignment = Enum.TextXAlignment.Right })
	chip.Size = UDim2.fromOffset(0, 34)
	tween(chip, 0.25, { Size = UDim2.fromOffset(210, 34) }, Enum.EasingStyle.Back)
	return chip, timer
end

local function updateBuffs()
	if not refs.Buffs then
		return
	end
	local now = os.clock()
	for _, buffId in ipairs(Config.BuffOrder) do
		local ends = buffEnds[buffId]
		local chip = refs.Buffs:FindFirstChild(buffId)
		if ends and ends > now then
			local timer
			if chip then
				timer = chip:FindFirstChild("Timer")
			else
				chip, timer = buffChip(buffId)
			end
			if timer then
				timer.Text = Rules.FormatTime(ends - now)
			end
		elseif chip then
			chip:Destroy()
			buffEnds[buffId] = nil
		end
	end
end

local function refreshHud()
	if not state then
		return
	end
	tween(refs.CoinValue, 0.45, { Value = state.Coins })
	if lastCoins and state.Coins ~= lastCoins then
		local delta = state.Coins - lastCoins
		pop(refs.CoinScale, delta > 0 and 1.15 or 0.92)
		floatText(refs.CoinFrame, (delta > 0 and "+" or "") .. Rules.FormatNumber(delta), delta > 0 and THEME.Gold or THEME.Red)
	end
	lastCoins = state.Coins
	if lastLevel and state.Level > lastLevel then
		pop(refs.LevelScale, 1.45)
	end
	lastLevel = state.Level
	refs.Points.Text = "✦ Очки навыков: " .. state.SkillPoints .. "   ☠ " .. Rules.FormatNumber(state.Kills or 0)
	refs.Level.Text = tostring(state.Level)
	local need = math.max(1, state.XPRequired or 1)
	tween(refs.XPFill, 0.35, { Size = UDim2.fromScale(math.clamp(state.XP / need, 0, 1), 1) })
	refs.XPText.Text = "XP " .. Rules.FormatNumber(state.XP) .. " / " .. Rules.FormatNumber(need)
	local now = os.clock()
	for _, buffId in ipairs(Config.BuffOrder) do
		local remaining = state.Buffs[buffId]
		if remaining and remaining > 0 then
			buffEnds[buffId] = now + remaining
		else
			buffEnds[buffId] = nil
		end
	end
	updateBuffs()
end

local function buildExpansionPanels()
 local body = makePanel("Teleports","Телепорты",UDim2.fromOffset(570,440),THEME.Accent)
 refs.TravelList = scroller(body,{Size=UDim2.fromScale(1,1)})
 body = makePanel("Shop","Магазин и поддержка",UDim2.fromOffset(570,440),THEME.Gold)
 label(body,"КУЗНИЦА НА ПОЛЯНЕ",18,{Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-16,0,28),TextColor3=THEME.Gold})
 label(body,"Оружие, броня и зелья покупаются за игровые монеты. Покупки проверяются сервером рядом с торговцем.",15,{Position=UDim2.fromOffset(8,38),Size=UDim2.new(1,-16,0,70)})
 button(body,"Открыть кузницу",THEME.Green,function()
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and (root.Position-Config.NPC.Blacksmith.Position).Magnitude<=Config.ShopDistance then UI.OpenShop("Blacksmith")
  else UI.Toast("Кузнец находится на рынке стартового острова. Используй телепорт на Поляну.","info") end
 end,{Position=UDim2.fromOffset(8,116),Size=UDim2.new(1,-16,0,44)})
 local passes = scroller(body,{Position=UDim2.fromOffset(0,178),Size=UDim2.new(1,0,1,-178)})
 local countPasses=0
 for _, pass in ipairs(Config.GamePasses) do
  if type(pass.Id)=="number" and pass.Id>0 then
   countPasses=countPasses+1
   local id=pass.Id
   button(passes,pass.Name or "Поддержать игру",THEME.Gold,function()
    game:GetService("MarketplaceService"):PromptGamePassPurchase(player,id)
   end,{Size=UDim2.new(1,-16,0,44)})
  end
 end
 if countPasses==0 then
  label(passes,"Покупки за Robux не подключены. Все игровые возможности доступны без доната.",15,{Size=UDim2.new(1,-16,0,72),TextColor3=THEME.Muted})
 end
 refs.Boss = new("Frame",{Name="BossBar",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,55),Size=UDim2.fromOffset(470,70),BackgroundColor3=THEME.Panel,Visible=false},gui)
 corner(refs.Boss,12)
 stroke(refs.Boss,THEME.Gold,2,0.1)
 refs.BossTitle=label(refs.Boss,"",16,{Position=UDim2.fromOffset(12,4),Size=UDim2.new(1,-24,0,24),TextXAlignment=Enum.TextXAlignment.Center})
 local back=new("Frame",{Position=UDim2.fromOffset(12,34),Size=UDim2.new(1,-24,0,15),BackgroundColor3=rgb(65,35,43),BorderSizePixel=0},refs.Boss)
 corner(back,6)
 refs.BossFill=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=rgb(245,99,64),BorderSizePixel=0},back)
 corner(refs.BossFill,6)
 gradient(refs.BossFill,rgb(255,198,90),rgb(220,60,65),0)
 refs.BossHealth=label(refs.Boss,"",12,{Position=UDim2.fromOffset(12,51),Size=UDim2.new(1,-24,0,16),TextXAlignment=Enum.TextXAlignment.Center})
end
local function refreshTravel()
 if not state or not refs.TravelList then return end
 clear(refs.TravelList)
 for i,id in ipairs(Config.IslandOrder) do
  local def=Config.Islands[id]
  local c=card(refs.TravelList,94,i)
  Icons.Draw(c,"Teleport",def.Color,UDim2.fromOffset(12,18),UDim2.fromOffset(50,50))
  label(c,def.Name,17,{Position=UDim2.fromOffset(74,10),Size=UDim2.new(1,-235,0,26),TextColor3=def.Color})
  label(c,"Уровень "..def.Level.."+ • Бесплатно",13,{Position=UDim2.fromOffset(74,42),Size=UDim2.new(1,-235,0,30),TextColor3=THEME.Muted})
  local allowed=state.Level>=def.Level
  local target=id
  button(c,allowed and "Перейти" or "Закрыто",allowed and THEME.Green or THEME.Gray,function()
   request("Teleport",target)
  end,{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(128,40)})
 end
end
local function updateBoss(dt)
 if not refs.Boss then return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local mobs=workspace:FindFirstChild("GladeSlayerMobs")
 local best, humanoid, distance
 if root and mobs then
  distance=120
  for _, model in ipairs(mobs:GetChildren()) do
   local h=model:FindFirstChildOfClass("Humanoid")
   if model:GetAttribute("Boss") and model.PrimaryPart and h and h.Health>0 and not model:GetAttribute("MobDead") then
    local d=(model.PrimaryPart.Position-root.Position).Magnitude
    if d<distance then best,humanoid,distance=model,h,d end
   end
  end
 end
 refs.Boss.Visible=best~=nil
 if best then
  local ratio=humanoid.Health/humanoid.MaxHealth
  bossSmoothRatio=bossSmoothRatio+(ratio-bossSmoothRatio)*math.min(1,dt*9)
  refs.BossFill.Size=UDim2.fromScale(math.clamp(bossSmoothRatio,0,1),1)
  local def=Config.Mobs[best:GetAttribute("MobId")]
  refs.BossTitle.Text=(def and def.Name or best.Name).." • Фаза "..tostring(best:GetAttribute("Phase") or 1)
  refs.BossHealth.Text=math.ceil(humanoid.Health).." / "..math.floor(humanoid.MaxHealth)
 else bossSmoothRatio=1 end
 local camera=workspace.CurrentCamera
 if camera then
  local viewport=camera.ViewportSize
  refs.Bars.Size=UDim2.fromOffset(math.min(420,viewport.X-32),64)
  refs.Toasts.Size=UDim2.fromOffset(math.min(460,viewport.X-24),220)
  local compact=viewport.X<700 or viewport.Y<500
  refs.Menu.Size=UDim2.fromOffset(compact and 54 or 174,222)
  refs.MenuScale.Scale=viewport.Y<480 and 0.75 or 1
  refs.Menu.AnchorPoint=Vector2.new(0,viewport.Y<480 and 0 or 0.5)
  refs.Menu.Position=viewport.Y<480 and UDim2.fromOffset(16,154) or UDim2.new(0,16,0.5,0)
  for _,b in ipairs(refs.Menu:GetChildren()) do
   if b:IsA("TextButton") then
    b.Size=UDim2.fromOffset(compact and 54 or 174,44)
    for _,child in ipairs(b:GetChildren()) do if child:IsA("TextLabel") then child.Visible=not compact end end
   end
  end
  if compact then refs.Buffs.Position=UDim2.new(1,-16,0,viewport.Y<480 and 64 or 270) else refs.Buffs.Position=UDim2.new(1,-16,0,64) end
  refs.Boss.Size=UDim2.fromOffset(math.min(470,viewport.X-32),70)
  refs.Boss.Position=UDim2.new(0.5,0,0,viewport.X<850 and 158 or 55)
  for _,panel in pairs(panels) do
   local base=panel.Root.Size
   panel.TargetScale=math.min(1,(viewport.X-24)/base.X.Offset,(viewport.Y-80)/base.Y.Offset)
   if panel.Root.Visible and panel.Scale.Scale>panel.TargetScale+0.01 then panel.Scale.Scale=panel.TargetScale end
  end
 end
end

-- Публичный API -----------------------------------------------------------------------------------
function UI.Init(remoteFolder, attackCallback)
	remotes = remoteFolder
	onAttack = attackCallback
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("GladeSlayerUI")
	if old then
		old:Destroy()
	end
	gui = new("ScreenGui", { Name = "GladeSlayerUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
	buildHud()
	buildStats()
	buildInventory()
	buildMerchant()
 buildBlacksmith()
 buildExpansionPanels()
 refs.ClickSound = new("Sound",{Name="UIClick",SoundId="rbxasset://sounds/electronicpingshort.wav",Volume=0.25},gui)
 -- Выезд HUD при входе.
	refs.Bars.Position = UDim2.new(0.5, 0, 1, 120)
	tween(refs.Bars, 0.7, { Position = UDim2.new(0.5, 0, 1, -18) }, Enum.EasingStyle.Back)
	refs.CoinFrame.Position = UDim2.fromOffset(-240, 64)
	tween(refs.CoinFrame, 0.6, { Position = UDim2.fromOffset(16, 64) }, Enum.EasingStyle.Back)
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not gui.Parent then
			connection:Disconnect()
			return
		end
		animateHud()
  updateBoss(dt)
	end)
	task.spawn(function()
		while gui.Parent do
			updateBuffs()
			task.wait(0.25)
		end
	end)
end

function UI.Refresh()
	refreshHud()
	if currentPanel == "Stats" then
		refreshStats()
	elseif currentPanel == "Inventory" then
		refreshInventory()
	elseif currentPanel == "Teleports" then
  refreshTravel()
	elseif currentPanel == "Merchant" then
		refreshMerchant()
	elseif currentPanel == "Blacksmith" then
		refreshBlacksmith()
	end
end

function UI.SetState(newState)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	UI.Refresh()
end

function UI.SetHealth(health, maxHealth)
	if not refs.HPFill then
		return
	end
	local ratio = maxHealth > 0 and math.clamp(health / maxHealth, 0, 1) or 0
	hpRatio = ratio
	tween(refs.HPFill, 0.15, { Size = UDim2.fromScale(ratio, 1) })
	-- Получили урон: короткая тряска полоски ХП.
	if lastHealth and health < lastHealth - 0.5 and refs.HPFrame then
		local home = UDim2.fromOffset(64, 28)
		task.spawn(function()
			for i = 1, 5 do
				refs.HPFrame.Position = home + UDim2.fromOffset((i % 2 == 0 and 1 or -1) * (6 - i), 0)
				task.wait(0.03)
			end
			refs.HPFrame.Position = home
		end)
	end
	lastHealth = health
	-- «След» урона догоняет полоску с задержкой.
	task.delay(0.35, function()
		tween(refs.HPLag, 0.5, { Size = UDim2.fromScale(ratio, 1) })
	end)
	if ratio < 0.3 then
		refs.HPGradient.Color = ColorSequence.new(rgb(255, 110, 100), rgb(190, 40, 40))
	elseif ratio < 0.6 then
		refs.HPGradient.Color = ColorSequence.new(rgb(255, 220, 90), rgb(220, 150, 40))
	else
		refs.HPGradient.Color = ColorSequence.new(rgb(110, 230, 110), rgb(40, 160, 70))
	end
	refs.HPText.Text = "❤ " .. math.floor(health + 0.5) .. " / " .. math.floor(maxHealth + 0.5)
end

function UI.Open(name)
	local panel = panels[name]
	if not panel then
		return
	end
	if currentPanel and currentPanel ~= name then
		local old = panels[currentPanel]
		old.Root.Visible = false
		old.Root.GroupTransparency = 1
	end
	currentPanel = name
	if name == "Merchant" or name == "Blacksmith" then
		currentShop = name
	else
		currentShop = nil
	end
	UI.Refresh()
	panel.Root.Visible = true
	panel.Scale.Scale = (panel.TargetScale or 1)*0.85
	tween(panel.Scale, 0.28, { Scale = panel.TargetScale or 1 }, Enum.EasingStyle.Back)
	tween(panel.Root, 0.2, { GroupTransparency = 0 })
end

function UI.Close()
	if not currentPanel then
		return
	end
	local panel = panels[currentPanel]
	currentPanel = nil
	currentShop = nil
	tween(panel.Scale, 0.15, { Scale = (panel.TargetScale or 1)*0.9 })
	tween(panel.Root, 0.15, { GroupTransparency = 1 }).Completed:Connect(function()
		if panel.Root.GroupTransparency >= 0.99 then
			panel.Root.Visible = false
		end
	end)
end

function UI.Toggle(name)
	if currentPanel == name then
		UI.Close()
	else
		UI.Open(name)
	end
end

function UI.OpenShop(kind)
	if kind == "Merchant" or kind == "Blacksmith" then
		UI.Open(kind)
	end
end

function UI.CurrentShop()
	return currentShop
end

function UI.Toast(text, kind)
	if not refs.Toasts or type(text) ~= "string" or text == "" then
		return
	end
	local color = TOAST_COLORS[kind] or THEME.Accent
	local toasts = {}
	for _, child in ipairs(refs.Toasts:GetChildren()) do
		if child:IsA("CanvasGroup") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= 4 then
		toasts[1]:Destroy()
	end
	local toast = new("CanvasGroup", { BackgroundColor3 = THEME.Panel, Size = UDim2.new(1,-20,0,58), GroupTransparency = 1, LayoutOrder = math.floor(os.clock() * 100) }, refs.Toasts)
	corner(toast, 10)
	local bar = new("Frame", { BackgroundColor3 = color, Size = UDim2.new(0, 6, 1, 0) }, toast)
	corner(bar, 3)
	label(toast, text, 15, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -24, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
	local outline = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, toast)
	corner(outline, 10)
	stroke(outline, color, 1.5, 0.2)
	local toastScale = new("UIScale", { Scale = 0.7 }, toast)
	tween(toastScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(toast, 0.2, { GroupTransparency = 0 })
	task.delay(3.2, function()
		if toast.Parent then
			tween(toast, 0.35, { GroupTransparency = 1 }).Completed:Connect(function()
				toast:Destroy()
			end)
		end
	end)
end

return UI
