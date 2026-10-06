--!strict
-- Observe replicated arrivals only; joining beside an existing gem is not a new arrival.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Art = require(script.Parent:WaitForChild("UiArt"))
local Chrome = require(script.Parent:WaitForChild("UiChromeAssets"))
local Controller = {}; Controller.__index = Controller
function Controller.new(): any
 local gui=Instance.new("ScreenGui"); gui.Name="GemArrivalGui"; gui.ResetOnSpawn=false; gui.DisplayOrder=8; gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets; gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
 local group=Instance.new("CanvasGroup"); group.Name="Announcement"; group.AnchorPoint=Vector2.new(.5,0); group.Position=UDim2.new(.5,0,0,8); group.Size=UDim2.fromOffset(420,92); group.BackgroundTransparency=1; group.Visible=false; group.Parent=gui
 local image=Instance.new("ImageLabel"); image.Name="IllustratedFrame"; image.Size=UDim2.fromScale(1,1); image.BackgroundTransparency=1; image.Image=Chrome.GemAnnouncement
 -- Roblox stores this upload at 1023x341; slice coordinates refer to the delivered image.
 image.ScaleType=Enum.ScaleType.Slice; image.SliceCenter=Rect.new(132,104,891,236); image.SliceScale=.20; image.Parent=group
 local icon=Instance.new("Frame"); icon.Name="GemIcon"; icon.Position=UDim2.fromOffset(19,16); icon.Size=UDim2.fromOffset(60,60); icon.BackgroundTransparency=1; icon.Parent=group; Art.resource(icon,"BasicGem")
 local function text(name,value,y,height,max)
  local t=Instance.new("TextLabel"); t.Name=name; t.Text=value; t.Position=UDim2.fromOffset(85,y); t.Size=UDim2.new(1,-108,0,height); t.BackgroundTransparency=1; t.TextColor3=Color3.fromRGB(22,56,91); t.Font=Enum.Font.FredokaOne; t.TextScaled=true; t.TextWrapped=true; t.Parent=group
  local cap=Instance.new("UITextSizeConstraint"); cap.MinTextSize=10; cap.MaxTextSize=max; cap.Parent=t; return t
 end
 local title=text("Title","A BASIC GEM HAS APPEARED!",19,30,19)
 title.TextColor3=Color3.fromRGB(145,86,8)
 local gold=Instance.new("UIGradient"); gold.Rotation=90; gold.Color=ColorSequence.new(Color3.fromRGB(255,228,137),Color3.fromRGB(208,137,38)); gold.Parent=title
 text("Subtitle","ONLY ONE SCAVENGER CAN CLAIM IT",52,22,12)
 local self:any=setmetatable({gui=gui,group=group,seen={},connections={},token=0,destroyed=false,arrivals=0},Controller)
 local function layout()
  local camera=Workspace.CurrentCamera
  local viewport=if camera then camera.ViewportSize else Vector2.new(1280,720)
  local width=math.min(if viewport.X<900 then 340 else 420,math.max(240,viewport.X-356))
  group.Size=UDim2.fromOffset(width,92)
  -- On narrow screens leave the upper-right status console completely visible.
  self.centerX=math.min(viewport.X*.5,(viewport.X-340)*.5)
  group.Position=UDim2.fromOffset(self.centerX,8)
 end
 if Workspace.CurrentCamera then table.insert(self.connections,Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)) end
 layout()
 -- Connect before inspecting so replication between these operations cannot be missed.
 table.insert(self.connections,Workspace.DescendantAdded:Connect(function(child)
  if child.Name=="BasicGem" and child:IsA("BasePart") and child.Parent and child.Parent.Name=="SpecialDrops" then self:observe(child,false) end
 end))
 local hoard=Workspace:FindFirstChild("Hoard"); local drops=if hoard then hoard:FindFirstChild("SpecialDrops") else nil
 if drops then for _,child in drops:GetChildren() do if child.Name=="BasicGem" and child:IsA("BasePart") then self:observe(child,true) end end end
 return self
end
function Controller:observe(gem: BasePart, existing: boolean)
 local function receive()
  local id=gem:GetAttribute("ItemId")
  if id==nil or self.seen[id] or self.destroyed then return end
  self.seen[id]=true
  if not existing then self:announce() end
 end
 if gem:GetAttribute("ItemId")~=nil then receive()
 else
  local connection
  connection=gem:GetAttributeChangedSignal("ItemId"):Connect(function() receive(); if gem:GetAttribute("ItemId")~=nil then connection:Disconnect() end end)
  table.insert(self.connections,connection)
 end
end
function Controller:announce()
 self.token+=1; self.arrivals+=1; local token=self.token
 if self.tween then self.tween:Cancel() end
 self.group.Visible=true; self.group.GroupTransparency=1; self.group.Position=UDim2.fromOffset(self.centerX,-18)
 self.tween=TweenService:Create(self.group,TweenInfo.new(.25),{GroupTransparency=0,Position=UDim2.fromOffset(self.centerX,8)}); self.tween:Play()
 task.delay(3.75,function()
  if self.destroyed or token~=self.token then return end
  self.tween=TweenService:Create(self.group,TweenInfo.new(.25),{GroupTransparency=1}); self.tween:Play()
  task.delay(.25,function() if not self.destroyed and token==self.token then self.group.Visible=false end end)
 end)
end
function Controller:destroy()
 self.destroyed=true; self.token+=1
 if self.tween then self.tween:Cancel() end
 for _,connection in self.connections do connection:Disconnect() end
 self.gui:Destroy()
end
return Controller
