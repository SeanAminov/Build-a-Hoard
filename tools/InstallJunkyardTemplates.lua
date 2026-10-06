-- Edit-only. Import the six reviewed packs into ServerStorage._JunkyardImport first.
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local storage = game:GetService("ServerStorage")
local imports = assert(storage:FindFirstChild("_JunkyardImport"), "Missing reviewed import staging")
local history = game:GetService("ChangeHistoryService")
local recording = if not history:IsRecordingInProgress() then history:TryBeginRecording("Install reviewed junkyard templates") else nil
local kit = Instance.new("Folder")
kit.Name = "JunkyardTemplates"
local count = 0
local allowed = {Model=true, Folder=true, Part=true, WedgePart=true, CornerWedgePart=true,
 MeshPart=true, UnionOperation=true, SpecialMesh=true, BlockMesh=true, CylinderMesh=true,
 Decal=true, Texture=true, SurfaceAppearance=true}
local function add(source, name, category, id, creator, maxWidth, height)
 local model = Instance.new("Model"); model.Name=name
 local clone=source:Clone(); clone.Parent=model
 -- Explicit visual-only allowlist. No scripts, seats, lights, constraints or effects survive.
 for _,d in model:GetDescendants() do
  if not allowed[d.ClassName] then d:Destroy()
  else
   for _,tag in d:GetTags() do d:RemoveTag(tag) end
   for key in d:GetAttributes() do d:SetAttribute(key,nil) end
   if d:IsA("BasePart") then
    d.Anchored=true; d.CanCollide=false; d.CanTouch=false; d.CanQuery=false
    d.AssemblyLinearVelocity=Vector3.zero; d.AssemblyAngularVelocity=Vector3.zero
   end
  end
 end
 -- Imported pivots often have tilt/roll even when their parts are upright. Reset only the
 -- pivot frame, without rotating geometry, before measuring or placing the model.
 local initial=model:GetBoundingBox()
 model.WorldPivot=CFrame.new(initial.Position)
 local cf,size=model:GetBoundingBox()
 local scale=if height then height/size.Y else maxWidth/math.max(size.X,size.Z)
 model:ScaleTo(scale)
 cf,size=model:GetBoundingBox()
 model:PivotTo(CFrame.new(-cf.Position)*model:GetPivot())
 if category=="Lamp" then
  for _,part in model:GetDescendants() do if part:IsA("BasePart") then
   local c=part.Color
   if c.G>c.R*1.25 and c.G>c.B*1.15 then part.Color=Color3.fromRGB(244,174,58) end
  end end
 end
 model:SetAttribute("Category",category); model:SetAttribute("SourceAssetId",id)
 model:SetAttribute("Creator",creator); model:SetAttribute("ReviewedVisualOnly",true)
 model.Parent=kit; count+=1
end
local ok,err=xpcall(function()
 local junk=imports.Junk.Model
 add(junk["Morris Mini"],"CarRed","Car",11335168110,"HUNGSTYREST1",15)
 add(junk["Toyota Starlet"],"CarDark","Car",11335168110,"HUNGSTYREST1",14)
 add(junk["Scrapyard Dumpster"],"ScrapDumpster","Dumpster",11335168110,"HUNGSTYREST1",9)
 add(junk["Oil Drum 001f"],"OilDrum","Barrel",11335168110,"HUNGSTYREST1",3.5)
 add(junk["Traffic Barrel"],"TrafficBarrel","Barrel",11335168110,"HUNGSTYREST1",3)
 for _,name in {"engine","door","tire","battery"} do add(junk[name],name,"Scrap",11335168110,"HUNGSTYREST1",3.5) end
 local garbage=imports.Garbage.GarbageProps
 for i=1,3 do add(garbage["DumpsterProp"..i],"Dumpster"..i,"Dumpster",12467888417,"TheECOMaster",8) end
 for i=1,3 do add(garbage["GarbageCluster"..i],"Clutter"..i,"Scrap",12467888417,"TheECOMaster",5) end
 for _,name in {"BasicCrate","LongCrate","XCrate"} do add(imports.Crates.CrateAssets[name],name,"Crate",10555330376,"Blistered_Outlaw",5) end
 for i,tree in imports.Trees.Tree:GetChildren() do add(tree,"Tree"..i,"Tree",10300773179,"BluePart_io",nil,20+i*3) end
 add(imports.Tires,"BagsAndTires","Scrap",16749845322,"maksroblox2010",5)
 add(imports.Lamp,"YardLamp","Lamp",217321138,"WoahItsJeebus",nil,19)
 local old=storage:FindFirstChild(kit.Name); if old then old:Destroy() end
 kit.Parent=storage
 imports:Destroy()
end,debug.traceback)
if not ok then kit:Destroy() end
if recording then history:FinishRecording(recording,if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel) end
assert(ok,err)
return count.." sanitized templates installed; save the place with Ctrl+S"
