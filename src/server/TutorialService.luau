-- GladeSlayer: гайд новичка на сервере. Прогресс хранится в профиле (Rules.TutorialEvent),
-- события приходят из убийств мобов и успешных действий игрока (Equip, Upgrade, Sell).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local TutorialService = {}
local DataService, Remotes

local ACTION_EVENTS = { Upgrade = "Upgrade", Equip = "Equip", Sell = "Sell", SellAll = "Sell" }

local function toast(player, text, kind)
	if player.Parent then
		Remotes.Toast:FireClient(player, text, kind)
	end
end

function TutorialService.Event(player, profile, event, data)
	local result = Rules.TutorialEvent(profile, event, data)
	if not result then
		return
	end
	if table.find(result.Granted, "OldSword") then
		toast(player, "Слизень выронил Старый меч! Открой Инвентарь [I] и надень его.", "loot")
	end
	if result.Finished then
		local itemDef = result.Item and Config.Items[result.Item]
		toast(player, "Гайд пройден! Награда: +" .. Rules.FormatNumber(result.Coins or 0) .. " монет" .. (itemDef and (" и " .. itemDef.Name) or "") .. ".", "success")
		if player.Character then
			Remotes.FX:FireAllClients("LevelUp", player.Character, profile.Level)
		end
	elseif result.Advanced then
		local step, index = Rules.TutorialStep(profile)
		if step then
			toast(player, "Цель " .. index .. "/" .. #Config.Tutorial.Steps .. ": " .. step.Text, "info")
		end
	end
	DataService.Changed(player)
end

function TutorialService.OnAction(player, profile, action, a)
	local event = ACTION_EVENTS[action]
	if event then
		TutorialService.Event(player, profile, event, a)
	end
end

function TutorialService.Init(dataService, remotes, mobService, economyService)
	DataService = dataService
	Remotes = remotes
	mobService.OnKill = function(player, profile, mobId)
		TutorialService.Event(player, profile, "Kill", mobId)
	end
	economyService.OnAction = TutorialService.OnAction
end

return TutorialService
