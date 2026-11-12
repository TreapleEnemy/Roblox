-- MOCK smoke harness, not an engine emulator. Physics/rendering/API validity require Studio.
local now, queue, all = 100, {}, {}
-- Стандартные библиотеки Luau только для чтения: подменяем os целиком, остальное — только если нет (Lua 5.4).
local realOs=os
os=setmetatable({clock=function() return now end},{__index=realOs})
if not math.clamp then math.clamp=function(x,a,b) return math.max(a,math.min(b,x)) end end
if not table.find then table.find=function(t,x) for i,v in ipairs(t) do if v==x then return i end end end end
local function signal()
 local s={listeners={}}
 function s:Connect(fn) self.listeners[#self.listeners+1]=fn; return {Disconnect=function() end} end
 function s:Fire(...) for _,fn in ipairs(self.listeners) do fn(...) end end
 return s
end
local function vec(x,y,z)
 local v={X=x or 0,Y=y or 0,Z=z or 0}
 return setmetatable(v,{
  __add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
  __sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
  __unm=function(a) return vec(-a.X,-a.Y,-a.Z) end,
  __mul=function(a,b) if type(a)=="number" then a,b=b,a end; if type(b)=="number" then return vec(a.X*b,a.Y*b,a.Z*b) end; return vec(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end,
  __div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end,
  __index=function(a,k) if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) elseif k=="Unit" then local m=math.max(0.001,math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z));return vec(a.X/m,a.Y/m,a.Z/m) end end,
 })
end
Vector3={new=vec,zero=vec(),one=vec(1,1,1)}
Vector2={new=function(x,y) return {X=x,Y=y} end}
local function color(r,g,b)
 return {R=r,G=g,B=b,Lerp=function(a,c,t) return color(a.R+(c.R-a.R)*t,a.G+(c.G-a.G)*t,a.B+(c.B-a.B)*t) end}
end
Color3={new=color,fromRGB=function(r,g,b) return color(r/255,g/255,b/255) end}
local function cf(x,y,z)
 local p=type(x)=="table" and x or vec(x,y,z)
 local t={Position=p}
 return setmetatable(t,{
  __mul=function(a,b) return cf(a.Position+b.Position) end,
  __add=function(a,b) return cf(a.Position+b) end,
  __sub=function(a,b) return cf(a.Position-b) end,
  __index=function(a,k)
   if k=="Inverse" then return function() return cf(-a.Position) end end
   if k=="LookVector" then return vec(0,0,-1) end
   if k=="RightVector" then return vec(1,0,0) end
   if k=="UpVector" then return vec(0,1,0) end
   if k=="X" or k=="Y" or k=="Z" then return a.Position[k] end
  end,
 })
