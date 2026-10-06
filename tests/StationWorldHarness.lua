-- Edit-only fixture for runtime station geometry. Builds under ServerStorage and always removes it.
local storage=game:GetService("ServerStorage")
assert(not storage:FindFirstChild("_Stage5StationFixture"),"Existing fixture; abort")
local server=game:GetService("ServerScriptService").Server
local base=getfenv(1)
local cache={}
local function load(mod)
 if cache[mod] then return cache[mod] end
 local fn=assert(loadstring(mod.Source,"="..mod.Name))
 setfenv(fn,setmetatable({script=mod,require=load},{__index=base}))
 local value=fn();cache[mod]=value;return value
end
local temp=Instance.new("Model");temp.Name="_Stage5StationFixture";temp.Parent=storage
local ground=Instance.new("Part");ground.Name="Ground";ground.Size=Vector3.new(64,1,64);ground.CFrame=CFrame.new(0,-.5,0);ground.Anchored=true;ground.Parent=temp
local bench=Instance.new("Part");bench.Name="Workbench";bench.Size=Vector3.new(12,3,6);bench.CFrame=CFrame.new(18,1.5,-18);bench.Anchored=true;bench.Parent=temp
local count=0
local function check(ok,message) assert(ok,message);count+=1 end
local ok,err=pcall(function()
 local world=load(server.StationWorld)
 world.render(temp,{crafted={AFKSorter=true,CollectionBin=true}},123)
 local stations=temp:FindFirstChild("Stations")
 check(stations~=nil,"Stations folder missing")
 check(stations:FindFirstChild("WorkbenchArt")~=nil and #stations.WorkbenchArt:GetDescendants()>=10,"clean workbench art missing")
 local lowest=math.huge
 for _,part in ipairs(stations.WorkbenchArt:GetDescendants()) do if part:IsA("BasePart") then lowest=math.min(lowest,part.Position.Y-part.Size.Y/2) end end
 check(lowest>=-.01,"workbench art must build upward from the plot surface")
 check(stations:FindFirstChild("AFKSorter")~=nil and stations.AFKSorter:FindFirstChild("AfkZone")~=nil and stations.AFKSorter:FindFirstChild("IndicatorAnchor")~=nil,"AFK Sorter hooks missing")
 check(stations:FindFirstChild("CollectionBin")~=nil and stations.CollectionBin:FindFirstChild("InteractionPart")~=nil and stations.CollectionBin:FindFirstChild("IndicatorAnchor")~=nil,"Collection Bin hooks missing")
 check(stations.AFKSorter:GetAttribute("OwnerUserId")==123 and stations.CollectionBin:GetAttribute("OwnerUserId")==123,"station ownership attributes missing")
 check(bench.Transparency==1 and not bench.CanCollide,"placeholder workbench must be replaced by clean art")
 local benchArt=stations.WorkbenchArt
 check(benchArt:FindFirstChild("Drawer") and benchArt:FindFirstChild("TopPlank3") and not benchArt:FindFirstChild("ToolRail") and not benchArt:FindFirstChild("LampShade"),"starter workbench must have defined planks and one drawer without equipment clutter")
 for _,part in benchArt:GetChildren() do if part:IsA("BasePart") then
  check((benchArt:GetAttribute("ArtBase"):ToObjectSpace(part.CFrame)).Y+part.Size.Y/2<=2.01,"starter tabletop must remain clear")
 end end
 check(stations.AFKSorter.PadInset.Material==Enum.Material.SmoothPlastic and stations.AFKSorter:FindFirstChild("StandingMark") and stations.AFKSorter:FindFirstChild("HopperLip") and stations.AFKSorter:FindFirstChild("ConveyorRoller"),"AFK sorter needs a clean pad and basic sorting details")
 check(stations.AFKSorter.OutputBin1.Color~=stations.AFKSorter.OutputBin2.Color,"sorter output bins must be visually distinct")
 local pad=stations.AFKSorter.Pad
 check(pad.Position.Y-pad.Size.Y/2>ground.Position.Y+ground.Size.Y/2+.05,"AFK pad underside must clear plot top to avoid flicker")
 for _,part in ipairs(stations.CollectionBin:GetChildren()) do
  if part.Name=="Corner" then check(part.Position.Y-part.Size.Y/2>ground.Position.Y+ground.Size.Y/2+.05,"bin corner posts must also clear plot top") end
 end
 local binFloor=stations.CollectionBin.Floor
 check(binFloor.Position.Y-binFloor.Size.Y/2>ground.Position.Y+ground.Size.Y/2+.05,"Collection Bin floor underside must clear plot top to avoid flicker")
 check(stations.CollectionBin:FindFirstChild("HingedLid") and stations.CollectionBin:FindFirstChild("InnerFloor") and stations.CollectionBin:FindFirstChild("ClockDial") and stations.CollectionBin:FindFirstChild("FrontHandle"),"starter collection bin details missing")
 for _,name in ipairs({"WorkbenchArt","AFKSorter","CollectionBin"}) do check(stations[name]:GetAttribute("ArtTier")==1,"stations must be simple tier-one starter models") end
 local originalBench=bench.CFrame
 for _,yaw in ipairs({0,90,180,270}) do
  local plotFrame=CFrame.new(200,0,100)*CFrame.Angles(0,math.rad(yaw),0)
  ground.CFrame=plotFrame*CFrame.new(0,-.5,0)
  bench.CFrame=plotFrame*originalBench
  stations.WorkbenchArt:Destroy();world.render(temp,{crafted={AFKSorter=true,CollectionBin=true}},123)
  local art=stations.WorkbenchArt
  local artBase=art:GetAttribute("ArtBase")
  check((artBase.LookVector-plotFrame:VectorToWorldSpace(Vector3.new(-1,0,0))).Magnitude<.001,"workbench front must face plot-local -X")
  local contained=true
  for _,part in ipairs(art:GetDescendants()) do if part:IsA("BasePart") then
   for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
    local p=ground.CFrame:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)/2))
    if math.abs(p.X)>32 or math.abs(p.Z)>32 or p.Y<.49 then contained=false end
   end end end
  end end
  check(contained,"all workbench art must fit above every rotated plot")
 end
 local gemRoot=Instance.new("Part");gemRoot.Name="BasicGem";gemRoot.Size=Vector3.new(3.5,3.5,3.5);gemRoot.Anchored=true;gemRoot:SetAttribute("ItemId","gem-fixture");gemRoot:SetAttribute("SpecialItemId","BasicGem");gemRoot.Parent=temp
 local gem=load(server.BasicGemWorldArt).decorate(gemRoot)
 check(gemRoot.Transparency==1 and gemRoot:GetAttribute("ItemId")=="gem-fixture" and gemRoot:GetAttribute("SpecialItemId")=="BasicGem","gem decoration preserves invisible authoritative root")
 local wedges,bounded,decorative=0,true,true
 for _,part in ipairs(gem:GetChildren()) do if part:IsA("BasePart") then
  if part:IsA("WedgePart") then wedges+=1 end
  decorative=decorative and not part.CanCollide and not part.CanQuery and not part.CanTouch and part:FindFirstChildOfClass("WeldConstraint")~=nil
  for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local p=gemRoot.CFrame:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)/2))
   if math.abs(p.X)>1.75 or math.abs(p.Y)>1.75 or math.abs(p.Z)>1.75 then bounded=false end
  end end end
 end end
 check(wedges>=4 and wedges<=6 and bounded and decorative,"faceted crystal must remain decorative and inside the pickup root")
 check(math.abs(gem.CrystalCore.GemGlow.Brightness-.65)<.0001 and gem.CrystalCore.GemGlow.Range==8 and gem.CrystalCore.GemSparkles.Rate==3 and gem.CrystalCore.GemSparkles.LightEmission<=.35,"gem glow and particles must remain restrained")
 world.clearOwned(temp)
 check(stations:FindFirstChild("WorkbenchArt")~=nil and not stations:FindFirstChild("AFKSorter") and not stations:FindFirstChild("CollectionBin"),"plot release must clear owned buildings only")
end)
temp:Destroy()
assert(ok,err)
return string.format("%d station world checks passed; fixture removed",count)
