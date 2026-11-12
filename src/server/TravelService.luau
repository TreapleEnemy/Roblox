-- Server-authoritative travel. No client-supplied coordinates, prices, or levels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GladeSlayer")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local DungeonService = require(script.Parent:WaitForChild("DungeonService"))
local TravelService = {}
local cooldowns = {}
local DataService
function TravelService.Teleport(player, profile, islandId)
 local ok, message = Rules.CanTeleport(profile, islandId)
 if not ok then return false, message end
 if DungeonService.InDungeon(player) then
  return false, "Сначала покинь подземелье."
 end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or not humanoid or humanoid.Health <= 0 or humanoid.Sit then
  return false, "Телепорт сейчас недоступен."
 end
 local now = os.clock()
 if now < (cooldowns[player] or 0) then return false, "Телепорт перезаряжается." end
 local combatAt = player:GetAttribute("GladeCombatAt")
 if combatAt and now - combatAt < Config.TeleportCombatSeconds then
  return false, "Нельзя телепортироваться в бою. Подожди 8 секунд."
 end
 cooldowns[player] = now + Config.TeleportCooldown
 character:PivotTo(CFrame.new(Config.Islands[islandId].Arrival))
 root.AssemblyLinearVelocity = Vector3.zero
 root.AssemblyAngularVelocity = Vector3.zero
 return true, "Локация: " .. message
end
function TravelService.Init(dataService, remotes)
 DataService = dataService
 local world = workspace:FindFirstChild("GladeSlayerWorld")
 if world then
  for _, prompt in ipairs(world:GetDescendants()) do
   if prompt:IsA("ProximityPrompt") and prompt.Name == "IslandTravel" then
    local core = prompt.Parent
    prompt.Triggered:Connect(function(player)
     local profile = DataService.Get(player)
     local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
     -- Prompt events can be forged by exploiters; re-check range on the server.
     if not profile or not root or (root.Position-core.Position).Magnitude > 15 then return end
     local ok, message = TravelService.Teleport(player,profile,core:GetAttribute("DestinationIsland"))
     remotes.Toast:FireClient(player,message,ok and "success" or "error")
    end)
   end
  end
 end
 Players.PlayerRemoving:Connect(function(player) cooldowns[player] = nil end)
end
return TravelService
