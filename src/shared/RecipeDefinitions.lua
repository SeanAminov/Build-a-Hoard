--!strict
-- Recipes are data rows so the server and UI read one validated contract.

local ResourceDefinitions = require(script.Parent:WaitForChild("ResourceDefinitions"))
local SpecialItemDefinitions = require(script.Parent:WaitForChild("SpecialItemDefinitions"))

export type RecipeDefinition = {
	id: string,
	displayName: string,
	coinCost: number,
	resources: { [string]: number },
	specialItems: { [string]: number }?,
	resultKind: string,
	resultValue: number,
	resultBase: number?,
	requires: string?,
	workbenchTab: string,
	category: string,
	categoryRequires: string?,
	order: number,
}

local rows: { [string]: RecipeDefinition } = {
	AFKSorter = { id = "AFKSorter", displayName = "AFK Sorter", coinCost = 1, resources = { Wood = 1, Stone = 1, ScrapMetal = 1, OldCan = 1 }, resultKind = "BUILDING_UNLOCK", resultValue = 1, resultBase = nil, requires = nil, workbenchTab = "BUILDINGS", category = "STARTER", categoryRequires = nil, order = 1 },
	CollectionBin = { id = "CollectionBin", displayName = "Collection Bin", coinCost = 25, resources = { Wood = 2, Stone = 1, ScrapMetal = 1, OldCan = 1 }, resultKind = "BUILDING_UNLOCK", resultValue = 1, resultBase = nil, requires = nil, workbenchTab = "BUILDINGS", category = "STARTER", categoryRequires = nil, order = 2 },
	ScavengerSatchel = { id = "ScavengerSatchel", displayName = "Scavenger Satchel", coinCost = 50, resources = { Wood = 3, ScrapMetal = 2, OldCan = 1 }, resultKind = "CARRY_CAPACITY", resultValue = 8, resultBase = 5, requires = nil, workbenchTab = "UPGRADES", category = "STARTER", categoryRequires = nil, order = 3 },
	CarryRack = { id = "CarryRack", displayName = "Better Carry Rack", coinCost = 250, resources = { Wood = 5, ScrapMetal = 3 }, resultKind = "CARRY_CAPACITY", resultValue = 10, resultBase = 8, requires = "ScavengerSatchel", workbenchTab = "UPGRADES", category = "STARTER", categoryRequires = nil, order = 4 },
	TrailBoots = { id = "TrailBoots", displayName = "Trail Boots", coinCost = 300, resources = { Wood = 3, Stone = 5 }, resultKind = "WALK_SPEED", resultValue = 21.6, resultBase = 20, requires = nil, workbenchTab = "UPGRADES", category = "STARTER", categoryRequires = nil, order = 5 },
	HoardCrate = { id = "HoardCrate", displayName = "Hoard Crate", coinCost = 500, resources = { Wood = 8, ScrapMetal = 5 }, resultKind = "STORAGE_CAPACITY", resultValue = 70, resultBase = 60, requires = nil, workbenchTab = "UPGRADES", category = "STARTER", categoryRequires = nil, order = 6 },
	BiggerPlot = { id = "BiggerPlot", displayName = "Hoard Expansion", coinCost = 800, resources = { Wood = 20, Stone = 15, ScrapMetal = 12, OldCan = 5 }, resultKind = "PLOT_EXPANSION", resultValue = 1, resultBase = nil, requires = "HoardCrate", workbenchTab = "UPGRADES", category = "STARTER", categoryRequires = nil, order = 7 },
	WorkshopLevel2 = { id = "WorkshopLevel2", displayName = "Workshop Level 2", coinCost = 1000, resources = { Wood = 20, Stone = 15, ScrapMetal = 12, OldCan = 5 }, resultKind = "WORKSHOP_TIER", resultValue = 2, resultBase = 1, requires = "BiggerPlot", workbenchTab = "UPGRADES", category = "STARTER", categoryRequires = nil, order = 8 },
	ReinforcedCarryRack = { id = "ReinforcedCarryRack", displayName = "Reinforced Carry Rack", coinCost = 800, resources = { Wood = 15, ScrapMetal = 10, OldCan = 4 }, resultKind = "CARRY_CAPACITY", resultValue = 12, resultBase = 10, requires = "CarryRack", workbenchTab = "UPGRADES", category = "WORKSHOP_2", categoryRequires = "WorkshopLevel2", order = 9 },
	TrailBoots2 = { id = "TrailBoots2", displayName = "Trail Boots II", coinCost = 800, resources = { Wood = 10, Stone = 15, ScrapMetal = 6 }, resultKind = "WALK_SPEED", resultValue = 23.2, resultBase = 21.6, requires = "TrailBoots", workbenchTab = "UPGRADES", category = "WORKSHOP_2", categoryRequires = "WorkshopLevel2", order = 10 },
	StorageShelves = { id = "StorageShelves", displayName = "Storage Shelves", coinCost = 1200, resources = { Wood = 20, Stone = 12, ScrapMetal = 15, OldCan = 8 }, resultKind = "STORAGE_CAPACITY", resultValue = 120, resultBase = 100, requires = "HoardCrate", workbenchTab = "UPGRADES", category = "WORKSHOP_2", categoryRequires = "WorkshopLevel2", order = 11 },
	PortalKey = { id = "PortalKey", displayName = "Junkyard Portal Key", coinCost = 2000, resources = { Wood = 25, Stone = 20, ScrapMetal = 18, OldCan = 10 }, specialItems = { BasicGem = 1 }, resultKind = "AREA_UNLOCK", resultValue = 2, resultBase = nil, requires = nil, workbenchTab = "UPGRADES", category = "WORKSHOP_2", categoryRequires = "WorkshopLevel2", order = 12 },
}

