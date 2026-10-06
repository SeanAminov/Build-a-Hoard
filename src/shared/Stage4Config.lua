--!strict
-- Every number here is PROTOTYPE BALANCE for the first-zone special drop and area unlock.

local Stage4Config = {
	dataVersion = 4,
	firstGemDelay = 300,
	gemRespawnTime = 300,
	gemPickupRange = 8,
	gemPosition = Vector3.new(0, 3.25, 0),
	gemSize = Vector3.new(3.5, 3.5, 3.5),
	portalAreaId = "Zone2",
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validate(candidate: any): true
	assert(type(candidate) == "table", "Stage 4 config must be a table")
	assert(candidate.dataVersion == 4, "Stage 4 dataVersion must be 4")
	for _, key in ipairs({ "firstGemDelay", "gemRespawnTime", "gemPickupRange" }) do
		assert(type(candidate[key]) == "number" and finite(candidate[key]) and candidate[key] > 0, key .. " must be positive and finite")
	end
	assert(candidate.firstGemDelay == 300 and candidate.gemRespawnTime == 300, "Basic Gem timers must remain five minutes")
	assert(typeof(candidate.gemPosition) == "Vector3", "gemPosition must be a Vector3")
	assert(typeof(candidate.gemSize) == "Vector3" and candidate.gemSize.X > 0 and candidate.gemSize.Y > 0 and candidate.gemSize.Z > 0, "gemSize must be positive")
	assert(type(candidate.portalAreaId) == "string" and candidate.portalAreaId ~= "", "portalAreaId is required")
	return true
end

validate(Stage4Config)
function Stage4Config.validate(candidate: any?): true return validate(candidate or Stage4Config) end
return table.freeze(Stage4Config)