end
CFrame={new=cf,Angles=function() return cf() end,lookAt=function(p) return cf(p) end,identity=cf()}
Enum=setmetatable({},{__index=function(t,k) local v=setmetatable({},{__index=function(_,n) return n end});rawset(t,k,v);return v end})
UDim={new=function(s,o) return {Scale=s,Offset=o} end}
UDim2={new=function(xs,xo,ys,yo) return {X=UDim.new(xs or 0,xo or 0),Y=UDim.new(ys or 0,yo or 0)} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
ColorSequence={new=function(...) return {...} end}
ColorSequenceKeypoint={new=function(...) return {...} end}
NumberSequence={new=function(...) return {...} end}
NumberSequenceKeypoint={new=function(...) return {...} end}
NumberRange={new=function(...) return {...} end}
TweenInfo={new=function(...) return {...} end}
Random={new=function() return {NextNumber=function(_,a,b) return a and (a+(b-a)*0.5) or 0.5 end,NextInteger=function(_,a,b) return math.floor((a+b)/2) end} end}
local methods={}
local signals={Destroying=true,Changed=true,Activated=true,MouseEnter=true,MouseLeave=true,MouseButton1Down=true,MouseButton1Up=true,Triggered=true,HealthChanged=true,Died=true}
-- Дети хранятся списком у родителя: перебор всех объектов делал смоук квадратичным на большом мире.
local childrenOf=setmetatable({},{__mode="k"})
local function instance(class)
 local p={ClassName=class,Name=class,Size=vec(2,2,2),CFrame=cf(),Transparency=0,Color=color(1,1,1),Health=100,MaxHealth=100,AssemblyLinearVelocity=vec(),_attributes={}}
 local o
 o=setmetatable({_p=p},{
  __index=function(t,k)
   if methods[k] then return methods[k] end
   if k=="Position" and p.CFrame then return p.CFrame.Position end
   if signals[k] and not p[k] then p[k]=signal() end
   if p[k]~=nil then return p[k] end
   for _,obj in ipairs(childrenOf[t] or {}) do if obj._p.Name==k then return obj end end
  end,
  __newindex=function(_,k,v)
   if k=="Parent" and p.Parent~=v then
    local old=p.Parent and childrenOf[p.Parent]
    if old then local i=table.find(old,o);if i then table.remove(old,i) end end
    if v~=nil then childrenOf[v]=childrenOf[v] or {};table.insert(childrenOf[v],o) end
   end
   p[k]=v
  end,
 })
 all[#all+1]=o
 return o
end
Instance={new=instance}
function methods:IsA(c)
 if c=="BasePart" then return self.ClassName=="Part" or self.ClassName=="WedgePart" end
 if c=="GuiButton" then return self.ClassName=="TextButton" or self.ClassName=="ImageButton" end
 return self.ClassName==c
end
function methods:GetChildren() return table.clone and table.clone(childrenOf[self] or {}) or {table.unpack(childrenOf[self] or {})} end
function methods:GetDescendants() local t={} for _,o in ipairs(self:GetChildren()) do t[#t+1]=o;for _,d in ipairs(o:GetDescendants()) do t[#t+1]=d end end return t end
function methods:FindFirstChild(n,recursive) for _,o in ipairs(recursive and self:GetDescendants() or self:GetChildren()) do if o.Name==n then return o end end end
function methods:WaitForChild(n) return assert(self:FindFirstChild(n),"Missing mock child "..n) end
function methods:FindFirstChildOfClass(c) for _,o in ipairs(self:GetChildren()) do if o:IsA(c) then return o end end end
function methods:GetPropertyChangedSignal() return signal() end
function methods:SetAttribute(k,v) self._attributes[k]=v end
function methods:GetAttribute(k) return self._attributes[k] end
function methods:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end self.Parent=nil end
function methods:PivotTo(c) self.LastPivot=c;if self.PrimaryPart then self.PrimaryPart.CFrame=c end end
function methods:SetNetworkOwner() end
function methods:SetStateEnabled() end
function methods:MoveTo(p) self.MoveTarget=p end
function methods:Play() self.Played=true end
function methods:TakeDamage(n) self.Health=math.max(0,self.Health-n) end
function methods:GetBoundingBox() return (self.PrimaryPart and self.PrimaryPart.CFrame or cf()),vec(4,4,4) end
function methods:GetPivot() return self.LastPivot or (self.PrimaryPart and self.PrimaryPart.CFrame) or cf() end
function methods:FindFirstChildWhichIsA(c,recursive) for _,o in ipairs(recursive and self:GetDescendants() or self:GetChildren()) do if o:IsA(c) then return o end end end
function methods:Clone()
 local copy=instance(self.ClassName)
 for k,v in pairs(self._p) do if k~="Parent" and type(v)~="table" or k=="CFrame" or k=="Size" or k=="Color" then copy._p[k]=v end end
 copy._p.Parent=nil
 for _,c in ipairs(self:GetChildren()) do local cc=c:Clone();cc.Parent=copy;if self.PrimaryPart==c then copy.PrimaryPart=cc end end
 return copy
end
local function schedule(delay,fn,...) queue[#queue+1]={at=now+delay,co=coroutine.create(fn),args={...}} end
task={spawn=function(fn,...) schedule(0,fn,...) end,delay=function(d,fn,...) schedule(d,fn,...) end,wait=function(d) return coroutine.yield(d or 0.03) end}
local function advance(dt)
 local stop=now+dt
 for _=1,10000 do
  local i,best
  for k,q in ipairs(queue) do if q.at<=stop and (not best or q.at<best.at) then i,best=k,q end end
  if not best then now=stop;return end
  table.remove(queue,i);now=best.at
  local ok,delay=coroutine.resume(best.co,table.unpack(best.args));assert(ok,delay)
  if coroutine.status(best.co)~="dead" then queue[#queue+1]={at=now+(delay or 0.03),co=best.co,args={}} end
 end
 error("Mock scheduler runaway")
end
local services={}
workspace=instance("Workspace")
workspace.CurrentCamera={ViewportSize={X=1280,Y=720},CFrame=cf()}
services.ReplicatedStorage=instance("ReplicatedStorage")
local shared=instance("Folder");shared.Name="GladeSlayer";shared.Parent=services.ReplicatedStorage
services.Players={PlayerRemoving=signal(),list={}}
function services.Players:GetPlayers() return self.list end
services.RunService={Heartbeat=signal(),Stepped=signal(),RenderStepped=signal(),IsClient=function() return false end}
services.GuiService={GetGuiInset=function() return vec(0,58,0) end}
services.Lighting=instance("Lighting")
services.PhysicsService={IsCollisionGroupRegistered=function() return true end,CollisionGroupSetCollidable=function() end}
services.TweenService={Create=function(_,obj,info,props) return {Play=function() for k,v in pairs(props) do obj[k]=v end end,Cancel=function() end,Completed=signal()} end}
services.Debris={AddItem=function(_,obj,dt) task.delay(dt,function() obj:Destroy() end) end}
services.UserInputService={TouchEnabled=false,KeyboardEnabled=true}
services.MarketplaceService={PromptGamePassPurchase=function() end}
game={GetService=function(_,n) return assert(services[n],"Unknown mock service "..n) end}
warn=print
__sources={}
local cache={}
__parent={WaitForChild=function(_,n) return {__module=n} end}
function __require(x) local n=x.__module or x.Name;if not cache[n] then cache[n]=assert(__sources[n],n)() end;return cache[n] end
for _,n in ipairs({"Config","Rules","Models","Animator"}) do local m=instance("ModuleScript");m.Name=n;m.Parent=shared end
-- INSERT_MODULES
local Config=__require({__module="Config"})
local Rules=__require({__module="Rules"})
local Models=__require({__module="Models"})
local total=0
local function check(name,test) assert(test,name);total=total+1 end
for _,id in ipairs(Config.MobOrder) do
 local m=Models.BuildMob(id)
 check("Factory creates "..id,m and m.PrimaryPart and m:FindFirstChildOfClass("Humanoid"))
 local joints=0
 for _,d in ipairs(m:GetDescendants()) do if d:IsA("Motor6D") then joints=joints+1;check("Motor connected",d.Part0~=nil and d.Part1~=nil) end end
 check("Rig articulates "..id,joints==((Config.Mobs[id].Model or id)=="Slime" and 1 or 6))
 check("Model name matches rig "..id,m.Name==(Config.Mobs[id].Model or id))
end
for _,id in ipairs(Config.ItemOrder) do check("Item factory: "..id,Models.BuildItem(id)~=nil) end
local world=instance("Folder");world.Name="GladeSlayerWorld";world.Parent=workspace
__require({__module="ExpansionWorld"}).Build(world)
local portals,entrances=0,0
for _,d in ipairs(world:GetDescendants()) do
 if d:IsA("ProximityPrompt") and d.Name=="IslandTravel" then portals=portals+1 end
 if d:IsA("ProximityPrompt") and d.Name=="DungeonEntrance" then entrances=entrances+1 end
end
check("Nine portal endpoints (Glade 2, Desert 2, Volcano 3, Frost 2)",portals==9)
check("Dungeon entrance on the Glade",entrances==1)
local player=instance("Player");player.UserId=1;player.Parent=services.Players
services.Players.list={player};services.Players.LocalPlayer=player
local pg=instance("PlayerGui");pg.Name="PlayerGui";pg.Parent=player
player.Character=instance("Model")
local root=instance("Part");root.Name="HumanoidRootPart";root.Parent=player.Character;player.Character.PrimaryPart=root
root.CFrame=cf(0,6,118)
local hum=instance("Humanoid");hum.Parent=player.Character
local profile=Rules.NewProfile()
local changed=0
local data={Get=function() return profile end,Changed=function() changed=changed+1 end,Toast=function() end}
local sent={}
local fx={FireAllClients=function(_,kind,...) sent[#sent+1]={kind,...} end,FireClient=function() end}
local remotes={FX=fx,Toast={FireClient=function() end},Request={InvokeServer=function() return true,"" end}}
local travel=__require({__module="TravelService"})
travel.Init(data,remotes)
check("Server blocks low level",not travel.Teleport(player,profile,"Desert"))
profile.Level=35
check("Server accepts unlocked island",travel.Teleport(player,profile,"Desert"))
check("Destination exact",root.Position.X==720)
check("Travel cooldown",not travel.Teleport(player,profile,"Volcano"))
advance(6)
player:SetAttribute("GladeCombatAt",now)
check("Combat travel blocked",not travel.Teleport(player,profile,"Glade"))
advance(9)
check("Post-combat travel",travel.Teleport(player,profile,"Volcano"))
advance(6)
hum.Health=0
check("Dead travel blocked",not travel.Teleport(player,profile,"Glade"))
hum.Health=100
local mobService=__require({__module="MobService"})
local damageCalls=0
mobService.Init(data,{Damage=function(_,n) damageCalls=damageCalls+1;hum.Health=math.max(0,hum.Health-n);return true end},remotes)
mobService.Start()
local folder=mobService.GetFolder()
local expectedSlots=0
for _,id in ipairs(Config.MobOrder) do expectedSlots=expectedSlots+Config.Mobs[id].Count end
check("All island mob slots spawned",#folder:GetChildren()==expectedSlots and expectedSlots==47)
local boss=folder:FindFirstChild("AshOverlord")
local mob=mobService.FromPart(boss.PrimaryPart)
check("Boss recognized",mob and mob.Def.Boss and boss:GetAttribute("Phase")==1)
-- Keep player in AoE range but beyond melee range so first attack is an AoE.
root.CFrame=cf(mob.Root.Position+vec(18,-7,0))
mobService.Damage(mob,player,13000,false)
advance(4.4)
check("Boss enters phase two",boss:GetAttribute("Phase")==2)
check("Server creates warning",boss:FindFirstChild("BossWarning")~=nil)
root.CFrame=cf(1440,6,112)
local before=damageCalls
advance(2)
check("Warning cleaned",boss:FindFirstChild("BossWarning")==nil)
check("Dodging avoids AoE damage",damageCalls==before)
local impact=false
for _,event in ipairs(sent) do if event[1]=="BossImpact" then impact=true end end
check("Boss impact broadcast",impact)
-- Killing boss while its next telegraph exists must cancel the delayed damage.
root.CFrame=cf(mob.Root.Position+vec(18,-7,0))
advance(5)
check("Second telegraph appears",boss:FindFirstChild("BossWarning")~=nil)
mobService.Damage(mob,player,999999,false)
check("Boss marked dead",boss:GetAttribute("MobDead"))
before=damageCalls
advance(2)
check("Dead boss cannot deal delayed AoE",damageCalls==before)
check("Boss reward granted",profile.Coins>=3500)
-- Мировой босс Ледяной Цитадели: три фазы, призыв миньонов и метеоры-телеграфы.
local emperorModel=folder:FindFirstChild("FrostEmperor")
local emperor=mobService.FromPart(emperorModel.PrimaryPart)
check("Frost Emperor spawned",emperor and emperor.Def.Boss)
root.CFrame=cf(emperor.Root.Position+vec(30,-7,0))
mobService.Damage(emperor,player,60000,false)
advance(0.5)
check("Emperor phase two",emperorModel:GetAttribute("Phase")==2)
local slotsBefore=#folder:GetChildren()
advance(3)
check("Emperor summons minions",#folder:GetChildren()>slotsBefore)
mobService.Damage(emperor,player,60000,false)
advance(0.5)
check("Emperor phase three",emperorModel:GetAttribute("Phase")==3)
local meteor=false
for _=1,40 do
 advance(0.5)
 hum.Health=100
 for _,c in ipairs(emperorModel:GetChildren()) do if c.Name=="BossWarning" then meteor=true end end
end
check("Emperor telegraphs attacks",meteor)
-- Гайд: три слизня → гарантированный меч.
profile.Tutorial,profile.TutorialProgress=1,0
local tutorial=__require({__module="TutorialService"})
local economy={}
tutorial.Init(data,remotes,mobService,economy)
local swordsBefore=profile.Inventory.OldSword or 0
for _=1,3 do mobService.OnKill(player,profile,"Slime") end
check("Tutorial advances after 3 slimes",profile.Tutorial==2)
check("Tutorial grants Old Sword",(profile.Inventory.OldSword or 0)>=math.max(1,swordsBefore))
economy.OnAction(player,profile,"Equip","OldSword")
economy.OnAction(player,profile,"Upgrade","Damage")
economy.OnAction(player,profile,"SellAll")
check("Tutorial finished through actions",profile.Tutorial==#Config.Tutorial.Steps+1)
-- Подземелье: вход, отсчёт, 3 волны, босс, сундук и возврат.
advance(10)
hum.Health=100
remotes.Dungeon={FireClient=function(_,_,payload) remotes.LastDungeon=payload end}
remotes.OpenShop={FireClient=function() end}
local dungeons=__require({__module="DungeonService"})
dungeons.Init(data,mobService,remotes)
profile.Level=9
check("Dungeon level gate",not dungeons.Enter(player,profile,"Catacombs"))
profile.Level=12
player:SetAttribute("GladeCombatAt",nil)
local okEnter,msg=dungeons.Enter(player,profile,"Catacombs")
check("Dungeon entered: "..tostring(msg),okEnter and dungeons.InDungeon(player))
check("Teleport blocked inside dungeon",not travel.Teleport(player,profile,"Glade"))
check("Arena built",workspace:FindFirstChild("GladeSlayerDungeons"):FindFirstChild("Dungeon_Catacombs")~=nil)
check("Player moved to arena",root.Position.X<-3000)
advance(Config.DungeonCountdown+1)
check("Wave 1 started",remotes.LastDungeon.Stage=="Wave" and remotes.LastDungeon.Wave==1 and remotes.LastDungeon.Remaining==5)
local function killTagged()
 for _,model in ipairs(folder:GetChildren()) do
  local m=model.PrimaryPart and mobService.FromPart(model.PrimaryPart)
  if m and m.Opts.Tag then mobService.Damage(m,player,10^7,false) end
 end
end
for wave=1,3 do
 killTagged()
 advance(Config.DungeonWaveDelay+1.5)
 hum.Health=100
end
check("Boss wave reached",remotes.LastDungeon.Stage=="Boss" and remotes.LastDungeon.Wave==4)
local coinsBeforeBoss=profile.Coins
killTagged()
advance(1)
check("Victory after boss",remotes.LastDungeon.Stage=="Victory")
local arena=workspace:FindFirstChild("GladeSlayerDungeons"):FindFirstChild("Dungeon_Catacombs")
local chestPrompt,exitPrompt
for _,d in ipairs(arena:GetDescendants()) do
 if d.Name=="DungeonChest" then chestPrompt=d end
 if d.Name=="DungeonExit" then exitPrompt=d end
end
check("Chest and return portal spawned",chestPrompt~=nil and exitPrompt~=nil)
root.CFrame=cf(chestPrompt.Parent.Position)
chestPrompt.Triggered:Fire(player)
check("Chest rewards coins",profile.Coins>coinsBeforeBoss)
root.CFrame=cf(exitPrompt.Parent.Position)
exitPrompt.Triggered:Fire(player)
check("Returned home",not dungeons.InDungeon(player) and root.Position.X==0 and remotes.LastDungeon.Active==false)
advance(3)
check("Arena cleaned up",workspace:FindFirstChild("GladeSlayerDungeons"):FindFirstChild("Dungeon_Catacombs")==nil)
-- UI constructors and panel refresh execute using the same config and profile.
local UI=__require({__module="UI"})
UI.Init(remotes,function() end)
UI.SetState(Rules.ClientState(profile,now))
for _,name in ipairs({"Inventory","Stats","Teleports","Shop","Merchant","Blacksmith","Dungeons"}) do UI.Open(name);check("UI panel opens "..name,pg:FindFirstChild("GladeSlayerUI"):FindFirstChild(name).Visible);UI.Close() end
UI.SetDungeon({Active=true,Id="Tomb",Name="Гробница",Stage="Wave",Wave=2,Waves=4,Remaining=3,Total=5,TimeLeft=200})
check("Dungeon HUD visible",pg:FindFirstChild("GladeSlayerUI"):FindFirstChild("DungeonBar").Visible)
UI.SetDungeon({Active=false})
check("Dungeon HUD hidden",not pg:FindFirstChild("GladeSlayerUI"):FindFirstChild("DungeonBar").Visible)
local guiState=Rules.ClientState(profile,now)
guiState.Tutorial=2
UI.SetState(guiState)
check("Tutorial tracker visible",pg:FindFirstChild("GladeSlayerUI"):FindFirstChild("Tutorial").Visible)
__require({__module="Guide"}).SetState(guiState)
advance(0.3)
services.RunService.Heartbeat:Fire(0.016)
services.RunService.RenderStepped:Fire(0.016)
print("PASS: "..total.." mocked factory/travel/boss/UI assertions (not real Roblox runtime)")
