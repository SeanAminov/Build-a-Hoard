-- Edit-only fixture for the Collection Bin overview and overflow chooser.
local SG=game:GetService("StarterGui")
assert(not SG:FindFirstChild("_CollectionBinPreview"),"Existing preview; abort")
local base=getfenv(1)
local cache={}
local fakePlayers={LocalPlayer={WaitForChild=function(_,name) assert(name=="PlayerGui");return SG end}}
local fakeInput={InputBegan={Connect=function() return {Disconnect=function() end} end}}
local fakeGame={GetService=function(_,name) if name=="Players" then return fakePlayers elseif name=="UserInputService" then return fakeInput else return game:GetService(name) end end}
local loadModule
loadModule=function(mod)
 if cache[mod] then return cache[mod] end
 local fn=assert(loadstring(mod.Source,"="..mod.Name))
 setfenv(fn,setmetatable({script=mod,require=loadModule,game=fakeGame},{__index=base}))
 local value=fn();cache[mod]=value;return value
end
local client=game:GetService("StarterPlayer").StarterPlayerScripts.Client
local fired={}
local controller=loadModule(client.CollectionBinController).new({FireServer=function(_,action,payload)table.insert(fired,{action=action,payload=payload})end})
controller.gui.Name="_CollectionBinPreview"
local count=0
local function check(ok,message) assert(ok,message);count+=1 end
local ok,err=pcall(function()
 local counts={Wood=2,Stone=1,ScrapMetal=3,OldCan=1}
 local overview={collectionBinPending=false,collectionBinCounts=counts,collectionBinTotal=7,collectionBinCapacity=12,collectionBinNextAt=1900,serverNow=1000,freeSlots=2}
 controller:render(overview)
 check(not controller.gui.Enabled,"ordinary snapshots do not force the bin menu open")
 controller:open();task.wait(.1)
 check(controller.gui.Enabled and controller.mode=="OVERVIEW" and controller.overview.Visible and not controller.scroll.Visible,"E-key view opens the compact overview mode")
 check(controller.overviewRows.Wood.count.Text=="×2" and controller.overviewRows.Stone.count.Text=="×1" and controller.overviewRows.ScrapMetal.count.Text=="×3" and controller.overviewRows.OldCan.count.Text=="×1","overview lays out every current resource count")
 local overviewTop=controller.overview.AbsolutePosition.Y
 local overviewBottom=overviewTop+controller.overview.AbsoluteSize.Y
 local overviewLeft=controller.overview.AbsolutePosition.X
 local overviewRight=overviewLeft+controller.overview.AbsoluteSize.X
 local firstY=nil
 local cardsFit=true
 for _,row in pairs(controller.overviewRows) do
  local tile=row.tile
  firstY=firstY or tile.AbsolutePosition.Y
  cardsFit=cardsFit and math.abs(tile.AbsolutePosition.Y-firstY)<.01 and tile.AbsolutePosition.X>=overviewLeft+2 and tile.AbsolutePosition.X+tile.AbsoluteSize.X<=overviewRight-2 and tile.AbsolutePosition.Y>=overviewTop+2 and tile.AbsolutePosition.Y+tile.AbsoluteSize.Y<=overviewBottom-2
 end
 check(cardsFit and controller.overview.AbsoluteCanvasSize.Y<=controller.overview.AbsoluteSize.Y,"four current item cards align in one unclipped row without default scrolling")
 local accent=controller.panel.TopAccent
 check(accent.Position==UDim2.fromOffset(10,8) and accent.Size==UDim2.new(1,-20,0,8) and accent:FindFirstChildOfClass("UICorner")~=nil,"top blue accent stays inset and rounded inside the panel")
 check(string.find(controller.timer.Text,"NEXT ITEM IN ",1,true)==1 and controller.capacity.Text=="7 / 12 ITEMS","overview shows the authoritative timer and bin capacity")
 check(controller.summary.Text=="IN BIN 7  •  HOARD SPACE 2" and controller.confirm.Text=="COLLECT 7 ITEMS" and controller.confirm.Active,"overview has a clear collect action")
 controller:collect()
 check(not controller.gui.Enabled and fired[#fired].action=="OPEN_COLLECTION_BIN","Collect closes the overview and asks the server to claim")

 local snapshot={collectionBinPending=true,collectionBinToken=7,collectionBinBatchCounts=counts,collectionBinCounts=counts,collectionBinTotal=7,collectionBinCapacity=12,collectionBinNextAt=1900,serverNow=1000,freeSlots=2}
 controller:render(snapshot);task.wait(.1)
 check(controller.gui.Enabled and controller.mode=="CHOOSER" and controller.token==7 and controller.scroll.Visible and not controller.overview.Visible,"overflow response changes the same panel into its chooser")
 check(controller.rows.Wood~=nil and controller.rows.Stone~=nil and controller.rows.ScrapMetal~=nil and controller.rows.OldCan~=nil,"all current resources need chooser rows")
 check(controller.summary.Text=="STORE 0  •  SELL 0 FOR $0  •  LEAVE 7","every overflow item defaults to leave in bin")
 controller:change("Wood","STORE",1);controller:change("Stone","STORE",1);controller:change("ScrapMetal","STORE",1)
 check(controller.storeCounts.Wood==1 and controller.storeCounts.Stone==1 and controller.storeCounts.ScrapMetal==0,"store choices respect authoritative free slots")
 controller:change("ScrapMetal","SELL",2)
 check(controller.sellCounts.ScrapMetal==2 and string.find(controller.summary.Text,"SELL 2 FOR $30",1,true)~=nil,"sell summary uses resource values")
 controller:render(snapshot)
 check(controller.storeCounts.Wood==1 and controller.storeCounts.Stone==1 and controller.sellCounts.ScrapMetal==2,"same-token passive snapshots preserve choices")
 controller:submit()
 check(fired[#fired].action=="RESOLVE_COLLECTION_BIN" and fired[#fired].payload.token==7 and fired[#fired].payload.storeCounts.Wood==1 and fired[#fired].payload.sellCounts.ScrapMetal==2,"confirm sends exact grouped choices")
 controller:close()
 check(not controller.gui.Enabled and fired[#fired].action=="CANCEL_COLLECTION_BIN","X dismisses overflow without transferring items")
 controller:render(snapshot)
 check(not controller.gui.Enabled,"a delayed same-token snapshot cannot reopen a dismissed chooser")
 snapshot.collectionBinToken=8;snapshot.collectionBinBatchCounts={Wood=1};snapshot.collectionBinCounts={Wood=1};snapshot.collectionBinTotal=1;snapshot.freeSlots=1
 controller:render(snapshot)
 check(controller.storeCounts.Wood==0 and controller.sellCounts.Wood==0 and controller.summary.Text=="STORE 0  •  SELL 0 FOR $0  •  LEAVE 1","new token resets all choices")
 controller:render({collectionBinPending=false,collectionBinCounts={},collectionBinTotal=0,collectionBinCapacity=12,collectionBinNextAt=1900,serverNow=1000,freeSlots=1})
 check(not controller.gui.Enabled and controller.token==nil,"authoritative resolution closes the chooser")
 controller:open();task.wait(.1)
 check(controller.mode=="OVERVIEW" and controller.confirm.Text=="BIN IS EMPTY" and not controller.confirm.Active,"empty bin still shows its timer but disables collection")
 local overviewSeed=controller.overview:FindFirstChild("WoodTile")
 for i=1,8 do local clone=overviewSeed:Clone();clone.Name="FutureTile"..i;clone.LayoutOrder=10+i;clone.Parent=controller.overview end
 task.wait(.1)
 check(controller.overview.AbsoluteCanvasSize.Y>controller.overview.AbsoluteSize.Y,"future overview resources scroll instead of enlarging the popup")
 controller:setMode("CHOOSER");controller.gui.Enabled=true
 local rowSeed=controller.scroll:FindFirstChild("WoodRow")
 for i=1,8 do local clone=rowSeed:Clone();clone.Name="FutureRow"..i;clone.LayoutOrder=10+i;clone.Parent=controller.scroll end
 task.wait(.1)
 check(controller.scroll.AbsoluteCanvasSize.Y>controller.scroll.AbsoluteSize.Y,"future chooser resources remain scrollable")
end)
controller:destroy()
assert(ok,err)
return string.format("%d Collection Bin UI checks passed; preview removed",count)
