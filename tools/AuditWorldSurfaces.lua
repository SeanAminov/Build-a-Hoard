-- Edit-only post-build audit. Run after any floor, path, wall, or scenery change.
-- This catches visual seams that ordinary CanCollide checks miss.
assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")

local hoard=assert(workspace:FindFirstChild("Hoard"),"Missing Hoard")
local base=assert(workspace:FindFirstChild("Baseplate"),"Missing Baseplate")
local plots=assert(hoard:FindFirstChild("Plots"),"Missing plots")
local paths=assert(hoard:FindFirstChild("Paths"),"Missing paths")
local field=assert(hoard:FindFirstChild("Field") and hoard.Field:FindFirstChild("Ground"),"Missing field ground")
local courtyard=assert(hoard:FindFirstChild("Courtyard"),"Missing courtyard")
local checks=0
local function check(value,message) assert(value,message); checks+=1 end
local function hasSurfaceImage(part)
	for _,child in part:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then return true end
	end
	return false
end
local function horizontalBounds(part)
	local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
	for _,x in {-1,1} do for _,z in {-1,1} do
		local p=part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X/2,0,z*part.Size.Z/2))
		minX=math.min(minX,p.X);maxX=math.max(maxX,p.X);minZ=math.min(minZ,p.Z);maxZ=math.max(maxZ,p.Z)
	end end
	return minX,maxX,minZ,maxZ
end

check(base:IsA("BasePart") and base.Anchored and base.CanCollide,"Base must be one stable walking collider")
check(base.Material==Enum.Material.Sand and base.MaterialVariant=="","Base must use unmodified Sand")
check(not hasSurfaceImage(base),"Base has a leftover Texture/Decal/SurfaceAppearance")
check(courtyard:FindFirstChild("BackgroundGrass")==nil and courtyard:FindFirstChild("GrassPatch")==nil,
	"Thin decorative floor panels are forbidden; they cause flicker and seams")

local floorTop=field.Position.Y+field.Size.Y/2
for i=1,4 do
	local plot=assert(plots:FindFirstChild("Plot"..i),"Missing Plot"..i)
	local ground=assert(plot:FindFirstChild("Ground"),"Missing plot Ground")
	local path=assert(paths:FindFirstChild("Path"..i),"Missing Path"..i)
	check(math.abs(ground.Position.Y+ground.Size.Y/2-floorTop)<.001,"Plot top is not flush")
	check(math.abs(path.Position.Y+path.Size.Y/2-floorTop)<.001,"Path top is not flush")
	check(path.Material==Enum.Material.Pebble and path.TopSurface==Enum.SurfaceType.Studs,
		"Path must be grey studded gravel")
	check(path.Anchored and path.CanCollide and not path.CanTouch and not path.CanQuery,
		"Path collision role is wrong")
	check(not hasSurfaceImage(path),"Path has a leftover surface image")
	local pMinX,pMaxX,pMinZ,pMaxZ=horizontalBounds(path)
	local gMinX,gMaxX,gMinZ,gMaxZ=horizontalBounds(ground)
	local fMinX,fMaxX,fMinZ,fMaxZ=horizontalBounds(field)
	local meetsPlot=(math.abs(pMinX-gMaxX)<.002 or math.abs(pMaxX-gMinX)<.002 or
		math.abs(pMinZ-gMaxZ)<.002 or math.abs(pMaxZ-gMinZ)<.002)
	local meetsField=(math.abs(pMinX-fMaxX)<.002 or math.abs(pMaxX-fMinX)<.002 or
		math.abs(pMinZ-fMaxZ)<.002 or math.abs(pMaxZ-fMinZ)<.002)
	check(meetsPlot,"Path does not meet its plot edge")
	check(meetsField,"Path does not meet the field edge")
end

local walls=0
for _,object in courtyard:GetChildren() do
	if object:IsA("BasePart") then
		check(object.Name:match("^GreenWall")~=nil,"Unexpected loose courtyard floor/collider: "..object.Name)
		walls+=1;check(object.Anchored and object.CanCollide and not object.CanTouch and not object.CanQuery,
			"Boundary wall collision role is wrong")
	elseif object:IsA("Model") then
		for _,descendant in object:GetDescendants() do
			if descendant:IsA("BasePart") then
				check(descendant.Anchored and not descendant.CanCollide and not descendant.CanTouch and not descendant.CanQuery,
					"Scenery must be visual-only: "..descendant:GetFullName())
			end
		end
	end
end
check(walls==4,"Expected exactly four boundary walls")
local sky=game:GetService("Lighting"):FindFirstChild("JunkyardSunset")
check(sky and sky:IsA("Sky") and sky.StarCount==0,"Custom junkyard sky is missing")
return string.format("%d live floor, seam, collision, and sky checks passed",checks)
