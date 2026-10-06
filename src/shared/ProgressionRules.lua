--!strict
-- Pure authoritative transitions for the shared litter world and each player's private progress.

local RecipeDefinitions = require(script.Parent:WaitForChild("RecipeDefinitions"))
local ResourceDefinitions = require(script.Parent:WaitForChild("ResourceDefinitions"))
local Config = require(script.Parent:WaitForChild("Stage1Config"))
local Stage4Config = require(script.Parent:WaitForChild("Stage4Config"))
local Stage5Config = require(script.Parent:WaitForChild("Stage5Config"))
local SpecialItemDefinitions = require(script.Parent:WaitForChild("SpecialItemDefinitions"))
local TutorialRules = require(script.Parent:WaitForChild("TutorialRules"))

export type ItemRow = { itemId: string, resourceId: string }
export type LitterState = {
	litterId: string,
	resourceId: string,
	position: Vector3,
	yaw: number,
	generation: number,
	available: boolean,
	respawnAt: number?,
}
export type WorldState = {
	revision: number,
	litter: { [string]: LitterState },
	litterOrder: { string },
	basicGemGeneration: number,
	basicGemActive: boolean,
	basicGemNextSpawnAt: number,
}
export type PlayerState = {
	revision: number,
	carry: { ItemRow },
	storedItems: { ItemRow },
	coins: number,
	crafted: { [string]: boolean },
	specialItems: { [string]: number },
	tutorialStep: number,
	trackedRecipeIds: { string },
	expansionLevel: number,
	lastPickup: number?,
	pendingOverflow: boolean,
	overflowToken: number,
	depositToken: number,
	lastDepositCount: number,
	lastDepositPassiveDelta: number,
	collectionBinCounts: { [string]: number },
	collectionBinLastAt: number,
	collectionBinCursor: number,
	collectionBinPending: boolean,
	collectionBinToken: number,
	collectionBinBatchCounts: { [string]: number },
	collectionBinInteracted: boolean,
	afkRewardCursor: number,
	afkNextRewardAt: number?,
	afkProgressSeconds: number,
	afkLastSampleAt: number?,
	afkActive: boolean,
	afkInteracted: boolean,
	generatedItemSequence: number,
	offlineIncomeAt: number,
}

local Rules = {}

local function finite(value: number): boolean return value == value and value > -math.huge and value < math.huge end
local function roundTenths(value: number): number return math.round(value * 10) / 10 end

local function copyItem(row: ItemRow): ItemRow return { itemId = row.itemId, resourceId = row.resourceId } end

local function emptyResourceCounts(): { [string]: number }
	local counts: { [string]: number } = {}
	for _, resourceId in ipairs(Config.resourceOrder) do counts[resourceId] = 0 end
	return counts
end

local function copyResourceCounts(source: { [string]: number }): { [string]: number }
	local counts = emptyResourceCounts()
	for _, resourceId in ipairs(Config.resourceOrder) do counts[resourceId] = math.max(0, math.floor(source[resourceId] or 0)) end
	return counts
end

local function countResources(counts: { [string]: number }): number
	local total = 0
	for _, resourceId in ipairs(Config.resourceOrder) do total += math.max(0, math.floor(counts[resourceId] or 0)) end
	return total
end

function Rules.carryCapacity(state: PlayerState): number
	if state.crafted.ReinforcedCarryRack then return Config.stage3CarryCapacity end
	if state.crafted.CarryRack then return Config.upgradedCarryCapacity end
	return if state.crafted.ScavengerSatchel then Config.beginnerCarryCapacity else Config.startingCarryCapacity
end

function Rules.storageCapacity(state: PlayerState): number
	local capacity = if state.expansionLevel == 1 and state.crafted.HoardCrate then Config.expandedStorageCapacity elseif state.crafted.HoardCrate then Config.upgradedStorageCapacity else Config.startingStorageCapacity
	return if state.crafted.StorageShelves then Config.stage3StorageCapacity else capacity
end

function Rules.walkSpeed(state: PlayerState): number
	if state.crafted.TrailBoots2 then return Config.stage3WalkSpeed end
	return if state.crafted.TrailBoots then Config.upgradedWalkSpeed else Config.startingWalkSpeed
end

function Rules.workshopTier(state: PlayerState): number
	return if state.crafted.WorkshopLevel2 then 2 else 1
end

function Rules.hoardCounts(state: PlayerState): { [string]: number }
	local counts: { [string]: number } = {}
	for _, resourceId in ipairs(Config.resourceOrder) do counts[resourceId] = 0 end
	for _, item in ipairs(state.storedItems) do counts[item.resourceId] = (counts[item.resourceId] or 0) + 1 end
	return counts
end

function Rules.tutorialStep(state: PlayerState): number
	return TutorialRules.step(Config.resourceOrder, state.carry, Rules.hoardCounts(state), state.crafted, state.trackedRecipeIds, state.tutorialStep)
end

local function advanceDurableTutorial(state: PlayerState)
	local current = Rules.tutorialStep(state)
	-- COLLECT/DEPOSIT guidance is derived from unsaved carry. Only deposit and later milestones persist.
	if current >= 2 and current > state.tutorialStep then state.tutorialStep = current end
