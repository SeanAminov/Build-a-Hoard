--!strict
--[[
	Prototype resources are intentionally plain Parts. Keeping gameplay, economy and presentation data in one
	validated catalogue lets later art replace the placeholders without changing collection rules.
]]

export type ResourceDefinition = {
	id: string,
	displayName: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	sellValue: number,
	passivePerSecond: number,
	order: number,
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validateRows(rows: { [string]: ResourceDefinition }): true
	assert(type(rows) == "table", "resource definitions must be a table")
	local count = 0
	for key, row in pairs(rows) do
		count += 1
		assert(type(key) == "string" and key ~= "", "resource key must be a nonempty string")
		assert(type(row) == "table", string.format("resource %s must be a table", key))
		assert(row.id == key, string.format("resource %s id must equal its key", key))
		assert(type(row.displayName) == "string" and row.displayName ~= "", string.format("resource %s needs a display name", key))
		assert(typeof(row.shape) == "EnumItem" and row.shape.EnumType == Enum.PartType, string.format("resource %s needs a PartType shape", key))
		assert(typeof(row.size) == "Vector3", string.format("resource %s needs a Vector3 size", key))
		assert(finite(row.size.X) and finite(row.size.Y) and finite(row.size.Z), string.format("resource %s size must be finite", key))
		assert(row.size.X > 0 and row.size.Y > 0 and row.size.Z > 0, string.format("resource %s size must be positive", key))
		assert(typeof(row.color) == "Color3", string.format("resource %s needs a Color3", key))
		assert(type(row.sellValue) == "number" and finite(row.sellValue) and row.sellValue >= 0 and row.sellValue % 1 == 0, string.format("resource %s needs a nonnegative integer sellValue", key))
		assert(type(row.passivePerSecond) == "number" and finite(row.passivePerSecond) and row.passivePerSecond >= 0, string.format("resource %s needs a nonnegative passivePerSecond", key))
		assert(type(row.order) == "number" and row.order >= 1 and row.order % 1 == 0, string.format("resource %s needs a positive integer order", key))
	end
	assert(count == 4, "Stage 1 must define exactly four resources")
	assert(rows.Wood ~= nil and rows.Stone ~= nil and rows.ScrapMetal ~= nil and rows.OldCan ~= nil, "Stage 1 requires Wood, Stone, ScrapMetal and OldCan")
	local orders: { [number]: boolean } = {}
	for _, row in pairs(rows) do assert(not orders[row.order], "resource order must be unique"); orders[row.order] = true end
	return true
end

-- PROTOTYPE BALANCE: placeholder dimensions and colours, not final art.
local definitions: { [string]: ResourceDefinition } = {
	Wood = {
		id = "Wood",
		displayName = "Wood",
		shape = Enum.PartType.Block,
		size = Vector3.new(2, 1, 1),
		color = Color3.fromRGB(124, 92, 70),
		sellValue = 5,
		passivePerSecond = 0.15,
		order = 1,
	},
	Stone = {
		id = "Stone",
		displayName = "Stone",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.6, 1.6, 1.6),
		color = Color3.fromRGB(112, 112, 118),
		sellValue = 8,
		passivePerSecond = 0.15,
		order = 2,
	},
	ScrapMetal = {
		id = "ScrapMetal",
		displayName = "Scrap Metal",
		shape = Enum.PartType.Block,
		size = Vector3.new(1.5, 0.5, 1.5),
		color = Color3.fromRGB(125, 145, 160),
		sellValue = 15,
		passivePerSecond = 0.3,
		order = 3,
	},
	OldCan = {
		id = "OldCan",
		displayName = "Old Can",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.5, 1, 1),
		color = Color3.fromRGB(190, 105, 55),
		sellValue = 25,
		passivePerSecond = 0.45,
		order = 4,
	},
}

validateRows(definitions)
for _, row in pairs(definitions) do
	table.freeze(row)
end
table.freeze(definitions)

local ResourceDefinitions = { rows = definitions }

function ResourceDefinitions.get(resourceId: string): ResourceDefinition?
	return definitions[resourceId]
end

function ResourceDefinitions.validate(candidate: { [string]: ResourceDefinition }?): true
	return validateRows(candidate or definitions)
end

return table.freeze(ResourceDefinitions)
