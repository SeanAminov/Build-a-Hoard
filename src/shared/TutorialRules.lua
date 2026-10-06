--!strict
--[[
	The collecting step, in one place so the server and the client cannot disagree about it.

	The player gathers one of every resource plus a single spare: five objects in all. The spare is
	what they sell to afford their first upgrade, and that only works if it duplicates something they
	already hold. Two Wood is fine; two Wood and two Stone leaves them a type short and the tutorial
	stalls. So the same rule that tells the arrow where to point also tells the server which pickup to
	refuse, rather than the two drifting apart.
]]

local TutorialRules = {}

-- PROTOTYPE BALANCE: one of each of the four resources, plus one spare to sell.
local TARGET_ITEMS = 5
local COMPLETE = 5

export type Progress = {
	counts: { [string]: number },
	total: number,
	wanted: { [string]: boolean },
	remaining: number,
	missingTypes: number,
	done: boolean,
	active: boolean,
}

function TutorialRules.progress(resourceOrder: { string }, carry: { any }?, hoardCounts: { [string]: number }?, crafted: { [string]: boolean }?): Progress
	local counts: { [string]: number } = {}
	for _, resourceId in ipairs(resourceOrder) do counts[resourceId] = 0 end
	for resourceId, amount in pairs(hoardCounts or {}) do
		if counts[resourceId] ~= nil and type(amount) == "number" and amount > 0 then
			counts[resourceId] += math.floor(amount)
		end
	end
	for _, item in ipairs(carry or {}) do
		if type(item) == "table" and type(item.resourceId) == "string" and counts[item.resourceId] ~= nil then
			counts[item.resourceId] += 1
		end
	end

	local total = 0
	local missingTypes = 0
	local wanted: { [string]: boolean } = {}
	for _, resourceId in ipairs(resourceOrder) do
		total += counts[resourceId]
		if counts[resourceId] == 0 then
			wanted[resourceId] = true
			missingTypes += 1
		end
	end
	local done = missingTypes == 0 and total >= TARGET_ITEMS
	-- Once every type is held, any resource at all will do as the spare.
	if missingTypes == 0 and not done then
		for _, resourceId in ipairs(resourceOrder) do wanted[resourceId] = true end
	end
	local hasCrafted = false
	for _ in pairs(crafted or {}) do hasCrafted = true; break end

	return {
		counts = counts,
		total = total,
		wanted = if done then {} else wanted,
		remaining = math.max(TARGET_ITEMS - total, missingTypes),
		missingTypes = missingTypes,
		done = done,
		active = not hasCrafted and not done,
	}
end

-- One spare only: refuse a resource the player already holds once something is already doubled.
function TutorialRules.blocksPickup(progress: Progress, resourceId: string): boolean
	if not progress.active then return false end
	local held = progress.counts[resourceId]
	if held == nil or held == 0 then return false end
	for _, amount in pairs(progress.counts) do
		if amount >= 2 then return true end
	end
	return false
end

local function totalCounts(resourceOrder: { string }, counts: { [string]: number }?): (number, boolean)
	local total = 0
	local everyType = true
	for _, resourceId in ipairs(resourceOrder) do
		local amount = math.max(0, math.floor((counts or {})[resourceId] or 0))
		total += amount
		if amount < 1 then everyType = false end
	end
	return total, everyType
end

-- Returns the one tutorial-safe item to sell after five objects are deposited.
function TutorialRules.duplicateResourceId(resourceOrder: { string }, hoardCounts: { [string]: number }?): string?
	for _, resourceId in ipairs(resourceOrder) do
		if ((hoardCounts or {})[resourceId] or 0) > 1 then return resourceId end
	end
	return nil
end

-- The visible step is derived from real state and cannot fall below the durable saved milestone.
-- Step 1 is intentionally not durable: carry is not saved, so leaving before deposit resumes COLLECT.
function TutorialRules.step(
	resourceOrder: { string },
	carry: { any }?,
	hoardCounts: { [string]: number }?,
	crafted: { [string]: boolean }?,
	trackedRecipeIds: { string }?,
	storedStep: number?
): number
	local raw = if type(storedStep) == "number" then storedStep else 0
	local result = math.clamp(math.floor(raw), 0, COMPLETE)
	if result >= COMPLETE then return COMPLETE end

	local collect = TutorialRules.progress(resourceOrder, carry, hoardCounts, {})
	if result == 0 and collect.done then result = 1 end
	local storedTotal, everyStoredType = totalCounts(resourceOrder, hoardCounts)
	if result <= 1 and everyStoredType and storedTotal >= TARGET_ITEMS then result = 2 end
	if result <= 2 and everyStoredType and storedTotal == #resourceOrder then result = 3 end
	if result <= 3 and (crafted or {}).AFKSorter == true then result = 4 end
	if result <= 4 then
		for _, recipeId in ipairs(trackedRecipeIds or {}) do
			if recipeId == "CollectionBin" then result = COMPLETE; break end
		end
	end
	return result
end

TutorialRules.targetItems = TARGET_ITEMS
TutorialRules.completeStep = COMPLETE

return table.freeze(TutorialRules)