end

function Rules.passivePerSecond(state: PlayerState): number
	local total = 0
	for _, item in ipairs(state.storedItems) do
		local definition = ResourceDefinitions.get(item.resourceId)
		if definition ~= nil then total += definition.passivePerSecond end
	end
	return roundTenths(total)
end

function Rules.newWorld(seed: number, now: number?): WorldState
	local litter: { [string]: LitterState } = {}
	local order: { string } = {}
	for _, row in ipairs(Config.generateLitter(seed)) do
		litter[row.litterId] = {
			litterId = row.litterId,
			resourceId = row.resourceId,
			position = row.position,
			yaw = row.yaw,
			generation = 1,
			available = true,
			respawnAt = nil,
		}
		table.insert(order, row.litterId)
	end
	local startedAt = now or 0
	return {
		revision = 0,
		litter = litter,
		litterOrder = order,
		basicGemGeneration = 0,
		basicGemActive = false,
		basicGemNextSpawnAt = startedAt + Stage4Config.firstGemDelay,
	}
end

function Rules.newPlayerState(): PlayerState
	return {
		revision = 0,
		carry = {},
		storedItems = {},
		coins = 0,
		crafted = {},
		specialItems = { BasicGem = 0 },
		tutorialStep = 0,
		trackedRecipeIds = {},
		expansionLevel = 0,
		lastPickup = nil,
		pendingOverflow = false,
		overflowToken = 0,
		depositToken = 0,
		lastDepositCount = 0,
		lastDepositPassiveDelta = 0,
		collectionBinCounts = emptyResourceCounts(),
		collectionBinLastAt = 0,
		collectionBinCursor = 0,
		collectionBinPending = false,
		collectionBinToken = 0,
		collectionBinBatchCounts = emptyResourceCounts(),
		collectionBinInteracted = false,
		afkRewardCursor = 0,
		afkNextRewardAt = nil,
		afkProgressSeconds = 0,
		afkLastSampleAt = nil,
		afkActive = false,
		afkInteracted = false,
		generatedItemSequence = 0,
		offlineIncomeAt = 0,
	}
end

function Rules.currentBasicGemId(world: WorldState): string?
	if not world.basicGemActive then return nil end
	return string.format("BasicGem:%d", world.basicGemGeneration)
end

function Rules.spawnBasicGemDue(world: WorldState, now: number): boolean
	assert(type(now) == "number" and finite(now), "now must be finite")
	if world.basicGemActive or now < world.basicGemNextSpawnAt then return false end
	world.basicGemGeneration += 1
	world.basicGemActive = true
	world.revision += 1
	return true
end

function Rules.claimBasicGem(world: WorldState, state: PlayerState, request: any): (boolean, string)
	if type(request) ~= "table" or type(request.itemId) ~= "string" or #request.itemId > 64 then return false, "MALFORMED_ITEM" end
	if request.isOwner ~= true then return false, "NOT_OWNER" end
	if request.alive ~= true then return false, "NOT_ALIVE" end
	if typeof(request.rootPosition) ~= "Vector3" or not finite(request.rootPosition.X) or not finite(request.rootPosition.Y) or not finite(request.rootPosition.Z) then return false, "MALFORMED_POSITION" end
	if type(request.now) ~= "number" or not finite(request.now) then return false, "MALFORMED_TIME" end
	local generationText = string.match(request.itemId, "^BasicGem:(%d+)$")
	if generationText == nil then return false, "MALFORMED_ITEM" end
	if not world.basicGemActive or world.basicGemGeneration ~= tonumber(generationText) then return false, "ITEM_UNAVAILABLE" end
	if (request.rootPosition - Stage4Config.gemPosition).Magnitude > Stage4Config.gemPickupRange then return false, "TOO_FAR" end
	world.basicGemActive = false
	world.basicGemNextSpawnAt = request.now + Stage4Config.gemRespawnTime
	state.specialItems.BasicGem = (state.specialItems.BasicGem or 0) + 1
	world.revision += 1
	state.revision += 1
	return true, "BASIC_GEM_CLAIMED"
end

function Rules.currentItemId(world: WorldState, litterId: string): string?
	local row = world.litter[litterId]
	if row == nil or not row.available then return nil end
	return string.format("%s:%d", litterId, row.generation)
end

