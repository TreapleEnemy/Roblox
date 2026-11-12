-- Underground dungeon arenas built from anchored Parts; one themed hall per Config.Dungeons entry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GladeSlayer"):WaitForChild("Config"))
local DungeonWorld = {}
local V = Vector3.new
local C = CFrame.new
local rgb = Color3.fromRGB
local M = Enum.Material

local HALF = 65 -- inner half-width of the hall
local HEIGHT = 32

local THEMES = {
 Catacombs = {
  floor = rgb(78,84,82), floorMat = M.Cobblestone, wall = rgb(64,70,72), wallMat = M.Slate,
  column = rgb(92,98,96), trim = rgb(48,54,52), fire = rgb(110,255,130), accent = rgb(120,230,140),
 },
 Tomb = {
  floor = rgb(196,166,112), floorMat = M.Sandstone, wall = rgb(176,146,98), wallMat = M.Sandstone,
  column = rgb(214,184,128), trim = rgb(150,120,76), fire = rgb(120,190,255), accent = rgb(255,205,100),
 },
 Forge = {
  floor = rgb(40,36,44), floorMat = M.Basalt, wall = rgb(34,30,38), wallMat = M.Basalt,
  column = rgb(58,50,60), trim = rgb(24,20,28), fire = rgb(255,140,60), accent = rgb(255,120,60),
 },
}

local function part(parent, name, size, cf, color, material, solid)
 local p = Instance.new("Part")
 p.Name, p.Size, p.CFrame = name, size, cf
 p.Color, p.Material, p.Anchored = color, material or M.Slate, true
 p.CanCollide = solid == true
 p.CanTouch = false
 p.CanQuery = solid == true
 p.CastShadow = solid == true
 p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 p.Parent = parent
 return p
end
local function group(parent, name)
 local f = Instance.new("Folder")
 f.Name, f.Parent = name, parent
 return f
end
local function light(p, color, range, brightness)
 local l = Instance.new("PointLight")
 l.Color, l.Range, l.Brightness = color, range or 14, brightness or 1.4
 l.Parent = p
 return l
end
local function fire(p, color, size)
 local fx = Instance.new("Fire")
 fx.Color, fx.SecondaryColor = color, rgb(255,170,60)
 fx.Size, fx.Heat = size or 4, 6
 fx.Parent = p
 return fx
end
local function label(p, title, offset)
 local ui = Instance.new("BillboardGui")
 ui.Size = UDim2.fromOffset(260, 62)
 ui.StudsOffsetWorldSpace = V(0, offset or 5, 0)
 ui.MaxDistance, ui.AlwaysOnTop = 75, true
 local t = Instance.new("TextLabel")
 t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
 t.Font, t.TextSize = Enum.Font.GothamBold, 18
 t.TextColor3, t.TextStrokeTransparency = Color3.new(1,1,1), 0.25
 t.TextWrapped, t.Text = true, title
 t.Parent = ui
 ui.Parent = p
end
local function disk(parent, name, pos, diameter, thickness, color, material)
 local p = part(parent,name,V(thickness,diameter,diameter),C(pos)*CFrame.Angles(0,0,math.pi/2),color,material)
 p.Shape = Enum.PartType.Cylinder
 return p
end
local function skull(parent, cf)
 local s = part(parent,"Skull",V(1.2,1.2,1.2),cf,rgb(224,218,198),M.Marble)
 s.Shape = Enum.PartType.Ball
 part(parent,"SkullJaw",V(0.8,0.3,0.7),cf*C(0,-0.7,-0.15),rgb(206,200,180),M.Marble)
 for _, side in ipairs({-1,1}) do
  local eye = part(parent,"SkullEye",V(0.32,0.32,0.2),cf*C(side*0.3,0.1,-0.55),rgb(8,6,8),M.SmoothPlastic)
  eye.Shape = Enum.PartType.Ball
 end
end
local function bonePile(parent, pos, rng)
 local cf = C(pos)*CFrame.Angles(0,rng:NextNumber(0,6.28),0)
 for i=1,3 do
  part(parent,"Bone",V(0.35,0.35,rng:NextNumber(1.8,3)),cf*C((i-2)*0.7,0.2+i*0.05,0)*CFrame.Angles(0,(i-2)*0.5,0),rgb(222,214,190),M.Marble)
 end
 if rng:NextNumber() < 0.6 then skull(parent,cf*C(0.5,0.9,0.4)) end
