-- Additive deterministic world decoration; legacy world/NPC coordinates are preserved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GladeSlayer"):WaitForChild("Config"))
local ExpansionWorld = {}
local V = Vector3.new
local C = CFrame.new
local rgb = Color3.fromRGB
local M = Enum.Material
local rng = Random.new(71023)
local function part(parent, name, size, cf, color, material, solid)
 local p = Instance.new("Part")
 p.Name, p.Size, p.CFrame = name, size, cf
 p.Color, p.Material, p.Anchored = color, material or M.Slate, true
 p.CanCollide = solid == true
 p.CanTouch = false
 p.CanQuery = solid == true
 p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 p.Parent = parent
 return p
end
local function group(parent, name)
 local f = Instance.new("Folder")
 f.Name, f.Parent = name, parent
 return f
end
local function light(p, color, range)
 local l = Instance.new("PointLight")
 l.Color, l.Range, l.Brightness = color, range or 12, 1.5
 l.Parent = p
end
local function text(p, title)
 local ui = Instance.new("BillboardGui")
 ui.Size = UDim2.fromOffset(260, 62)
 ui.StudsOffsetWorldSpace = V(0, 5, 0)
 ui.MaxDistance, ui.AlwaysOnTop = 75, true
 local label = Instance.new("TextLabel")
 label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
 label.Font, label.TextSize = Enum.Font.GothamBold, 18
 label.TextColor3, label.TextStrokeTransparency = Color3.new(1,1,1), 0.25
 label.TextWrapped, label.Text = true, title
 label.Parent, ui.Parent = ui, p
end
local function crystal(parent, pos, color, scale)
 local base = part(parent,"CrystalRock",V(3,1.5,3)*scale,C(pos+V(0,0.5*scale,0)),rgb(65,68,83),M.Rock)
 for i=1,3 do
  local h = (2+i*0.8)*scale
  local p = part(parent,"Crystal",V(0.6*scale,h,0.6*scale),C(pos+V((i-2)*0.7*scale,h/2,0))*CFrame.Angles(0,0,(i-2)*0.2),color,M.Neon)
  if i==2 then light(p,color,10) end
 end
 return base
end
local function lantern(parent, pos, color)
 part(parent,"LanternFoot",V(1.6,0.4,1.6),C(pos+V(0,0.2,0)),rgb(58,50,48),M.Cobblestone)
 part(parent,"LanternPost",V(0.4,6,0.4),C(pos+V(0,3,0)),rgb(65,49,38),M.Wood)
 local lamp = part(parent,"LanternGlow",V(0.8,1.1,0.8),C(pos+V(0,6,0)),color,M.Neon)
 light(lamp,color,17)
 for _, y in ipairs({5.35,6.65}) do part(parent,"LanternCap",V(1.3,0.2,1.3),C(pos+V(0,y,0)),rgb(53,49,51),M.Metal) end
end
local function portal(parent, pos, destination, facing)
 local def = Config.Islands[destination]
 local f = group(parent,"Portal_"..destination)
 -- Local -Z of base points at `facing`, so the core plane faces the approaching player.
 local base = CFrame.lookAt(pos, V(facing.X, pos.Y, facing.Z))
 part(f,"PortalPlinth",V(12,0.5,10),base,rgb(65,66,86),M.Marble,true)
 for _, side in ipairs({-1,1}) do
  part(f,"PortalPillar",V(1.2,9,1.4),base*C(side*4.5,4.5,0),rgb(86,85,103),M.Slate,true)
  crystal(f,(base*C(side*4.5,9,0)).Position,def.Color,0.6)
 end
 part(f,"PortalLintel",V(10,0.9,1.6),base*C(0,9,0),rgb(93,88,113),M.Marble,true)
 local core = part(f,"PortalCore",V(7.5,7.8,0.25),base*C(0,4.5,0),def.Color,M.Neon)
 core.Transparency = 0.65
 light(core,def.Color,20)
 text(core,def.Name.."\nУровень "..def.Level.." • E — перейти")
 local prompt = Instance.new("ProximityPrompt")
 prompt.Name = "IslandTravel"
 prompt.ActionText, prompt.ObjectText = "Перейти", def.Name
 prompt.KeyboardKeyCode, prompt.HoldDuration = Enum.KeyCode.E, 0.4
 prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 11, false
 prompt.Parent = core
 core:SetAttribute("DestinationIsland",destination)
