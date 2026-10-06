--!strict
-- Runtime-only clean toy station models. Geometry lives under each plot and is rebuilt from saved ownership.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage5Config"))

local StationWorld = {}

local WOOD = Color3.fromRGB(232, 139, 48)
local WOOD_DARK = Color3.fromRGB(151, 78, 37)
local BLUE = Color3.fromRGB(31, 139, 224)
local BLUE_DARK = Color3.fromRGB(22, 56, 91)
local STEEL = Color3.fromRGB(142, 177, 204)
local CREAM = Color3.fromRGB(255, 238, 174)
local GREEN = Color3.fromRGB(104, 211, 67)

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collide == true
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function stationFrame(plot: Model, localPosition: Vector3): CFrame
	local ground = plot:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then return ground.CFrame * CFrame.new(localPosition) end
	return plot:GetPivot() * CFrame.new(localPosition)
end

local function ensureStations(plot: Model): Folder
	local existing = plot:FindFirstChild("Stations")
	if existing and existing:IsA("Folder") then return existing end
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Stations"
	folder.Parent = plot
	return folder
end

local function addBand(parent: Instance, frame: CFrame, size: Vector3)
	makePart(parent, "BlueBand", size, frame, BLUE, Enum.Material.SmoothPlastic, false)
end

local function ensureWorkbench(plot: Model, folder: Folder)
	if folder:FindFirstChild("WorkbenchArt") then return end
	local root = plot:FindFirstChild("Workbench")
	if root == nil or not root:IsA("BasePart") then return end
	root.Transparency = 1
	root.CanCollide = false
	local model = Instance.new("Model")
	model.Name = "WorkbenchArt"
	model:SetAttribute("StationId", "Workbench")
	model.Parent = folder
	local base = root.CFrame * CFrame.Angles(0, math.rad(90), 0)
	model:SetAttribute("ArtTier", 1)
	model:SetAttribute("ArtBase", base)
	-- A bare starter bench: defined plank edges and sturdy joinery, with equipment reserved
	-- for future tiers. Keep the original interaction root and front-facing orientation.
	makePart(model, "Top", Vector3.new(12, 0.6, 6), base * CFrame.new(0, 1.4, 0), WOOD_DARK, nil, true)
	for index, z in ipairs({ -2, 0, 2 }) do
		makePart(model, "TopPlank" .. index, Vector3.new(12, 0.3, 1.96),
			base * CFrame.new(0, 1.85, z), if index == 2 then Color3.fromRGB(224, 159, 83) else Color3.fromRGB(235, 174, 99),
			Enum.Material.Wood, true)
	end
	makePart(model, "FrontTrim", Vector3.new(12, 0.35, 0.18), base * CFrame.new(0, 1.2, -3.06), BLUE, nil, false)
	for _, x in ipairs({ -5, 5 }) do
		for _, z in ipairs({ -2.2, 2.2 }) do
			makePart(model, "Leg", Vector3.new(1, 2.6, 1), base * CFrame.new(x, -0.2, z), WOOD_DARK, Enum.Material.Wood, true)
		end
		makePart(model, "SideBrace", Vector3.new(0.55, 0.55, 4.4), base * CFrame.new(x, -0.65, 0), WOOD_DARK, nil, false)
	end
	makePart(model, "DrawerHousing", Vector3.new(3.9, 0.95, 3.4), base * CFrame.new(2.35, 0.55, -0.85), BLUE_DARK, nil, false)
	makePart(model, "Drawer", Vector3.new(3.55, 0.7, 0.18), base * CFrame.new(2.35, 0.55, -2.62), BLUE, nil, false)
	makePart(model, "DrawerHandle", Vector3.new(1.15, 0.16, 0.2), base * CFrame.new(2.35, 0.55, -2.82), CREAM, nil, false)
end

