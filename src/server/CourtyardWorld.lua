--!strict
-- Compact shared courtyard; deterministic reviewed scenery protects fixed plots and routes.
local Stage2 = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Stage2Config"))
local Courtyard = {}
local SAND = Color3.fromRGB(197, 175, 132)
local PATH = Color3.fromRGB(125, 124, 119)

-- Conservative rectangle overlap in each plot's local space, including every candidate corner.
function Courtyard.isClear(plots: Instance, field: BasePart, cf: CFrame, size: Vector3): boolean
	local function overlaps(ground: BasePart, halfX: number, halfZ: number): boolean
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, x in ipairs({-1, 1}) do for _, z in ipairs({-1, 1}) do
			local p = ground.CFrame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(x * size.X / 2, 0, z * size.Z / 2)))
			minX = math.min(minX, p.X); maxX = math.max(maxX, p.X)
			minZ = math.min(minZ, p.Z); maxZ = math.max(maxZ, p.Z)
		end end
		return minX < halfX and maxX > -halfX and minZ < halfZ and maxZ > -halfZ
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local ground = plot:FindFirstChild("Ground")
		if ground and ground:IsA("BasePart") then
			local half = math.max(Stage2.expandedGroundSize, ground.Size.X, ground.Size.Z) / 2 + 6
			if overlaps(ground, half, half) then return false end
		end
	end
	return not overlaps(field, field.Size.X / 2 + 4, field.Size.Z / 2 + 4)
end