end
local function torch(parent, cf, color)
 part(parent,"TorchBracket",V(0.5,0.5,1.6),cf*C(0,-0.9,0.8),rgb(40,36,36),M.Metal)
 local head = part(parent,"TorchHead",V(0.9,0.7,0.9),cf*C(0,0,0.2),rgb(30,28,28),M.Metal)
 fire(head,color,5)
 light(head,color,24,1.6)
 part(parent,"TorchStick",V(0.4,2,0.4),cf*C(0,-0.6,0.3),rgb(70,48,32),M.Wood)
end
local function column(parent, pos, theme)
 local f = group(parent,"Column")
 part(f,"ColumnBase",V(6,1.6,6),C(pos+V(0,0.8,0)),theme.trim,M.Cobblestone,true)
 part(f,"ColumnShaft",V(4,HEIGHT-4,4),C(pos+V(0,HEIGHT/2,0)),theme.column,theme.wallMat,true)
 part(f,"ColumnCap",V(6,1.6,6),C(pos+V(0,HEIGHT-1.4,0)),theme.trim,M.Cobblestone,true)
 return f
end

local function gate(parent, base, theme)
 local f = group(parent,"Portcullis")
 local iron = rgb(48,46,52)
 part(f,"GateGap",V(13,13,0.4),base*C(0,6.5,-0.1),rgb(4,4,8),M.SmoothPlastic)
 for _, side in ipairs({-1,1}) do
  part(f,"GatePost",V(2,14,1.4),base*C(side*7.5,7,-0.7),theme.trim,M.Cobblestone)
 end
 part(f,"GateLintel",V(17,2,1.4),base*C(0,14.5,-0.7),theme.trim,M.Cobblestone)
 for i=-4,4 do
  part(f,"GateBar",V(0.4,13,0.4),base*C(i*1.5,6.6,-0.9),iron,M.Metal)
 end
 for _, y in ipairs({4,9}) do
  part(f,"GateCrossbar",V(13,0.4,0.4),base*C(0,y,-1.1),iron,M.Metal)
 end
end

local function catacombs(parent, theme, rng)
 local pools = {{-38,-32},{40,-36},{-44,20},{44,26},{-20,-52},{22,-50}}
 for i, p in ipairs(pools) do
  local d = rng:NextNumber(8,13)
  local pool = disk(parent,"SlimePool",V(p[1],0.07,p[2]),d,0.1,rgb(90,220,110),M.Neon)
  pool.Transparency = 0.35
  if i%2==1 then light(pool,theme.fire,16,1) end
  for j=1,3 do
   local b = part(parent,"SlimeBubble",V(0.7,0.7,0.7),C(p[1]+rng:NextNumber(-d/3,d/3),0.5,p[2]+rng:NextNumber(-d/3,d/3)),rgb(150,255,160),M.Glass)
   b.Shape, b.Transparency = Enum.PartType.Ball, 0.3
  end
 end
 for i=1,16 do
  local a = rng:NextNumber(0,6.28)
  local r = rng:NextNumber(30,60)
  bonePile(parent,V(math.cos(a)*r,0.1,math.sin(a)*r),rng)
 end
 for _, x in ipairs({-52,-26,26,52}) do
  part(parent,"CoffinNiche",V(8,5,0.6),C(x,6,-HALF+0.3),rgb(30,34,34),M.Slate)
  part(parent,"CoffinLid",V(7,0.8,2),C(x,3.4,-HALF+1.2),rgb(96,102,98),M.Cobblestone)
 end
end