function Rules.pickUp(world: WorldState, state: PlayerState, request: any): (boolean, string)
	if type(request) ~= "table" or type(request.itemId) ~= "string" or #request.itemId > 64 then return false, "MALFORMED_ITEM" end
	if request.isOwner ~= true then return false, "NOT_OWNER" end
	if request.alive ~= true then return false, "NOT_ALIVE" end
	if typeof(request.rootPosition) ~= "Vector3" or not finite(request.rootPosition.X) or not finite(request.rootPosition.Y) or not finite(request.rootPosition.Z) then return false, "MALFORMED_POSITION" end
	if type(request.now) ~= "number" or not finite(request.now) then return false, "MALFORMED_TIME" end
	if #state.carry >= Rules.carryCapacity(state) then return false, "CARRY_FULL" end
	if state.lastPickup ~= nil and request.now - state.lastPickup < Config.successfulPickupInterval then return false, "TOO_FAST" end
	local litterId, generationText = string.match(request.itemId, "^([%w_]+):(%d+)$")
	if litterId == nil or generationText == nil then return false, "MALFORMED_ITEM" end
	local row = world.litter[litterId]
	if row == nil or not row.available or row.generation ~= tonumber(generationText) then return false, "ITEM_UNAVAILABLE" end
	if (request.rootPosition - row.position).Magnitude > Config.pickupRange then return false, "TOO_FAR" end
	-- While the tutorial is collecting, allow exactly one spare, so the player cannot end up holding
	-- two of two kinds and one of none. See TutorialRules for why the limit exists.
	if Rules.tutorialStep(state) == 0 and TutorialRules.blocksPickup(TutorialRules.progress(Config.resourceOrder, state.carry, Rules.hoardCounts(state), state.crafted), row.resourceId) then
		return false, "TUTORIAL_SPARE_LIMIT"
	end
	row.available = false
	row.respawnAt = request.now + Config.respawnTime
	state.lastPickup = request.now
	table.insert(state.carry, { itemId = request.itemId, resourceId = row.resourceId })
	world.revision += 1
	state.revision += 1
	return true, "PICKED_UP"
end

function Rules.respawnDue(world: WorldState, now: number): { ItemRow }
	assert(type(now) == "number" and finite(now), "now must be finite")
	local result: { ItemRow } = {}
	for _, litterId in ipairs(world.litterOrder) do
		local row = world.litter[litterId]
		if not row.available and row.respawnAt ~= nil and now >= row.respawnAt then
			row.available = true
			row.generation += 1
			row.respawnAt = nil
			table.insert(result, { itemId = string.format("%s:%d", litterId, row.generation), resourceId = row.resourceId })
		end
	end
	if #result > 0 then world.revision += 1 end
	return result
end

function Rules.deposit(state: PlayerState, insideZone: boolean, alive: boolean, isOwner: boolean): (boolean, string, number, number)
	if not isOwner then return false, "NOT_OWNER", 0, 0 end
	if not alive then return false, "NOT_ALIVE", 0, 0 end
	if not insideZone then return false, "OUTSIDE_ZONE", 0, 0 end
	if #state.carry == 0 then return false, "EMPTY", 0, 0 end
	local free = Rules.storageCapacity(state) - #state.storedItems
	if #state.carry > free then
		-- One overflow event owns one token so the chooser can keep the player's KEEP/SELL choices
		-- while unrelated snapshots, passive income above all, keep moving the general revision.
		if not state.pendingOverflow then state.pendingOverflow = true; state.overflowToken += 1; state.revision += 1 end
		return false, "OVERFLOW", 0, 0
	end
	local count = #state.carry
	local passiveDelta = 0
	for _, item in ipairs(state.carry) do
		table.insert(state.storedItems, item)
		local definition = ResourceDefinitions.get(item.resourceId)
		if definition ~= nil then passiveDelta += definition.passivePerSecond end
	end
	table.clear(state.carry)
	state.pendingOverflow = false
	state.depositToken += 1
	state.lastDepositCount = count
	state.lastDepositPassiveDelta = roundTenths(passiveDelta)
	advanceDurableTutorial(state)
	state.revision += 1
	return true, "DEPOSITED", count, state.lastDepositPassiveDelta
end

function Rules.resolveOverflow(state: PlayerState, keepItemIds: any): (boolean, string, number, number)
	if not state.pendingOverflow then return false, "NO_OVERFLOW", 0, 0 end
	if type(keepItemIds) ~= "table" or #keepItemIds > Rules.carryCapacity(state) then return false, "MALFORMED_SELECTION", 0, 0 end
	local carried: { [string]: ItemRow } = {}
	for _, item in ipairs(state.carry) do carried[item.itemId] = item end
	local keep: { [string]: boolean } = {}
	for _, itemId in ipairs(keepItemIds) do
		if type(itemId) ~= "string" or #itemId > 64 or keep[itemId] or carried[itemId] == nil then return false, "MALFORMED_SELECTION", 0, 0 end
		keep[itemId] = true
	end
	local free = Rules.storageCapacity(state) - #state.storedItems
	if #keepItemIds > free then return false, "TOO_MANY_KEPT", 0, 0 end
	local soldCount = 0
	local soldValue = 0
	local keptCount = 0
	local passiveDelta = 0
	for _, item in ipairs(state.carry) do
		local definition = ResourceDefinitions.get(item.resourceId)
		if keep[item.itemId] then
			table.insert(state.storedItems, item)
			keptCount += 1
			if definition ~= nil then passiveDelta += definition.passivePerSecond end
		else
			soldCount += 1
			if definition ~= nil then soldValue += definition.sellValue end
		end
	end
	table.clear(state.carry)
	state.coins = roundTenths(state.coins + soldValue)
	state.pendingOverflow = false
	if keptCount > 0 then
		state.depositToken += 1
		state.lastDepositCount = keptCount
		state.lastDepositPassiveDelta = roundTenths(passiveDelta)
	end
	advanceDurableTutorial(state)
	state.revision += 1
	return true, "OVERFLOW_RESOLVED", keptCount, soldCount