local function smooth(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Smooth; part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
end

local function removeSurfaceImages(part: BasePart)
	for _,child in part:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then child:Destroy() end
	end
	part.MaterialVariant = ""
end

-- Intersect the plot's inward centerline with the actual field rectangle in field-local space.
function Courtyard.pathSpan(ground: BasePart, field: BasePart): (number, number)
	local origin=field.CFrame:PointToObjectSpace(ground.Position)
	local direction=field.CFrame:VectorToObjectSpace(ground.CFrame.LookVector)
	local enter,leave=-math.huge,math.huge
	for _,axis in {"X","Z"} do
		local o,d,half=origin[axis],direction[axis],field.Size[axis]/2
		if math.abs(d)<1e-6 then assert(math.abs(o)<=half,"Path centerline misses field")
		else
			local a,b=(-half-o)/d,(half-o)/d
			enter=math.max(enter,math.min(a,b)); leave=math.min(leave,math.max(a,b))
		end
	end
	local start=ground.Size.Z/2
	assert(enter<=leave and enter>start,"Field must lie ahead of plot approach")
	return start,enter
end

function Courtyard.render(root: Instance): number
	local hoard = root:FindFirstChild("Hoard")
	local base = root:FindFirstChild("Baseplate")
	assert(hoard and base and base:IsA("BasePart"), "Courtyard requires Hoard and Baseplate")
	local plots = hoard:FindFirstChild("Plots")
	local fieldModel = hoard:FindFirstChild("Field")
	local field = if fieldModel then fieldModel:FindFirstChild("Ground") else nil
	assert(plots and field and field:IsA("BasePart"), "Courtyard requires plots and field")
	local old = hoard:FindFirstChild("Courtyard")
	if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name = "Courtyard"; folder.Parent = hoard
	base.Color = SAND; smooth(base)
	removeSurfaceImages(base); base.Material=Enum.Material.Sand
	base.Anchored=true; base.CanCollide=true
	base.Size = Vector3.new(306, base.Size.Y, 306)
	base.Position = Vector3.new(0, base.Position.Y, 0)
	for _,plot in plots:GetChildren() do
		local ground=plot:FindFirstChild("Ground")
		if ground and ground:IsA("BasePart") then
			ground.Size=Vector3.new(Stage2.baseGroundSize,ground.Size.Y,Stage2.baseGroundSize)
			ground:SetAttribute("BaseSize",Stage2.baseGroundSize); ground:SetAttribute("ExpandedSize",Stage2.baseGroundSize)
			ground.Color=Color3.fromRGB(207,191,151)
		end
	end
	-- Keep the shared floor below every plot/field surface, with no coplanar flicker.
	local top = field.Position.Y + field.Size.Y / 2
	for _, plot in ipairs(plots:GetChildren()) do
		local ground = plot:FindFirstChild("Ground")
		if ground and ground:IsA("BasePart") then top = math.min(top, ground.Position.Y + ground.Size.Y / 2) end
	end
	local sandTop = top - 0.18
	base.Position = Vector3.new(base.Position.X, sandTop - base.Size.Y / 2, base.Position.Z)
	local paths = hoard:FindFirstChild("Paths")
	if paths then
		for _, path in ipairs(paths:GetChildren()) do
			if path:IsA("BasePart") then
				local plot = plots:FindFirstChild("Plot" .. (string.match(path.Name, "%d+$") or ""))
				local ground = if plot then plot:FindFirstChild("Ground") else nil
				if ground and ground:IsA("BasePart") then
					local start,finish = Courtyard.pathSpan(ground,field)
					path.Size = Vector3.new(14, 0.18, finish-start)
					local cf = ground.CFrame * CFrame.new(0, 0, -(start+finish)/2)
					path.CFrame = CFrame.new(cf.Position.X, top-path.Size.Y/2, cf.Position.Z) * cf.Rotation
				end
				path.Color = PATH; smooth(path); removeSurfaceImages(path)
				path.Material=Enum.Material.Pebble; path.TopSurface=Enum.SurfaceType.Studs
				path.Anchored=true; path.CanCollide=true; path.CanTouch=false; path.CanQuery=false
			end
		end
	end
	-- Walls own collision. Imported decoration never participates in physics or targeting.
	for i,row in ipairs({{0,153,306,2},{0,-153,306,2},{153,0,2,306},{-153,0,2,306}}) do
		local wall=Instance.new("Part"); wall.Name="GreenWall"..i
		wall.Size=Vector3.new(row[3],28,row[4]); wall.Position=Vector3.new(row[1],sandTop+14,row[2])
		wall.Color=Color3.fromRGB(81,143,65); wall.Material=Enum.Material.Plastic
		wall.Anchored=true; wall.CanCollide=true; wall.CanTouch=false; wall.CanQuery=false
		wall.TopSurface=Enum.SurfaceType.Studs
		wall.FrontSurface=Enum.SurfaceType.Studs; wall.BackSurface=Enum.SurfaceType.Studs
		wall.LeftSurface=Enum.SurfaceType.Studs; wall.RightSurface=Enum.SurfaceType.Studs
		wall.Parent=folder
	end
	local kit=game:GetService("ServerStorage"):FindFirstChild("JunkyardTemplates")
	if not kit then warn("JunkyardTemplates missing: run tools/InstallJunkyardTemplates.lua and save the place"); return #folder:GetChildren() end
	local pool={}
	local templates=kit:GetChildren()
	table.sort(templates,function(a,b) return a.Name<b.Name end)
	for _,model in templates do
		local category=model:GetAttribute("Category")
		if model:IsA("Model") and type(category)=="string" then
			pool[category]=pool[category] or {}; table.insert(pool[category],model)
		end
	end
	local rng=Random.new(9172026)
	local placed={}
	local function bounds(cf,size)
		local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
		for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
			local v=cf:PointToWorldSpace(size*Vector3.new(x,y,z)/2); lo=lo:Min(v); hi=hi:Max(v)
		end end end
		return lo,hi
	end
	local function place(category,x,z,quadrant)
		local choices=pool[category]; if not choices or #choices==0 then return false end
		local model=choices[rng:NextInteger(1,#choices)]:Clone()
		model:ScaleTo(model:GetScale()*rng:NextNumber(.88,1.12))
		model:PivotTo(CFrame.new(x,0,z)*CFrame.Angles(0,rng:NextNumber(-math.pi,math.pi),0))
		local cf,size=model:GetBoundingBox(); local lo,hi=bounds(cf,size)
		model:PivotTo(model:GetPivot()+Vector3.new(0,sandTop+.04-lo.Y,0))
		cf,size=model:GetBoundingBox(); lo,hi=bounds(cf,size)
		local clear=lo.X>-150 and hi.X<150 and lo.Z>-150 and hi.Z<150 and Courtyard.isClear(plots,field,cf,size)
		for _,other in placed do
			if lo.X<other.hi.X+2 and hi.X>other.lo.X-2 and lo.Z<other.hi.Z+2 and hi.Z>other.lo.Z-2 then clear=false; break end
		end
		if paths then for _,path in paths:GetChildren() do
			if path:IsA("BasePart") then
				local a,b=bounds(path.CFrame,path.Size)
				if lo.X<b.X+3 and hi.X>a.X-3 and lo.Z<b.Z+3 and hi.Z>a.Z-3 then clear=false end
			end
		end end
		if not clear then model:Destroy(); return false end
		for _,part in model:GetDescendants() do if part:IsA("BasePart") then
			part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
		end end
		model:SetAttribute("Quadrant",quadrant); model.Parent=folder
		table.insert(placed,{lo=lo,hi=hi})
		return true
	end
	-- Each region shares the same shuffled categories: variety is guaranteed, locations are random.
	for quadrant,sign in ipairs({{1,1},{-1,1},{1,-1},{-1,-1}}) do
		local categories={"Car","Tree","Dumpster","Crate","Lamp","Barrel","Scrap","Crate","Scrap","Barrel","Scrap","Scrap"}
		for i=#categories,2,-1 do local j=rng:NextInteger(1,i); categories[i],categories[j]=categories[j],categories[i] end
		for _,category in categories do
			local success=false
			for _=1,120 do
				if place(category,sign[1]*rng:NextNumber(48,143),sign[2]*rng:NextNumber(62,143),quadrant) then success=true; break end
			end
			if not success then warn("No safe scenery position for "..category.." in quadrant "..quadrant) end
		end
	end
	folder:SetAttribute("Seed",9172026); folder:SetAttribute("PlacedProps",#placed)
	if root==workspace then
		local lighting=game:GetService("Lighting")
		-- Only the reviewed six image references are used. No imported model/code is retained.
		-- Free sunset source: 113093661966209, StarFusionVeno_m.
		local sky=lighting:FindFirstChild("JunkyardSunset")
		if not sky or not sky:IsA("Sky") then
			for _,child in lighting:GetChildren() do if child:IsA("Sky") then child:Destroy() end end
			sky=Instance.new("Sky"); sky.Name="JunkyardSunset"; sky.Parent=lighting
		end
		sky.SkyboxBk="rbxassetid://1517742875"; sky.SkyboxFt="rbxassetid://1517742875"
		sky.SkyboxLf="rbxassetid://1517742875"; sky.SkyboxRt="rbxassetid://1517742875"
		sky.SkyboxDn="rbxassetid://1517742869"; sky.SkyboxUp="rbxassetid://1517742871"
		sky.StarCount=0; sky.CelestialBodiesShown=false
		lighting.ClockTime=16.2; lighting.Brightness=2.25; lighting.ExposureCompensation=-.05
		lighting.Ambient=Color3.fromRGB(154,147,136); lighting.OutdoorAmbient=Color3.fromRGB(181,170,151)
		local atmosphere=lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
		atmosphere.Color=Color3.fromRGB(255,239,216); atmosphere.Decay=Color3.fromRGB(214,190,163)
		atmosphere.Density=.12; atmosphere.Haze=.3; atmosphere.Glare=.05; atmosphere.Parent=lighting
		local tint=lighting:FindFirstChild("JunkyardWarmth") or Instance.new("ColorCorrectionEffect")
		tint.Name="JunkyardWarmth"; tint.TintColor=Color3.fromRGB(255,252,246); tint.Saturation=.015; tint.Parent=lighting
		local rays=lighting:FindFirstChildOfClass("SunRaysEffect")
		if rays then rays.Intensity=.025; rays.Spread=.6 end
	end
	return #folder:GetChildren()
end
return table.freeze(Courtyard)
