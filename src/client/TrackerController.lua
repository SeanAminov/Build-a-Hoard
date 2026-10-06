--!strict
-- A right-side recipe viewer. Local visibility never removes a tracked goal.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipes = require(Shared:WaitForChild("RecipeDefinitions"))
local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
local Specials = require(Shared:WaitForChild("SpecialItemDefinitions"))
local Config = require(Shared:WaitForChild("Stage1Config"))
local Art = require(script.Parent:WaitForChild("UiArt"))
local Tracker = {}; Tracker.__index = Tracker
local INK, SKY, CREAM = Color3.fromRGB(22,56,91), Color3.fromRGB(63,187,230), Color3.fromRGB(255,249,224)
local GREEN = Color3.fromRGB(36,133,66)
local function box(parent, name, pos, size, color)
 local f=Instance.new("Frame"); f.Name=name; f.Position=pos; f.Size=size; f.BackgroundTransparency=if color then 0 else 1; f.BackgroundColor3=color or CREAM; f.BorderSizePixel=0; f.Parent=parent; return f
end
local function round(f,r)
 local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=f
end
local function label(parent,name,pos,size,max)
 local t=Instance.new("TextLabel"); t.Name=name; t.Text=""; t.Position=pos; t.Size=size; t.BackgroundTransparency=1; t.Font=Enum.Font.FredokaOne; t.TextColor3=INK; t.TextScaled=true; t.TextWrapped=true; t.Parent=parent
 local c=Instance.new("UITextSizeConstraint"); c.MinTextSize=9; c.MaxTextSize=max; c.Parent=t; return t
end
local function button(parent,name,value,pos,size)
 local b=Instance.new("TextButton"); b.Name=name; b.Text=value; b.Position=pos; b.Size=size; b.BackgroundColor3=SKY; b.TextColor3=INK; b.Font=Enum.Font.FredokaOne; b.TextSize=16; b.BorderSizePixel=0; b.Parent=parent; round(b,10); return b
end
local function ingredients(recipe)
 local rows,seen={},{}
 for _,id in ipairs(Config.resourceOrder) do if recipe.resources[id] then table.insert(rows,{id=id,needed=recipe.resources[id]}); seen[id]=true end end
 local extra={}; for id in pairs(recipe.resources) do if not seen[id] then table.insert(extra,id) end end; table.sort(extra)
 for _,id in ipairs(extra) do table.insert(rows,{id=id,needed=recipe.resources[id]}) end
 for _,d in ipairs(Specials.ordered()) do if recipe.specialItems and recipe.specialItems[d.id] then table.insert(rows,{id=d.id,needed=recipe.specialItems[d.id],special=true}) end end
 table.insert(rows,{id="Coins",needed=recipe.coinCost}); return rows
end
local function owned(s,r)
 return if r.id=="Coins" then s.coins or 0 elseif r.special then (s.specialItemCounts or {})[r.id] or 0 else (s.hoardCounts or {})[r.id] or 0
