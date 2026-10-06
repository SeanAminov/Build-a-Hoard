--!strict
--[[
	Every number below is PROTOTYPE BALANCE unless it is an identifier or engine convention.
	The server generates a reproducible, balanced litter scatter for each fresh solo session.
]]

local ResourceDefinitions = require(script.Parent:WaitForChild("ResourceDefinitions"))

export type LitterDefinition = { litterId: string, resourceId: string, position: Vector3, yaw: number }
export type Config = {
	carryCapacity: number,
	visiblePileCap: number,
	promptRange: number,
	pickupRange: number,
	successfulPickupInterval: number,
	respawnTime: number,
	maintenanceInterval: number,
	targetRefreshInterval: number,
	readyInterval: number,
	feedbackLifetime: number,
	depositDropHeight: number,
	depositDropDuration: number,
	walkSpeed: number,
	depositZonePosition: Vector3,
	depositZoneSize: Vector3,
	litterCount: number,
	litterSeedBase: number,
	litterBoundsCenter: Vector3,
	litterBoundsSize: Vector3,
	litterMinimumSpacing: number,
	carryOffsets: { Vector3 },
	pileYaws: { number },
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function positiveInteger(value: number): boolean
	return finite(value) and value > 0 and value % 1 == 0
end

local function validateVector(value: any, label: string, positive: boolean?)
	assert(typeof(value) == "Vector3", label .. " must be a Vector3")
	assert(finite(value.X) and finite(value.Y) and finite(value.Z), label .. " must be finite")
	if positive then
		assert(value.X > 0 and value.Y > 0 and value.Z > 0, label .. " must be positive")
	end
end

local function validateConfig(candidate: Config): true
	assert(type(candidate) == "table", "Stage 0 config must be a table")
	for _, field in { "carryCapacity", "visiblePileCap", "litterCount", "litterSeedBase" } do
		local value = (candidate :: any)[field]
		assert(type(value) == "number" and positiveInteger(value), field .. " must be a positive integer")
	end
	assert(candidate.litterCount % 2 == 0, "litterCount must be even for an exact two-resource split")
	for _, field in { "promptRange", "pickupRange", "successfulPickupInterval", "respawnTime", "maintenanceInterval", "targetRefreshInterval", "readyInterval", "feedbackLifetime", "depositDropHeight", "depositDropDuration", "walkSpeed", "litterMinimumSpacing" } do
		local value = (candidate :: any)[field]
		assert(type(value) == "number" and finite(value) and value > 0, field .. " must be a positive finite number")
	end
	validateVector(candidate.depositZonePosition, "depositZonePosition")
	validateVector(candidate.depositZoneSize, "depositZoneSize", true)
	validateVector(candidate.litterBoundsCenter, "litterBoundsCenter")
	validateVector(candidate.litterBoundsSize, "litterBoundsSize", true)
	assert(candidate.litterMinimumSpacing < math.min(candidate.litterBoundsSize.X, candidate.litterBoundsSize.Z), "litter spacing must fit inside its bounds")
	assert(type(candidate.carryOffsets) == "table" and #candidate.carryOffsets == candidate.carryCapacity, "carryOffsets must match carryCapacity")
	for index, offset in ipairs(candidate.carryOffsets) do
		validateVector(offset, string.format("carryOffsets[%d]", index))
	end
	assert(type(candidate.pileYaws) == "table" and #candidate.pileYaws == 8, "pileYaws must contain eight columns")
	for index, yaw in ipairs(candidate.pileYaws) do
		assert(type(yaw) == "number" and finite(yaw), string.format("pileYaws[%d] must be finite", index))
	end
	assert(candidate.pickupRange >= candidate.promptRange, "server pickup range must cover the visible prompt range")
	return true
end

local config: Config = {
	carryCapacity = 5,
	visiblePileCap = 120,
	promptRange = 6,
	pickupRange = 7,
	successfulPickupInterval = 0.15,
	respawnTime = 8,
	maintenanceInterval = 0.1,
	targetRefreshInterval = 0.1,
	readyInterval = 0.5,
	feedbackLifetime = 1.5,
	depositDropHeight = 2,
	depositDropDuration = 0.25,
	walkSpeed = 20,
	depositZonePosition = Vector3.new(0, 3, 86),
	depositZoneSize = Vector3.new(20, 6, 12),
	litterCount = 72,
	litterSeedBase = 17391,
	litterBoundsCenter = Vector3.new(0, 0, 0),
	litterBoundsSize = Vector3.new(120, 1, 96),
	litterMinimumSpacing = 6,
	carryOffsets = {
		Vector3.new(0, 0.75, 0),
		Vector3.new(0.15, 1.85, 0),
		Vector3.new(-0.15, 2.95, 0),
		Vector3.new(0.15, 4.05, 0),
		Vector3.new(0, 5.15, 0),
	},
	pileYaws = { -20, 15, -10, 25, 0, -28, 18, -8 },
}

local function validateLitter(rows: { LitterDefinition }): true
	assert(type(rows) == "table" and #rows == config.litterCount, string.format("litter must contain exactly %d rows", config.litterCount))
	local half = config.litterBoundsSize / 2
	local seen: { [string]: boolean } = {}
	local counts: { [string]: number } = { Wood = 0, ScrapMetal = 0 }
	local previousType = ""
	local runLength = 0
	for index, row in ipairs(rows) do
		assert(type(row) == "table", string.format("litter[%d] must be a table", index))
		local expectedId = string.format("Litter%02d", index)
		assert(row.litterId == expectedId and not seen[row.litterId], string.format("litter[%d] needs unique ordered id %s", index, expectedId))
		seen[row.litterId] = true
		local definition = ResourceDefinitions.get(row.resourceId)
		assert(definition ~= nil, "unknown resourceId: " .. tostring(row.resourceId))
		validateVector(row.position, string.format("litter[%d].position", index))
		assert(type(row.yaw) == "number" and finite(row.yaw) and row.yaw >= -180 and row.yaw <= 180, string.format("litter[%d].yaw must be between -180 and 180", index))
		assert(math.abs(row.position.X - config.litterBoundsCenter.X) <= half.X and math.abs(row.position.Z - config.litterBoundsCenter.Z) <= half.Z, string.format("litter[%d] lies outside LitterBounds", index))
		assert(math.abs(row.position.Y - definition.size.Y / 2) <= 1e-6, string.format("litter[%d] must rest on the field", index))
		for previousIndex = 1, index - 1 do
			local previous = rows[previousIndex].position
			local distance = (Vector2.new(row.position.X, row.position.Z) - Vector2.new(previous.X, previous.Z)).Magnitude
			assert(distance >= config.litterMinimumSpacing, string.format("litter[%d] overlaps litter[%d]", index, previousIndex))
		end
		counts[row.resourceId] = (counts[row.resourceId] or 0) + 1
		if row.resourceId == previousType then runLength += 1 else previousType, runLength = row.resourceId, 1 end
		assert(runLength <= 2, "litter resource shuffle contains a run longer than two")
	end
	local perType = config.litterCount / 2
	assert(counts.Wood == perType and counts.ScrapMetal == perType, "litter must split evenly between Wood and ScrapMetal")
	return true
end

local function generateLitter(seed: number): { LitterDefinition }
	assert(type(seed) == "number" and finite(seed) and seed % 1 == 0, "litter seed must be a finite integer")
	local random = Random.new(seed)
	local positions: { Vector3 } = {}
	local half = config.litterBoundsSize / 2
	local maximumAttempts = config.litterCount * 1000
	local attempts = 0
	while #positions < config.litterCount and attempts < maximumAttempts do
		attempts += 1
		local candidate = Vector3.new(
			random:NextNumber(config.litterBoundsCenter.X - half.X, config.litterBoundsCenter.X + half.X),
			0,
			random:NextNumber(config.litterBoundsCenter.Z - half.Z, config.litterBoundsCenter.Z + half.Z)
		)
		local accepted = true
		for _, existing in ipairs(positions) do
			if (Vector2.new(candidate.X, candidate.Z) - Vector2.new(existing.X, existing.Z)).Magnitude < config.litterMinimumSpacing then
				accepted = false
				break
			end
		end
		if accepted then table.insert(positions, candidate) end
	end
	assert(#positions == config.litterCount, "could not generate the configured litter scatter")
	table.sort(positions, function(a, b)
		return if a.Z == b.Z then a.X < b.X else a.Z < b.Z
	end)

	local resourceOrder: { string } = {}
	for _ = 1, config.litterCount / 2 do
		if random:NextInteger(0, 1) == 0 then
			table.insert(resourceOrder, "Wood")
			table.insert(resourceOrder, "ScrapMetal")
		else
			table.insert(resourceOrder, "ScrapMetal")
			table.insert(resourceOrder, "Wood")
		end
	end
	local rows: { LitterDefinition } = {}
	for index, position in ipairs(positions) do
		local resourceId = resourceOrder[index]
		local definition = ResourceDefinitions.get(resourceId) :: ResourceDefinitions.ResourceDefinition
		table.insert(rows, {
			litterId = string.format("Litter%02d", index),
			resourceId = resourceId,
			position = Vector3.new(position.X, definition.size.Y / 2, position.Z),
			yaw = random:NextNumber(-180, 180),
		})
	end
	validateLitter(rows)
	return rows
end

validateConfig(config)
table.freeze(config.carryOffsets)
table.freeze(config.pileYaws)

local Stage0Config = {}
for key, value in pairs(config :: any) do
	(Stage0Config :: any)[key] = value
end

function Stage0Config.validate(candidate: Config?): true
	return validateConfig(candidate or config)
end

function Stage0Config.generateLitter(seed: number): { LitterDefinition }
	return generateLitter(seed)
end

function Stage0Config.validateLitter(rows: { LitterDefinition }): true
	return validateLitter(rows)
end

return table.freeze(Stage0Config)
