--!strict
-- Converts live prototype outcomes into concrete player-facing upgrade and income copy.

local Stage1Config = require(script.Parent:WaitForChild("Stage1Config"))


local UiPresentation = {}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function UiPresentation.benefitText(recipe: any): string
	assert(type(recipe) == "table", "recipe must be a table")
	if recipe.resultKind == "CARRY_CAPACITY" then
		return string.format("+%d BACKPACK SPACE", recipe.resultValue - (recipe.resultBase or Stage1Config.startingCarryCapacity))
	elseif recipe.resultKind == "WALK_SPEED" then
		local baseline = recipe.resultBase or Stage1Config.startingWalkSpeed
		local percent = math.floor(((recipe.resultValue / baseline) - 1) * 100 + 0.5)
		return string.format("+%d%% WALK SPEED", percent)
	elseif recipe.resultKind == "STORAGE_CAPACITY" then
		return string.format("+%d HOARD SPACE", recipe.resultValue - (recipe.resultBase or Stage1Config.startingStorageCapacity))
	elseif recipe.resultKind == "PLOT_EXPANSION" then
		return string.format(
			"+%d HOARD SPACE",
			Stage1Config.expandedStorageCapacity - Stage1Config.upgradedStorageCapacity
		)
	elseif recipe.resultKind == "WORKSHOP_TIER" then
		return "UNLOCK WORKSHOP II"
	elseif recipe.resultKind == "AREA_UNLOCK" then
		return "UNLOCK ZONE 2 PORTAL"
	elseif recipe.resultKind == "BUILDING_UNLOCK" then
		if recipe.id == "AFKSorter" then return "SORT JUNK WHILE YOU REST" end
		if recipe.id == "CollectionBin" then return "COLLECT JUNK FOR 3 HOURS" end
		return "UNLOCK PLOT BUILDING"
	end
	error("unknown recipe resultKind")
end

function UiPresentation.formatRate(rate: number): string
	assert(type(rate) == "number" and finite(rate) and rate >= 0, "rate must be finite and nonnegative")
	return string.format("+$%.2f/sec", rate)
end

return table.freeze(UiPresentation)
