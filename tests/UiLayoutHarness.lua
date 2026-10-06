-- Edit-mode fixture: actual client controllers with inert remotes/input; no Play mode.
local SG = game:GetService("StarterGui")
assert(not SG:FindFirstChild("WorkbenchGui"), "Existing GUI; abort preview")
local base=getfenv(1)
local cache={}
local fakePlayers={LocalPlayer={WaitForChild=function(_,name) assert(name=="PlayerGui"); return SG end}}
local fakeInput={InputBegan={Connect=function() return {Disconnect=function() end} end}}
local fakeCamera={ViewportSize=Vector2.new(1440,800),GetPropertyChangedSignal=function() return fakeInput.InputBegan end}
local fakeGame={GetService=function(_,name) if name=="Players" then return fakePlayers elseif name=="Workspace" then return {CurrentCamera=fakeCamera} elseif name=="UserInputService" then return fakeInput else return game:GetService(name) end end}
local loadModule
loadModule=function(mod)
 if cache[mod] then return cache[mod] end
 local fn=assert(loadstring(mod.Source,"="..mod.Name))
 setfenv(fn,setmetatable({script=mod,require=loadModule,game=fakeGame,task=setmetatable({spawn=function() end},{__index=task})},{__index=base}))
 local value=fn();cache[mod]=value;return value
end
local client=game:GetService("StarterPlayer").StarterPlayerScripts.Client
local workbenchIntents={}
local controller=loadModule(client.WorkbenchController).new({FireServer=function(_,action,payload) table.insert(workbenchIntents,{action=action,payload=payload}) end})
controller.gui.Name="_HoardUiPreview"
controller.gui.Enabled=true
controller:render({hoardCounts={Wood=7,Stone=1,ScrapMetal=3,OldCan=5},hoardTotal=16,storageCapacity=60,coins=48.3,passivePerSecond=2.9,crafted={}})

local count=0
local function check(ok,message) assert(ok,message);count+=1 end
local function fits(child,parent)
 local a,b=child.AbsolutePosition-parent.AbsolutePosition,child.AbsoluteSize
 return a.X>=-1 and a.Y>=-1 and a.X+b.X<=parent.AbsoluteSize.X+1 and a.Y+b.Y<=parent.AbsoluteSize.Y+1