local function tomb(parent, theme, rng, wallBases)
 for _, base in ipairs(wallBases) do
  part(parent,"GoldBand",V(136,2,0.4),base*C(0,22,-0.3),theme.accent,M.Metal)
  for i=-7,7,2 do
   part(parent,"Hieroglyph",V(1.2,1.2,0.3),base*C(i*8,19.5,-0.35),rgb(40,70,110),M.SmoothPlastic)
  end
 end
 for _, x in ipairs({-46,-22,22,46}) do
  local cf = CFrame.lookAt(V(x,0,-HALF+6),V(x,0,0))
  part(parent,"Sarcophagus",V(5,3,10),cf*C(0,1.5,0),rgb(214,184,128),M.Sandstone)
  part(parent,"SarcophagusLid",V(5.4,0.8,10.4),cf*C(0,3.3,0),theme.accent,M.Metal)
  part(parent,"SarcophagusMask",V(2,2,0.4),cf*C(0,3.9,3.6),rgb(60,110,180),M.SmoothPlastic)
 end
 for _, p in ipairs({{-34,-56},{34,-56},{-26,56},{26,56},{-58,-10},{58,-10}}) do
  part(parent,"BrazierStand",V(2,3,2),C(p[1],1.5,p[2]),theme.trim,M.Slate)
  local bowl = part(parent,"BrazierBowl",V(1,3.4,3.4),C(p[1],3.5,p[2])*CFrame.Angles(0,0,math.pi/2),theme.accent,M.Metal)
  bowl.Shape = Enum.PartType.Cylinder
  local flame = part(parent,"BrazierFlame",V(1,1,1),C(p[1],4.4,p[2]),rgb(120,190,255),M.Neon)
  flame.Transparency = 0.6
  fire(flame,theme.fire,6)
  light(flame,theme.fire,26,1.5)
 end
 for i=1,10 do
  local a = rng:NextNumber(0,6.28)
  local r = rng:NextNumber(34,60)
  part(parent,"SandDrift",V(6,0.4,4),C(math.cos(a)*r,0.2,math.sin(a)*r)*CFrame.Angles(0,a,0),rgb(226,196,138),M.Sand)
 end
 for i=1,8 do
  local a = rng:NextNumber(0,6.28)
  bonePile(parent,V(math.cos(a)*rng:NextNumber(34,58),0.1,math.sin(a)*rng:NextNumber(34,58)),rng)
 end
end

local function forge(parent, theme, rng)
 for _, x in ipairs({-58,58}) do
  local lava = part(parent,"LavaChannel",V(6,0.1,120),C(x,0.06,0),rgb(255,96,24),M.Neon)
  light(lava,rgb(255,120,50),30,2)
  for _, s in ipairs({-1,1}) do
   part(parent,"ObsidianCurb",V(1,0.6,120),C(x+s*3.5,0.3,0),rgb(18,14,24),M.Glass)
  end
 end
 for _, p in ipairs({{-26,-56},{26,-56},{-26,56},{26,56}}) do
  part(parent,"AnvilBase",V(3,2,2.4),C(p[1],1,p[2]),rgb(36,34,40),M.Metal)
  part(parent,"AnvilTop",V(4.6,0.9,2.2),C(p[1],2.45,p[2]),rgb(70,68,76),M.Metal)
  part(parent,"AnvilHorn",V(1.8,0.6,1.2),C(p[1]+2.8,2.5,p[2]),rgb(70,68,76),M.Metal)
  local ember = part(parent,"AnvilEmber",V(1.2,0.15,0.8),C(p[1],2.95,p[2]),rgb(255,120,50),M.Neon)
  light(ember,theme.fire,14,1.2)
 end
 for i=1,8 do
  local x,z = rng:NextNumber(-55,55),rng:NextNumber(-55,55)
  if math.sqrt(x*x+z*z) > 20 then
   part(parent,"ChainLine",V(0.4,12,0.4),C(x,HEIGHT-6,z),rgb(60,58,64),M.Metal)
   local hook = part(parent,"ChainHook",V(1.4,1.4,0.5),C(x,HEIGHT-12.6,z)*CFrame.Angles(0,i,0),rgb(80,76,84),M.Metal)
   hook.Shape = Enum.PartType.Cylinder
  end
 end
 for i=1,10 do
  local a = rng:NextNumber(0,6.28)
  local r = rng:NextNumber(30,58)
  part(parent,"SlagRock",V(2.4,1.4,2),C(math.cos(a)*r,0.7,math.sin(a)*r)*CFrame.Angles(0,a,0.2),rgb(54,46,56),M.Slate)
 end
end

