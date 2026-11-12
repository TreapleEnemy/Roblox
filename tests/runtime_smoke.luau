-- MOCK smoke harness, not an engine emulator. Physics/rendering/API validity require Studio.
local now, queue, all = 100, {}, {}
os.clock=function() return now end
math.clamp=function(x,a,b) return math.max(a,math.min(b,x)) end
table.find=function(t,x) for i,v in ipairs(t) do if v==x then return i end end end
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
  __index=function(a,k) if k=="Inverse" then return function() return cf(-a.Position) end end end,
 })
end
CFrame={new=cf,Angles=function() return cf() end}
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
local signals={Destroying=true,Changed=true,Activated=true,MouseEnter=true,MouseLeave=true,MouseButton1Down=true,MouseButton1Up=true,Triggered=true,HealthChanged=true}
local function instance(class)
 local p={ClassName=class,Name=class,Size=vec(2,2,2),CFrame=cf(),Transparency=0,Color=color(1,1,1),Health=100,MaxHealth=100,AssemblyLinearVelocity=vec(),_attributes={}}
 local o=setmetatable({_p=p},{
  __index=function(t,k)
   if methods[k] then return methods[k] end
   if k=="Position" and p.CFrame then return p.CFrame.Position end
   if signals[k] and not p[k] then p[k]=signal() end
   if p[k]~=nil then return p[k] end
   for _,obj in ipairs(all) do if obj._p.Parent==t and obj._p.Name==k then return obj end end
  end,
  __newindex=function(_,k,v) p[k]=v end,
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
function methods:GetChildren() local t={} for _,o in ipairs(all) do if o.Parent==self then t[#t+1]=o end end return t end
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
services.RunService={Heartbeat=signal(),Stepped=signal(),IsClient=function() return false end}
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
 check("Rig articulates "..id,joints==(id=="Slime" and 1 or 6))
end
for _,id in ipairs(Config.ItemOrder) do check("Item factory: "..id,Models.BuildItem(id)~=nil) end
local world=instance("Folder");world.Name="GladeSlayerWorld";world.Parent=workspace
__require({__module="ExpansionWorld"}).Build(world)
local portals=0
for _,d in ipairs(world:GetDescendants()) do if d:IsA("ProximityPrompt") then portals=portals+1 end end
check("Six portal endpoints",portals==6)
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
check("All 28 mob slots spawned",#folder:GetChildren()==28)
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
-- UI constructors and panel refresh execute using the same config and profile.
local UI=__require({__module="UI"})
UI.Init(remotes,function() end)
UI.SetState(Rules.ClientState(profile,now))
for _,name in ipairs({"Inventory","Stats","Teleports","Shop","Merchant","Blacksmith"}) do UI.Open(name);check("UI panel opens "..name,pg:FindFirstChild("GladeSlayerUI"):FindFirstChild(name).Visible);UI.Close() end
advance(0.3)
services.RunService.Heartbeat:Fire(0.016)
print("PASS: "..total.." mocked factory/travel/boss/UI assertions (not real Roblox runtime)")
