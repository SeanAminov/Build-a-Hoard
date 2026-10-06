--!strict
-- Stage 2 presentation and replication numbers. Every numeric value is PROTOTYPE BALANCE.

local Stage2Config = {
	dataVersion = 3,
	baseGroundSize = 64,
	expandedGroundSize = 64,
	expansionDuration = 0.5,
	publicPileCap = 120,
	publicCoalesceSeconds = 0.1,
	markerPulseSeconds = 0.4,
	markerBaseColor = Color3.fromRGB(65, 205, 220),
	markerPulseColor = Color3.fromRGB(130, 255, 150),
	pileStartScale = 0.7,
}

local function finite(value: number): boolean return value == value and value > -math.huge and value < math.huge end

function Stage2Config.validate(candidate: any?): true
	local value = candidate or Stage2Config
	assert(type(value) == "table", "Stage 2 config must be a table")
	for _, key in ipairs({ "dataVersion", "baseGroundSize", "expandedGroundSize", "publicPileCap" }) do
		assert(type(value[key]) == "number" and finite(value[key]) and value[key] > 0 and value[key] % 1 == 0, key .. " must be a positive integer")
	end
	for _, key in ipairs({ "expansionDuration", "publicCoalesceSeconds", "markerPulseSeconds", "pileStartScale" }) do
		assert(type(value[key]) == "number" and finite(value[key]) and value[key] > 0, key .. " must be positive and finite")
	end
	assert(value.baseGroundSize == value.expandedGroundSize, "storage upgrades keep the fixed plot footprint")
	assert(value.pileStartScale < 1, "pile animation must start below full scale")
	assert(typeof(value.markerBaseColor) == "Color3" and typeof(value.markerPulseColor) == "Color3", "marker colors must be Color3")
	return true
end

Stage2Config.validate()
return table.freeze(Stage2Config)
