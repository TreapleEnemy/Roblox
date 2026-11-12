-- GladeSlayer: профили игроков в DataStore с «арендой» сессии (защита от дюпа при перескоке между серверами)
-- и безопасным фоллбэком в память, если плейс не опубликован или API DataStore выключен в Studio.
-- Запись в хранилище: { Data = Rules.Snapshot(...), Lease = { Job = JobId, Expires = os.time() + LeaseSeconds } }.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local DataService = {}

local hooks = {}
local profiles = {}
local listeners = {}
local saving = {}
local memoryStore = {}
local store = nil
local useMemory = false
local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(math.random(1, 1000000000)))

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function openStore()
	local studio = RunService:IsStudio()
	if studio and (Config.StudioForceMemory or game.PlaceId == 0) then
		useMemory = true
		warn("[GladeSlayer] DataStore: Studio без опубликованного плейса — прогресс хранится только в памяти.")
		return
	end
	local name = Config.DataStoreName .. (studio and Config.StudioStoreSuffix or "")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok and result then
		store = result
	else
		useMemory = true
		warn("[GladeSlayer] DataStore недоступен (" .. tostring(result) .. ") — прогресс только в памяти.")
	end
end

-- UpdateAsync с повторами. transform(old) -> new | nil (nil = отмена записи).
local function update(key, transform)
	if useMemory then
		local old = memoryStore[key] and Rules.CopyRecord(memoryStore[key]) or nil
		local new = transform(old)
		if new ~= nil then
			memoryStore[key] = Rules.CopyRecord(new)
		end
		return true, new
	end
	local lastError = nil
	for attempt = 1, Config.SaveAttempts do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(attempt * 1.5)
	end
	-- Ошибка API в Studio (например, «API Services» выключены): переходим в память, чтобы игра продолжалась.
	if RunService:IsStudio() and tostring(lastError):find("403") then
		useMemory = true
		warn("[GladeSlayer] DataStore запрещён в Studio — переключаюсь на память.")
		return update(key, transform)
	end
	return false, lastError
end

local function leaseFree(record)
	local lease = type(record) == "table" and record.Lease or nil
	return type(lease) ~= "table" or lease.Job == jobId or (tonumber(lease.Expires) or 0) <= os.time()
end

function DataService.Init(hookTable)
	hooks = hookTable or {}
	openStore()
end

function DataService.Toast(player, text, kind)
	if hooks.Toast then
		hooks.Toast(player, text, kind)
	end
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.OnChanged(callback)
	table.insert(listeners, callback)
end

function DataService.Changed(player)
	if not profiles[player] then
		return
	end
	for _, callback in ipairs(listeners) do
		task.spawn(callback, player)
	end
end

function DataService.IsMemory()
	return useMemory
end

-- Загружает профиль, захватывая аренду. Возвращает true, если игрок может играть.
function DataService.Load(player)
	local key = keyFor(player)
	local deadline = os.clock() + Config.LeaseSeconds + Config.LeaseSafetySeconds
	local profile, problem = nil, nil
	while player.Parent and os.clock() < deadline do
		local busy = false
		problem = nil
		local ok, result = update(key, function(old)
			busy = false
			problem = nil
			if old ~= nil and not leaseFree(old) then
				busy = true
				return nil
			end
			local record = type(old) == "table" and old or {}
			if record.Data ~= nil then
				local decoded, reason = Rules.Decode(record.Data, os.clock())
				if not decoded then
					problem = reason
					return nil
				end
			end
			record.Lease = { Job = jobId, Expires = os.time() + Config.LeaseSeconds }
			return record
		end)
		if not ok then
			problem = "DataStore не отвечает: " .. tostring(result)
			break
		end
		if problem then
			break
		end
		if not busy then
			if type(result) == "table" and result.Data ~= nil then
				profile = Rules.Decode(result.Data, os.clock())
			else
				profile = Rules.NewProfile()
			end
			break
		end
		DataService.Toast(player, "Прошлая сессия ещё сохраняется, ждём…", "info")
		task.wait(5)
	end
	if not player.Parent then
		return false
	end
	if not profile then
		-- Не выдаём пустой профиль поверх существующего: лучше переподключение, чем потерянный прогресс.
		player:Kick("Не удалось загрузить прогресс. " .. tostring(problem or "Сессия занята.") .. " Зайди ещё раз через минуту.")
		return false
	end
	profiles[player] = profile
	if useMemory then
		DataService.Toast(player, "Studio: сохранение в памяти — прогресс сбросится после остановки.", "info")
	end
	return true
end

-- Сохраняет профиль. release = true снимает аренду (выход игрока / закрытие сервера).
function DataService.Save(player, release)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if saving[player] then
		return false
	end
	saving[player] = true
	local snapshot = Rules.Snapshot(profile, os.clock())
	local lost = false
	local ok, err = update(keyFor(player), function(old)
		if old ~= nil and not leaseFree(old) then
			lost = true
			return nil
		end
		local record = type(old) == "table" and old or {}
		record.Data = snapshot
		if release then
			record.Lease = nil
		else
			record.Lease = { Job = jobId, Expires = os.time() + Config.LeaseSeconds }
		end
		return record
	end)
	saving[player] = nil
	if not ok then
		warn("[GladeSlayer] Сохранение " .. player.Name .. ": " .. tostring(err))
		return false
	end
	if lost then
		warn("[GladeSlayer] Аренда профиля " .. player.Name .. " перехвачена другим сервером — запись пропущена.")
		return false
	end
	return true
end

function DataService.Unload(player)
	if not profiles[player] then
		return
	end
	local deadline = os.clock() + 10
	while saving[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	DataService.Save(player, true)
	profiles[player] = nil
end

function DataService.Shutdown()
	local pending = 0
	for player in pairs(profiles) do
		pending = pending + 1
		task.spawn(function()
			pcall(DataService.Save, player, true)
			pending = pending - 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function DataService.Start()
	-- Автосохранение (продлевает аренду).
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in pairs(profiles) do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)
	-- Истечение баффов зелий.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, profile in pairs(profiles) do
				if Rules.PruneBuffs(profile, now) then
					DataService.Changed(player)
					DataService.Toast(player, "Действие зелья закончилось.", "info")
				end
			end
		end
	end)
	-- Страховка: если игрок ушёл, а Unload не вызван (ошибка в обработчике), всё равно сохраняем.
	Players.PlayerRemoving:Connect(function(player)
		task.delay(15, function()
			if profiles[player] and not player.Parent then
				DataService.Unload(player)
			end
		end)
	end)
end

return DataService