end
function Tracker.new(actionRemote)
 local gui=Instance.new("ScreenGui"); gui.Name="RecipeTrackerGui"; gui.ResetOnSpawn=false; gui.DisplayOrder=7; gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets; gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
 local panel=box(gui,"Tracker",UDim2.new(1,-10,0,180),UDim2.fromOffset(340,252),INK); panel.AnchorPoint=Vector2.new(1,0); round(panel,22)
 local rail=box(panel,"BlueRail",UDim2.fromOffset(4,4),UDim2.new(1,-8,1,-8),SKY); round(rail,19)
 local body=box(rail,"Body",UDim2.fromOffset(5,5),UDim2.new(1,-10,1,-10),CREAM); round(body,15)
 local grad=Instance.new("UIGradient"); grad.Rotation=90; grad.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(244,232,201)); grad.Parent=body
 local accent=box(panel,"OrangeAccent",UDim2.fromOffset(-3,54),UDim2.fromOffset(8,34),Color3.fromRGB(248,166,50)); round(accent,4)
 local prev=button(body,"Previous","‹",UDim2.fromOffset(8,7),UDim2.fromOffset(30,28))
 local page=label(body,"Page",UDim2.fromOffset(42,7),UDim2.fromOffset(52,28),14)
 local nextButton=button(body,"Next","›",UDim2.fromOffset(98,7),UDim2.fromOffset(30,28))
 local close=button(body,"Close","",UDim2.new(1,-40,0,6),UDim2.fromOffset(32,32)); close.BackgroundColor3=Color3.fromRGB(228,89,65)
 for _,a in ipairs({45,-45}) do local bar=box(close,"Cross",UDim2.fromScale(.5,.5),UDim2.fromOffset(17,3),Color3.new(1,1,1)); bar.AnchorPoint=Vector2.new(.5,.5); bar.Rotation=a; round(bar,2) end
 local hero=box(body,"RecipeArt",UDim2.fromOffset(10,43),UDim2.fromOffset(60,60))
 local title=label(body,"RecipeName",UDim2.fromOffset(80,43),UDim2.new(1,-94,0,40),21); title.TextXAlignment=Enum.TextXAlignment.Left
 local state=label(body,"CraftState",UDim2.fromOffset(80,84),UDim2.new(1,-94,0,20),12); state.TextXAlignment=Enum.TextXAlignment.Left
 local scroll=Instance.new("ScrollingFrame"); scroll.Name="Requirements"; scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=SKY; scroll.ScrollingDirection=Enum.ScrollingDirection.Y; scroll.Parent=body
 local more=label(body,"More",UDim2.new(0,12,1,-34),UDim2.new(1,-152,0,26),13); more.TextXAlignment=Enum.TextXAlignment.Left
 local expand=button(body,"Expand","EXPAND ↗",UDim2.new(1,-131,1,-35),UDim2.fromOffset(122,28)); expand.TextSize=13
 local hanger=button(gui,"Reopen","‹  GOALS",UDim2.new(1,-4,0,188),UDim2.fromOffset(90,42)); hanger.AnchorPoint=Vector2.new(1,0)
 local self=setmetatable({gui=gui,panel=panel,body=body,hero=hero,title=title,state=state,scroll=scroll,page=page,previous=prev,nextButton=nextButton,expand=expand,more=more,hanger=hanger,closed=false,expanded=false,selectedIndex=1,tracked={},snapshot={},cells={},actionRemote=actionRemote},Tracker)
 prev.Activated:Connect(function() self:cycle(-1) end); nextButton.Activated:Connect(function() self:cycle(1) end)
 close.Activated:Connect(function() self:setClosed(true) end); hanger.Activated:Connect(function() self:setClosed(false) end)
 expand.Activated:Connect(function() self:setExpanded(not self.expanded) end)
 local camera=Workspace.CurrentCamera
 if camera then self.viewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:layout(); self:updateContent() end) end
 self:layout(); return self
end
function Tracker:layout()
 local camera=Workspace.CurrentCamera
 local v=if camera then camera.ViewportSize else Vector2.new(1280,720)
 local width=if self.expanded then math.min(480,math.floor(v.X*.44)) elseif v.X<900 then 300 else 340
 local available=math.max(100,v.Y-218); self.short=available<245
 self.panel.Size=UDim2.fromOffset(math.min(width,v.X-24),math.min(if self.expanded then 450 else 252,available))
 local top=if self.short then 91 else 110
 self.hero.Size=UDim2.fromOffset(if self.short then 48 else 60,if self.short then 48 else 60)
 self.hero.Position=UDim2.fromOffset(10,if self.short then 37 else 43)
 self.title.Position=UDim2.fromOffset(if self.short then 65 else 80,if self.short then 37 else 43)
 self.title.Size=UDim2.new(1,if self.short then -77 else -94,0,if self.short then 30 else 40)
 self.state.Position=UDim2.fromOffset(if self.short then 65 else 80,if self.short then 69 else 84)
 self.state.Size=UDim2.new(1,if self.short then -77 else -94,0,18)
 self.scroll.Position=UDim2.fromOffset(8,top); self.scroll.Size=UDim2.new(1,-16,1,-top-39)
 self.panel.Visible=#self.tracked>0 and not self.closed; self.hanger.Visible=#self.tracked>0 and self.closed
 self.expand.Text=if self.expanded then "SHRINK ↙" else "EXPAND ↗"
