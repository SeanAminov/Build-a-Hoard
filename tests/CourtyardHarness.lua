-- Edit-only: actual geometry, stable seed, sanitation, fixed footprints and repeatability.
local env=getfenv(1); local cache={}
local function fresh(mod)
 if cache[mod] then return cache[mod] end
 local fn=assert(loadstring(mod.Source,"="..mod.Name))
 setfenv(fn,setmetatable({script=mod,require=fresh},{__index=env}))
 local value=fn(); cache[mod]=value; return value
end
local art=fresh(game.ServerScriptService.Server.CourtyardWorld)
local root=Instance.new("Folder"); root.Name="_JunkyardFixture"; root.Parent=game.ServerStorage
local count=0
local function check(v,m) assert(v,m); count+=1 end
local function part(parent,name,size,cf)
 local p=Instance.new("Part"); p.Name=name;p.Size=size;p.CFrame=cf;p.Anchored=true;p.Parent=parent;return p
end
local ok,err=xpcall(function()
 local base=part(root,"Baseplate",Vector3.new(500,1,500),CFrame.new(0,-1.5,0))
 local oldTexture=Instance.new("Texture");oldTexture.Texture="rbxassetid://6372755229";oldTexture.Parent=base
 local hoard=Instance.new("Model");hoard.Name="Hoard";hoard.Parent=root
 local field=Instance.new("Model");field.Name="Field";field.Parent=hoard
 local fg=part(field,"Ground",Vector3.new(132,1,108),CFrame.new(0,-.5,0))
 local plots=Instance.new("Folder");plots.Name="Plots";plots.Parent=hoard
 local paths=Instance.new("Folder");paths.Name="Paths";paths.Parent=hoard
 for i,row in {{0,110,0},{120,0,90},{0,-110,180},{-120,0,-90}} do
  local plot=Instance.new("Model");plot.Name="Plot"..i;plot.Parent=plots
  local cf=CFrame.new(row[1],-.5,row[2])*CFrame.Angles(0,math.rad(row[3]),0)
  part(plot,"Ground",Vector3.new(80,1,80),cf)
  part(paths,"Path"..i,Vector3.new(14,1,24),cf*CFrame.new(0,0,-44))
 end
 local total=art.render(root)
 check(base.Size.X==306 and base.Size.Z==306,"shared floor fits boundary")
 check(base.Material==Enum.Material.Sand and base:FindFirstChildWhichIsA("Texture")==nil,"sand removes inherited checker texture")
 check(base.CanCollide and base.Anchored,"continuous base supports walking")
 check(hoard.Courtyard:FindFirstChild("BackgroundGrass")==nil and hoard.Courtyard:FindFirstChild("GrassPatch")==nil,"no overlapping ground overlay panels")
 for i=1,4 do
  local ground=plots["Plot"..i].Ground;local path=paths["Path"..i]
  local start,finish=art.pathSpan(ground,fg)
  local near=ground.CFrame:PointToObjectSpace(path.CFrame:PointToWorldSpace(Vector3.new(0,0,path.Size.Z/2)))
  local far=fg.CFrame:PointToObjectSpace(path.CFrame:PointToWorldSpace(Vector3.new(0,0,-path.Size.Z/2)))
  check(math.abs(near.Z+ground.Size.Z/2)<.001,"path meets plot edge without gap or overlap")
  check(math.abs(math.abs(far.X)-fg.Size.X/2)<.001 or math.abs(math.abs(far.Z)-fg.Size.Z/2)<.001,"path meets actual field edge")
  check(math.abs(path.Position.Y+path.Size.Y/2)<.001,"walkway top flush with plot and field")
  check(path.Material==Enum.Material.Pebble and path.TopSurface==Enum.SurfaceType.Studs,"grey gravel uses studded top")
  check(path.Anchored and path.CanCollide and not path.CanTouch,"path has stable walking collision")
  check(finish>start and math.abs(path.Size.Z-(finish-start))<.001,"path length matches real gap")
 end
 for _,plot in plots:GetChildren() do check(plot.Ground.Size==Vector3.new(64,1,64),"legacy expanded plots become fixed size") end
 local first={};local categories={};local walls=0
 for _,obj in hoard.Courtyard:GetChildren() do
  if obj:IsA("Model") then
   local cf,size=obj:GetBoundingBox()
   check(art.isClear(plots,fg,cf,size),"scenery must clear plots and field")
   for _,x in {-1,1} do for _,z in {-1,1} do
    local p=cf:PointToWorldSpace(Vector3.new(x*size.X/2,0,z*size.Z/2))
    check(math.abs(p.X)<150 and math.abs(p.Z)<150,"prop bounds stay inside walls")
   end end
   local q=obj:GetAttribute("Quadrant");categories[q]=categories[q] or {};categories[q][obj:GetAttribute("Category")]=true
   table.insert(first,obj.Name..tostring(obj:GetPivot()))
   for _,d in obj:GetDescendants() do
    check(not d:IsA("LuaSourceContainer") and not d:IsA("Constraint") and not d:IsA("Seat"),"visuals have no executable or vehicle content")
    if d:IsA("BasePart") then check(d.Anchored and not d.CanCollide and not d.CanTouch and not d.CanQuery,"decoration is inert") end
   end
  elseif obj.Name:match("^GreenWall") then walls+=1;check(obj.CanCollide and obj.Anchored,"walls form physical barrier") end
 end
 check(walls==4,"four enclosing walls")
 for q=1,4 do for _,category in {"Car","Tree","Dumpster","Crate","Lamp","Barrel","Scrap"} do
  check(categories[q] and categories[q][category],"every quadrant has "..category)
 end end
 check(hoard.Courtyard:GetAttribute("PlacedProps")==48,"all intended mixed props fit safely")
 check(art.render(root)==total,"rebuild count stable")
 local second={};for _,obj in hoard.Courtyard:GetChildren() do if obj:IsA("Model") then table.insert(second,obj.Name..tostring(obj:GetPivot())) end end
 check(table.concat(first,"|")==table.concat(second,"|"),"seed preserves exact placement across rebuilds")
end,debug.traceback)
root:Destroy();assert(ok,err)
return count.." junkyard geometry and sanitation checks passed"