local function createAfkSorter(plot: Model, folder: Folder, ownerUserId: number)
	local model = Instance.new("Model")
	model.Name = "AFKSorter"
	model:SetAttribute("StationId", "AFKSorter")
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("ArtTier", 1)
	model.Parent = folder
	local center = stationFrame(plot, Config.afkZoneLocalPosition)
	-- Ground CFrame is its centre, not its top. Keep the pad underside clear of the studded plot.
	local ground = plot:FindFirstChild("Ground")
	local surface = if ground and ground:IsA("BasePart") then ground.Size.Y / 2 else 0.5
	local floor = stationFrame(plot, Vector3.new(Config.afkZoneLocalPosition.X, surface + 0.25 + Config.stationSurfaceClearance, Config.afkZoneLocalPosition.Z))
	makePart(model, "Pad", Vector3.new(14, 0.5, 14), floor, CREAM, nil, true)
	makePart(model, "PadInset", Vector3.new(12.5, 0.18, 12.5), floor * CFrame.new(0, 0.34, 0), CREAM, nil, false)
	for _, x in ipairs({ -4.4, 4.4 }) do makePart(model, "StandingMark", Vector3.new(0.35, 0.08, 4.5), floor * CFrame.new(x, 0.47, -3), GREEN, nil, false) end
	for _, x in ipairs({ -6.5, 6.5 }) do addBand(model, floor * CFrame.new(x, 0.4, 0), Vector3.new(0.45, 0.8, 14)) end
	local machine = floor * CFrame.new(0, 2.5, 3.8)
	makePart(model, "SorterBody", Vector3.new(7.5, 4.5, 3.2), machine, WOOD, nil, true)
	makePart(model, "Hopper", Vector3.new(6.2, 1.8, 4), machine * CFrame.new(0, 2.8, 0), WOOD, nil, false)
	makePart(model, "HopperLip", Vector3.new(6.6, 0.3, 4.4), machine * CFrame.new(0, 3.8, 0), BLUE, nil, false)
	makePart(model, "HopperOpening", Vector3.new(5.7, 0.05, 3.5), machine * CFrame.new(0, 3.98, 0), BLUE_DARK, nil, false)
	makePart(model, "Conveyor", Vector3.new(6.5, 0.5, 4.5), machine * CFrame.new(0, -1.4, -3.5), BLUE, nil, false)
	for _, z in ipairs({ -2, -3, -4, -5 }) do
		local roller = makePart(model, "ConveyorRoller", Vector3.new(5.8, 0.4, 0.4), machine * CFrame.new(0, -1.1, z), STEEL, nil, false)
		roller.Shape = Enum.PartType.Cylinder
	end
	for index, x in ipairs({ -2, 2 }) do
		makePart(model, "OutputBin" .. index, Vector3.new(3.4, 1.5, 2.8), machine * CFrame.new(x, -2, -5.4), if index == 1 then BLUE else WOOD, nil, false)
		makePart(model, "OutputOpening" .. index, Vector3.new(2.7, 0.05, 2.1), machine * CFrame.new(x, -1.22, -5.4), BLUE_DARK, nil, false)
	end
	local light = makePart(model, "StatusLight", Vector3.new(1, 1, 1), machine * CFrame.new(3.1, 1.5, -1.7), GREEN, Enum.Material.Neon, false)
	light.Shape = Enum.PartType.Ball
	local zone = makePart(model, "AfkZone", Config.afkZoneSize, center, GREEN, nil, false)
	zone.Transparency = 1
	zone.CanQuery = false
	local anchor = makePart(model, "IndicatorAnchor", Vector3.new(0.2, 0.2, 0.2), center * CFrame.new(0, 6, 0), CREAM, nil, false)
	anchor.Transparency = 1
end