end
function Tracker:setClosed(value) self.closed=value; self:layout() end
function Tracker:setExpanded(value) self.expanded=value; self:layout(); self:updateContent() end
function Tracker:cycle(direction)
 if #self.tracked<2 then return end
 self.selectedIndex=((self.selectedIndex-1+direction)%#self.tracked)+1; self.selectedId=self.tracked[self.selectedIndex]; self:updateContent()
end
function Tracker:updateContent()
 local recipe=if self.selectedId then Recipes.get(self.selectedId) else nil; if not recipe then return end
 local rows=ingredients(recipe); local width=self.panel.Size.X.Offset-34
 local key=recipe.id..tostring(self.expanded)..tostring(width)..tostring(self.short)
 if key~=self.viewKey then
  self.viewKey=key; self.hero:ClearAllChildren(); Art.recipe(self.hero,recipe.id)
  self.scroll:ClearAllChildren(); self.scroll.CanvasPosition=Vector2.zero; self.cells={}
  local count=if self.expanded then #rows else math.min(5,#rows)
  local columns=if self.expanded then 2 else math.max(1,count)
  local cw=math.floor((width-6)/columns); local ch=if self.expanded then 80 elseif self.short then 65 else 82
  for i=1,count do
   local row=rows[i]; local cell=box(self.scroll,row.id.."Chip",UDim2.fromOffset(((i-1)%columns)*cw,math.floor((i-1)/columns)*ch),UDim2.fromOffset(cw-4,ch-4))
   local n=if self.expanded then 48 elseif self.short then 36 else 42
   local icon=box(cell,"Icon",if self.expanded then UDim2.fromOffset(2,8) else UDim2.new(.5,-n/2,0,3),UDim2.fromOffset(n,n))
   if row.id=="Coins" then Art.coin(icon) else Art.resource(icon,row.id) end
   local countLabel
   if self.expanded then
    local d=Specials.get(row.id) or Resources.get(row.id)
    local name=label(cell,"Name",UDim2.fromOffset(54,9),UDim2.new(1,-58,0,31),14); name.Text=if d then d.displayName else row.id; name.TextXAlignment=Enum.TextXAlignment.Left
    countLabel=label(cell,"Count",UDim2.fromOffset(54,42),UDim2.new(1,-58,0,23),15); countLabel.TextXAlignment=Enum.TextXAlignment.Left
    box(cell,"Divider",UDim2.new(0,4,1,-2),UDim2.new(1,-8,0,1),Color3.fromRGB(199,219,222))
   else countLabel=label(cell,"Count",UDim2.fromOffset(0,n+5),UDim2.new(1,0,0,22),13) end
   table.insert(self.cells,{row=row,label=countLabel})
  end
  self.scroll.CanvasSize=UDim2.fromOffset(0,math.ceil(count/columns)*ch)
 end
 self.title.Text=recipe.displayName; self.page.Text=string.format("%d / %d",self.selectedIndex,#self.tracked)
 self.previous.Visible=#self.tracked>1; self.nextButton.Visible=#self.tracked>1
 local crafted=self.snapshot.crafted or {}
 local ready=not crafted[recipe.id] and (not recipe.requires or crafted[recipe.requires]) and (not recipe.categoryRequires or crafted[recipe.categoryRequires])
 for _,row in ipairs(rows) do if owned(self.snapshot,row)<row.needed then ready=false end end
 self.state.Text=if ready then "✓ READY TO CRAFT" else "GATHER MATERIALS"; self.state.TextColor3=if ready then GREEN else Color3.fromRGB(133,94,42)
 self.more.Text=if not self.expanded and #rows>5 then string.format("… +%d MORE",#rows-5) else "TRACKED"
 for _,cell in ipairs(self.cells) do local amount=owned(self.snapshot,cell.row); cell.label.Text=string.format("%g / %g",if cell.row.id=="Coins" then math.floor(amount) else amount,cell.row.needed); cell.label.TextColor3=if amount>=cell.row.needed then GREEN else INK end
end
function Tracker:render(snapshot)
 self.snapshot=snapshot; self.tracked={}
 for _,id in ipairs(snapshot.trackedRecipeIds or {}) do if Recipes.get(id) then table.insert(self.tracked,id) end end
 self.selectedIndex=table.find(self.tracked,self.selectedId) or math.clamp(self.selectedIndex,1,math.max(1,#self.tracked))
 self.selectedId=self.tracked[self.selectedIndex]; self:layout(); self:updateContent()
end
function Tracker:destroy() if self.viewportConnection then self.viewportConnection:Disconnect() end; self.gui:Destroy() end
return Tracker