end
local overflow
local ok,err=pcall(function()
check(controller.gui:FindFirstChild("Panel",true).Size==UDim2.new(1,-8,1,-8),"workbench does not use full safe screen")
controller:setTab("BUILDINGS");task.wait(.1)
check(controller.recipeCards.AFKSorter.button.Visible and controller.recipeCards.CollectionBin.button.Visible,"Buildings tab must show both early stations")
check(not controller.recipeCards.ScavengerSatchel.button.Visible and controller.buildingsTab.BackgroundColor3==Color3.fromRGB(104,211,67),"Buildings tab must hide upgrades and show selected state")
for sizeIndex,size in ipairs({Vector2.new(1440,740),Vector2.new(1024,600),Vector2.new(844,400)}) do
 fakeCamera.ViewportSize=size
 controller.gui:FindFirstChild("Panel",true).Size=UDim2.fromOffset(size.X,size.Y)
 controller:layout();controller:setTab("INVENTORY");task.wait(.25)
 local inv=controller.inventory
 check(inv.left.AbsoluteSize.X>inv.detail.AbsoluteSize.X,"inventory catalog should be wider than item detail")
 check(inv.hero.Size.Y.Offset<=(if sizeIndex==3 then 150 else 240),"inventory hero art is oversized")
 local itemCard=inv.gridFrame:FindFirstChildWhichIsA("TextButton")
 check(itemCard~=nil and itemCard.AbsoluteSize.Y<=(if sizeIndex==3 then 132 else 154)+1,"inventory card is oversized")
 local expectedColumns=if sizeIndex==1 then 4 elseif sizeIndex==2 then 3 else 2
 check(math.abs(inv.gridFrame.UIGridLayout.CellSize.X.Scale-1/expectedColumns)<0.001,"inventory column count is not responsive")
 for _,name in ipairs({"ItemTitle","HeroArt","Stats","Decrease","Increase","Quantity","QuantityTitle","SellSelected","SellAll"}) do
  check(fits(inv.detail[name],inv.detail),"inventory clipped "..name.." at "..tostring(size))
 end
 check(inv.detail.HeroArt.AbsolutePosition.Y+inv.detail.HeroArt.AbsoluteSize.Y<=inv.detail.QuantityTitle.AbsolutePosition.Y,"art overlaps quantity")
 check(inv.detail.SellAll.AbsolutePosition.Y>=inv.plus.AbsolutePosition.Y+inv.plus.AbsoluteSize.Y,"sale overlaps quantity")
 check(inv.summary:FindFirstChildOfClass("UIStroke").ApplyStrokeMode==Enum.ApplyStrokeMode.Border,"summary text stroke")
 if sizeIndex<=2 then
  check(inv.gridFrame.AbsoluteCanvasSize.Y<=inv.gridFrame.AbsoluteSize.Y+1,"four inventory items should fit without scrolling on desktop")
 end
 controller:setTab("UPGRADES");controller:selectRecipe("BiggerPlot");task.wait(.1)
 check(fits(controller.detailCraft,controller.detail),"craft clipped")
 check(controller.detail.Requirements.AbsoluteSize.Y>0,"requirements collapsed")
 local requirements=controller.detail.Requirements
 local firstRow
 for _,row in pairs(controller.detailRows) do
  if not firstRow or row.row.LayoutOrder<firstRow.LayoutOrder then firstRow=row.row end
  check(fits(row.icon,row.row) and row.icon.AbsoluteSize==Vector2.new(48,48),"requirement icon must fit completely inside its rectangle")
  check(fits(row.name,row.row) and fits(row.count,row.row) and fits(row.status,row.row) and fits(row.track,row.row),"requirement labels and progress bar must fit their row")
  check(row.name.AbsolutePosition.X+row.name.AbsoluteSize.X<=row.count.AbsolutePosition.X+1,"requirement name overlaps owned/needed count")
  check(row.status.AbsolutePosition.Y+row.status.AbsoluteSize.Y<=row.track.AbsolutePosition.Y+1,"requirement status overlaps progress")
 end
 check(firstRow.AbsolutePosition.X-requirements.AbsolutePosition.X>=4,"requirement left stroke touches scroll clipping edge")
 check(firstRow.AbsolutePosition.Y-requirements.AbsolutePosition.Y>=3,"first requirement top stroke touches scroll clipping edge")
 check(controller.detail.AbsoluteSize.X>controller.gridFrame.AbsoluteSize.X,"recipe detail should be wider than upgrade catalog")
 if sizeIndex<=2 then
  check(controller.detail.Requirements.AbsoluteCanvasSize.Y<=controller.detail.Requirements.AbsoluteSize.Y+1,"desktop recipe requirements should fit without scrolling")
 end
end
check(not controller.workshopCategory.Active and controller.workshopCategory.Text=="WORKSHOP II  LOCKED","Workshop II category should begin locked")
for _,id in ipairs({"ReinforcedCarryRack","TrailBoots2","StorageShelves","PortalKey"}) do check(not controller.recipeCards[id].button.Visible,"locked advanced card is visible "..id) end
controller:render({hoardCounts={Wood=40,Stone=30,ScrapMetal=30,OldCan=20},specialItemCounts={BasicGem=1},hoardTotal=120,storageCapacity=120,coins=3000,passivePerSecond=10,crafted={HoardCrate=true,BiggerPlot=true,WorkshopLevel2=true,CarryRack=true,TrailBoots=true}})
controller:setCategory("WORKSHOP_2");task.wait(.1)
check(controller.activeCategory=="WORKSHOP_2" and controller.workshopCategory.Active and controller.workshopCategory.Text=="WORKSHOP II","Workshop II category did not unlock")
for _,id in ipairs({"ReinforcedCarryRack","TrailBoots2","StorageShelves","PortalKey"}) do check(controller.recipeCards[id].button.Visible,"advanced card is hidden "..id) end
check(not controller.recipeCards.CarryRack.button.Visible and not controller.recipeCards.WorkshopLevel2.button.Visible,"starter cards remain visible in Workshop II")
controller:selectRecipe("StorageShelves");task.wait(.1)
check(controller.detailCraft.Text=="CRAFT" and fits(controller.detailCraft,controller.detail),"advanced recipe is not craft-ready and in bounds")
controller:selectRecipe("PortalKey");task.wait(.1)
check(controller.detailRows.BasicGem~=nil and controller.detailRows.BasicGem.count.Text=="1 / 1" and controller.detailCraft.Text=="CRAFT","Portal Key does not show a ready Basic Gem requirement")
-- Configured icons replace the procedural art everywhere UiArt draws them; blank IDs keep the fallback.
local assets=loadModule(client.UiImageAssets)
local wired={}
for _,art in ipairs(controller.gui:GetDescendants()) do
 local id=art:IsA("Frame") and string.match(art.Name,"^(%w+)Art$")
 if id and assets[id]~=nil then
  local icon=art:FindFirstChild("CartoonIcon")
  local good=if assets[id]=="" then icon==nil else #art:GetChildren()==1 and icon~=nil and icon:IsA("ImageLabel") and icon.Image==assets[id] and icon.ScaleType==Enum.ScaleType.Fit
  wired[id]=wired[id]~=false and good
 end
end
for id in pairs(assets) do check(wired[id]==true,"icon not wired "..id) end
for _,grid in ipairs({controller.gui:FindFirstChild("ItemGrid",true),controller.gui:FindFirstChild("UpgradeGrid",true)}) do
 check(grid:IsA("ScrollingFrame"),"catalog must scroll")
 local seed=grid:FindFirstChildWhichIsA("TextButton")
 for i=1,12 do local copy=seed:Clone();copy.LayoutOrder=10+i;copy.Parent=grid end
 task.wait(.1)
 check(grid.CanvasSize.Y.Offset>grid.AbsoluteSize.Y,"additional cards not scrollable")
end
local inv=controller.inventory
inv:render({hoardCounts={Wood=7},hoardTotal=7,storageCapacity=60,passivePerSecond=0})
inv:select("Wood")
inv.quantity=99;inv:renderSelected();check(inv.quantity==7,"quantity exceeds owned")
inv:render({hoardCounts={Wood=0}});check(inv.quantity==0 and not inv.sellAll.Active,"empty sale enabled")

-- Tracking and crafting communicate separate facts through real snapshot transitions.
local Recipes=loadModule(game:GetService("ReplicatedStorage").Shared.RecipeDefinitions)
local targetRecipe=Recipes.get("CollectionBin")
local trackingState={tutorialStep=5,trackedRecipeIds={},hoardCounts={},specialItemCounts={},coins=0,crafted={AFKSorter=true}}
controller:render(trackingState);controller:setTab("BUILDINGS");controller:selectRecipe(targetRecipe.id)
local targetCard=controller.recipeCards[targetRecipe.id]
check(not targetCard.tracked.Visible and targetCard.status.Text=="NEEDS ITEMS" and controller.detailTrack.Text=="TRACK","untracked missing recipe must show needs-items state")
for kind,row in pairs(controller.detailRows) do
 check(string.find(row.status.Text,"NEED",1,true)~=nil and string.find(row.count.Text," / ",1,true)~=nil,"short requirement must disclose both shortage and owned/needed")
end
controller:toggleTracking()
check(#workbenchIntents==1 and workbenchIntents[1].action=="TRACK" and workbenchIntents[1].payload.action=="ADD","Track sends one add intent")
trackingState.trackedRecipeIds={targetRecipe.id};controller:render(trackingState)
check(targetCard.tracked.Visible and targetCard.status.Text=="NEEDS ITEMS" and controller.detailTracked.Visible,"tracking must remain distinct from missing-material state")
check(controller.detailTrack.Text=="TRACKED ✓","tracked action must remain identifiable")
controller:toggleTracking()
check(#workbenchIntents==2 and workbenchIntents[2].payload.action=="REMOVE","tracked action must still allow untracking")
trackingState.hoardCounts=table.clone(targetRecipe.resources);trackingState.coins=targetRecipe.coinCost
controller:render(trackingState)
check(targetCard.tracked.Visible and targetCard.status.Text=="READY TO CRAFT" and controller.detailTracked.Visible and controller.detailState.Text=="READY TO CRAFT","tracked and ready signals must coexist")
check(controller.detailCraft.Active and controller.detailCraft.Text=="CRAFT","ready recipe must enable Craft")
for _,row in pairs(controller.detailRows) do check(row.status.Text=="✓  REQUIREMENT MET","fulfilled requirement needs a check state") end
trackingState.crafted[targetRecipe.id]=true;trackingState.trackedRecipeIds={};controller:render(trackingState)
check(targetCard.status.Text=="CRAFTED" and not targetCard.tracked.Visible and controller.detailState.Text=="CRAFTED","crafted snapshot must retire tracking but retain completion state")
check(not controller.detailCraft.Active and not controller.detailTrack.Active and controller.detailTrack.Text=="CRAFTED","crafted recipe actions must be disabled")
controller:toggleTracking();check(#workbenchIntents==2,"crafted recipe cannot send a Track intent")

-- Stage 3 v3 onboarding: each Workbench step leaves only the intended control available.
controller.gui.Enabled=true
controller:render({tutorialStep=2,tutorialDuplicateResourceId="Wood",trackedRecipeIds={},hoardCounts={Wood=2,Stone=1,ScrapMetal=1,OldCan=1},hoardTotal=5,storageCapacity=60,coins=0,passivePerSecond=1.2,crafted={}})
task.wait(.1)
check(controller.inventory.selectedResourceId=="Wood" and controller.inventory.quantity==1,"tutorial sell should select the duplicate and lock quantity to one")
check(not controller.inventory.sellAll.Active and not controller.inventory.plus.Active and not controller.inventory.minus.Active,"tutorial sell must disable bulk and quantity controls")
check(controller.overlay.root.Visible and controller.overlay.target==controller.inventory.sellSelected,"tutorial sell focus should land on SELL 1")
controller:render({tutorialStep=3,trackedRecipeIds={},hoardCounts={Wood=1,Stone=1,ScrapMetal=1,OldCan=1},hoardTotal=4,storageCapacity=60,coins=5,passivePerSecond=1.05,crafted={}})
task.wait(.1)
check(controller.activeTab=="BUILDINGS" and controller.selectedRecipeId=="AFKSorter" and controller.overlay.target==controller.detailCraft,"tutorial craft should focus AFK Sorter in Buildings")
controller:render({tutorialStep=4,trackedRecipeIds={},hoardCounts={},hoardTotal=0,storageCapacity=60,coins=4,passivePerSecond=0,crafted={AFKSorter=true}})
task.wait(.1)
check(controller.activeTab=="BUILDINGS" and controller.selectedRecipeId=="CollectionBin" and controller.overlay.target==controller.detailTrack,"tutorial tracking should focus Collection Bin Track")
controller:render({tutorialStep=5,trackedRecipeIds={"CollectionBin"},hoardCounts={},hoardTotal=0,storageCapacity=60,coins=4,passivePerSecond=0,crafted={AFKSorter=true}})
check(not controller.overlay.root.Visible,"completed tutorial should remove the focus overlay")

-- Stage 3 v2: the real overflow chooser, an inert remote that records intents, existing resource art.
local fired={}
overflow=loadModule(client.OverflowController).new({FireServer=function(_,action,payload) table.insert(fired,{action=action,payload=payload}) end})
overflow.gui.Name="_HoardOverflowPreview"
local Definitions=loadModule(game:GetService("ReplicatedStorage").Shared.ResourceDefinitions)
local function carryOf(...)
 local items={}
 for index,resourceId in ipairs({...}) do table.insert(items,{itemId="carry"..index,resourceId=resourceId}) end
 return items
end
local function overflowSnapshot(token,revision,carry,free)
 return {pendingOverflow=true,overflowToken=token,revision=revision,carry=carry,hoardTotal=60-free,storageCapacity=60,freeSlots=free,coins=12.5}
end
local five=carryOf("Wood","Stone","ScrapMetal","OldCan","Wood")
overflow:render(overflowSnapshot(1,10,five,3))
task.wait(.15)
check(overflow.gui.Enabled and #overflow.order==5,"overflow panel should open with one card per carried item")
for _,name in ipairs({"Close","Cancel","Dismiss","Minimize"}) do check(overflow.gui:FindFirstChild(name,true)==nil,"overflow must not offer "..name) end
for sizeIndex,size in ipairs({Vector2.new(1440,800),Vector2.new(1024,600),Vector2.new(844,400)}) do
 fakeCamera.ViewportSize=size
 overflow.panel.Size=UDim2.fromOffset(size.X,size.Y)
 overflow:layout();task.wait(.25)
 for _,part in ipairs({overflow.header,overflow.badge,overflow.shelf,overflow.footer,overflow.keepSummary,overflow.sellSummary,overflow.confirm}) do
  check(fits(part,overflow.panel),"overflow element "..part.Name.." outside the safe panel at "..tostring(size))
 end
 check(overflow.footer.AbsolutePosition.Y>=overflow.shelf.AbsolutePosition.Y+overflow.shelf.AbsoluteSize.Y-1,"the action footer must not overlap the shelf")
 check(not overflow.footer:IsDescendantOf(overflow.shelf),"the action footer must never scroll")
 check(overflow.cards.carry1.art.AbsoluteSize.X>=(if sizeIndex==3 then 52 else 64),"resource art below the readable minimum")
 check(overflow.grid.CellSize.Y.Offset==(if sizeIndex==3 then 126 else 150),"card height below the readable minimum")
end
for _,case in ipairs({{800,4},{560,3},{500,2}}) do
 overflow.panel.Size=UDim2.fromOffset(case[1],700);task.wait(.2)
 check(math.abs(overflow.grid.CellSize.X.Scale-1/case[2])<0.001,"overflow shelf should use "..case[2].." columns at panel width "..case[1])
end
fakeCamera.ViewportSize=Vector2.new(1440,800);overflow.panel.Size=UDim2.fromOffset(1440,800);overflow:layout();task.wait(.2)
local startedOnSell=true
for _,itemId in ipairs(overflow.order) do if overflow.selected[itemId] or overflow.cards[itemId].pill.Text=="KEEP" then startedOnSell=false end end
check(startedOnSell and overflow.keepSummary.Text=="KEEP 0 / 3","every card must start on SELL")
for itemId,card in pairs(overflow.cards) do
 local art=card.art:FindFirstChild(card.resourceId.."Art")
 local icon=if art then art:FindFirstChild("CartoonIcon") else nil
 local configured=assets[card.resourceId]~=""
 check(art~=nil and (if configured then icon~=nil and icon.Image==assets[card.resourceId] and icon.ScaleType==Enum.ScaleType.Fit else icon==nil),"overflow card art "..itemId)
end
overflow:toggle("carry1");overflow:toggle("carry3");overflow:toggle("carry5")
local expectedSale=Definitions.get("Stone").sellValue+Definitions.get("OldCan").sellValue
check(overflow.keepSummary.Text=="KEEP 3 / 3","toggling three exact ids must show KEEP 3 / 3")
check(overflow.sellSummary.Text==string.format("SELL 2 • +$%d",expectedSale),"sale total must come from the shipped resource values")
check(overflow.cards.carry1.pill.Text=="KEEP" and overflow.cards.carry1.check.Visible,"a kept card must show the keep badge")
overflow:toggle("carry2")
check(overflow.selected.carry2==false and overflow.keepSummary.Text=="ONLY 3 SPACES LEFT","the keep limit must hold at the free-slot count")
local twelve=carryOf("Wood","Stone","ScrapMetal","OldCan","Wood","Stone","ScrapMetal","OldCan","Wood","Stone","ScrapMetal","OldCan")
overflow:render(overflowSnapshot(2,40,twelve,3));task.wait(.25)
local anyKeep=false
for _,value in pairs(overflow.selected) do if value then anyKeep=true end end
check(#overflow.order==12 and not anyKeep and overflow.keepSummary.Text=="KEEP 0 / 3","a new token must rebuild twelve cards reset to SELL")
for _,size in ipairs({Vector2.new(1440,800),Vector2.new(1024,600),Vector2.new(844,400)}) do
 fakeCamera.ViewportSize=size
 overflow.panel.Size=UDim2.fromOffset(size.X,size.Y)
 overflow:layout();task.wait(.25)
 local lowest=0
 for _,card in pairs(overflow.cards) do
  lowest=math.max(lowest,card.button.AbsolutePosition.Y-overflow.shelf.AbsolutePosition.Y+overflow.shelf.CanvasPosition.Y+card.button.AbsoluteSize.Y)
 end
 check(overflow.shelf.AbsoluteCanvasSize.Y+1>=lowest,"all twelve cards must sit inside the scroll canvas at "..tostring(size))
end
overflow.shelf.CanvasPosition=Vector2.new(0,60);task.wait(.15)
local parked=overflow.shelf.CanvasPosition
overflow:toggle("carry2");overflow:toggle("carry4")
local keptCard=overflow.cards.carry2.button
overflow:render(overflowSnapshot(2,41,twelve,3));task.wait(.2)
check(overflow.cards.carry2.button==keptCard and keptCard.Parent==overflow.shelf,"a same-token snapshot must not rebuild the cards")
check(overflow.selected.carry2 and overflow.selected.carry4 and overflow.keepSummary.Text=="KEEP 2 / 3","a same-token snapshot must keep every choice")
check(parked.Y>0 and overflow.shelf.CanvasPosition==parked,"a same-token snapshot must keep the scroll position")
check(overflow.gui.Enabled,"a same-token snapshot must leave the open panel in place")
local before=#fired
overflow:submit();overflow:submit()
check(#fired==before+1 and fired[#fired].action=="RESOLVE_OVERFLOW","confirm must fire exactly one intent")
local payload=fired[#fired].payload
table.sort(payload)
check(#payload==2 and payload[1]=="carry2" and payload[2]=="carry4","confirm must send exactly the selected item ids")
check(not overflow.confirm.Active and overflow.confirm.Text=="WORKING...","confirm must stay disabled until the server answers")
overflow:toggle("carry6")
check(not overflow.selected.carry6,"cards must not change while a confirmation is in flight")
overflow:render(overflowSnapshot(2,42,twelve,3));task.wait(.15)
check(overflow.confirm.Active,"an authoritative snapshot must release the confirmation")
overflow:render({pendingOverflow=false,revision=43,carry={},hoardTotal=60,storageCapacity=60,freeSlots=0,coins=20})
check(not overflow.gui.Enabled and next(overflow.cards)==nil,"resolved overflow must close and clear the screen")
end)
controller:destroy()
if overflow then overflow:destroy() end
assert(ok,err)
return string.format("%d Edit UI checks passed; workbench, inventory and overflow at desktop, small desktop and landscape; previews removed",count)