local validKinds = { CARRY_CAPACITY = true, WALK_SPEED = true, STORAGE_CAPACITY = true, PLOT_EXPANSION = true, WORKSHOP_TIER = true, AREA_UNLOCK = true, BUILDING_UNLOCK = true }
local validCategories = { STARTER = true, WORKSHOP_2 = true }
local validTabs = { BUILDINGS = true, UPGRADES = true }

local function validate(candidate: { [string]: RecipeDefinition }, expectedCount: number?): true
	assert(type(candidate) == "table", "recipes must be a table")
	local count = 0
	local orders: { [number]: boolean } = {}
	for key, row in pairs(candidate) do
		count += 1
		assert(type(key) == "string" and key ~= "" and row.id == key, "recipe id must match its key")
		assert(type(row.displayName) == "string" and row.displayName ~= "", "recipe needs a display name")
		assert(type(row.coinCost) == "number" and row.coinCost >= 0 and row.coinCost % 1 == 0, "recipe coinCost must be a nonnegative integer")
		assert(type(row.resources) == "table", "recipe resources must be a table")
		local ingredientCount = 0
		for resourceId, amount in pairs(row.resources) do
			ingredientCount += 1
			assert(ResourceDefinitions.get(resourceId) ~= nil, "recipe has an unknown resource")
			assert(type(amount) == "number" and amount > 0 and amount % 1 == 0, "recipe resource amounts must be positive integers")
		end
		assert(ingredientCount > 0, "recipe needs at least one resource")
		if row.specialItems ~= nil then
			for itemId, amount in pairs(row.specialItems) do
				assert(SpecialItemDefinitions.get(itemId) ~= nil, "recipe has an unknown special item")
				assert(type(amount) == "number" and amount > 0 and amount % 1 == 0, "recipe special item amounts must be positive integers")
			end
		end
		assert(validKinds[row.resultKind] == true, "recipe resultKind is invalid")
		assert(type(row.resultValue) == "number" and row.resultValue > 0, "recipe resultValue must be positive")
		assert(row.resultBase == nil or (type(row.resultBase) == "number" and row.resultBase >= 0 and row.resultValue > row.resultBase), "recipe resultBase is invalid")
		assert(row.requires == nil or (type(row.requires) == "string" and row.requires ~= key), "recipe dependency is invalid")
		assert(validTabs[row.workbenchTab] == true, "recipe workbenchTab is invalid")
		assert(validCategories[row.category] == true, "recipe category is invalid")
		assert(row.categoryRequires == nil or (type(row.categoryRequires) == "string" and row.categoryRequires ~= key), "recipe category dependency is invalid")
		assert(type(row.order) == "number" and row.order > 0 and row.order % 1 == 0 and not orders[row.order], "recipe order must be a unique positive integer")
		orders[row.order] = true
	end
	if expectedCount ~= nil then assert(count == expectedCount, "unexpected recipe count") end
	for _, row in pairs(candidate) do
		assert(row.requires == nil or candidate[row.requires] ~= nil, "recipe dependency is unknown")
		assert(row.categoryRequires == nil or candidate[row.categoryRequires] ~= nil, "recipe category dependency is unknown")
	end
	return true
end

validate(rows, 12)
for _, row in pairs(rows) do table.freeze(row.resources); if row.specialItems then table.freeze(row.specialItems) end; table.freeze(row) end
table.freeze(rows)

local RecipeDefinitions = { rows = rows }
function RecipeDefinitions.get(recipeId: string): RecipeDefinition? return rows[recipeId] end
function RecipeDefinitions.validate(candidate: { [string]: RecipeDefinition }?, expectedCount: number?): true return validate(candidate or rows, expectedCount or 12) end
function RecipeDefinitions.ordered(): { RecipeDefinition }
	local result = {}
	for _, row in pairs(rows) do table.insert(result, row) end
	table.sort(result, function(a, b) return a.order < b.order end)
	return result
end
return table.freeze(RecipeDefinitions)