local function createCollectionBin(plot: Model, folder: Folder, ownerUserId: number)
	local model = Instance.new("Model")
	model.Name = "CollectionBin"
	model:SetAttribute("StationId", "CollectionBin")
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("ArtTier", 1)
	model.Parent = folder
	local ground = plot:FindFirstChild("Ground")
	local surface = if ground and ground:IsA("BasePart") then ground.Size.Y / 2 else 0.5
	local position = Config.collectionBinLocalPosition
	local base = stationFrame(plot, Vector3.new(position.X, surface + Config.stationSurfaceClearance + position.Y, position.Z))
	makePart(model, "Floor", Vector3.new(10, 0.8, 8), base * CFrame.new(0, -2.1, 0), WOOD_DARK, Enum.Material.WoodPlanks, true)
	makePart(model, "InnerFloor", Vector3.new(8.4, 0.2, 6.4), base * CFrame.new(0, -1.6, 0), CREAM, nil, false)
	makePart(model, "Front", Vector3.new(10, 5, 0.8), base * CFrame.new(0, 0, -3.6), WOOD, Enum.Material.WoodPlanks, true)
	makePart(model, "Back", Vector3.new(10, 5, 0.8), base * CFrame.new(0, 0, 3.6), WOOD, Enum.Material.WoodPlanks, true)
	for _, x in ipairs({ -4.6, 4.6 }) do makePart(model, "Side", Vector3.new(0.8, 5, 6.5), base * CFrame.new(x, 0, 0), WOOD, Enum.Material.WoodPlanks, true) end
	for _, x in ipairs({ -4.8, 4.8 }) do
		for _, z in ipairs({ -3.8, 3.8 }) do makePart(model, "Corner", Vector3.new(0.9, 5.6, 0.9), base * CFrame.new(x, 0.3, z), BLUE, Enum.Material.Metal, false) end
	end
	makePart(model, "HingedLid", Vector3.new(9.8, 0.45, 7), base * CFrame.new(0, 2.6, 3.5) * CFrame.Angles(math.rad(65), 0, 0) * CFrame.new(0, 0, -3.5), BLUE, nil, false)
	makePart(model, "FrontHandle", Vector3.new(2.6, 0.45, 0.5), base * CFrame.new(2.2, 0.9, -4.2), WOOD_DARK, nil, false)
	local dial = makePart(model, "ClockDial", Vector3.new(0.3, 2, 2), base * CFrame.new(-2.1, 0.3, -4.15) * CFrame.Angles(0, math.rad(90), 0), CREAM, nil, false)
	dial.Shape = Enum.PartType.Cylinder
	makePart(model, "ClockHand", Vector3.new(0.15, 0.7, 0.1), base * CFrame.new(-2.1, 0.55, -4.35), BLUE_DARK, nil, false)
	makePart(model, "WoodJunk", Vector3.new(2.4, 1.1, 5), base * CFrame.new(-2.2, 1, 0) * CFrame.Angles(0, 0, math.rad(24)), WOOD_DARK, Enum.Material.Wood, false)
	local can = makePart(model, "CanJunk", Vector3.new(1.5, 2.8, 1.5), base * CFrame.new(1.1, 1, 0.8) * CFrame.Angles(0, 0, math.rad(72)), WOOD, Enum.Material.Metal, false)
	can.Shape = Enum.PartType.Cylinder
	local scrap = makePart(model, "ScrapJunk", Vector3.new(2.5, 1.2, 2.5), base * CFrame.new(2.8, 1.1, -0.8), STEEL, Enum.Material.Metal, false)
	scrap.Shape = Enum.PartType.Ball
	local interaction = makePart(model, "InteractionPart", Vector3.new(11, 7, 9), base * CFrame.new(0, 0.5, 0), CREAM, nil, false)
	interaction.Transparency = 1
	interaction.CanQuery = false
	local anchor = makePart(model, "IndicatorAnchor", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 5.5, 0), CREAM, nil, false)
	anchor.Transparency = 1
end

function StationWorld.render(plot: Model, state: any, ownerUserId: number)
	local folder = ensureStations(plot)
	ensureWorkbench(plot, folder)
	local afk = folder:FindFirstChild("AFKSorter")
	if state.crafted.AFKSorter and afk == nil then createAfkSorter(plot, folder, ownerUserId) elseif not state.crafted.AFKSorter and afk then afk:Destroy() end
	local bin = folder:FindFirstChild("CollectionBin")
	if state.crafted.CollectionBin and bin == nil then createCollectionBin(plot, folder, ownerUserId) elseif not state.crafted.CollectionBin and bin then bin:Destroy() end
end

function StationWorld.clearOwned(plot: Model)
	local folder = ensureStations(plot)
	for _, name in ipairs({ "AFKSorter", "CollectionBin" }) do local child = folder:FindFirstChild(name); if child then child:Destroy() end end
end

return table.freeze(StationWorld)
