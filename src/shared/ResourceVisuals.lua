--!strict
-- One small, reusable toy silhouette for field loot, carried loot and the bounded hoard.
-- Authoritative roots retain their position, dimensions and attributes; art is disposable.

local Resources = require(script.Parent:WaitForChild("ResourceDefinitions"))

export type Piece = { name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, className: string?, material: Enum.Material?, meshType: Enum.MeshType?, meshScale: Vector3? }
export type Descriptor = { pieces: { Piece } }

local function piece(name: string, shape: Enum.PartType, size: Vector3, position: Vector3, color: Color3, yaw: number?, roll: number?): Piece
	return { name = name, shape = shape, size = size, offset = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), math.rad(roll or 0)), color = color }
end

local block, ball, cylinder = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local rows: { [string]: Descriptor } = {
	Wood = { pieces = {
		piece("Trunk", cylinder, Vector3.new(2.1, .62, .62), Vector3.new(0, -.16, 0), Color3.fromRGB(145, 83, 41)),
		piece("Fork", cylinder, Vector3.new(1.05, .36, .36), Vector3.new(.35, -.08, -.33), Color3.fromRGB(164, 99, 49), 42),
		piece("Twig", cylinder, Vector3.new(.7, .25, .25), Vector3.new(-.45, -.08, .26), Color3.fromRGB(127, 71, 37), 48),
		piece("CutEnd", cylinder, Vector3.new(.035, .53, .53), Vector3.new(1.06, -.16, 0), Color3.fromRGB(240, 191, 113)),
		piece("ForkCutEnd", cylinder, Vector3.new(.035, .29, .29), Vector3.new(.75, -.08, -.69), Color3.fromRGB(244, 203, 135), 42),
	} },
	Stone = { pieces = {
		(function(): Piece
			local rock = piece("Stone", block, Vector3.one, Vector3.new(0, -.35, 0), Color3.fromRGB(112, 134, 153), 28, 5)
			rock.material = Enum.Material.Slate
			rock.meshType = Enum.MeshType.Sphere
			rock.meshScale = Vector3.new(1.45, .75, 1.2)
			return rock
		end)(),
	} },
	ScrapMetal = { pieces = {
		piece("SteelPlate", block, Vector3.new(1.65, .18, .57), Vector3.new(0, -.15, .04), Color3.fromRGB(107, 148, 176), -25),
		piece("CrossPlate", block, Vector3.new(1.48, .16, .53), Vector3.new(0, .02, -.03), Color3.fromRGB(165, 195, 210), 42),
		piece("OrangeEdge", block, Vector3.new(.22, .26, .59), Vector3.new(-.51, .06, .43), Color3.fromRGB(236, 151, 56), 42),
		piece("Bolt", cylinder, Vector3.new(.16, .42, .42), Vector3.new(.05, .19, 0), Color3.fromRGB(57, 79, 104), 0, 90),
	} },
	OldCan = { pieces = {
		piece("CanBody", cylinder, Vector3.new(1.36, .92, .92), Vector3.zero, Color3.fromRGB(225, 231, 218)),
		piece("BottomRim", cylinder, Vector3.new(.11, 1, 1), Vector3.new(-.7, 0, 0), Color3.fromRGB(70, 96, 116)),
		piece("TopRim", cylinder, Vector3.new(.11, 1, 1), Vector3.new(.7, 0, 0), Color3.fromRGB(98, 129, 147)),
		piece("OrangeLabel", cylinder, Vector3.new(.62, .96, .96), Vector3.zero, Color3.fromRGB(243, 132, 49)),
		piece("PullTab", block, Vector3.new(.05, .29, .15), Vector3.new(.765, .09, 0), Color3.fromRGB(207, 223, 229)),
	} },
}

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function validate(candidate: { [string]: Descriptor }): true
	for resourceId in pairs(Resources.rows) do assert(candidate[resourceId] ~= nil, "resource visual missing: " .. resourceId) end
	for resourceId, descriptor in pairs(candidate) do
		assert(Resources.get(resourceId) ~= nil, "unknown visual resource: " .. resourceId)
		assert(type(descriptor) == "table" and type(descriptor.pieces) == "table", "visual must have pieces")
		assert(#descriptor.pieces >= 1 and #descriptor.pieces <= 5, "resource visuals require 1-5 pieces")
		local names: { [string]: boolean } = {}
		for _, row in ipairs(descriptor.pieces) do
			assert(type(row.name) == "string" and row.name ~= "" and not names[row.name], "piece names must be unique")
			names[row.name] = true
			assert(typeof(row.shape) == "EnumItem" and row.shape.EnumType == Enum.PartType, "invalid piece shape")
			assert(row.className == nil or row.className == "WedgePart", "invalid facet class")
			assert(row.material == nil or (typeof(row.material) == "EnumItem" and row.material.EnumType == Enum.Material), "invalid piece material")
			assert(row.meshType == nil or (typeof(row.meshType) == "EnumItem" and row.meshType.EnumType == Enum.MeshType), "invalid piece mesh type")
			assert((row.meshType == nil) == (row.meshScale == nil), "mesh type and scale must be provided together")
			if row.meshScale then
				assert(row.meshScale.X > 0 and row.meshScale.Y > 0 and row.meshScale.Z > 0, "invalid piece mesh scale")
				assert(finite(row.meshScale.X) and finite(row.meshScale.Y) and finite(row.meshScale.Z), "piece mesh scale must be finite")
			end
			assert(typeof(row.size) == "Vector3" and row.size.X > 0 and row.size.Y > 0 and row.size.Z > 0, "invalid piece size")
			assert(finite(row.size.X) and finite(row.size.Y) and finite(row.size.Z), "piece size must be finite")
			assert(typeof(row.color) == "Color3" and typeof(row.offset) == "CFrame", "invalid piece presentation")
			for _, value in ipairs({ row.offset:GetComponents() }) do assert(finite(value), "piece offset must be finite") end
		end
	end
	return true
end

validate(rows)
for _, descriptor in pairs(rows) do
	for _, row in ipairs(descriptor.pieces) do table.freeze(row) end
	table.freeze(descriptor.pieces)
	table.freeze(descriptor)
end
table.freeze(rows)

local ResourceVisuals = { rows = rows }

function ResourceVisuals.validate(candidate: { [string]: Descriptor }?): true
	return validate(candidate or rows)
end

function ResourceVisuals.decorate(root: BasePart, resourceId: string): Model
	local descriptor = rows[resourceId]
	assert(descriptor ~= nil, "unknown resource visual: " .. tostring(resourceId))
	local previous = root:FindFirstChild("ResourceVisual")
	if previous then previous:Destroy() end
	root.Transparency = 1
	local model = Instance.new("Model")
	model.Name = "ResourceVisual"
	for _, row in ipairs(descriptor.pieces) do
		local art = Instance.new(row.className or "Part") :: BasePart
		art.Name = row.name
		if art:IsA("Part") then art.Shape = row.shape end
		art.Size = row.size
		art.CFrame = root.CFrame * row.offset
		art.Color = row.color
		art.Material = row.material or Enum.Material.SmoothPlastic
		if row.meshType and row.meshScale then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = row.meshType
			mesh.Scale = row.meshScale
			mesh.Parent = art
		end
		art.TopSurface = Enum.SurfaceType.Smooth
		art.BottomSurface = Enum.SurfaceType.Smooth
		art.Anchored = false
		art.Massless = true
		art.CanCollide = false
		art.CanTouch = false
		art.CanQuery = false
		art.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Name = "RootWeld"
		weld.Part0 = root
		weld.Part1 = art
		weld.Parent = art
	end
	model.Parent = root
	return model
end

return table.freeze(ResourceVisuals)