end
local function clearSpawn(x,z)
 local p = V(x,2,z)
 for _, zone in pairs(Config.Zones) do
  if (p-zone.Center).Magnitude < zone.Radius+8 then return false end
 end
 return true
end
local function torch(parent, cf, color)
 part(parent,"TorchStick",V(0.4,2.6,0.4),cf,rgb(70,48,32),M.Wood)
 local head = part(parent,"TorchHead",V(0.8,0.6,0.8),cf*C(0,1.5,0),rgb(40,34,32),M.Metal)
 local fire = Instance.new("Fire")
 fire.Color, fire.SecondaryColor, fire.Size, fire.Heat = color, rgb(255,140,40), 4, 6
 fire.Parent = head
 light(head,color,16)
end
local function dungeonEntrance(parent)
 local f = group(parent,"DungeonEntrance")
 local base = CFrame.lookAt(V(40,2,134), V(0,2,118))
 local stone, dark = rgb(78,76,86), rgb(34,32,40)
 part(f,"EntranceSteps",V(16,0.3,9),base*C(0,0.15,-6.5),rgb(92,90,98),M.Cobblestone,true)
 part(f,"EntranceFloor",V(14,0.4,6),base*C(0,0.2,0),dark,M.Slate,true)
 for i=1,4 do
  part(f,"DescendingStep",V(8-i*0.6,0.1,1.2),base*C(0,0.46,-3.6+i*1.1),rgb(34-i*5,32-i*5,40-i*5),M.Slate)
 end
 for _, side in ipairs({-1,1}) do
  part(f,"ArchPillar",V(3,13,3.5),base*C(side*6,6.5,0),stone,M.Slate,true)
  part(f,"PillarBase",V(4.2,1.2,4.7),base*C(side*6,0.6,0),rgb(60,58,68),M.Cobblestone,true)
  part(f,"PillarCap",V(4.2,1,4.7),base*C(side*6,13.4,0),rgb(60,58,68),M.Cobblestone,true)
  torch(f,base*C(side*6,4.5,-2.4),rgb(255,150,60))
 end
 part(f,"ArchLintel",V(16,3,4),base*C(0,14.5,0),stone,M.Slate,true)
 part(f,"ArchKeystone",V(3,2,4.4),base*C(0,17,0),rgb(95,92,104),M.Cobblestone,true)
 part(f,"ArchVoid",V(9,12,0.6),base*C(0,6,1.2),rgb(8,6,12),M.SmoothPlastic,true)
 part(f,"ArchBackWall",V(16,13,1),base*C(0,6.5,2.6),dark,M.Slate,true)
 local skull = part(f,"Skull",V(2.4,2.4,2.4),base*C(0,17.6,-2.4),rgb(226,220,200),M.Marble)
 skull.Shape = Enum.PartType.Ball
 for _, side in ipairs({-1,1}) do
  local eye = part(f,"SkullEye",V(0.7,0.7,0.5),base*C(side*0.6,17.8,-3.4),rgb(10,8,10),M.SmoothPlastic)
  eye.Shape = Enum.PartType.Ball
  part(f,"SkullHorn",V(0.5,2.4,0.5),base*C(side*1.5,19,-2.4)*CFrame.Angles(0,0,-side*0.4),rgb(205,198,176),M.Marble)
 end
 part(f,"SkullJaw",V(1.8,0.6,1.4),base*C(0,16.4,-2.7),rgb(214,208,188),M.Marble)
 local core = part(f,"DungeonEntranceCore",V(8,6,3),base*C(0,3,-1),rgb(120,230,140),M.Neon)
 core.Transparency = 1
 local prompt = Instance.new("ProximityPrompt")
 prompt.Name = "DungeonEntrance"
 prompt.ActionText, prompt.ObjectText = "Подземелья", "Вход в подземелья"
 prompt.KeyboardKeyCode, prompt.HoldDuration = Enum.KeyCode.E, 0
 prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 12, false
 prompt.Parent = core
 local label = part(f,"DungeonSign",V(1,1,1),base*C(0,14,-3),rgb(255,255,255),M.SmoothPlastic)
 label.Transparency = 1
 text(label,"ПОДЗЕМЕЛЬЯ\nE — выбрать данж")
 for _, off in ipairs({{-11,1},{11,-1},{-10,-5},{10,-5}}) do
  local rock = part(f,"Rubble",V(1.6,1,1.4),base*C(off[1],0.5,off[2])*CFrame.Angles(0,off[1],0.2),rgb(86,84,92),M.Rock)
  rock.CanCollide = false
 end
