--!strict
-- Every number in this module is PROTOTYPE BALANCE for early plot stations.

local Stage5Config = {
	dataVersion = 6,
	offlineIncomeCapSeconds = 3 * 60 * 60,
	afkRewardInterval = 60,
	collectionBinInterval = 900,
	collectionBinCapacity = 12,
	stationInteractionRange = 9,
	stationSurfaceClearance = 0.08,
	afkZoneLocalPosition = Vector3.new(-17, 3, 18),
	afkZoneSize = Vector3.new(14, 6, 14),
	collectionBinLocalPosition = Vector3.new(17, 2.5, 18),
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validate(candidate: any): true
	assert(type(candidate) == "table", "Stage 5 config must be a table")
	assert(candidate.dataVersion == 6, "Save dataVersion must be 6")
	for _, key in ipairs({ "afkRewardInterval", "collectionBinInterval", "collectionBinCapacity", "stationInteractionRange" }) do
		local value = candidate[key]
		assert(type(value) == "number" and finite(value) and value > 0 and value % 1 == 0, key .. " must be a positive integer")
	end
	assert(candidate.collectionBinInterval * candidate.collectionBinCapacity == 10800, "Collection Bin must fill from empty in exactly three hours")
	assert(type(candidate.stationSurfaceClearance) == "number" and finite(candidate.stationSurfaceClearance) and candidate.stationSurfaceClearance > 0, "stationSurfaceClearance must be positive and finite")
	assert(typeof(candidate.afkZoneLocalPosition) == "Vector3", "afkZoneLocalPosition must be a Vector3")
	assert(typeof(candidate.afkZoneSize) == "Vector3" and candidate.afkZoneSize.X > 0 and candidate.afkZoneSize.Y > 0 and candidate.afkZoneSize.Z > 0, "afkZoneSize must be positive")
	assert(typeof(candidate.collectionBinLocalPosition) == "Vector3", "collectionBinLocalPosition must be a Vector3")
	return true
end

validate(Stage5Config)
function Stage5Config.validate(candidate: any?): true return validate(candidate or Stage5Config) end
return table.freeze(Stage5Config)
