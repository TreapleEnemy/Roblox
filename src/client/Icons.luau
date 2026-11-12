-- Resolution-independent layered icons. No uploaded textures or emoji dependency.
local Icons = {}
local rgb = Color3.fromRGB
local function frame(parent,x,y,w,h,color,rotation,radius)
 local f = Instance.new("Frame")
 f.AnchorPoint = Vector2.new(0.5,0.5)
 f.Position, f.Size = UDim2.fromScale(x,y), UDim2.fromScale(w,h)
 f.Rotation, f.BackgroundColor3, f.BorderSizePixel = rotation or 0,color,0
 f.Parent = parent
 if radius then
  local c=Instance.new("UICorner")
  c.CornerRadius=UDim.new(radius,0)
  c.Parent=f
 end
 return f
end
local function stroke(p,color,thickness)
 local s=Instance.new("UIStroke")
 s.Color,s.Thickness,s.Parent=color,thickness or 1.5,p
end
function Icons.ItemKind(def)
 if not def then return "Crystal" end
 if def.Slot == "Weapon" then return "Sword" end
 if def.Slot == "Armor" then return "Armor" end
 if def.Slot == "Accessory" then return "Charm" end
 if def.Kind == "Potion" then return "Potion" end
 if def.Name == "Древняя монета" or def.Name == "Царский скарабей" then return "Coin" end
 return "Crystal"
end
function Icons.Draw(parent,kind,color,position,size)
 local root=Instance.new("Frame")
 root.Name="VectorIcon_"..kind
 root.BackgroundColor3=color or rgb(130,170,210)
 root.BorderSizePixel=0
 root.Position=position or UDim2.fromScale(0,0)
 root.Size=size or UDim2.fromScale(1,1)
 root.Parent=parent
 local c=Instance.new("UICorner")
 c.CornerRadius=UDim.new(0.2,0)
 c.Parent=root
 local gradient=Instance.new("UIGradient")
 gradient.Color=ColorSequence.new(Color3.new(1,1,1),rgb(70,78,109))
 gradient.Rotation=55
 gradient.Parent=root
 stroke(root,root.BackgroundColor3:Lerp(Color3.new(1,1,1),0.4),1)
 local ink=rgb(247,248,255)
 local shade=rgb(67,73,99)
 if kind=="Sword" or kind=="Damage" then
  frame(root,0.56,0.38,0.13,0.52,ink,35,0.1)
  frame(root,0.60,0.36,0.035,0.42,rgb(174,220,255),35)
  frame(root,0.40,0.62,0.42,0.085,rgb(255,217,119),35,0.15)
  frame(root,0.33,0.74,0.11,0.20,shade,35,0.1)
  frame(root,0.27,0.83,0.13,0.1,rgb(255,222,145),35,0.2)
 elseif kind=="Health" then
  frame(root,0.40,0.38,0.29,0.32,ink,0,1)
  frame(root,0.61,0.38,0.29,0.32,ink,0,1)
  frame(root,0.5,0.53,0.37,0.37,ink,45,0.1)
  frame(root,0.39,0.34,0.11,0.07,rgb(255,202,210),-30,1)
 elseif kind=="Regen" or kind=="Stats" then
  frame(root,0.5,0.5,0.18,0.65,ink,0,0.12)
  frame(root,0.5,0.5,0.65,0.18,ink,0,0.12)
  frame(root,0.5,0.5,0.12,0.12,rgb(163,255,215),45)
 elseif kind=="Speed" then
  for _,x in ipairs({0.35,0.65}) do
   frame(root,x,0.38,0.12,0.35,ink,-40,0.1)
   frame(root,x,0.62,0.12,0.35,ink,40,0.1)
  end
 elseif kind=="Inventory" then
  local handle=frame(root,0.5,0.24,0.32,0.25,shade,0,0.3)
  stroke(handle,ink,2)
  frame(root,0.5,0.55,0.60,0.60,ink,0,0.2)
  frame(root,0.5,0.67,0.40,0.19,shade,0,0.2)
  frame(root,0.5,0.43,0.09,0.15,rgb(255,215,114),0,0.2)
 elseif kind=="Teleport" then
  local outer=frame(root,0.5,0.5,0.61,0.77,shade,0,1)
  stroke(outer,ink,2)
  local inner=frame(root,0.5,0.5,0.34,0.54,root.BackgroundColor3:Lerp(ink,0.4),0,1)
  stroke(inner,rgb(205,235,255),1)
  frame(root,0.5,0.5,0.12,0.30,ink,35,0.2)
 elseif kind=="Shop" then
  frame(root,0.5,0.62,0.62,0.43,ink,0,0.08)
  frame(root,0.5,0.36,0.74,0.22,rgb(255,225,147),0,0.1)
  for _,x in ipairs({0.25,0.50,0.75}) do frame(root,x,0.36,0.10,0.22,shade) end
  frame(root,0.5,0.66,0.18,0.34,shade,0,0.06)
 elseif kind=="Armor" then
  frame(root,0.5,0.5,0.52,0.58,ink,0,0.18)
  frame(root,0.24,0.35,0.22,0.24,ink,25,0.15)
  frame(root,0.76,0.35,0.22,0.24,ink,-25,0.15)
  frame(root,0.5,0.49,0.26,0.32,shade,0,0.15)
  frame(root,0.5,0.68,0.52,0.08,rgb(255,215,133))
 elseif kind=="Charm" then
  local chain=frame(root,0.5,0.40,0.55,0.51,shade,0,1)
  stroke(chain,rgb(255,221,135),2)
  frame(root,0.5,0.68,0.28,0.28,ink,45,0.12)
  frame(root,0.5,0.68,0.15,0.15,root.BackgroundColor3,45,0.12)
 elseif kind=="Potion" then
  frame(root,0.5,0.57,0.49,0.53,ink,0,0.35)
  frame(root,0.5,0.65,0.38,0.26,root.BackgroundColor3,0,0.3)
  frame(root,0.5,0.30,0.20,0.25,ink,0,0.1)
  frame(root,0.5,0.20,0.27,0.09,rgb(210,170,101),0,0.1)
 elseif kind=="Coin" then
  local coin=frame(root,0.5,0.5,0.66,0.66,rgb(255,211,86),0,1)
  stroke(coin,rgb(255,239,171),2)
  frame(root,0.5,0.5,0.16,0.36,rgb(164,113,49),0,0.15)
 else
  frame(root,0.5,0.5,0.42,0.59,ink,25,0.12)
  frame(root,0.4,0.4,0.13,0.39,rgb(183,230,255),25,0.1)
  frame(root,0.72,0.7,0.18,0.27,ink,40,0.1)
 end
 return root
end
return Icons