function DungeonWorld.Build(dungeonId, origin)
 local def = Config.Dungeons[dungeonId]
 local theme = THEMES[def.Theme] or THEMES.Catacombs
 local seed = 0
 for i=1,string.len(dungeonId) do seed += dungeonId:byte(i)*i end
 local rng = Random.new(9100+seed)
 local model = Instance.new("Model")
 model.Name = "Dungeon_"..dungeonId
 local f = group(model,"Hall")
 local o = origin
 local floorY = o.Y
 -- Everything below is authored around (0,0,0) at floor level and shifted by origin.
 local rootCF = C(o.X,floorY,o.Z)
 local function at(x,y,z) return rootCF*C(x,y,z) end

 -- Shell: floor, thick walls, ceiling.
 part(f,"HallFloor",V(150,6,150),at(0,-3,0),theme.floor,theme.floorMat,true)
 local shell = group(f,"Shell")
 for _, side in ipairs({-1,1}) do
  part(shell,"HallWall",V(150,HEIGHT,6),at(0,HEIGHT/2,side*(HALF+3)),theme.wall,theme.wallMat,true)
  part(shell,"HallWall",V(6,HEIGHT,150),at(side*(HALF+3),HEIGHT/2,0),theme.wall,theme.wallMat,true)
 end
 part(shell,"HallCeiling",V(156,4,156),at(0,HEIGHT+2,0),theme.wall,theme.wallMat,true)
 -- Seal the corners against mobs/players clipping out.
 part(shell,"OuterSeal",V(170,2,170),at(0,-7,0),theme.trim,theme.wallMat,true)

 local decor = group(f,"Decor")
 local wallBases = {}
 for _, w in ipairs({{0,-HALF},{0,HALF},{-HALF,0},{HALF,0}}) do
  local wp = V(o.X+w[1],floorY,o.Z+w[2])
  table.insert(wallBases, CFrame.lookAt(wp,V(o.X,floorY,o.Z)))
 end
 -- Decorative helpers run in local space; shift whole folders to world afterwards.

 -- Ceiling beams, floor emblem.
 for i=-3,3 do
  part(decor,"CeilingBeam",V(4,3,150),at(i*20,HEIGHT-1.5,0),theme.trim,M.Cobblestone)
 end
 disk(decor,"FloorEmblem",at(0,0.05,0).Position,34,0.1,theme.trim,M.Slate)
 local ring = disk(decor,"FloorRing",at(0,0.08,0).Position,30,0.1,theme.accent,M.Neon)
 ring.Transparency = 0.7
 disk(decor,"FloorEmblemInner",at(0,0.1,0).Position,26,0.1,theme.floor,theme.floorMat)
 for i=1,12 do
  local a = i*math.pi/6
  local rune = part(decor,"FloorRune",V(1.2,0.1,1.2),at(math.cos(a)*14.5,0.14,math.sin(a)*14.5)*CFrame.Angles(0,a,math.pi/4),theme.accent,M.Neon)
  if i%4==0 then light(rune,theme.accent,16,1) end
 end

 -- Columns avoid the central 30-stud circle, spawn lanes and the portal/chest line.
 local colPositions = {{-45,-45},{45,-45},{-45,45},{45,45},{-45,0},{45,0},{0,-45},{-45,-22},{45,-22},{-45,22},{45,22}}
 for _, p in ipairs(colPositions) do column(f,at(p[1],0,p[2]).Position,theme) end

 -- Wall torches, gates and wall trim.
 for i, base in ipairs(wallBases) do
  for _, t in ipairs({-50,-34,-18,18,34,50}) do
   torch(decor,base*C(t,9,-0.9)*CFrame.Angles(0,0,0),theme.fire)
  end
  part(decor,"WallPlinth",V(136,2,1),base*C(0,1,-0.5),theme.trim,M.Cobblestone)
  if i~=2 then gate(decor,base,theme) end
 end

 -- Scattered skulls and rubble.
 for i=1,10 do
  local a,r = rng:NextNumber(0,6.28),rng:NextNumber(24,62)
  part(decor,"Rubble",V(rng:NextNumber(1.2,2.6),0.9,rng:NextNumber(1.2,2.4)),at(math.cos(a)*r,0.45,math.sin(a)*r)*CFrame.Angles(0,a,0.15),theme.column,M.Rock)
 end
 local themeDecor = group(f,"ThemeDecor")
 local worldCenter = V(o.X,floorY,o.Z)
 local function shifted(builder, ...)
  local tmp = Instance.new("Folder")
  builder(tmp, ...)
  for _, p in ipairs(tmp:GetDescendants()) do
   if p:IsA("BasePart") then
    p.CFrame = rootCF * p.CFrame
    p.Parent = themeDecor
   end
  end
  tmp:Destroy()
 end
 if def.Theme == "Tomb" then
  local localBases = {}
  for _, w in ipairs({{0,-HALF},{0,HALF},{-HALF,0},{HALF,0}}) do
   localBases[#localBases+1] = CFrame.lookAt(V(w[1],0,w[2]),V(0,0,0))
  end
  shifted(tomb,theme,rng,localBases)
 elseif def.Theme == "Forge" then
  shifted(forge,theme,rng)
 else
  shifted(catacombs,theme,rng)
 end

 -- Floor-level dim ambience lights over the hall.
 for _, p in ipairs({{-30,-30},{30,-30},{-30,30},{30,30},{0,-55}}) do
  local lamp = part(decor,"AmbientLight",V(1,1,1),at(p[1],HEIGHT-4,p[2]),theme.accent,M.Neon)
  lamp.Transparency = 1
  light(lamp,theme.accent,50,0.5)
 end

 local spawns = {}
 local playerSpawnPos = V(o.X,floorY+3,o.Z+50)
 local function addSpawn(x,z)
  if (V(x,0,z)-V(0,0,50)).Magnitude >= 16 then spawns[#spawns+1] = V(o.X+x,floorY,o.Z+z) end
 end
 for i=0,7 do
  local a = i*math.pi/4
  addSpawn(math.sin(a)*32,math.cos(a)*32)
 end
 for k=0,3 do
  local a = math.rad(45+k*90)
  addSpawn(math.sin(a)*50,math.cos(a)*50)
 end
 addSpawn(-34,-8)
 addSpawn(34,-8)

 return {
  Folder = model,
  PlayerSpawn = CFrame.lookAt(playerSpawnPos,V(o.X,floorY+3,o.Z)),
  MobSpawns = spawns,
  BossSpawn = V(o.X,floorY,o.Z-28),
  ChestCFrame = CFrame.lookAt(V(o.X,floorY,o.Z-10),V(o.X,floorY,o.Z+50)),
  PortalCFrame = CFrame.lookAt(V(o.X,floorY,o.Z+57),V(o.X,floorY,o.Z)),
  Center = worldCenter,
  Radius = 62,
 }
end

function DungeonWorld.BuildChest(cframe, color)
 local m = Instance.new("Model")
 m.Name = "DungeonChest"
 local gold = rgb(236,186,64)
 local wood = rgb(122,80,44)
 local base = part(m,"ChestBase",V(5,2.6,3.2),cframe*C(0,1.3,0),wood,M.WoodPlanks,true)
 local lid = part(m,"ChestLid",V(5.2,1.2,3.4),cframe*C(0,3.2,0),wood,M.WoodPlanks)
 local arch = part(m,"ChestLidArch",V(5.2,1,3.4),cframe*C(0,3.9,0)*CFrame.Angles(0,0,0),rgb(138,92,52),M.WoodPlanks)
 arch.Size = V(4.4,0.8,3.2)
 for _, x in ipairs({-2.3,2.3}) do
  part(m,"ChestTrim",V(0.4,3.9,3.5),cframe*C(x,1.95,0),gold,M.Metal)
 end
 part(m,"ChestBand",V(5.4,0.4,3.5),cframe*C(0,2.65,0),gold,M.Metal)
 part(m,"ChestLock",V(1,1.2,0.3),cframe*C(0,2.6,-1.7),gold,M.Metal)
 local glow = part(m,"ChestGlow",V(0.9,0.9,0.9),cframe*C(0,2.6,-1.95),color,M.Neon)
 glow.Shape = Enum.PartType.Ball
 light(glow,color,22,2)
 local aura = part(m,"ChestAura",V(0.3,6,0.3),cframe*C(0,6,0),color,M.Neon)
 aura.Transparency = 0.75
 for _, p in ipairs({base,lid,arch}) do p.CanQuery = true end
 m.PrimaryPart = base
 m.Parent = nil
 return m
end

function DungeonWorld.BuildReturnPortal(cframe)
 local def = Config.Islands and Config.Islands.Glade
 local color = def and def.Color or rgb(120,230,150)
 local m = Instance.new("Model")
 m.Name = "ReturnPortal"
 local stone = rgb(86,85,103)
 part(m,"PortalPlinth",V(12,0.6,6),cframe*C(0,0.3,0),rgb(65,66,86),M.Marble,true)
 for _, side in ipairs({-1,1}) do
  part(m,"PortalPillar",V(1.4,9,1.6),cframe*C(side*4.5,5.1,0),stone,M.Slate,true)
  local gem = part(m,"PortalGem",V(0.9,1.6,0.9),cframe*C(side*4.5,10.4,0),color,M.Neon)
  gem.Shape = Enum.PartType.Ball
 end
 part(m,"PortalLintel",V(10.4,1,1.8),cframe*C(0,9.6,0),rgb(93,88,113),M.Marble,true)
 local core = part(m,"PortalCore",V(7.6,8.4,0.25),cframe*C(0,5.1,0),color,M.Neon)
 core.Transparency = 0.55
 light(core,color,24,2)
 label(core,"Портал на Поляну\nE — вернуться",7)
 m.PrimaryPart = core
 return m
end

return DungeonWorld
