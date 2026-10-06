--!strict
-- Every numeric setting in this module is PROTOTYPE BALANCE for Stages 1 and 2.

local ResourceDefinitions = require(script.Parent:WaitForChild("ResourceDefinitions"))

export type LitterDefinition = { litterId: string, resourceId: string, position: Vector3, yaw: number }
export type PlotDefinition = { plotId: number, center: Vector3, yaw: number }

local Stage1Config = {
	resourceOrder = { "Wood", "Stone", "ScrapMetal", "OldCan" },
	startingCarryCapacity = 5,
	beginnerCarryCapacity = 8,
	upgradedCarryCapacity = 10,
	stage3CarryCapacity = 12,
	startingStorageCapacity = 60,
	upgradedStorageCapacity = 70,
	expandedStorageCapacity = 100,
	stage3StorageCapacity = 120,
	visiblePileCap = 120,
	promptRange = 6,
	pickupRange = 7,
	workbenchRange = 8,
	successfulPickupInterval = 0.15,
	respawnTime = 8,
	maintenanceInterval = 0.1,
	targetRefreshInterval = 0.1,
	readyInterval = 0.5,
	feedbackLifetime = 2,
	depositDropHeight = 2,
	depositDropDuration = 0.25,
	startingWalkSpeed = 20,
	upgradedWalkSpeed = 21.6,
	stage3WalkSpeed = 23.2,
	passiveTickSeconds = 1,
	autosaveSeconds = 60,
	litterCount = 72,
	litterSeedBase = 17391,
	litterBoundsCenter = Vector3.new(0, 0, 0),
	litterBoundsSize = Vector3.new(120, 1, 96),
	litterMinimumSpacing = 6,
	depositZoneLocalPosition = Vector3.new(0, 3, -24),
	depositZoneSize = Vector3.new(20, 6, 12),
	workbenchLocalPosition = Vector3.new(18, 1.5, -18),
	carryOffsets = {
		Vector3.new(0, 0.75, 0),
		Vector3.new(0.15, 1.85, 0),
		Vector3.new(-0.15, 2.95, 0),
		Vector3.new(0.15, 4.05, 0),
		Vector3.new(0, 5.15, 0),
		Vector3.new(-0.15, 6.25, 0),
		Vector3.new(0.15, 7.35, 0),
		Vector3.new(0, 8.45, 0),
		Vector3.new(-0.15, 9.55, 0),
		Vector3.new(0.15, 10.65, 0),
		Vector3.new(0, 11.75, 0),
		Vector3.new(-0.15, 12.85, 0),
	},
	pileYaws = { -20, 15, -10, 25, 0, -28, 18, -8 },
	plots = {
		{ plotId = 1, center = Vector3.new(0, 0, 110), yaw = 0 },
		{ plotId = 2, center = Vector3.new(120, 0, 0), yaw = 90 },
		{ plotId = 3, center = Vector3.new(0, 0, -110), yaw = 180 },
		{ plotId = 4, center = Vector3.new(-120, 0, 0), yaw = -90 },
	},
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validateVector(value: any, label: string, positive: boolean?)
	assert(typeof(value) == "Vector3", label .. " must be a Vector3")
	assert(finite(value.X) and finite(value.Y) and finite(value.Z), label .. " must be finite")
	if positive then assert(value.X > 0 and value.Y > 0 and value.Z > 0, label .. " must be positive") end
end

local function validateConfig(candidate: any): true
	assert(type(candidate) == "table", "Stage 1 config must be a table")
	for _, key in ipairs({ "startingCarryCapacity", "beginnerCarryCapacity", "upgradedCarryCapacity", "stage3CarryCapacity", "startingStorageCapacity", "upgradedStorageCapacity", "expandedStorageCapacity", "stage3StorageCapacity", "visiblePileCap", "litterCount", "litterSeedBase" }) do
		local value = candidate[key]
		assert(type(value) == "number" and finite(value) and value > 0 and value % 1 == 0, key .. " must be a positive integer")
	end
	for _, key in ipairs({ "promptRange", "pickupRange", "workbenchRange", "successfulPickupInterval", "respawnTime", "maintenanceInterval", "targetRefreshInterval", "readyInterval", "feedbackLifetime", "depositDropHeight", "depositDropDuration", "startingWalkSpeed", "upgradedWalkSpeed", "stage3WalkSpeed", "passiveTickSeconds", "autosaveSeconds", "litterMinimumSpacing" }) do
		local value = candidate[key]
		assert(type(value) == "number" and finite(value) and value > 0, key .. " must be positive and finite")
	end
	assert(candidate.pickupRange >= candidate.promptRange, "server pickup tolerance must cover the prompt")
	assert(candidate.startingCarryCapacity < candidate.beginnerCarryCapacity, "beginner carry upgrade must increase capacity")
	assert(candidate.beginnerCarryCapacity < candidate.upgradedCarryCapacity, "carry upgrade must increase capacity")
	assert(candidate.upgradedCarryCapacity < candidate.stage3CarryCapacity, "Stage 3 carry must increase capacity")
	assert(candidate.startingStorageCapacity < candidate.upgradedStorageCapacity and candidate.upgradedStorageCapacity < candidate.expandedStorageCapacity, "storage upgrades must increase capacity")
	assert(candidate.expandedStorageCapacity < candidate.stage3StorageCapacity, "Stage 3 storage must increase capacity")
	assert(candidate.startingWalkSpeed < candidate.upgradedWalkSpeed, "speed upgrade must increase speed")
	assert(candidate.upgradedWalkSpeed < candidate.stage3WalkSpeed, "Stage 3 speed must increase speed")
	validateVector(candidate.litterBoundsCenter, "litterBoundsCenter")
	validateVector(candidate.litterBoundsSize, "litterBoundsSize", true)
	validateVector(candidate.depositZoneLocalPosition, "depositZoneLocalPosition")
	validateVector(candidate.depositZoneSize, "depositZoneSize", true)
	validateVector(candidate.workbenchLocalPosition, "workbenchLocalPosition")
	assert(type(candidate.resourceOrder) == "table" and #candidate.resourceOrder == 4, "resourceOrder must contain four ids")
	local seenResources: { [string]: boolean } = {}
	for index, resourceId in ipairs(candidate.resourceOrder) do
		assert(ResourceDefinitions.get(resourceId) ~= nil, "unknown resource in resourceOrder")
		assert(not seenResources[resourceId], "resourceOrder contains a duplicate")
		assert((ResourceDefinitions.get(resourceId) :: ResourceDefinitions.ResourceDefinition).order == index, "resourceOrder disagrees with definition order")
		seenResources[resourceId] = true
	end
	assert(type(candidate.carryOffsets) == "table" and #candidate.carryOffsets == candidate.stage3CarryCapacity, "carryOffsets must cover maximum carry")
	for index, offset in ipairs(candidate.carryOffsets) do validateVector(offset, string.format("carryOffsets[%d]", index)) end
	assert(type(candidate.pileYaws) == "table" and #candidate.pileYaws == 8, "pileYaws must contain eight values")
	assert(type(candidate.plots) == "table" and #candidate.plots == 4, "exactly four plots are required")
	local seenPlots: { [number]: boolean } = {}
	for index, plot in ipairs(candidate.plots) do
		assert(plot.plotId == index and not seenPlots[plot.plotId], "plots must be uniquely ordered")
		seenPlots[plot.plotId] = true
		validateVector(plot.center, string.format("plots[%d].center", index))
		assert(type(plot.yaw) == "number" and finite(plot.yaw), "plot yaw must be finite")
	end
	return true
end

local function validateLitter(rows: { LitterDefinition }): true
	assert(type(rows) == "table" and #rows == Stage1Config.litterCount, "litter must contain exactly 72 rows")
	local half = Stage1Config.litterBoundsSize / 2
	local counts: { [string]: number } = {}
	local seen: { [string]: boolean } = {}
	local previousType = ""
	local runLength = 0
	for index, row in ipairs(rows) do
		local expectedId = string.format("Litter%02d", index)
		assert(row.litterId == expectedId and not seen[expectedId], "litter ids must be unique and ordered")
		seen[expectedId] = true
		local definition = ResourceDefinitions.get(row.resourceId)
		assert(definition ~= nil, "unknown litter resource")
		validateVector(row.position, "litter position")
		assert(type(row.yaw) == "number" and finite(row.yaw) and row.yaw >= -180 and row.yaw <= 180, "litter yaw must be within -180..180")
		assert(math.abs(row.position.X - Stage1Config.litterBoundsCenter.X) <= half.X and math.abs(row.position.Z - Stage1Config.litterBoundsCenter.Z) <= half.Z, "litter lies outside bounds")
		assert(math.abs(row.position.Y - definition.size.Y / 2) <= 1e-6, "litter must rest on field")
		for previousIndex = 1, index - 1 do
			local previous = rows[previousIndex].position
			assert((Vector2.new(row.position.X, row.position.Z) - Vector2.new(previous.X, previous.Z)).Magnitude >= Stage1Config.litterMinimumSpacing, "litter spacing is too small")
		end
		counts[row.resourceId] = (counts[row.resourceId] or 0) + 1
		if row.resourceId == previousType then runLength += 1 else previousType, runLength = row.resourceId, 1 end
		assert(runLength <= 2, "litter resource order contains a run over two")
	end
	for _, resourceId in ipairs(Stage1Config.resourceOrder) do assert(counts[resourceId] == 18, "litter must contain 18 of every resource") end
	return true
end

local function generateLitter(seed: number): { LitterDefinition }
	assert(type(seed) == "number" and finite(seed) and seed % 1 == 0, "seed must be a finite integer")
	local random = Random.new(seed)
	local positions: { Vector3 } = {}
	local half = Stage1Config.litterBoundsSize / 2
	local attempts = 0
	while #positions < Stage1Config.litterCount and attempts < Stage1Config.litterCount * 1000 do
		attempts += 1
		local candidate = Vector3.new(
			random:NextNumber(Stage1Config.litterBoundsCenter.X - half.X, Stage1Config.litterBoundsCenter.X + half.X),
			0,
			random:NextNumber(Stage1Config.litterBoundsCenter.Z - half.Z, Stage1Config.litterBoundsCenter.Z + half.Z)
		)
		local accepted = true
		for _, existing in ipairs(positions) do
			if (Vector2.new(candidate.X, candidate.Z) - Vector2.new(existing.X, existing.Z)).Magnitude < Stage1Config.litterMinimumSpacing then accepted = false; break end
		end
		if accepted then table.insert(positions, candidate) end
	end
	assert(#positions == Stage1Config.litterCount, "could not generate configured litter")
	table.sort(positions, function(a, b) return if a.Z == b.Z then a.X < b.X else a.Z < b.Z end)

	local typeOrder: { string } = {}
	for _ = 1, Stage1Config.litterCount / #Stage1Config.resourceOrder do
		local group = table.clone(Stage1Config.resourceOrder)
		for index = #group, 2, -1 do
			local swapIndex = random:NextInteger(1, index)
			group[index], group[swapIndex] = group[swapIndex], group[index]
		end
		for _, resourceId in ipairs(group) do table.insert(typeOrder, resourceId) end
	end
	local rows: { LitterDefinition } = {}
	for index, position in ipairs(positions) do
		local resourceId = typeOrder[index]
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

validateConfig(Stage1Config)
table.freeze(Stage1Config.resourceOrder)
table.freeze(Stage1Config.carryOffsets)
table.freeze(Stage1Config.pileYaws)
for _, plot in ipairs(Stage1Config.plots) do table.freeze(plot) end
table.freeze(Stage1Config.plots)

function Stage1Config.validate(candidate: any?): true return validateConfig(candidate or Stage1Config) end
function Stage1Config.generateLitter(seed: number): { LitterDefinition } return generateLitter(seed) end
function Stage1Config.validateLitter(rows: { LitterDefinition }): true return validateLitter(rows) end
function Stage1Config.plotCFrame(plotId: number): CFrame
	local plot = Stage1Config.plots[plotId]
	assert(plot ~= nil, "unknown plot")
	return CFrame.new(plot.center) * CFrame.Angles(0, math.rad(plot.yaw), 0)
end

return table.freeze(Stage1Config)