end
local function starter(parent)
 -- Remove only small pre-existing static decorations along the new portal approaches.
 for _, p in ipairs(parent:GetDescendants()) do
  if p:IsA("BasePart") and p.Anchored and p.Name~="Boundary" and p.Size.X<25 and p.Size.Z<25 then
   local pos=p.Position
   local inPath=math.abs(pos.X)<105 and math.abs(pos.Z-106)<7 and math.abs(pos.X)>20
   local inPortal=math.abs(math.abs(pos.X)-94)<14 and math.abs(pos.Z-106)<14
   if (inPath or inPortal) and pos.Y>Config.GroundY+0.5 then p:Destroy() end
  end
 end
 for _, p in ipairs(parent:GetDescendants()) do
  if p:IsA("BasePart") and p.Anchored and p.Name~="Boundary" and p.Size.X<25 and p.Size.Z<25 and p.Position.Y>Config.GroundY+0.5 then
   local pos=p.Position
   if (V(pos.X,0,pos.Z)-V(40,0,134)).Magnitude<14 then p:Destroy() end
  end
 end
 local f = group(parent,"GladeDetails")
 -- Side paths stop before the old boundary walls.
 for _, x in ipairs({-94,94}) do
  part(f,"PortalPath",V(math.abs(x),0.12,6),C(x/2,2.13,106),rgb(153,134,107),M.Cobblestone)
 end
 portal(f,V(-94,2.6,106),"Desert",V(0,2,106))
 portal(f,V(94,2.6,106),"Volcano",V(0,2,106))
 dungeonEntrance(f)
 for i=1,28 do
  local x,z = rng:NextNumber(-140,140), rng:NextNumber(-140,135)
  if clearSpawn(x,z) and math.abs(x)>65 and math.abs(z-106)>12 then
   local p = part(f,"MossyBoulder",V(3,2,4),C(x,2.8,z)*CFrame.Angles(0,i,0.2),rgb(94,115,96),M.Rock)
   p.Shape = Enum.PartType.Ball
   crystal(f,V(x+2.2,2,z),rgb(114,218,225),0.6)
   for j=1,3 do
    local leaf = part(f,"Fern",V(0.18,1.8,1),C(x+j-2,2.8,z+2)*CFrame.Angles(0,j,0.4),rgb(69,140,78),M.Grass)
    leaf.CastShadow = false
   end
  end
 end
 for _, x in ipairs({-17,17}) do
  for _, z in ipairs({48,86,129}) do lantern(f,V(x,2,z),rgb(255,224,151)) end
 end
 for _, npc in pairs(Config.NPC) do
  -- Extra display shelving behind existing stalls, not on their interaction side.
  local pos = npc.Position+V(0,0,-7)
  for _, h in ipairs({1.5,3.1}) do
   part(f,"DisplayShelf",V(8,0.22,1.4),C(pos+V(0,h,0)),rgb(104,70,43),M.WoodPlanks)
   for j=-2,2 do
    local bottle = part(f,"DisplayBottle",V(0.5,0.8,0.5),C(pos+V(j*1.2,h+0.5,0)),j%2==0 and rgb(86,183,204) or rgb(201,128,96),M.Glass)
    bottle.Transparency = 0.25
    part(f,"BottleStopper",V(0.3,0.2,0.3),bottle.CFrame*C(0,0.5,0),rgb(135,103,61),M.Wood)
   end
  end
  for _, side in ipairs({-1,1}) do
   part(f,"SupplyCrate",V(2.2,2.2,2.2),C(pos+V(side*6,1.1,1)),rgb(138,101,62),M.WoodPlanks)
   lantern(f,pos+V(side*7,0,2),rgb(255,207,126))
  end
 end
