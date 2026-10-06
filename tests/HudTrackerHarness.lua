-- Edit-only real-controller fixture. No simulated input or live remotes.
local SG=game:GetService("StarterGui")
local base=getfenv(1); local cache={}; local callbacks={}
local camera={ViewportSize=Vector2.new(1440,800),GetPropertyChangedSignal=function() return {Connect=function(_,fn) table.insert(callbacks,fn);return {Disconnect=function()end} end} end}
local fakeGame={GetService=function(_,name)
 if name=="Players" then return {LocalPlayer={WaitForChild=function() return SG end}}
 elseif name=="Workspace" then return {CurrentCamera=camera}
 else return game:GetService(name) end
end}
local load
load=function(mod)
 if cache[mod] then return cache[mod] end
 local fn=assert(loadstring(mod.Source,"="..mod.Name));setfenv(fn,setmetatable({script=mod,require=load,game=fakeGame},{__index=base}))
 local v=fn();cache[mod]=v;return v
end
local client=game.StarterPlayer.StarterPlayerScripts.Client
local sent=0
local tracker=load(client.TrackerController).new({FireServer=function()sent+=1 end})
local hud=load(client.HudController).new()
local n=0;local function check(v,msg)assert(v,msg);n+=1 end
local ok,err=pcall(function()
 local s={trackedRecipeIds={"CarryRack","TrailBoots","JunkyardPortalKey"},crafted={ScavengerSatchel=true},hoardCounts={},specialItemCounts={},coins=12}
 -- Use the actual area-key id rather than assume a display name.
 local recipes=load(game.ReplicatedStorage.Shared.RecipeDefinitions)
 local key
 for _,r in recipes.ordered() do if r.resultKind=="AREA_UNLOCK" then key=r.id end end
 assert(key);s.trackedRecipeIds[3]=key
 tracker:render(s);task.wait(.1)
 check(tracker.selectedId=="CarryRack" and tracker.page.Text=="1 / 3","first recipe shown")
 check(#tracker.cells==3,"only selected recipe ingredients appear")
 tracker:cycle(-1);check(tracker.selectedId==key and tracker.page.Text=="3 / 3","arrows wrap")
 check(#tracker.cells==5 and tracker.more.Text=="… +1 MORE","compact caps requirements at five")
 tracker:setExpanded(true);task.wait(.1)
 check(#tracker.cells==6,"expanded includes all requirements")
 check(tracker.panel.Size.X.Offset<=480 and tracker.panel.Position.X.Scale==1,"expanded stays on right")
 check(tracker.panel.AnchorPoint.X==1 and tracker.panel.Size.X.Offset+10<camera.ViewportSize.X/2,"expanded leaves centre visible")
 check(tracker.panel.Position.Y.Offset>=180,"tracker stays below money/status")
 tracker.scroll.CanvasPosition=Vector2.new(0,10)
 local cell=tracker.cells[1].label
 s.coins=13;tracker:render(s)
 check(tracker.cells[1].label==cell and tracker.selectedId==key and tracker.expanded,"snapshots preserve selected view and cells")
 tracker:setClosed(true);tracker:render(s)
 check(not tracker.panel.Visible and tracker.hanger.Visible,"dismissal survives snapshots")
 tracker:setClosed(false);check(tracker.panel.Visible and not tracker.hanger.Visible,"hanger reopens")
 check(sent==0,"view controls never remove/focus authoritative goals")
 s.trackedRecipeIds={"CarryRack","TrailBoots"};tracker:render(s)
 check(tracker.selectedId=="TrailBoots","removing selected recipe picks surviving neighbour")
 s.trackedRecipeIds={};tracker:render(s);check(not tracker.panel.Visible and not tracker.hanger.Visible,"empty tracker is hidden")
 s.trackedRecipeIds={key};tracker:render(s);check(not tracker.previous.Visible and not tracker.nextButton.Visible,"single goal hides arrows")
 camera.ViewportSize=Vector2.new(844,400);for _,cb in callbacks do cb() end
 check(tracker.panel.Size.X.Offset<=camera.ViewportSize.X*.44 and tracker.panel.Size.Y.Offset<=182,"short expanded panel stays bounded")
 check(tracker.scroll.CanvasSize.Y.Offset>tracker.scroll.Size.Y.Offset,"large recipes remain scrollable on short screens")
 task.wait(.1)
 tracker.scroll.CanvasPosition=Vector2.new(0,35);task.wait()
 local scrollBefore=tracker.scroll.CanvasPosition
 s.coins=14;tracker:render(s);task.wait()
 check(tracker.scroll.CanvasPosition==scrollBefore,"income snapshots preserve expanded scroll position")
 hud:render({carry=table.create(12,{}),capacity=12,hoardTotal=120,storageCapacity=120,coins=999999.9,passivePerSecond=999.9},"OWNER",nil)
 task.wait(.1)
 local chrome=hud.gui.HudChrome
 check(chrome.Size==UDim2.fromOffset(320,156),"HUD footprint")
 check(chrome.MoneyChip.CoinIcon.Size.X.Offset==60 and chrome.StatusPanel.CarryChip.CarryIcon.Size.X.Offset==46,"larger illustrations")
 check(hud.money.TextFits and hud.income.TextFits and hud.carry.TextFits and hud.hoard.TextFits,"largest amounts fit HUD")
 check(hud.feedback.Text=="","no default Label text")
end)
tracker:destroy();hud.gui:Destroy();assert(ok,err)
return string.format("%d tracker modes/HUD checks passed; fixtures removed",n)