end

function Rules.cancelOverflow(state: PlayerState): boolean
	if not state.pendingOverflow then return false end
	state.pendingOverflow = false
	state.revision += 1
	return true
end

function Rules.sell(state: PlayerState, resourceId: string, amount: number): (boolean, string, number)
	local definition = ResourceDefinitions.get(resourceId)
	if definition == nil or type(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then return false, "MALFORMED_SELL", 0 end
	if Rules.tutorialStep(state) == 2 and (resourceId ~= TutorialRules.duplicateResourceId(Config.resourceOrder, Rules.hoardCounts(state)) or amount ~= 1) then return false, "TUTORIAL_SELL_ONE", 0 end
	local available = 0
	for _, item in ipairs(state.storedItems) do if item.resourceId == resourceId then available += 1 end end
	if available < amount then return false, "NOT_ENOUGH_ITEMS", 0 end
	local remaining = amount
	for index = #state.storedItems, 1, -1 do
		if remaining > 0 and state.storedItems[index].resourceId == resourceId then
			table.remove(state.storedItems, index)
			remaining -= 1
		end
	end
	local value = amount * definition.sellValue
	state.coins = roundTenths(state.coins + value)
	advanceDurableTutorial(state)
	state.revision += 1
	return true, "SOLD", value
end

function Rules.sellAll(state: PlayerState, resourceId: string): (boolean, string, number)
	local amount = 0
	for _, item in ipairs(state.storedItems) do if item.resourceId == resourceId then amount += 1 end end
	if amount == 0 then return false, "NOT_ENOUGH_ITEMS", 0 end
	return Rules.sell(state, resourceId, amount)
end

local function removeResources(state: PlayerState, requirements: { [string]: number })
	for resourceId, amount in pairs(requirements) do
		local remaining = amount
		for index = #state.storedItems, 1, -1 do
			if remaining > 0 and state.storedItems[index].resourceId == resourceId then table.remove(state.storedItems, index); remaining -= 1 end
		end
	end
end

function Rules.craft(state: PlayerState, recipeId: string, now: number?): (boolean, string)
	if Rules.tutorialStep(state) == 3 and recipeId ~= "AFKSorter" then return false, "TUTORIAL_CRAFT_AFK_SORTER" end
	local recipe = RecipeDefinitions.get(recipeId)
	if recipe == nil then return false, "UNKNOWN_RECIPE" end
	if state.crafted[recipeId] then return false, "ALREADY_CRAFTED" end
	if recipe.requires ~= nil and not state.crafted[recipe.requires] then return false, "MISSING_DEPENDENCY" end
	if recipe.categoryRequires ~= nil and not state.crafted[recipe.categoryRequires] then return false, "MISSING_CATEGORY" end
	if state.coins < recipe.coinCost then return false, "NOT_ENOUGH_COINS" end
	local counts = Rules.hoardCounts(state)
	for resourceId, amount in pairs(recipe.resources) do if (counts[resourceId] or 0) < amount then return false, "NOT_ENOUGH_RESOURCES" end end
	for itemId, amount in pairs(recipe.specialItems or {}) do if (state.specialItems[itemId] or 0) < amount then return false, "NOT_ENOUGH_SPECIAL_ITEMS" end end
	removeResources(state, recipe.resources)
	for itemId, amount in pairs(recipe.specialItems or {}) do state.specialItems[itemId] = (state.specialItems[itemId] or 0) - amount end
	state.coins = roundTenths(state.coins - recipe.coinCost)
	state.crafted[recipeId] = true
	if recipeId == "CollectionBin" then state.collectionBinLastAt = math.max(0, math.floor(now or 0)) end
	for index = #state.trackedRecipeIds, 1, -1 do
		if state.trackedRecipeIds[index] == recipeId then table.remove(state.trackedRecipeIds, index) end
	end
	if recipe.resultKind == "PLOT_EXPANSION" then state.expansionLevel = 1 end
	advanceDurableTutorial(state)
	state.revision += 1
	return true, "CRAFTED"
end

function Rules.track(state: PlayerState, recipeId: string, action: string): (boolean, string)
	if Rules.tutorialStep(state) < 4 then return false, "TUTORIAL_TRACK_LOCKED" end
	if Rules.tutorialStep(state) == 4 and (recipeId ~= "CollectionBin" or action ~= "ADD") then return false, "TUTORIAL_TRACK_COLLECTION_BIN" end
	local recipe = RecipeDefinitions.get(recipeId)
	if recipe == nil then return false, "UNKNOWN_RECIPE" end
	if state.crafted[recipeId] then return false, "ALREADY_CRAFTED" end
	local found: number? = nil
	for index, trackedId in ipairs(state.trackedRecipeIds) do if trackedId == recipeId then found = index; break end end
	if action == "ADD" then
		if found ~= nil then return false, "ALREADY_TRACKED" end
		if #state.trackedRecipeIds >= 3 then return false, "TRACKING_FULL" end
		table.insert(state.trackedRecipeIds, recipeId)
	elseif action == "REMOVE" then
		if found == nil then return false, "NOT_TRACKED" end
		table.remove(state.trackedRecipeIds, found)
	elseif action == "FOCUS" then
		if found == nil then return false, "NOT_TRACKED" end
		if found == 1 then return true, "TRACKED" end
		table.remove(state.trackedRecipeIds, found)
		table.insert(state.trackedRecipeIds, 1, recipeId)
	else
		return false, "MALFORMED_TRACK"
	end
	advanceDurableTutorial(state)
	state.revision += 1
	return true, "TRACKED"
end

local function nextStationResource(state: PlayerState, cursorKind: string): string
	local cursor = if cursorKind == "AFK" then state.afkRewardCursor else state.collectionBinCursor
	local resourceId = Config.resourceOrder[(cursor % #Config.resourceOrder) + 1]
	if cursorKind == "AFK" then state.afkRewardCursor = cursor + 1 else state.collectionBinCursor = cursor + 1 end
	return resourceId
end

local function addGeneratedStoredItem(state: PlayerState, resourceId: string, source: string)
	state.generatedItemSequence += 1
	table.insert(state.storedItems, {
		itemId = string.format("%s:%d", source, state.generatedItemSequence),
		resourceId = resourceId,
	})
end

function Rules.resetAfkProgress(state: PlayerState): boolean
	local changed = state.afkProgressSeconds > 0 or state.afkActive
	state.afkProgressSeconds = 0
	state.afkLastSampleAt = nil
	state.afkNextRewardAt = nil
	state.afkActive = false
	if changed then state.revision += 1 end
	return changed
end

function Rules.tickAfk(state: PlayerState, standing: boolean, now: number): (boolean, string?, string?, number)
	assert(type(now) == "number" and finite(now), "now must be finite")
	local available = state.crafted.AFKSorter == true and standing and not state.pendingOverflow
	if not available then
		state.afkLastSampleAt = nil
		if state.afkActive or state.afkNextRewardAt ~= nil then
			state.afkActive = false
			state.afkNextRewardAt = nil
			state.revision += 1
			return true, "AFK_STOPPED", nil, 0
		end
		return false, nil, nil, 0
	end

	local changed = false
	if not state.afkActive then state.afkActive = true; changed = true end
	if not state.afkInteracted then state.afkInteracted = true; changed = true end
	local interval = Stage5Config.afkRewardInterval
	local previousProgress = state.afkProgressSeconds
	-- Only consecutive eligible samples contribute. Entry, exit and overflow never credit time.
	-- Cap a stalled maintenance sample to one interval: AFK has no offline/catch-up production.
	if state.afkLastSampleAt ~= nil then
		state.afkProgressSeconds += math.clamp(now - state.afkLastSampleAt, 0, interval)
	end
	state.afkLastSampleAt = now
	state.afkNextRewardAt = now + math.max(0, interval - state.afkProgressSeconds)
	if math.floor(previousProgress) ~= math.floor(state.afkProgressSeconds) then changed = true end
	if state.afkProgressSeconds < interval then
		if changed then state.revision += 1 end
		return changed, if previousProgress == state.afkProgressSeconds and changed then "AFK_STARTED" else nil, nil, 0
	end

	state.afkProgressSeconds -= interval
	state.afkNextRewardAt = now + interval - state.afkProgressSeconds
	local resourceId = nextStationResource(state, "AFK")
	local soldValue = 0
	local event = "AFK_STORED"
	if #state.storedItems < Rules.storageCapacity(state) then
		addGeneratedStoredItem(state, resourceId, "AFK")
	else
		local definition = ResourceDefinitions.get(resourceId)
		soldValue = if definition then definition.sellValue else 0
		state.coins = roundTenths(state.coins + soldValue)
		event = "AFK_SOLD"
	end
	state.revision += 1
	return true, event, resourceId, soldValue
end

function Rules.collectionBinTotal(state: PlayerState): number return countResources(state.collectionBinCounts) end

function Rules.reconcileCollectionBin(state: PlayerState, now: number): number
	assert(type(now) == "number" and finite(now), "now must be finite")
	now = math.max(0, math.floor(now))
	if not state.crafted.CollectionBin then return 0 end
	if state.collectionBinLastAt <= 0 then state.collectionBinLastAt = now; return 0 end
	local total = Rules.collectionBinTotal(state)
	if total >= Stage5Config.collectionBinCapacity then state.collectionBinLastAt = now; return 0 end
	local elapsed = math.max(0, now - state.collectionBinLastAt)
	local periods = math.floor(elapsed / Stage5Config.collectionBinInterval)
	if periods <= 0 then return 0 end
	local generated = math.min(periods, Stage5Config.collectionBinCapacity - total)
	for _ = 1, generated do
		local resourceId = nextStationResource(state, "BIN")
		state.collectionBinCounts[resourceId] = (state.collectionBinCounts[resourceId] or 0) + 1
	end
	-- Reaching capacity discards every partial or whole interval left in the elapsed window. This
	-- prevents a player who opens a full offline bin immediately from carrying banked time forward.
	if total + generated >= Stage5Config.collectionBinCapacity then
		state.collectionBinLastAt = now
	else
		state.collectionBinLastAt += periods * Stage5Config.collectionBinInterval
	end
	state.revision += 1
	return generated
end

function Rules.viewCollectionBin(state: PlayerState): (boolean, string)
	if not state.crafted.CollectionBin then return false, "BIN_LOCKED" end
	if not state.collectionBinInteracted then
		state.collectionBinInteracted = true
		state.revision += 1
	end
	return true, "BIN_VIEWED"
end
function Rules.openCollectionBin(state: PlayerState): (boolean, string, number, number)
	if not state.crafted.CollectionBin then return false, "BIN_LOCKED", 0, 0 end
	local total = Rules.collectionBinTotal(state)
	if total == 0 then return false, "BIN_EMPTY", 0, 0 end
	local free = math.max(0, Rules.storageCapacity(state) - #state.storedItems)
	if total <= free then
		for _, resourceId in ipairs(Config.resourceOrder) do
			for _ = 1, state.collectionBinCounts[resourceId] or 0 do addGeneratedStoredItem(state, resourceId, "Bin") end
			state.collectionBinCounts[resourceId] = 0
		end
		state.collectionBinPending = false
		state.collectionBinBatchCounts = emptyResourceCounts()
		state.collectionBinInteracted = true
		state.revision += 1
		return true, "BIN_CLAIMED", total, 0
	end
	if not state.collectionBinPending then
		state.collectionBinPending = true
		state.collectionBinToken += 1
		state.collectionBinBatchCounts = copyResourceCounts(state.collectionBinCounts)
		state.revision += 1
	end
	return false, "BIN_OVERFLOW", 0, 0
end

local function validSelectionCounts(value: any, batch: { [string]: number }): (boolean, { [string]: number })
	if type(value) ~= "table" then return false, emptyResourceCounts() end
	for key in pairs(value) do if type(key) ~= "string" or batch[key] == nil then return false, emptyResourceCounts() end end
	local result = emptyResourceCounts()
	for _, resourceId in ipairs(Config.resourceOrder) do
		local amount = value[resourceId] or 0
		if type(amount) ~= "number" or not finite(amount) or amount < 0 or amount % 1 ~= 0 then return false, emptyResourceCounts() end
		result[resourceId] = amount
	end
	return true, result
end

function Rules.resolveCollectionBin(state: PlayerState, request: any): (boolean, string, number, number, number)
	if not state.collectionBinPending then return false, "NO_BIN_SELECTION", 0, 0, 0 end
	if type(request) ~= "table" or request.token ~= state.collectionBinToken then return false, "STALE_BIN_SELECTION", 0, 0, 0 end
	local validStore, storeCounts = validSelectionCounts(request.storeCounts, state.collectionBinBatchCounts)
	local validSell, sellCounts = validSelectionCounts(request.sellCounts, state.collectionBinBatchCounts)
	if not validStore or not validSell then return false, "MALFORMED_BIN_SELECTION", 0, 0, 0 end
	local storeTotal, sellTotal, soldValue = 0, 0, 0
	for _, resourceId in ipairs(Config.resourceOrder) do
		local selected = storeCounts[resourceId] + sellCounts[resourceId]
		if selected > state.collectionBinBatchCounts[resourceId] or selected > state.collectionBinCounts[resourceId] then return false, "BIN_ITEMS_CHANGED", 0, 0, 0 end
		storeTotal += storeCounts[resourceId]
		sellTotal += sellCounts[resourceId]
		local definition = ResourceDefinitions.get(resourceId)
		if definition then soldValue += sellCounts[resourceId] * definition.sellValue end
	end
	if storeTotal + sellTotal == 0 then return false, "EMPTY_BIN_SELECTION", 0, 0, 0 end
	if storeTotal > Rules.storageCapacity(state) - #state.storedItems then return false, "BIN_STORAGE_CHANGED", 0, 0, 0 end
	for _, resourceId in ipairs(Config.resourceOrder) do
		for _ = 1, storeCounts[resourceId] do addGeneratedStoredItem(state, resourceId, "Bin") end
		state.collectionBinCounts[resourceId] -= storeCounts[resourceId] + sellCounts[resourceId]
	end
	state.coins = roundTenths(state.coins + soldValue)
	state.collectionBinPending = false
	state.collectionBinBatchCounts = emptyResourceCounts()
	state.collectionBinInteracted = true
	state.revision += 1
	return true, "BIN_RESOLVED", storeTotal, sellTotal, soldValue
end

function Rules.cancelCollectionBin(state: PlayerState, token: any?): boolean
	if not state.collectionBinPending then return false end
	if token ~= nil and token ~= state.collectionBinToken then return false end
	state.collectionBinPending = false
	state.collectionBinBatchCounts = emptyResourceCounts()
	state.revision += 1
	return true
end

function Rules.tickIncome(state: PlayerState, ticks: number): number
	assert(type(ticks) == "number" and finite(ticks) and ticks >= 0 and ticks % 1 == 0, "ticks must be a nonnegative integer")
	if ticks == 0 then return 0 end
	local amount = roundTenths(Rules.passivePerSecond(state) * ticks)
	if amount > 0 then state.coins = roundTenths(state.coins + amount); state.revision += 1 end
	return amount
end

function Rules.loseCarry(state: PlayerState): (boolean, string, number)
	if #state.carry == 0 and not state.pendingOverflow then return false, "EMPTY", 0 end
	local count = #state.carry
	table.clear(state.carry)
	state.pendingOverflow = false
	state.revision += 1
	return true, "CARRY_LOST", count
end

function Rules.snapshot(state: PlayerState): any
	local carry = {}
	for _, item in ipairs(state.carry) do table.insert(carry, copyItem(item)) end
	local pileItems = {}
	for index = 1, math.min(#state.storedItems, Config.visiblePileCap) do table.insert(pileItems, copyItem(state.storedItems[index])) end
	return {
		revision = state.revision,
		carry = carry,
		pileItems = pileItems,
		hoardCounts = Rules.hoardCounts(state),
		hoardTotal = #state.storedItems,
		coins = state.coins,
		capacity = Rules.carryCapacity(state),
		storageCapacity = Rules.storageCapacity(state),
		walkSpeed = Rules.walkSpeed(state),
		workshopTier = Rules.workshopTier(state),
		passivePerSecond = Rules.passivePerSecond(state),
		crafted = table.clone(state.crafted),
		specialItemCounts = table.clone(state.specialItems),
		unlockedAreas = { [Stage4Config.portalAreaId] = state.crafted.PortalKey == true },
		tutorialStep = Rules.tutorialStep(state),
		trackedRecipeIds = table.clone(state.trackedRecipeIds),
		tutorialDuplicateResourceId = TutorialRules.duplicateResourceId(Config.resourceOrder, Rules.hoardCounts(state)),
		expansionLevel = state.expansionLevel,
		pendingOverflow = state.pendingOverflow,
		overflowToken = state.overflowToken,
		freeSlots = math.max(0, Rules.storageCapacity(state) - #state.storedItems),
		depositToken = state.depositToken,
		depositCount = state.lastDepositCount,
		depositPassiveDelta = state.lastDepositPassiveDelta,
		collectionBinCounts = copyResourceCounts(state.collectionBinCounts),
		collectionBinTotal = Rules.collectionBinTotal(state),
		collectionBinCapacity = Stage5Config.collectionBinCapacity,
		collectionBinNextAt = state.collectionBinLastAt + Stage5Config.collectionBinInterval,
		collectionBinPending = state.collectionBinPending,
		collectionBinToken = state.collectionBinToken,
		collectionBinBatchCounts = copyResourceCounts(state.collectionBinBatchCounts),
		collectionBinInteracted = state.collectionBinInteracted,
		afkActive = state.afkActive,
		afkNextRewardAt = state.afkNextRewardAt,
		afkProgressSeconds = state.afkProgressSeconds,
		afkRemainingSeconds = math.ceil(Stage5Config.afkRewardInterval - state.afkProgressSeconds),
		afkInteracted = state.afkInteracted,
	}
end

-- Called once inside atomic profile acquisition, before the player can spend the reward.
function Rules.creditOfflineIncome(state: PlayerState, now: number): number
	assert(finite(now) and now >= 0, "offline income requires server time")
	now = math.floor(now)
	local elapsed = if state.offlineIncomeAt > 0 then math.clamp(now - state.offlineIncomeAt, 0, Stage5Config.offlineIncomeCapSeconds) else 0
	local reward = roundTenths(Rules.passivePerSecond(state) * elapsed)
	state.coins = roundTenths(math.min(1e12, state.coins + reward))
	state.offlineIncomeAt = now
	return reward
end

function Rules.serialize(state: PlayerState, now: number?): any
	return {
		version = Stage5Config.dataVersion,
		offlineIncomeAt = now or state.offlineIncomeAt,
		coins = state.coins,
		inventoryCounts = Rules.hoardCounts(state),
		specialItemCounts = table.clone(state.specialItems),
		crafted = table.clone(state.crafted),
		expansionLevel = state.expansionLevel,
		tutorialStep = state.tutorialStep,
		trackedRecipeIds = table.clone(state.trackedRecipeIds),
		collectionBinCounts = copyResourceCounts(state.collectionBinCounts),
		collectionBinLastAt = state.collectionBinLastAt,
		collectionBinCursor = state.collectionBinCursor,
		collectionBinInteracted = state.collectionBinInteracted,
		afkRewardCursor = state.afkRewardCursor,
		afkInteracted = state.afkInteracted,
		generatedItemSequence = state.generatedItemSequence,
	}
end

function Rules.normalize(saved: any): PlayerState
	local state = Rules.newPlayerState()
	if type(saved) ~= "table" then return state end
	if type(saved.offlineIncomeAt) == "number" and finite(saved.offlineIncomeAt) then state.offlineIncomeAt = math.max(0, math.floor(saved.offlineIncomeAt)) end
	if type(saved.coins) == "number" and finite(saved.coins) then state.coins = roundTenths(math.clamp(saved.coins, 0, 1e12)) end
	if type(saved.crafted) == "table" then
		for recipeId, value in pairs(saved.crafted) do if value == true and RecipeDefinitions.get(recipeId) ~= nil then state.crafted[recipeId] = true end end
	end
	if (type(saved.version) ~= "number" or saved.version < 3) and state.crafted.CarryRack then state.crafted.ScavengerSatchel = true end
	if (type(saved.version) == "number" and saved.version >= 2) and saved.expansionLevel == 1 and state.crafted.HoardCrate == true then
		state.expansionLevel = 1
		state.crafted.BiggerPlot = true
	else
		state.expansionLevel = 0
		state.crafted.BiggerPlot = nil
	end
	local changed = true
	while changed do
		changed = false
		for recipeId in pairs(state.crafted) do
			local recipe = RecipeDefinitions.get(recipeId)
			if recipe ~= nil and ((recipe.requires ~= nil and not state.crafted[recipe.requires]) or (recipe.categoryRequires ~= nil and not state.crafted[recipe.categoryRequires])) then
				state.crafted[recipeId] = nil
				changed = true
			end
		end
	end
	if type(saved.version) == "number" and saved.version >= 3 then
		local rawStep = if type(saved.tutorialStep) == "number" and finite(saved.tutorialStep) then math.floor(saved.tutorialStep) else 0
		if type(saved.version) == "number" and saved.version >= 5 then
			state.tutorialStep = math.clamp(rawStep, 0, TutorialRules.completeStep)
		elseif rawStep >= TutorialRules.completeStep then
			state.tutorialStep = TutorialRules.completeStep
		else
			state.tutorialStep = if rawStep <= 2 then math.clamp(rawStep, 0, 2) else 3
		end
		if type(saved.trackedRecipeIds) == "table" then
			local seen: { [string]: boolean } = {}
			for _, recipeId in ipairs(saved.trackedRecipeIds) do
				if #state.trackedRecipeIds >= 3 then break end
				if type(recipeId) == "string" and RecipeDefinitions.get(recipeId) ~= nil and not state.crafted[recipeId] and not seen[recipeId] then
					seen[recipeId] = true
					table.insert(state.trackedRecipeIds, recipeId)
				end
			end
		end
	else
		-- Existing saves have already learned the loop and must never be re-tutorialised.
		state.tutorialStep = TutorialRules.completeStep
	end
	if (type(saved.version) == "number" and saved.version >= 4) and type(saved.specialItemCounts) == "table" then
		for _, definition in ipairs(SpecialItemDefinitions.ordered()) do
			local raw = saved.specialItemCounts[definition.id]
			if type(raw) == "number" and finite(raw) then state.specialItems[definition.id] = math.clamp(math.floor(raw), 0, 999) end
		end
	end
	if type(saved.version) == "number" and saved.version >= 5 then
		if type(saved.collectionBinCounts) == "table" then
			local remainingBin = Stage5Config.collectionBinCapacity
			for _, resourceId in ipairs(Config.resourceOrder) do
				local raw = saved.collectionBinCounts[resourceId]
				local amount = if type(raw) == "number" and finite(raw) then math.clamp(math.floor(raw), 0, remainingBin) else 0
				state.collectionBinCounts[resourceId] = amount
				remainingBin -= amount
			end
		end
		for _, key in ipairs({ "collectionBinLastAt", "collectionBinCursor", "afkRewardCursor", "generatedItemSequence" }) do
			local raw = saved[key]
			if type(raw) == "number" and finite(raw) then state[key] = math.clamp(math.floor(raw), 0, 1e12) end
		end
		state.collectionBinInteracted = saved.collectionBinInteracted == true
		state.afkInteracted = saved.afkInteracted == true
	end
	local counts = if type(saved.inventoryCounts) == "table" then saved.inventoryCounts else {}
	local remaining = Rules.storageCapacity(state)
	for _, resourceId in ipairs(Config.resourceOrder) do
		local raw = counts[resourceId]
		local amount = if type(raw) == "number" and finite(raw) then math.clamp(math.floor(raw), 0, remaining) else 0
		for index = 1, amount do table.insert(state.storedItems, { itemId = string.format("Saved:%s:%d", resourceId, index), resourceId = resourceId }) end
		remaining -= amount
	end
	return state
end

function Rules.assignLowest(owners: { [number]: number }, userId: number): number?
	for plotId = 1, 4 do if owners[plotId] == nil or owners[plotId] == 0 then owners[plotId] = userId; return plotId end end
	return nil
end

function Rules.releasePlot(owners: { [number]: number }, userId: number): number?
	for plotId = 1, 4 do if owners[plotId] == userId then owners[plotId] = 0; return plotId end end
	return nil
end

return table.freeze(Rules)