end
local function island(parent,id,cx,volcanic)
 local def = Config.Islands[id]
 local f = group(parent,id.."Island")
 local surface = volcanic and rgb(65,56,66) or rgb(214,184,124)
 part(f,"IslandBedrock",V(316,32,316),C(cx,-16,0),volcanic and rgb(35,29,42) or rgb(150,115,79),M.Rock,true)
 part(f,"IslandSurface",V(310,4,310),C(cx,0,0),surface,volcanic and M.Basalt or M.Sand,true)
 -- A safe, level path joins arrival and all farming areas. All decorative obstacles avoid spawn disks.
 part(f,"MainCauseway",V(9,0.15,245),C(cx,2.12,0),volcanic and rgb(102,78,85) or rgb(183,148,95),M.Cobblestone)
 for i=1,65 do
  local x,z = cx+rng:NextNumber(-144,144),rng:NextNumber(-144,144)
  if clearSpawn(x,z) and math.abs(x-cx)>17 and z<85 then
   if volcanic then
    local h = rng:NextNumber(6,19)
    part(f,"BasaltSpire",V(4,h,5),C(x,2+h/2,z)*CFrame.Angles(0,i,0.08),rgb(42,34,52),M.Basalt)
    if i%3==0 then crystal(f,V(x+4,2,z),rgb(255,102,49),0.8) end
   else
    local h = rng:NextNumber(1.5,4)
    local dune = part(f,"Dune",V(17,h,14),C(x,2+h/5,z),surface,M.Sand)
    dune.Shape = Enum.PartType.Ball
    if i%3==0 then
     part(f,"Cactus",V(1.2,5,1.2),C(x,4.5,z),rgb(83,134,86),M.Grass)
     part(f,"CactusArm",V(3,0.8,0.8),C(x,5,z),rgb(83,134,86),M.Grass)
    end
   end
  end
 end
 -- Ruin pillars stand outside each combat disk; the entire combat floor stays traversable.
 local templeZ = volcanic and -105 or -68
 for i=0,7 do
  local a = i*math.pi/4
  local templeX = volcanic and cx or cx+38
  local px,pz = templeX+math.cos(a)*49,templeZ+math.sin(a)*39
  local h = volcanic and 13 or 10
  part(f,"TempleColumn",V(3,h,3),C(px,2+h/2,pz),surface,M.Sandstone,true)
  part(f,"ColumnCap",V(4.5,1,4.5),C(px,2+h,pz),surface,M.Marble)
  local glow = part(f,"ColumnRune",V(1.1,1.1,0.15),C(px,6,pz-1.6)*CFrame.Angles(0,0,math.pi/4),def.Color,M.Neon)
  light(glow,def.Color,10)
 end
 if volcanic then
  -- Lava is visual only; no hidden unavoidable damage under the mob spawn floors.
  for _, x in ipairs({cx-116,cx+116}) do
   local lava = part(f,"LavaChannel",V(12,0.2,170),C(x,2.18,-10),rgb(255,96,24),M.Neon)
   light(lava,rgb(255,111,44),20)
  end
  part(f,"BossArena",V(94,0.25,86),C(cx,2.15,-105),rgb(74,57,70),M.Cobblestone,true)
  text(part(f,"ArenaSign",V(1,1,1),C(cx,7,-57),rgb(255,125,61),M.Neon),"ВЛАДЫКА ПЕПЛА\nКрасная зона — отступай!")
 else
  for step=0,5 do
   part(f,"DistantPyramid",V(65-step*9,3,65-step*9),C(cx+91,3.5+step*3,-112),rgb(188,149,91),M.Sandstone,true)
  end
 end
 for _, z in ipairs({72,30,-15}) do
  for _, x in ipairs({cx-14,cx+14}) do lantern(f,V(x,2,z),def.Color) end
 end
 portal(f,V(cx-22,2.6,114),"Glade",V(cx,2,114))
 portal(f,V(cx+22,2.6,114),volcanic and "Desert" or "Volcano",V(cx,2,114))
 if volcanic then
  part(f,"PortalPath",V(8,0.12,16),C(cx,2.13,130),rgb(102,78,85),M.Cobblestone)
  portal(f,V(cx,2.6,140),"Frost",V(cx,2,114))
 end
 text(part(f,"ArrivalMarker",V(1,1,1),C(cx,6,131),def.Color,M.Neon),def.Name.."\nРекомендуемый уровень: "..def.Level.."+")
 -- Low perimeter walls stop mobs leaving their island. Portals are entirely inside these walls.
 for _, side in ipairs({-1,1}) do
  part(f,"EdgeWall",V(310,6,2),C(cx,5,side*154),surface,M.Rock,true)
  part(f,"EdgeWall",V(2,6,310),C(cx+side*154,5,0),surface,M.Rock,true)
 end
end
-- Stacked tapering upright cylinders approximate a cone.
local function cone(parent, pos, radius, height, tiers, color, material, solid)
 local th = height/tiers
 for i=0,tiers-1 do
  local d = radius*2*(1-i/tiers)
  local p = part(parent,"ConeTier",V(th,math.max(d,0.4),math.max(d,0.4)),C(pos+V(0,th*(i+0.5),0))*CFrame.Angles(0,0,math.pi/2),color,material,solid)
  p.Shape = Enum.PartType.Cylinder
 end
end
local function disk(parent, name, pos, diameter, thickness, color, material, solid)
 local p = part(parent,name,V(thickness,diameter,diameter),C(pos)*CFrame.Angles(0,0,math.pi/2),color,material,solid)
 p.Shape = Enum.PartType.Cylinder
 return p
end
local function frost(parent)
 local cx = 2160
 local def = Config.Islands.Frost
 local f = group(parent,"FrostIsland")
 local throne = Config.Zones.FrostThrone.Center
 local ice, snow = rgb(176,220,245), rgb(236,244,250)
 -- Free of every spawn disk, the causeway, the throne arena and the portal/arrival strip.
 local function free(x,z,extra)
  if not clearSpawn(x,z) then return false end
  if math.abs(x-cx)<14 or z>95 or math.abs(x-cx)>144 or math.abs(z)>144 then return false end
  local dx,dz = x-throne.X,z-throne.Z
  return math.sqrt(dx*dx+dz*dz) > 58+(extra or 0)
 end
 part(f,"IslandBedrock",V(316,32,316),C(cx,-16,0),rgb(78,100,128),M.Rock,true)
 part(f,"IslandSurface",V(310,4,310),C(cx,0,0),snow,M.Snow,true)
 part(f,"MainCauseway",V(9,0.15,245),C(cx,2.12,0),rgb(150,185,215),M.Ice,false)
 -- Frozen lake (visual only) between the quarry and the rift, clear of all zones.
 disk(f,"FrozenLake",V(cx-98,2.12,-5),56,0.15,rgb(130,200,235),M.Glacier)
 disk(f,"FrozenLakeCore",V(cx-98,2.2,-5),34,0.1,rgb(170,225,248),M.Ice)
 for i=1,8 do
  local a = i*math.pi/4
  part(f,"LakeCrack",V(0.3,0.05,14),C(cx-98+math.cos(a)*9,2.3,-5+math.sin(a)*9)*CFrame.Angles(0,a,0),rgb(235,248,255),M.Neon)
 end
 -- Ice spires and crystals.
 local spires,crystals,pines = 0,0,0
 for i=1,260 do
  local x,z = cx+rng:NextNumber(-144,144),rng:NextNumber(-144,90)
  local lakeD = math.sqrt((x-(cx-98))^2+(z+5)^2)
  if free(x,z) and lakeD>34 then
   local kind = i%3
   if kind==0 and spires<26 then
    spires += 1
    local h = rng:NextNumber(8,20)
    part(f,"IceSpire",V(3.5,h,4),C(x,2+h/2,z)*CFrame.Angles(0,i,0.07),ice,M.Ice,true).Transparency = 0.15
   elseif kind==1 and crystals<20 then
    crystals += 1
    crystal(f,V(x,2,z),i%2==0 and rgb(120,210,255) or rgb(190,160,255),1.1)
   elseif kind==2 and pines<26 then
    pines += 1
    part(f,"PineTrunk",V(1,4,1),C(x,4,z),rgb(78,56,42),M.Wood)
    cone(f,V(x,5,z),3.6,7,3,rgb(60,100,92),M.Grass)
    cone(f,V(x,9,z),2.4,4,2,snow,M.Snow)
   end
  end
 end
 for _, a in ipairs({{-60,-20},{50,-6},{-70,60},{80,70}}) do
  local x,z = cx+a[1],a[2]
  if free(x,z) then
   local drift = part(f,"SnowDrift",V(14,2.4,10),C(x,2.2,z),snow,M.Snow)
   drift.Shape = Enum.PartType.Ball
  end
 end
 -- Void rift: glowing purple shards ringing the zone (decor only).
 local rift = Config.Zones.VoidRift
 for i=1,18 do
  local a = i*math.pi*2/18
  local pos = rift.Center+V(math.cos(a)*(rift.Radius+2),0,math.sin(a)*(rift.Radius+2))
  local h = 4+(i%4)*1.8
  local shard = part(f,"RiftShard",V(0.8,h,2.4),C(pos+V(0,h/2,0))*CFrame.Angles(0,-a,(i%3-1)*0.15),rgb(170,90,255),M.Neon)
  if i%6==0 then light(shard,rgb(170,90,255),18) end
 end
 disk(f,"RiftRing",rift.Center+V(0,0.18,0),rift.Radius*2,0.1,rgb(60,20,110),M.Neon).Transparency = 0.55
 disk(f,"RiftHeart",rift.Center+V(0,0.22,0),9,0.1,rgb(20,6,40),M.SmoothPlastic)
 -- Throne arena: flat 45-stud disk, rune rings and a boss sign; nothing collidable inside.
 disk(f,"ThroneArena",V(throne.X,2.15,throne.Z),84,0.3,rgb(182,206,230),M.Marble,true)
 disk(f,"ThroneRingOuter",V(throne.X,2.35,throne.Z),70,0.1,def.Color,M.Neon).Transparency = 0.4
 disk(f,"ThroneRingInner",V(throne.X,2.4,throne.Z),26,0.1,rgb(236,248,255),M.Glacier)
 for i=1,8 do
  local a = i*math.pi/4
  local rune = part(f,"ThroneRune",V(1.2,0.12,1.2),C(throne.X+math.cos(a)*20,2.5,throne.Z+math.sin(a)*20)*CFrame.Angles(0,a,math.pi/4),rgb(120,210,255),M.Neon)
  if i%2==0 then light(rune,def.Color,14) end
 end
 for i=0,9 do
  local a = math.rad(i*18)
  local px,pz = throne.X+math.cos(a)*54,throne.Z+math.sin(a)*54
  if math.abs(px-cx)<144 and pz>-146 and free(px,pz,-5) then
   part(f,"ArenaPillar",V(3.4,14,3.4),C(px,9,pz),ice,M.Ice,true).Transparency = 0.1
   crystal(f,V(px,16,pz),rgb(150,225,255),0.7)
  end
 end
 text(part(f,"ArenaSign",V(1,1,1),C(cx,7,-62),def.Color,M.Neon),"ИМПЕРАТОР ВЕЧНОЙ МЕРЗЛОТЫ\nКрасные круги — уклоняйся!")
 -- Citadel backdrop beyond the northern edge (never reachable).
 local cz = -190
 part(f,"CitadelCliff",V(280,32,62),C(cx,-14,cz+1),rgb(88,112,140),M.Rock)
 part(f,"CitadelCurtainWall",V(230,30,8),C(cx,17,-208),rgb(190,214,236),M.Ice)
 for _, x in ipairs({-110,-70,70,110}) do
  part(f,"CitadelTowerBody",V(14,50,14),C(cx+x,27,-208),rgb(176,200,226),M.Ice)
  cone(f,V(cx+x,52,-208),10,20,4,rgb(80,120,190),M.Glacier)
  local w = part(f,"TowerWindow",V(2.2,4,0.3),C(cx+x,40,-215.2),rgb(160,235,255),M.Neon)
  if x>0 then light(w,rgb(160,235,255),20) end
 end
 part(f,"CitadelKeep",V(60,64,30),C(cx,34,-215),rgb(170,196,224),M.Ice)
 for _, x in ipairs({-22,0,22}) do
  part(f,"KeepTower",V(12,80,12),C(cx+x,42,-215),rgb(190,214,236),M.Ice)
  cone(f,V(cx+x,82,-215),9,22+(x==0 and 14 or 0),4,rgb(92,130,205),M.Glacier)
 end
 part(f,"CitadelGateway",V(16,22,2),C(cx,13,-199),rgb(14,18,34),M.SmoothPlastic)
 local gateGlow = part(f,"CitadelGateGlow",V(14,20,0.4),C(cx,12,-200.2),rgb(120,200,255),M.Neon)
 gateGlow.Transparency = 0.5
 light(gateGlow,rgb(120,200,255),30)
 for i=-5,5 do
  part(f,"CitadelMerlon",V(6,4,8),C(cx+i*20,34,-208),rgb(190,214,236),M.Ice)
 end
 for _, z in ipairs({72,30,-15}) do
  for _, x in ipairs({cx-14,cx+14}) do lantern(f,V(x,2,z),rgb(150,220,255)) end
 end
 portal(f,V(cx-22,2.6,114),"Glade",V(cx,2,114))
 portal(f,V(cx+22,2.6,114),"Volcano",V(cx,2,114))
 text(part(f,"ArrivalMarker",V(1,1,1),C(cx,6,131),def.Color,M.Neon),def.Name.."\nРекомендуемый уровень: "..def.Level.."+")
 for _, side in ipairs({-1,1}) do
  part(f,"EdgeWall",V(310,6,2),C(cx,5,side*154),snow,M.Rock,true)
  part(f,"EdgeWall",V(2,6,310),C(cx+side*154,5,0),snow,M.Rock,true)
 end
end
function ExpansionWorld.Build(parent)
 starter(parent)
 island(parent,"Desert",720,false)
 island(parent,"Volcano",1440,true)
 frost(parent)
end
return ExpansionWorld
